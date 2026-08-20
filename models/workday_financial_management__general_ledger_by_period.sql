-- One row per company, ledger account, and calendar month, per source relation.
-- All amounts are stated in the ledger (functional) currency named by ledger_currency_code.

with general_ledger_balances as (

    select *
    from {{ ref('int_workday_financial_management__gl_balances') }}

),

final as (

    select
        source_relation,
        {{ dbt_utils.generate_surrogate_key(['company_id', 'ledger_account_id', 'period_first_day', 'source_relation']) }} as general_ledger_by_period_id,
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
        period_net_change,
        period_beginning_balance,
        period_ending_balance
    from general_ledger_balances

)

select *
from final
