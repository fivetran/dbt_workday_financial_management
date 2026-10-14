{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

-- Double-entry invariant: within a journal entry, debits equal credits.

{% set tolerance = 0.01 %}

with general_ledger as (

    select *
    from {{ ref('workday_financial_management__general_ledger') }}

),

entry_totals as (

    select
        source_relation,
        journal_entry_id,
        count(distinct currency_id) as currency_count,
        sum(coalesce(debit_amount, 0)) as total_debits,
        sum(coalesce(credit_amount, 0)) as total_credits,
        sum(coalesce(ledger_debit_amount, 0)) as total_ledger_debits,
        sum(coalesce(ledger_credit_amount, 0)) as total_ledger_credits
    from general_ledger
    {{ dbt_utils.group_by(2) }}

),

ledger_currency_check as (

    select
        source_relation,
        journal_entry_id,
        'ledger currency' as check_type,
        total_ledger_debits as debit_total,
        total_ledger_credits as credit_total,
        total_ledger_debits - total_ledger_credits as difference
    from entry_totals
    where abs(total_ledger_debits - total_ledger_credits) > {{ tolerance }}

),

transaction_currency_check as (

    select
        source_relation,
        journal_entry_id,
        'transaction currency' as check_type,
        total_debits as debit_total,
        total_credits as credit_total,
        total_debits - total_credits as difference
    from entry_totals
    where currency_count <= 1
      and abs(total_debits - total_credits) > {{ tolerance }}

),

final as (

    select * from ledger_currency_check

    union all

    select * from transaction_currency_check

)

select *
from final
