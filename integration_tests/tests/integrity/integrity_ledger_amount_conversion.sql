{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

-- Checks that the ledger-currency amounts are the transaction amounts converted at currency_rate.
--
-- This asserts something about the source data rather than about the model, which is the point.
-- The package never computes the ledger amounts -- it takes both sides from the connector -- so
-- nothing else would notice if the relationship does not hold. It matters because
-- workday_financial_management__general_ledger_by_period now reports ledger amounts exclusively.
--
-- It also settles the direction of currency_rate. The package assumes it converts transaction to
-- ledger. If it runs the other way, every row fails immediately and the failing rows carry
-- debit_amount, currency_rate, and ledger_debit_amount side by side so the direction is readable.
--
-- Note: against the generated seeds this test is tautological, because gen_seeds.py derives the
-- ledger amounts as amount * rate. It only proves anything against a real connection.
--
-- Tolerance is the greater of 0.01 and 0.05% of the converted amount. Workday rounds each line to
-- its currency's precision, which varies -- currency.currency_precision is 0 for JPY and 3 for
-- several Gulf currencies -- so a flat two-decimal tolerance would report rounding as a defect.

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
