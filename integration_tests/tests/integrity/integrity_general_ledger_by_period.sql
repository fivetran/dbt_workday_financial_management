{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

-- Reconciles the monthly rollup back to the transaction detail it is built from.
--
-- period_net_change should equal the sum of ledger_net_amount for the same company, account, and
-- month. Between that sum and this column the value passes through a date spine cross join, a left
-- join back onto that spine, a coalesce to zero, and a carry-forward window. Any of those can drop
-- a month, land activity on the wrong row, or double it, and none of it would break a build.
--
-- Densified months are expected and must not fail: a month present in the rollup with no matching
-- detail is correct exactly when its net change is zero.
--
-- The 0.01 buffer is the convention across our accounting and finance packages. Keep it that way:
-- a maintainer moving between these packages should not meet a different tolerance in each.
--
-- It is worth knowing what it rests on. Both sides sum the same rows in a different order, and
-- floating-point addition is order-dependent on every warehouse, so the two totals drift apart by
-- roughly sqrt(lines) * 2.2e-16 * gross. A flat 0.01 holds while gross * sqrt(lines) stays under
-- about 4.5e13 for a single company, account and month. Measured 08/18/2026 against a real tenant
-- with 2.2M journal lines and 220.9B in debits, the worst group scored 7.7e10 -- around 590x
-- inside the limit, drifting by 0.000017. Only if a tenant ever approached that limit would this
-- want widening, and then to greatest(0.01, abs(detail_net_change) * 1e-9) rather than to a larger
-- flat number, since a duplicated line is off by a fraction of the total rather than a billionth.

{% set tolerance = 0.01 %}

with general_ledger as (

    select *
    from {{ ref('workday_financial_management__general_ledger') }}

),

by_period as (

    select *
    from {{ ref('workday_financial_management__general_ledger_by_period') }}

),

gl_monthly as (

    select
        source_relation,
        company_id,
        ledger_account_id,
        cast({{ dbt.date_trunc("month", "accounting_date") }} as date) as period_first_day,
        sum(ledger_net_amount) as detail_net_change
    from general_ledger
    {{ dbt_utils.group_by(4) }}

),

period_rollup as (

    select
        source_relation,
        company_id,
        ledger_account_id,
        period_first_day,
        period_net_change
    from by_period

),

compared as (

    select
        coalesce(gl_monthly.source_relation, period_rollup.source_relation) as source_relation,
        coalesce(gl_monthly.company_id, period_rollup.company_id) as company_id,
        coalesce(gl_monthly.ledger_account_id, period_rollup.ledger_account_id) as ledger_account_id,
        coalesce(gl_monthly.period_first_day, period_rollup.period_first_day) as period_first_day,
        gl_monthly.detail_net_change,
        period_rollup.period_net_change
    from gl_monthly

    full outer join period_rollup
        on gl_monthly.source_relation = period_rollup.source_relation
        and gl_monthly.company_id = period_rollup.company_id
        and gl_monthly.ledger_account_id = period_rollup.ledger_account_id
        and gl_monthly.period_first_day = period_rollup.period_first_day

),

final as (

    select
        source_relation,
        company_id,
        ledger_account_id,
        period_first_day,
        detail_net_change,
        period_net_change,
        case
            when detail_net_change is null then 'month in rollup with no detail and a non-zero net change'
            when period_net_change is null then 'month has detail but is missing from the rollup'
            else 'rollup does not match the detail sum'
        end as failure_reason
    from compared

    -- A rollup month with no detail is a densified month and is correct at zero.
    where not (detail_net_change is null and coalesce(period_net_change, 0) = 0)
      and (
            detail_net_change is null
            or period_net_change is null
            or abs(detail_net_change - period_net_change) > {{ tolerance }}
          )

)

select *
from final
