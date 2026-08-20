{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

-- Reconciles the monthly rollup back to the transaction detail it is built from.

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
