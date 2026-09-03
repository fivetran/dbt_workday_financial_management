## Only posted journal entries reach the end models

Workday keeps every journal entry in one table regardless of what happened to it. Alongside posted entries you get canceled ones, entries that failed with an error, pro-forma entries, and entries that were created but never posted. Both end models include only entries whose status is `POSTED`.

If you need to see what was canceled or errored, the staging models carry the complete journal history with `journal_entry_status` intact — `stg_workday_financial_management__journal_entry` and `stg_workday_financial_management__journal_entry_line` are unfiltered.

If you use different status values, set `workday_financial_management__posted_statuses` to the list that means posted for you. It defaults to `['POSTED']`.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## Ledger currency comes from the ledger's company, not the journal header's

A journal entry names a company and a ledger. On an intercompany journal those point at different companies: the header company is the one transacting or paying, and the ledger belongs to the company that owns the accounts being posted to. The `ledger_*` amounts are the ledger's amounts, so the currency they are stated in is the ledger's company's functional currency.

`workday_financial_management__general_ledger_by_period` carries `ledger_currency_code` in its grain, so a null there groups with other nulls rather than disappearing.

## The monthly rollup reports in ledger currency only

Workday states each journal entry line twice: once in the currency the transaction happened in, and once converted to the company's ledger, or functional, currency. `workday_financial_management__general_ledger` carries both pairs, labeled by `currency_code` and `ledger_currency_code`.

`workday_financial_management__general_ledger_by_period` carries only the ledger-currency amounts. Transaction currency is not in its grain and its amounts are not reported. A company that posts in more than one transaction currency would have those amounts summed together, which adds euros to dollars and produces a number that means nothing. A period rollup is a functional-currency report, so we report the functional currency only.

Ledger currency is a different matter, and it is in the grain. As described above, the ledger currency comes from the ledger's company rather than the journal header's, so one company and account can post to ledgers resolving to more than one functional currency. Leaving ledger currency out would sum those together and reintroduce the same problem one level down, so the grain is company, ledger account, ledger currency, and month. For the common single-currency company this changes nothing, because there is only one ledger currency to group by.

If you need period totals in transaction currency, aggregate `workday_financial_management__general_ledger` yourself and include `currency_code` in your group by.

## Cumulative balances are produced for every account

In a general ledger rollup, a running balance is meaningful for balance sheet accounts and misleading for income statement accounts, which reset at the start of each fiscal year. The usual approach is to carry balances forward only for balance sheet accounts and to leave the rest at their period activity.

Workday exposes a ledger account type but no account class, so the connector gives us no field that reliably tells a balance sheet account from an income statement account. Rather than guess from account type names, which vary by account, we carry balances forward for every account and say so plainly. Treat `period_beginning_balance` and `period_ending_balance` as meaningful only for accounts you know to be balance sheet accounts. `period_net_change` is activity within the month and is safe to use for any account. We expect to revisit this once the account hierarchy is available.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## `net_amount` is debit minus credit, and negative amounts are expected

Workday lets each company choose how reversals are recorded: either "Reverse Debit/Credit", which moves the amount to the opposite column, or "Keep Debit/Credit and Reverse Sign", which negates the amount in place. The two settings are mutually exclusive and both surface on the company record, as `is_debit_credit_reversed` and `is_sign_reversed`.

We compute `net_amount` as `debit_amount - credit_amount` in both cases. That expression gives the same answer under either setting: a debit of 100 reversed as a credit of 100 and a debit of -100 both net to zero. The consequence you need to know about is that `debit_amount` and `credit_amount` are legitimately negative for companies configured to reverse signs. Do not wrap them in `abs()` and do not filter them out — you would drop real reversals. Both company flags are carried on every general ledger row so you can tell which convention produced a given line.

## Budget comes from business plans, and is paired on fiscal periods

Workday stores budgets as business plans, not as journal entries against a budget ledger. A business plan is dated by a fiscal year and a posting interval, not by a calendar month, so `workday_financial_management__budget_vs_actuals` is grained on fiscal periods. Actual activity is placed on the same periods by finding the period whose date range contains the accounting date. 

A posting interval names a position within the year — the third month, say — and repeats every year, so a period is identified by schedule, year, and interval together. Joining on the interval alone would multiply rows by roughly the number of years in your calendar. `stg_workday_financial_management__fiscal_period` carries a surrogate key built from all three, because the source table has no key of its own.

## Currency is part of the pairing key, not an attribute of it

Budget and actual amounts are only comparable when they are stated in the same currency. Rather than pick one side's currency and label the row with it, `workday_financial_management__budget_vs_actuals` puts currency in the key. Two figures in different currencies then stay as two unpaired rows instead of producing a variance that subtracts euros from dollars.

Currency is the only nullable part of that key, and a missing currency is an unknown one rather than a different one. A budget and an actual that are both missing it pair with each other, the same way nulls group together in the period rollup.

## Periods with neither budget nor actuals are not emitted

`workday_financial_management__general_ledger_by_period` densifies: every account gets a row for every month, so balances carry forward across quiet periods. `workday_financial_management__budget_vs_actuals` does not. A row appears only where a budget or actual figure exists.

Carrying a balance forward is the reason to densify, and this model reports period activity against a period target rather than a running balance. Densifying it would multiply rows by every account and period combination to say nothing — in the calendar rollup that ratio is 464,370 rows to 93,100 with activity — and year-to-date totals are unaffected, since a period with nothing in it adds nothing to a running sum.

Because both a missing figure and a real zero come through as `0`, the model carries `has_budget` and `has_actuals` so you can tell them apart. Unbudgeted spend is `has_budget = false` with a non-zero actual; a budgeted account that saw no posting is `has_actuals = false`.
