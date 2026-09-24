## Only posted journal entries reach the end models

Workday keeps every journal entry in one table, whatever happened to it. Posted entries sit alongside canceled ones, entries that hit an error, pro-forma entries, and entries nobody ever posted. Both end models include only entries with a status of `POSTED`.

To see what was canceled or errored, use the staging models. `stg_workday_financial_management__journal_entry` and `stg_workday_financial_management__journal_entry_line` are unfiltered and keep `journal_entry_status`.

If your tenant uses different status values, list yours in `workday_financial_management__posted_statuses`. It defaults to `['POSTED']`.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## Ledger currency comes from the ledger's company

A journal entry names a company and a ledger. On an intercompany journal, those are two different companies. The header company is the one doing the transaction. The ledger belongs to the company that owns the accounts being posted to.

The `ledger_*` amounts belong to the ledger, so we state them in the ledger company's currency, not the header company's.

`workday_financial_management__general_ledger_by_period` keeps `ledger_currency_code` in its grain. A null groups with other nulls instead of disappearing.

## The monthly rollup reports in ledger currency only

Workday states each journal line twice: once in the currency the transaction happened in, and once converted to the company's ledger currency. `workday_financial_management__general_ledger` carries both, labeled `currency_code` and `ledger_currency_code`.

`workday_financial_management__general_ledger_by_period` carries only the ledger-currency amounts. If a company posts in more than one transaction currency, adding those amounts together adds euros to dollars and gives you a meaningless number. A period rollup is a functional-currency report, so we report that currency alone.

Ledger currency is different, and it is in the grain. As above, it comes from the ledger's company, so one company and account can post to ledgers in more than one currency. Leaving it out would cause the same problem one level down. The grain is company, ledger account, ledger currency, and month. If your companies each use one currency, this changes nothing for you.

For period totals in transaction currency, roll up `workday_financial_management__general_ledger` yourself and group by `currency_code`.

## We carry balances forward for every account

A running balance makes sense for balance sheet accounts. It misleads for income statement accounts, which reset at the start of each fiscal year. Normally you would carry balances forward for the first group only.

We cannot tell the two apart. Workday gives us a ledger account type but no account class, and account type names vary too much to guess from. So we carry balances forward for every account and tell you plainly.

Use `period_beginning_balance` and `period_ending_balance` only for accounts you know to be balance sheet accounts. `period_net_change` is activity within the month and is safe for any account. We expect to revisit this once the account hierarchy is available.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## `net_amount` is debit minus credit, and negative amounts are normal

Workday lets each company choose how it records reversals. "Reverse Debit/Credit" moves the amount to the opposite column. "Keep Debit/Credit and Reverse Sign" makes the amount negative where it is. A company uses one or the other, and both show on the company record as `is_debit_credit_reversed` and `is_sign_reversed`.

We calculate `net_amount` as `debit_amount - credit_amount` either way. The answer is the same under both settings: a debit of 100 reversed as a credit of 100, and a debit of -100, both net to zero.

What this means for you: `debit_amount` and `credit_amount` are genuinely negative at companies that reverse signs. Do not wrap them in `abs()` and do not filter them out, or you drop real reversals. Every general ledger row carries both company flags, so you can tell which convention produced it.

## You choose which worktags become columns

Every Workday tenant sets up its own worktag types, and there can be many of them. We cannot tell which ones matter to you, so we do not pick any.

By default, neither end model carries worktag columns. To add them, list the types you want:

- `workday_financial_management__worktag_types` for `workday_financial_management__general_ledger`
- `workday_financial_management__budget_worktag_types` for `workday_financial_management__budget_vs_actuals`

We considered shipping a standard set of types. Any set we picked would be a guess about your chart of accounts, and often the wrong one. We also considered adding every type we find. That makes the general ledger as wide as your worktag setup, and most of those columns sit empty on most rows.

The worktag tables build either way. `worktag`, `custom_worktag`, and `journal_entry_line_worktag` always have staging models, so you can query a worktag we did not give a column to.

One thing to know: the two lists are connected. Budget vs actuals takes its actual amounts from the general ledger, so any type it uses has to be a column there too. When you add a type to `workday_financial_management__budget_worktag_types`, we add it to the general ledger as well.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## One line can have several worktags of the same type, and we keep them all

Workday lets a single journal line carry more than one worktag of the same type. Organization worktags are the common case, where one line is tagged with several organizations. Each is a separate allocation, not a repeat.

On `workday_financial_management__general_ledger`, we put every value in the cell, sorted and separated by ` | `. We do not pick one and drop the rest. Dropping them loses real allocations quietly: the row still looks fine, the totals still balance, and no test fails.

We use ` | ` rather than a comma because a worktag value can contain a comma.

Most worktag types hold one value per line. For those, the column reads as a normal value and you never see the separator.

## Budget comes from business plans, and pairs on fiscal periods

Workday stores budgets as business plans, not as journal entries against a budget ledger. A business plan is dated by a fiscal year and a posting interval, not by a calendar month. So `workday_financial_management__budget_vs_actuals` is grained on fiscal periods. We place actual activity on the same periods by finding the period whose dates contain the accounting date.

A posting interval names a position in the year — the third month, say — and repeats every year. That means a period needs a schedule, a year, and an interval to identify it. Joining on the interval alone multiplies your rows by the number of years in your calendar. The source table has no key of its own, so `stg_workday_financial_management__fiscal_period` builds one from all three.

## Project budgets are left out of budget vs actuals

`workday_financial_management__budget_vs_actuals` compares budget and actuals month by month. Workday project budgets cover the life of a project, not a fiscal year, so they have no month to fall in. Workday gives these plans a plan year of 0, and the model leaves them out.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## Currency is part of the pairing key

You can only compare a budget to an actual when both are in the same currency. Rather than pick one side's currency and label the row with it, `workday_financial_management__budget_vs_actuals` puts currency in the key. Two figures in different currencies stay as two unpaired rows, instead of producing a variance that subtracts euros from dollars.

A missing currency is an unknown one rather than a different one. A budget and an actual that are both missing it pair with each other, the same way nulls group together in the period rollup.

## Budget with no company goes to an unassigned bucket

Some business plans name no company. We cannot fill one in from another column, because one ledger account or cost center is shared by many companies. Dropping these plans would make your budget totals disagree with Workday without telling you.

So `workday_financial_management__budget_vs_actuals` keeps them. Their `company_id` is null, `company_name` reads Unassigned, and `has_company` is false. Null companies pair with each other the same way null currencies do.

The bucket holds budget only. The general ledger places a journal line on a fiscal period through its company's schedule, so a line with no company has no period and never reaches this model. Read unassigned rows as budget totals, not as a variance.

The `not_null` test on `company_id` warns instead of failing, so you can see how much budget has no company. A plan also needs a fiscal year that matches its plan year. A plan with no company and no matching year is still left out.

## On budget vs actuals, a worktag is part of the key

Worktags work differently in the two end models. On the general ledger, a worktag is a label sitting next to a row. On `workday_financial_management__budget_vs_actuals`, it is part of the key.

That is because this model adds amounts up. Anything you want to see on a row has to be something we group by, and anything we group by is part of the grain. There is no way to show a worktag here as a plain label.

Each type you add has a cost, so add them one at a time and check the result. A budget line and an actual line pair up only when they match on every part of the key. Where one side records a worktag and the other does not, a row that would have paired becomes two rows that do not. It reads as unspent budget next to unbudgeted spend, and neither is true.

Some worktag types get recorded far more consistently on actual spend than on plans. Region is a common example. Those are the ones to watch.

`budget_vs_actuals_id` is built from the key, so it includes your worktag columns in the order you listed them. Reordering the list changes the ids, though no row and no amount changes. This package has no incremental models, so a full refresh sorts it out.

## Organization worktags cannot be used on budget vs actuals

Put `Organization_Reference_ID` or `Custom_Organization_Reference_ID` in `workday_financial_management__budget_worktag_types` and the run stops with an error. We fail the run rather than drop the type quietly, so you find out at build time instead of wondering about your numbers later.

There are two reasons.

First, Workday lets one line carry several organization worktags at once, and a key needs one value per line. The general ledger joins the values into one cell, but that does not work for a key. `Clinical | Northeast` and `Clinical | Northeast | Retail` are two different keys, so a budget and an actual about the same thing stop pairing. You also could not group or filter on one organization without pulling the string apart.

Second, organization worktags mix several dimensions together. Cost center, region, pay group, and industry all arrive under the same type, and nothing in the connector says which is which. Even with one value per line, the column would not be a single dimension.

Use `Cost_Center_Reference_ID` or `Region_Reference_ID` instead. They hold the same values, carry one per line, and each is a single dimension. The error message points you to them.

## Periods with neither budget nor actuals are left out

`workday_financial_management__general_ledger_by_period` gives every account a row for every month, so balances carry forward through quiet periods. `workday_financial_management__budget_vs_actuals` does not. A row appears only where there is a budget or an actual figure.

Carrying a balance forward is the reason to fill in every month, and this model reports period activity against a period target rather than a running balance. Filling it in would multiply your rows by every account and period combination to say nothing. Year-to-date totals are unaffected either way, since an empty period adds nothing to a running sum.

A missing figure and a real zero both come through as `0`, so the model carries `has_budget` and `has_actuals` to tell them apart. Unbudgeted spend is `has_budget = false` with a non-zero actual. A budgeted account that saw no posting is `has_actuals = false`.
