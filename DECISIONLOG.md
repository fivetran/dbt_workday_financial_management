# Decision Log

In creating this package, which is meant for a wide range of use cases, we had to take opinionated stances on a few different questions we came across during development. We've consolidated significant choices we made here, and will continue to update as the package evolves.

## Only posted journal entries reach the end models

Workday keeps every journal entry in one table regardless of what happened to it. Alongside posted entries you get canceled ones, entries that failed with an error, pro-forma entries, and entries that were created but never posted. Both end models include only entries whose status is `POSTED`.

We did not start there. When we first validated the package against a real tenant, the general ledger carried all seven statuses and its balances did not tie. Posted lines netted to exactly zero across 2.1 million rows, which is what a double-entry ledger should do. The 404,744 of movement left over came entirely from canceled and errored entries — and every single unbalanced journal entry in the tenant was one of those two. Canceled entries also arrive with no company and no ledger, so they fell out of the monthly rollup silently and made its totals disagree with the detail.

A general ledger that reports voided journals as activity is wrong in a way that is hard to see: the numbers look plausible, nothing errors, and no test fails. So we filter, and we say so here rather than leaving you to discover it. If you need to see what was canceled or errored, the staging models carry the complete journal history with `journal_entry_status` intact — `stg_workday_financial_management__journal_entry` and `stg_workday_financial_management__journal_entry_line` are unfiltered.

If your tenant uses different status values, set `workday_financial_management__posted_statuses` to the list that means posted for you. It defaults to `['POSTED']`.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## Worktags become a named set of columns, not one column per type found

Workday worktags are flexible accounting dimensions. Each tenant defines its own set, and the connector delivers them as a bridge table rather than as columns, so there is no fixed schema we can model against. We considered leaving the bridge table for you to join yourself, which is predictable but pushes the hardest join in the package onto every downstream query.

We first went the other way and pivoted every worktag type we found, reading the list out of your `worktag` table while dbt parsed the project. That gave you a column for a new worktag type with no code change from you, and it had two costs we decided we were not willing to pay. It produces a very wide general ledger in which most columns are null for most rows, because a journal line carries a handful of worktags out of the dozens a tenant defines. And it makes the model's schema unknowable until the model has been built, since the column list comes from a query against your warehouse rather than from anything in the project.

So `workday_financial_management__general_ledger` carries a named set of worktag columns instead. Six delivered worktag types are always present, because those are the ones that reach general ledger journal lines in most tenants: `Organization_Reference_ID`, `Custom_Organization_Reference_ID`, `Cost_Center_Reference_ID`, `Region_Reference_ID`, `Spend_Category_ID`, and `Revenue_Category_ID`. Everything else you ask for by name in `workday_financial_management__worktag_types`, and each value there becomes its own column, named after the value slugified. Set `workday_financial_management_using_worktags` to `false` to drop all of them. If a worktag type shares a name with a column we already produce, we prefix the worktag column with `pivoted_` rather than silently emitting a duplicate.

Those names are the connector's, not Workday's. Workday's own worktag documentation lists these dimensions by display name — Cost Center, Region, Spend Category — but the Fivetran connector reports every worktag type in Workday's reference-ID form, so the value in `attribute` is `Cost_Center_Reference_ID`. We match the connector, because that is what lands in your destination. Use the same form for anything you add.

Worktags arrive in two source tables and we read both. `worktag` holds the delivered types, keyed on `attribute`. `custom_worktag` holds the ones your tenant defined, where `configuration_code` plays the same part `attribute` plays in the other table. The bridge resolves against either, so we union them into one dimension and you configure custom and delivered worktags the same way, in the same variable. We keep inactive custom worktags rather than filtering them out: a worktag retired last year is still the correct label for the journal lines posted under it.

A journal line routinely carries several worktags of the same type, and they are not duplicates — they are different allocations. Workday collapses several organizational dimensions into a single worktag type, so one line's `Organization_Reference_ID` tags read like this:

```
33100_Global_Support_North_America | CAN_Eastern | CAN_Semi_monthly | CPG
```

That is a cost center, a region, a pay group, and an industry. In the tenant we validated against, 1,729,826 of 1,906,666 line-and-type pairs carried more than one value, and not one of them was a true duplicate. These are real budget and payment allocations, so a pivoted column holds every value, joined by ` | `, rather than picking one. Types that only ever carry a single value are unaffected and read exactly as they would have.

This is also why we ship an `organization_reference_id` column alongside `cost_center_reference_id` and `region_reference_id`. Where your tenant reports cost center and region as worktag types in their own right, those two columns fill and `organization_reference_id` stays empty. Where it reports them all as Organization, they arrive together in `organization_reference_id` and we cannot pull them apart. The `worktag` table exposes only `attribute`, `value`, `descriptor`, and `id`, with no sub-type. The connector's other worktag tables do carry an explicit `worktag_type_code`, but they describe which worktag types are allowed or required on a project or cost center; they hold almost no worktag identifiers. Across all of them we could classify 9 of the 159 organization worktags in the tenant we checked. Splitting the values apart by pattern — numeric prefixes are cost centers, `US_Northeast` is a region — works for one tenant and fails for the next, so we do not do it.

The delimiter is ` | ` rather than a comma because a worktag value may contain a comma and would then split wrongly. Even so, treat the delimited column as something to read, not something to parse.

The value in each pivoted column comes from the worktag dimension's `value`, not its `descriptor`. Workday leaves `descriptor` null — it was null on all 3,907 worktags in the tenant we checked — so pivoting on it would produce a table of nulls.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## Ledger accounts join on their code, and ambiguous codes come through null

`journal_entry_line` carries a `ledger_account_id` that looks like a foreign key and is not one. Workday's `ledger_account` table is keyed on the account code — `1001`, `2150`, `S2002+` — and the connector does not give that table the hash the journal line carries. Joining the two on their identifiers matches nothing at all. We join the line's `ledger_account_code` to the account's identifier instead, which resolves 99.99% of lines.

An account code is only unique within an account set, and the connector syncs no account set table, so there is no key that would scope the join to the line's own set. Where a code appears in more than one set, the accounts behind it are genuinely different: in the tenant we validated against, `1550` is "Investment in Joint Ventures" in one set and "Furniture, Fixtures & Equipment" in another, and `4001` is an Equity account in one and an Income account in the other. We hold those accounts back from the join, so `ledger_account_name`, `ledger_account_type`, and `account_set_id` come through null on the affected lines rather than carrying a value we guessed. That was roughly 1% of lines in the tenant we checked.

We chose nulls over a deterministic pick because a wrong `ledger_account_type` is worse than a missing one — it silently misclassifies equity as income in any report that groups by account type, and nothing downstream would flag it. `ledger_account_code` is always populated, so you can join to your own account master if you need those attributes on the ambiguous rows.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## Ledger currency comes from the ledger's company, not the journal header's

A journal entry names a company and a ledger. On an intercompany journal those point at different companies: the header company is the one transacting or paying, and the ledger belongs to the company that owns the accounts being posted to. The `ledger_*` amounts are the ledger's amounts, so the currency they are stated in is the ledger's company's functional currency.

We first took it from the header company, because that company is already joined for its name and its reversal flags and no other table in the connector carries a currency. That was wrong, and quietly so. In the tenant we validated against it mislabeled 3,985 lines, every one of them a line where the transaction currency and the ledger currency were genuinely different but we reported them as the same. The amounts on those lines disagreed with each other while claiming a single currency, which is the kind of thing a reader notices only after trusting it. Reading the currency through `ledger.company_id` instead takes that count to zero, and takes the count of same-currency lines carrying a conversion rate other than 1 to zero with it.

Where the ledger a journal points at is missing from your `ledger` table, `ledger_currency_id` and `ledger_currency_code` come through null. Roughly 0.06% of lines in the tenant we checked, and we would rather leave them empty than fall back to the header company's currency: that is the value we just established is unreliable, and a fallback would put it back on the row with nothing to mark it. This is the same choice we make for ambiguous ledger accounts. The `ledger_*` amounts themselves are unaffected, since they come straight from the journal line.

`workday_financial_management__general_ledger_by_period` carries `ledger_currency_code` in its grain, so a null there groups with other nulls rather than disappearing.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## The monthly rollup reports in ledger currency only

Workday states each journal entry line twice: once in the currency the transaction happened in, and once converted to the company's ledger, or functional, currency. `workday_financial_management__general_ledger` carries both pairs, labeled by `currency_code` and `ledger_currency_code`.

`workday_financial_management__general_ledger_by_period` carries only the ledger-currency amounts. Its grain is company, ledger account, and month, with no currency in it. A company that posts in more than one transaction currency would have those amounts summed together at that grain, which adds euros to dollars and produces a number that means nothing. We considered adding currency to the grain, but that multiplies rows for multi-currency companies and leaves the converted amounts repeating across them, which trades one confusion for another. A period rollup is a functional-currency report, so we report the functional currency and name it on every row.

If you need period totals in transaction currency, aggregate `workday_financial_management__general_ledger` yourself and include `currency_code` in your group by.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## Periods are calendar months

`workday_financial_management__general_ledger_by_period` rolls activity up by calendar month. The connector syncs no fiscal calendar table, so we have no way to learn where your fiscal periods begin and end. We chose calendar months over inventing a configurable offset because an offset only covers fiscal years that are a whole number of months out of step with the calendar, and it would silently produce wrong periods for anyone it does not fit.

If your company runs on a non-calendar fiscal year, use `workday_financial_management__general_ledger` and apply your own period mapping. The transaction-level model carries the accounting date on every row.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## Cumulative balances are produced for every account

In a general ledger rollup, a running balance is meaningful for balance sheet accounts and misleading for income statement accounts, which reset at the start of each fiscal year. The usual approach is to carry balances forward only for balance sheet accounts and to leave the rest at their period activity.

Workday exposes a ledger account type but no account class, so the connector gives us no field that reliably tells a balance sheet account from an income statement account. Rather than guess from account type names, which vary by tenant, we carry balances forward for every account and say so plainly. Treat `period_beginning_balance` and `period_ending_balance` as meaningful only for accounts you know to be balance sheet accounts. `period_net_change` is activity within the month and is safe to use for any account. We expect to revisit this once the account hierarchy is available.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## `net_amount` is debit minus credit, and negative amounts are expected

Workday lets each company choose how reversals are recorded: either "Reverse Debit/Credit", which moves the amount to the opposite column, or "Keep Debit/Credit and Reverse Sign", which negates the amount in place. The two settings are mutually exclusive and both surface on the company record, as `is_debit_credit_reversed` and `is_sign_reversed`.

We compute `net_amount` as `debit_amount - credit_amount` in both cases. That expression gives the same answer under either setting: a debit of 100 reversed as a credit of 100 and a debit of -100 both net to zero. The consequence you need to know about is that `debit_amount` and `credit_amount` are legitimately negative for companies configured to reverse signs. Do not wrap them in `abs()` and do not filter them out — you would drop real reversals. Both company flags are carried on every general ledger row so you can tell which convention produced a given line.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## The `company` staging model selects 17 of 63 source columns

The `company` source table carries 63 columns, most of which describe organizational setup rather than anything you would use in financial reporting — approval routing, integration identifiers, and display settings among them. Our convention is to stage every column a source table provides.

We deviated here. Staging all 63 would put a wide table in front of a model that uses it for a handful of attributes, and would commit us to maintaining doc blocks and tests for columns no end model reads. The staging model selects the company identifiers, name and code, the reversal-method flags, the active flag, and the accounting-relevant attributes. If you need a column we left out, open a feature request and we will add it.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).

## Only the worktag tables are optional

Many Fivetran packages gate every source table behind its own `using_*` variable so the package still builds when a table is absent. This package gates one group. Seven of the ten source tables — `journal_entry`, `journal_entry_line`, `company`, `ledger`, `ledger_account`, `journal_source`, and `currency` — are delivered by the connector for every tenant and each one feeds the general ledger, so a missing table there means an incomplete ledger rather than a missing optional feature. We do not gate them, because a variable that lets you build a ledger without its accounts is not a feature.

`workday_financial_management_using_worktags` gates the remaining three: `worktag`, `custom_worktag`, and `journal_entry_line_worktag`. Setting it to `false` disables their staging models and the worktag pivot, and drops the worktag columns from the general ledger. Set it to `false` if your tenant does not use worktags, or if those tables are not present in your destination.

If further refinements are needed, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_workday_financial_management/issues).
