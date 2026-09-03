{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

-- Checks that the ledger-currency amounts are the transaction amounts converted at currency_rate.

with general_ledger as (

    select *
    from {{ ref('workday_financial_management__general_ledger') }}

),

converted as (

    select
        source_relation,
        general_ledger_id,
        journal_entry_id,
        journal_entry_line_index,
        currency_code,
        ledger_currency_code,
        currency_rate,
        debit_amount,
        ledger_debit_amount,
        credit_amount,
        ledger_credit_amount,
        abs(coalesce(ledger_debit_amount, 0) - coalesce(debit_amount, 0) * currency_rate) as debit_difference,
        abs(coalesce(ledger_credit_amount, 0) - coalesce(credit_amount, 0) * currency_rate) as credit_difference
    from general_ledger
    where currency_rate is not null
      and currency_rate != 0

),

final as (

    select *
    from converted
    where debit_difference > greatest(0.01, abs(coalesce(ledger_debit_amount, 0)) * 0.0005)
       or credit_difference > greatest(0.01, abs(coalesce(ledger_credit_amount, 0)) * 0.0005)

)

select *
from final
