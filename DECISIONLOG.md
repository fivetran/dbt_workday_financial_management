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

## The monthly rollup stays on calendar months, even though fiscal periods are now available

`workday_financial_management__general_ledger_by_period` rolls activity up by calendar month. When we built it the connector synced no fiscal calendar, so calendar months were the only option. `fiscal_period` and `fiscal_year` are now available, and we kept the model on calendar months anyway.

The reason is that a row can only carry one honest period. On a 4-4-5 schedule a fiscal period straddles two calendar months, so a calendar-month row contains activity from two fiscal periods and no single fiscal period label is true for it. Adding fiscal columns to this model would look helpful and be wrong for exactly the customers who need them most. The reverse holds too, which is why `workday_financial_management__budget_vs_actuals` carries no calendar month.

Where fiscal periods do appear is `workday_financial_management__general_ledger`, at line grain. A journal line has one accounting date, so it falls in exactly one fiscal period and there is nothing to be ambiguous about. Use those columns to build a fiscal rollup of your own if you need one.

The two models are deliberately not joinable on period. Join them on company and ledger account, and take the period from whichever model matches the calendar you report on.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## Cumulative balances are produced for every account

In a general ledger rollup, a running balance is meaningful for balance sheet accounts and misleading for income statement accounts, which reset at the start of each fiscal year. The usual approach is to carry balances forward only for balance sheet accounts and to leave the rest at their period activity.

Workday exposes a ledger account type but no account class, so the connector gives us no field that reliably tells a balance sheet account from an income statement account. Rather than guess from account type names, which vary by account, we carry balances forward for every account and say so plainly. Treat `period_beginning_balance` and `period_ending_balance` as meaningful only for accounts you know to be balance sheet accounts. `period_net_change` is activity within the month and is safe to use for any account. We expect to revisit this once the account hierarchy is available.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## `net_amount` is debit minus credit, and negative amounts are expected

Workday lets each company choose how reversals are recorded: either "Reverse Debit/Credit", which moves the amount to the opposite column, or "Keep Debit/Credit and Reverse Sign", which negates the amount in place. The two settings are mutually exclusive and both surface on the company record, as `is_debit_credit_reversed` and `is_sign_reversed`.

We compute `net_amount` as `debit_amount - credit_amount` in both cases. That expression gives the same answer under either setting: a debit of 100 reversed as a credit of 100 and a debit of -100 both net to zero. The consequence you need to know about is that `debit_amount` and `credit_amount` are legitimately negative for companies configured to reverse signs. Do not wrap them in `abs()` and do not filter them out — you would drop real reversals. Both company flags are carried on every general ledger row so you can tell which convention produced a given line.

## Budget comes from business plans, and is paired on fiscal periods

Workday stores budgets as business plans, not as journal entries against a budget ledger. There is no budget ledger to read: in the tenant we validated against, all 60 ledgers are `ACTUALS`. `business_plan_detail` holds the header, `business_plan_entry_line` holds the budgeted amounts, and both mirror the journal entry tables closely enough that the pairing is a straightforward join once the periods line up.

A business plan is dated by a fiscal year and a posting interval, not by a calendar month, so `workday_financial_management__budget_vs_actuals` is grained on fiscal periods. Actual activity is placed on the same periods by finding the period whose date range contains the accounting date. Every posted journal entry we checked landed in exactly one, with none unmatched and none matching two.

A posting interval names a position within the year — the third month, say — and repeats every year, so a period is identified by schedule, year, and interval together. Joining on the interval alone would multiply rows by roughly the number of years in your calendar. `stg_workday_financial_management__fiscal_period` carries a surrogate key built from all three, because the source table has no key of its own.

## Budget is dated without going through the company

A business plan names a company, and a company names the fiscal schedule it reports on, so we could have resolved a plan's period by way of its company. We date the plan directly against `fiscal_period` instead, on year and posting interval, because a posting interval already belongs to exactly one schedule and the company adds nothing the interval has not already settled.

What it does add is a dependency on the company resolving. In the tenant we validated against, 84 plans of 523 reference a company that is not in the `company` table. Routing through the company would have dropped all of them. Dating directly keeps them, at the cost of a `company_name` that comes through null.

The assumption this rests on is checked rather than assumed: `integrity_fiscal_calendar` fails if any plan dates against a schedule its own company does not report on. We found none.

## Plans with no period are left out

Roughly three quarters of the business plan headers we saw carry `year = 0` and no posting interval at all. They cannot be placed on a timeline, so they cannot be compared against actual activity from any particular period, and they do not appear in `workday_financial_management__budget_vs_actuals`. The join to `fiscal_period` is what excludes them — a year of 0 matches no fiscal year.

They are a small share of the money: 0.6% of gross budgeted amount in the tenant we checked, against 99.4% for plans that are dated. The staging models carry them in full if you need to see what they are.

Separately, about 18% of plan lines carry no ledger account. Every one of them we saw was a zero-amount placeholder, and they are excluded too, since a budget with no account has nothing to pair with.

## Currency is part of the pairing key, not an attribute of it

Budget and actual amounts are only comparable when they are stated in the same currency. Rather than pick one side's currency and label the row with it, `workday_financial_management__budget_vs_actuals` puts currency in the key. Two figures in different currencies then stay as two unpaired rows instead of producing a variance that subtracts euros from dollars.

In practice they agree. A plan's currency is its company's currency, and the ledger amounts are stated in the ledger's company's currency, so for a single company they are the same value arrived at two ways — we found no mismatches. Keeping currency in the key means that if that ever stops holding, the result is a visibly unpaired row rather than a quietly wrong number.

## Periods with neither budget nor actuals are not emitted

`workday_financial_management__general_ledger_by_period` densifies: every account gets a row for every month, so balances carry forward across quiet periods. `workday_financial_management__budget_vs_actuals` does not. A row appears only where a budget or actual figure exists.

Carrying a balance forward is the reason to densify, and this model reports period activity against a period target rather than a running balance. Densifying it would multiply rows by every account and period combination to say nothing — in the calendar rollup that ratio is 464,370 rows to 93,100 with activity — and year-to-date totals are unaffected, since a period with nothing in it adds nothing to a running sum.

Because both a missing figure and a real zero come through as `0`, the model carries `has_budget` and `has_actuals` so you can tell them apart. Unbudgeted spend is `has_budget = false` with a non-zero actual; a budgeted account that saw no posting is `has_actuals = false`.

## Budget and actuals pair on account, not on worktags

Both budget lines and journal lines carry worktags, and 97% of budget lines carry at least one, so pairing on a worktag such as cost center is available in principle. `workday_financial_management__budget_vs_actuals` pairs on company and ledger account only.

The reason is that a worktag on the general ledger is an attribute of a line, while a worktag in this model would be part of a key. Every dimension added to a key narrows what can pair, because a row pairs only when both sides carry the same value. Coverage differs sharply by type — cost center appears on 97% of budget lines but 85% of journal lines, and region on 49% against 79% — so the untagged remainder on either side becomes an unpaired row. Pairing on the six worktag types the general ledger carries by default would leave roughly 0.3% of budget lines able to pair at all.

We also declined to make it configurable. A variable that adds columns to the general ledger is safe, because it cannot change what a row means. A variable that adds columns to a key changes the model's grain, so two projects with different settings would produce models that mean different things while looking identically configured. If worktag-level variance is needed, the honest form is a second model with its own fixed grain, which also lets you have both views at once.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).
