{% docs fivetran_synced %}
Timestamp of when Fivetran last synced this row.
{% enddocs %}

{% docs source_relation %}
Name of the schema or connection this record came from. Populated only when you union multiple
Workday Financial Management connections together with the workday_financial_management_sources
variable. Otherwise it is an empty string.
{% enddocs %}

{% docs journal_entry_id %}
Unique identifier of the journal entry.
{% enddocs %}

{% docs journal_entry_line_index %}
Position of the line within its parent journal entry. Together with journal_entry_id this forms
the grain of the journal entry line table, and it is the key the worktag bridge joins on.
{% enddocs %}

{% docs line_order %}
Display ordering of the line within the entry. Distinct from journal_entry_line_index and not used
as a join key.
{% enddocs %}

{% docs journal_line_number %}
Line number assigned by Workday, visible to you on the journal.
{% enddocs %}

{% docs accounting_date %}
Date the entry posts to the ledger. Financial reporting periods derive from this date, not from
transaction_date.
{% enddocs %}

{% docs transaction_date %}
Date the underlying business transaction occurred.
{% enddocs %}

{% docs created_at %}
Timestamp the journal entry record was created in Workday.
{% enddocs %}

{% docs budget_date %}
Date used to align the line against budget periods.
{% enddocs %}

{% docs journal_number %}
Human-readable journal number assigned by Workday.
{% enddocs %}

{% docs journal_sequence_number %}
Sequence number of the journal entry within its ledger and period.
{% enddocs %}

{% docs journal_entry_status %}
Processing status of the entry, for example Posted, Draft, or Cancelled.
{% enddocs %}

{% docs book_code %}
Code of the accounting book the entry posts to.
{% enddocs %}

{% docs journal_entry_memo %}
Free-text memo entered on the journal header.
{% enddocs %}

{% docs journal_entry_line_memo %}
Free-text memo entered on the journal line.
{% enddocs %}

{% docs external_reference_id %}
Identifier of the entry in the external system that originated it.
{% enddocs %}

{% docs total_ledger_debits %}
Control total of all debit amounts across the entry's lines, in ledger currency.
{% enddocs %}

{% docs total_ledger_credits %}
Control total of all credit amounts across the entry's lines, in ledger currency.
{% enddocs %}

{% docs debit_amount %}
Debit amount on the line, in the transaction currency.
{% enddocs %}

{% docs credit_amount %}
Credit amount on the line, in the transaction currency.
{% enddocs %}

{% docs ledger_debit_amount %}
Debit amount on the line, converted to the ledger's functional currency.
{% enddocs %}

{% docs ledger_credit_amount %}
Credit amount on the line, converted to the ledger's functional currency.
{% enddocs %}

{% docs currency_rate %}
Exchange rate applied to convert the transaction currency amounts into ledger currency amounts.
{% enddocs %}

{% docs quantity %}
Statistical or unit quantity recorded on the line.
{% enddocs %}

{% docs exclude_from_spend_report %}
Whether the line is excluded from Workday spend reporting.
{% enddocs %}

{% docs cancel_reverses_journal_entry_id %}
Reference to the journal entry that this entry cancels and reverses.
{% enddocs %}

{% docs cancel_reversed_by_journal_entry_id %}
Reference to the journal entry that cancels and reverses this entry.
{% enddocs %}

{% docs functional_reverses_journal_entry_id %}
Reference to the journal entry that this entry functionally reverses.
{% enddocs %}

{% docs functional_reversed_by_journal_entry_id %}
Reference to the journal entry that functionally reverses this entry.
{% enddocs %}

{% docs ledger_period_id %}
Reference to the Workday ledger period. The connector does not sync a ledger period table, so you
cannot resolve this identifier to a period name or date range.
{% enddocs %}

{% docs ledger_id %}
Reference to the ledger the journal entry posts to.
{% enddocs %}

{% docs ledger_code %}
Code of the ledger.
{% enddocs %}

{% docs ledger_type %}
Type of ledger, for example Actuals, Budget, or Commitment.
{% enddocs %}

{% docs ledger_account_id %}
Reference to the ledger account the line posts to.
{% enddocs %}

{% docs ledger_account_code %}
Code of the ledger account, denormalized onto the journal line. The ledger account table does not
carry this code, so the line is the only place it is available.
{% enddocs %}

{% docs ledger_account_name %}
Name of the ledger account.
{% enddocs %}

{% docs ledger_account_type %}
Type of the ledger account.
{% enddocs %}

{% docs is_retired %}
Whether the account has been retired and is no longer available for posting.
{% enddocs %}

{% docs account_set_id %}
Reference to the account set, the chart of accounts grouping the account belongs to.
{% enddocs %}

{% docs account_set_name %}
Name of the account set the ledger account belongs to, denormalized onto the journal line.
{% enddocs %}

{% docs journal_source_id %}
Reference to the source system or process that generated the entry.
{% enddocs %}

{% docs journal_source_reference_id %}
Business key of the journal source, distinct from the surrogate identifier. Confirm which of the
two the journal entry's journal_source_id refers to before joining.
{% enddocs %}

{% docs journal_source_name %}
Name of the journal source, for example Manual Journal, Supplier Invoice, or Payroll.
{% enddocs %}

{% docs worktag_id %}
Reference to the worktag applied to the line.
{% enddocs %}

{% docs worktag_type %}
The worktag's type, reported in Workday's reference-ID form -- for example
Cost_Center_Reference_ID or Fund_Reference_ID. This is the dimension the general ledger resolves
worktags on, and what you name in workday_financial_management__worktag_types to give a worktag
type its own column there.
{% enddocs %}

{% docs worktag_name %}
Human-readable name of the worktag.
{% enddocs %}

{% docs worktag_value %}
Code or value of the worktag.
{% enddocs %}

{% docs custom_worktag_id %}
Unique identifier of the custom worktag.
{% enddocs %}

{% docs worktag_code %}
Code of the custom worktag.
{% enddocs %}

{% docs configuration_code %}
Code of the tenant configuration that defines this custom worktag type. This is the custom worktag
equivalent of worktag_type, and is what you name in workday_financial_management__worktag_types to
give a custom worktag its own column on the general ledger.
{% enddocs %}

{% docs custom_worktag_value %}
Value of the custom worktag.
{% enddocs %}

{% docs is_inactive %}
Whether the custom worktag has been deactivated.
{% enddocs %}

{% docs company_id %}
Reference to the company the journal entry belongs to.
{% enddocs %}

{% docs line_company_id %}
Reference to the company the line posts to. May differ from the journal header's company on
intercompany entries.
{% enddocs %}

{% docs company_name %}
Name of the company.
{% enddocs %}

{% docs company_code %}
Code of the company.
{% enddocs %}

{% docs is_active %}
Whether the company is currently active.
{% enddocs %}

{% docs fiscal_schedule_code %}
Code of the fiscal schedule the company reports on, for example Standard_Corporate_Schedule or
May_April. Join it to fiscal_year to resolve the schedule, and from there to fiscal_period for
period start and end dates.
{% enddocs %}

{% docs default_reporting_book_code %}
Code of the company's default reporting book.
{% enddocs %}

{% docs is_debit_credit_reversed %}
Whether the company reverses the debit and credit convention. Affects how you derive signed
amounts from debit_amount and credit_amount.
{% enddocs %}

{% docs is_sign_reversed %}
Whether the company keeps the debit and credit split but reverses the sign. Affects how you derive
signed amounts from debit_amount and credit_amount.
{% enddocs %}

{% docs currency_id %}
Reference to the currency the amounts are recorded in.
{% enddocs %}

{% docs currency_code %}
Three-letter ISO 4217 currency code, for example USD or EUR.
{% enddocs %}

{% docs currency_name %}
Name of the currency.
{% enddocs %}

{% docs currency_numeric_code %}
Three-digit ISO 4217 numeric currency code.
{% enddocs %}

{% docs currency_symbol %}
Display symbol of the currency.
{% enddocs %}

{% docs currency_precision %}
Number of decimal places the currency is recorded to.
{% enddocs %}

{% docs business_plan_detail_id %}
Unique identifier of the business plan. Workday stores budgets as business plans, so this is the
budget equivalent of journal_entry_id.
{% enddocs %}

{% docs business_plan_detail_index %}
Position of the plan within its parent record. The connector unpacks business plans from a nested
structure, and in observed data this is always 0. It is carried and joined on anyway, so a tenant
that does emit more than one stays correct.
{% enddocs %}

{% docs business_plan_reference_id %}
Business key of the plan, distinct from the surrogate identifier in business_plan_detail_id.
{% enddocs %}

{% docs business_plan_structure_id %}
Reference to the business plan structure, which defines the plan's shape and rules. The connector
syncs no business plan structure table, so you cannot resolve this identifier to a name.
{% enddocs %}

{% docs organizing_dimension_id %}
Reference to the dimension the plan is organized by. The connector syncs no table for this, so you
cannot resolve this identifier to a name.
{% enddocs %}

{% docs plan_year %}
Fiscal year the plan covers, as an integer. Together with fiscal_time_interval_id this places the
plan on a fiscal period. A value of 0 means the plan carries no period at all and cannot be placed
on a timeline.
{% enddocs %}

{% docs fiscal_time_interval_id %}
Reference to the posting interval within the fiscal year the plan budgets for. This is the same
identifier fiscal_period exposes as fiscal_posting_interval_id -- join on both this and the plan's
year, because an interval identifies a position in the year and repeats across years.
{% enddocs %}

{% docs award_posting_interval_code %}
Code of the award posting interval, used when the plan budgets against a grant award rather than a
fiscal schedule.
{% enddocs %}

{% docs award_contract_id %}
Reference to the award contract the plan budgets against, for grant accounting.
{% enddocs %}

{% docs award_proposal_code %}
Code of the award proposal the plan budgets against, for grant accounting.
{% enddocs %}

{% docs project_budget_code %}
Code of the project budget the plan belongs to, for project-based budgeting.
{% enddocs %}

{% docs business_plan_memo %}
Free-text memo entered on the business plan header.
{% enddocs %}

{% docs business_plan_entry_line_index %}
Position of the line within its business plan. Together with business_plan_detail_id and
business_plan_detail_index this forms the grain of the business plan entry line table, and it is
the key the budget worktag bridge joins on.
{% enddocs %}

{% docs business_plan_line_order %}
Display ordering token of the line within the plan. A string rather than a number, and not used as
a join key.
{% enddocs %}

{% docs business_plan_ledger_account_id %}
Reference to the ledger account the budgeted amount applies to. This resolves against
ledger_account, which is the same identifier space the journal line exposes as
ledger_account_code -- that is what lets budget and actuals pair on account.
{% enddocs %}

{% docs ledger_account_summary_id %}
Reference to the ledger account summary the budgeted amount applies to, when a plan budgets at a
rollup level rather than an individual account.
{% enddocs %}

{% docs business_plan_debit_amount %}
Budgeted debit amount on the line, in the plan's currency.
{% enddocs %}

{% docs business_plan_credit_amount %}
Budgeted credit amount on the line, in the plan's currency.
{% enddocs %}

{% docs business_plan_entry_line_memo %}
Free-text memo entered on the business plan line.
{% enddocs %}

{% docs fiscal_schedule_id %}
Reference to the fiscal schedule the period or year belongs to. Resolve a company to its schedule
through the company's fiscal_schedule_code.
{% enddocs %}

{% docs fiscal_year_name %}
Name of the fiscal year, for example 2025. Part of the key that identifies a fiscal period.
{% enddocs %}

{% docs fiscal_posting_interval_id %}
Reference to the posting interval, which is a position within the fiscal year rather than a
specific period. The same interval repeats every year, so a period is identified by schedule, year,
and interval together.
{% enddocs %}

{% docs fiscal_posting_interval_code %}
Code of the posting interval, for example the name of the month or quarter it represents.
{% enddocs %}

{% docs fiscal_month_start_date %}
First day of the fiscal period. On a 4-4-5 or similar schedule this does not fall on the first day
of a calendar month.
{% enddocs %}

{% docs fiscal_month_end_date %}
Last day of the fiscal period. On a 4-4-5 or similar schedule this does not fall on the last day of
a calendar month, and a single fiscal period can span two calendar months.
{% enddocs %}

{% docs fiscal_year_id %}
Unique identifier of the fiscal year.
{% enddocs %}

{% docs fiscal_year_code %}
Code of the fiscal year.
{% enddocs %}

{% docs fiscal_year_number %}
Numeric form of the fiscal year.
{% enddocs %}

{% docs fiscal_year_start_date %}
First day of the fiscal year. This is the boundary year-to-date figures reset on, and it is not
January 1 for a company on a non-calendar schedule.
{% enddocs %}

{% docs fiscal_year_end_date %}
Last day of the fiscal year.
{% enddocs %}
