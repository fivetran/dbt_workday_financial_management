-- Rolls journal activity up to one row per company, ledger account, and calendar month, then
-- carries the last known balance forward across months with no activity.
--
-- Balances are stated in the ledger (functional) currency only. A company may post journal lines
-- in several transaction currencies, and this grain has no currency in it, so summing the
-- transaction-currency amounts here would add one currency to another. The ledger amounts are
-- already converted to the company's single functional currency, which is what a period rollup
-- should report. See DECISIONLOG.
--
-- Cumulative balances are produced for every account, not just balance sheet accounts. Workday
-- exposes ledger_account.type but no account class, and the account hierarchy that would supply
-- one is not in scope for this phase, so there is no routing key to restrict the carry-forward.

with general_ledger as (

    select *
    from {{ ref('workday_financial_management__general_ledger') }}

),

gl_accounting_periods as (

    select *
    from {{ ref('int_workday_financial_management__general_ledger_date_spine') }}

),

gl_period_balance as (

    select
        source_relation,
        company_id,
        company_name,
        ledger_account_id,
        ledger_account_name,
        ledger_account_type,
        ledger_currency_id,
        ledger_currency_code,
        cast({{ dbt.date_trunc("year", "accounting_date") }} as date) as date_year,
        cast({{ dbt.date_trunc("month", "accounting_date") }} as date) as date_month,
        sum(ledger_net_amount) as period_balance
    from general_ledger
    {{ dbt_utils.group_by(10) }}

),

gl_cumulative_balance as (

    select
        *,
        sum(period_balance) over (
            partition by company_id, ledger_account_id {{ fivetran_utils.partition_by_source_relation(package_name='workday_financial_management') }}
            order by date_month rows unbounded preceding) as cumulative_balance
    from gl_period_balance

),

gl_beginning_balance as (

    select
        source_relation,
        company_id,
        company_name,
        ledger_account_id,
        ledger_account_name,
        ledger_account_type,
        ledger_currency_id,
        ledger_currency_code,
        date_year,
        date_month,
        period_balance as period_net_change,
        cumulative_balance - period_balance as period_beginning_balance,
        cumulative_balance as period_ending_balance
    from gl_cumulative_balance

),

gl_patch as (

    select
        gl_accounting_periods.source_relation,
        gl_accounting_periods.company_id,
        gl_accounting_periods.company_name,
        gl_accounting_periods.ledger_account_id,
        gl_accounting_periods.ledger_account_name,
        gl_accounting_periods.ledger_account_type,
        gl_accounting_periods.ledger_currency_id,
        gl_accounting_periods.ledger_currency_code,
        gl_accounting_periods.date_year,
        gl_accounting_periods.period_first_day,
        gl_accounting_periods.period_last_day,
        gl_accounting_periods.period_index,
        gl_beginning_balance.period_net_change,
        gl_beginning_balance.period_beginning_balance,
        case when gl_beginning_balance.period_ending_balance is null and gl_accounting_periods.period_index = 1
            then 0
            else gl_beginning_balance.period_ending_balance
                end as period_ending_balance_starter
    from gl_accounting_periods

    left join gl_beginning_balance
        on gl_beginning_balance.company_id = gl_accounting_periods.company_id
        and gl_beginning_balance.ledger_account_id = gl_accounting_periods.ledger_account_id
        and gl_beginning_balance.source_relation = gl_accounting_periods.source_relation
        and gl_beginning_balance.date_month = gl_accounting_periods.period_first_day

),

gl_value_partition as (

    select
        *,
        sum(case when period_ending_balance_starter is null
            then 0
            else 1
                end) over (
            order by source_relation, company_id, ledger_account_id, period_last_day rows unbounded preceding) as gl_partition
    from gl_patch

),

final as (

    select
        source_relation,
        company_id,
        company_name,
        ledger_account_id,
        ledger_account_name,
        ledger_account_type,
        ledger_currency_id,
        ledger_currency_code,
        date_year,
        period_first_day,
        period_last_day,
        period_index,
        coalesce(period_net_change, 0) as period_net_change,
        coalesce(period_beginning_balance,
            first_value(period_ending_balance_starter) over (
                partition by gl_partition {{ fivetran_utils.partition_by_source_relation(package_name='workday_financial_management') }}
                order by period_last_day rows unbounded preceding)) as period_beginning_balance,
        coalesce(period_ending_balance_starter,
            first_value(period_ending_balance_starter) over (
                partition by gl_partition {{ fivetran_utils.partition_by_source_relation(package_name='workday_financial_management') }}
                order by period_last_day rows unbounded preceding)) as period_ending_balance
    from gl_value_partition

)

select *
from final
