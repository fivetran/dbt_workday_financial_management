## Only posted journal entries reach the end models

Workday keeps every journal entry in one table regardless of what happened to it. Alongside posted entries you get canceled ones, entries that failed with an error, pro-forma entries, and entries that were created but never posted. Both end models include only entries whose status is `POSTED`.

If you need to see what was canceled or errored, the staging models carry the complete journal history with `journal_entry_status` intact — `stg_workday_financial_management__journal_entry` and `stg_workday_financial_management__journal_entry_line` are unfiltered.

If you use different status values, set `workday_financial_management__posted_statuses` to the list that means posted for you. It defaults to `['POSTED']`.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## Ledger currency comes from the ledger's company, not the journal header's

A journal entry names a company and a ledger. On an intercompany journal those point at different companies: the header company is the one transacting or paying, and the ledger belongs to the company that owns the accounts being posted to. The `ledger_*` amounts are the ledger's amounts, so the currency they are stated in is the ledger's company's functional currency.

We first took it from the header company, because that company is already joined for its name and its reversal flags and no other table in the connector carries a currency. That was wrong, and quietly so. In the tenant we validated against it mislabeled 3,985 lines, every one of them a line where the transaction currency and the ledger currency were genuinely different but we reported them as the same. The amounts on those lines disagreed with each other while claiming a single currency, which is the kind of thing a reader notices only after trusting it. Reading the currency through `ledger.company_id` instead takes that count to zero, and takes the count of same-currency lines carrying a conversion rate other than 1 to zero with it.

Where the ledger a journal points at is missing from your `ledger` table, `ledger_currency_id` and `ledger_currency_code` come through null. Roughly 0.06% of lines in the tenant we checked, and we would rather leave them empty than fall back to the header company's currency: that is the value we just established is unreliable, and a fallback would put it back on the row with nothing to mark it. This is the same choice we make for ambiguous ledger accounts. The `ledger_*` amounts themselves are unaffected, since they come straight from the journal line.

`workday_financial_management__general_ledger_by_period` carries `ledger_currency_code` in its grain, so a null there groups with other nulls rather than disappearing.

## The monthly rollup reports in ledger currency only

Workday states each journal entry line twice: once in the currency the transaction happened in, and once converted to the company's ledger, or functional, currency. `workday_financial_management__general_ledger` carries both pairs, labeled by `currency_code` and `ledger_currency_code`.

`workday_financial_management__general_ledger_by_period` carries only the ledger-currency amounts. Its grain is company, ledger account, and month, with no currency in it. A company that posts in more than one transaction currency would have those amounts summed together at that grain, which adds euros to dollars and produces a number that means nothing. We considered adding currency to the grain, but that multiplies rows for multi-currency companies and leaves the converted amounts repeating across them, which trades one confusion for another. A period rollup is a functional-currency report, so we report the functional currency and name it on every row.

If you need period totals in transaction currency, aggregate `workday_financial_management__general_ledger` yourself and include `currency_code` in your group by.

## Periods are calendar months

`workday_financial_management__general_ledger_by_period` rolls activity up by calendar month. The connector syncs no fiscal calendar table, so we have no way to learn where your fiscal periods begin and end. We chose calendar months over inventing a configurable offset because an offset only covers fiscal years that are a whole number of months out of step with the calendar, and it would silently produce wrong periods for anyone it does not fit.

If your company runs on a non-calendar fiscal year, use `workday_financial_management__general_ledger` and apply your own period mapping. The transaction-level model carries the accounting date on every row.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## Cumulative balances are produced for every account

In a general ledger rollup, a running balance is meaningful for balance sheet accounts and misleading for income statement accounts, which reset at the start of each fiscal year. The usual approach is to carry balances forward only for balance sheet accounts and to leave the rest at their period activity.

Workday exposes a ledger account type but no account class, so the connector gives us no field that reliably tells a balance sheet account from an income statement account. Rather than guess from account type names, which vary by account, we carry balances forward for every account and say so plainly. Treat `period_beginning_balance` and `period_ending_balance` as meaningful only for accounts you know to be balance sheet accounts. `period_net_change` is activity within the month and is safe to use for any account. We expect to revisit this once the account hierarchy is available.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## `net_amount` is debit minus credit, and negative amounts are expected

Workday lets each company choose how reversals are recorded: either "Reverse Debit/Credit", which moves the amount to the opposite column, or "Keep Debit/Credit and Reverse Sign", which negates the amount in place. The two settings are mutually exclusive and both surface on the company record, as `is_debit_credit_reversed` and `is_sign_reversed`.

We compute `net_amount` as `debit_amount - credit_amount` in both cases. That expression gives the same answer under either setting: a debit of 100 reversed as a credit of 100 and a debit of -100 both net to zero. The consequence you need to know about is that `debit_amount` and `credit_amount` are legitimately negative for companies configured to reverse signs. Do not wrap them in `abs()` and do not filter them out — you would drop real reversals. Both company flags are carried on every general ledger row so you can tell which convention produced a given line.
