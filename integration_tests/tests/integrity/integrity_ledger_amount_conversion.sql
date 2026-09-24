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
      -- A revaluation entry restates what an existing balance is worth in the functional currency.
      -- The transaction amount does not change, so Workday records zero for it and puts the gain or
      -- loss in the ledger amount alone. There is nothing to convert on these lines, and checking
      -- them compares a real ledger amount against zero times the rate.
      and (coalesce(debit_amount, 0) != 0 or coalesce(credit_amount, 0) != 0)

),

final as (

    select *
    from converted
    -- A row fails on whichever threshold it crosses first. The percentage catches a wrong rate on a
    -- line of any size, and is wide enough to let through the rate drift that is normal on expense
    -- reports, where the amount converts at the rate on the expense date rather than the rate
    -- recorded on the line. The flat amount catches a difference big enough to matter on its own,
    -- even where it is a small share of a large line.
    where debit_difference > least(greatest(0.01, abs(coalesce(ledger_debit_amount, 0)) * 0.05), 1000)
       or credit_difference > least(greatest(0.01, abs(coalesce(ledger_credit_amount, 0)) * 0.05), 1000)

)

select *
from final
