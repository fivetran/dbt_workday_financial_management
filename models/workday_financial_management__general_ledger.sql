{%- set using_worktags = var('workday_financial_management_using_worktags', True) -%}

{%- set using_fiscal_calendar = var('workday_financial_management_using_fiscal_calendar', True) -%}

{%- set posted_statuses = var('workday_financial_management__posted_statuses', ['POSTED']) -%}

{%- set worktag_types = workday_financial_management.resolve_worktag_types() if using_worktags else [] %}

-- One row per journal entry line, per source relation.

with journal_entry_line as (

    select *
    from {{ ref('stg_workday_financial_management__journal_entry_line') }}

),

-- Only posted journal entries reach the general ledger. 

journal_entry as (

    select *
    from {{ ref('stg_workday_financial_management__journal_entry') }}
    where journal_entry_status in ({% for status in posted_statuses %}'{{ status }}'{% if not loop.last %}, {% endif %}{% endfor %})

),

company as (

    select *
    from {{ ref('stg_workday_financial_management__company') }}

),

ledger as (

    select *
    from {{ ref('stg_workday_financial_management__ledger') }}

),

ledger_account as (

    select *
    from {{ ref('stg_workday_financial_management__ledger_account') }}

),

ledger_account_code_counts as (

    select
        ledger_account_id,
        source_relation,
        count(*) as accounts_sharing_code
    from ledger_account
    {{ dbt_utils.group_by(2) }}

),

unambiguous_ledger_account as (

    select ledger_account.*
    from ledger_account

    join ledger_account_code_counts
        on ledger_account.ledger_account_id = ledger_account_code_counts.ledger_account_id
        and ledger_account.source_relation = ledger_account_code_counts.source_relation

    where ledger_account_code_counts.accounts_sharing_code = 1

),

journal_source as (

    select *
    from {{ ref('stg_workday_financial_management__journal_source') }}

),

currency as (

    select *
    from {{ ref('stg_workday_financial_management__currency') }}

),

ledger_company as (

    select *
    from {{ ref('stg_workday_financial_management__company') }}

),

-- Currency joined a second time, to label the ledger_* amounts.
ledger_currency as (

    select *
    from {{ ref('stg_workday_financial_management__currency') }}

{% if using_fiscal_calendar %}
),

-- The fiscal periods of the schedule each company reports on. A line has one accounting date, so
-- it falls in exactly one of them -- there is no ambiguity at this grain, unlike a monthly rollup.
company_fiscal_period as (

    select *
    from {{ ref('int_workday_financial_management__fiscal_periods') }}
{% endif %}

{% if using_worktags %}
),

pivoted_worktags as (

    select *
    from {{ ref('int_workday_financial_management__worktags_pivoted') }}
{% endif %}

),

joined as (

    select
        journal_entry_line.source_relation,
        {{ dbt_utils.generate_surrogate_key(['journal_entry_line.journal_entry_id', 'journal_entry_line.journal_entry_line_index', 'journal_entry_line.source_relation']) }} as general_ledger_id,
        journal_entry_line.journal_entry_id,
        journal_entry_line.journal_entry_line_index,
        journal_entry.journal_number,
        journal_entry.journal_sequence_number,
        journal_entry.journal_entry_status,
        journal_entry.book_code,
        journal_entry.accounting_date,
        journal_entry.transaction_date,
        journal_entry.created_at,
        journal_entry_line.budget_date,
        {% if using_fiscal_calendar -%}
        company_fiscal_period.fiscal_schedule_code,
        company_fiscal_period.fiscal_year_name,
        company_fiscal_period.fiscal_period_id,
        company_fiscal_period.fiscal_posting_interval_code,
        company_fiscal_period.fiscal_period_start_date,
        company_fiscal_period.fiscal_period_end_date,
        {% endif -%}
        journal_entry.company_id,
        company.company_name,
        company.company_code,
        journal_entry_line.line_company_id,
        journal_entry.ledger_id,
        ledger.ledger_code,
        ledger.ledger_type,
        journal_entry_line.ledger_account_id,
        journal_entry_line.ledger_account_code,
        unambiguous_ledger_account.ledger_account_name,
        unambiguous_ledger_account.ledger_account_type,
        unambiguous_ledger_account.account_set_id,
        journal_entry_line.account_set_name,
        journal_entry.journal_source_id,
        journal_source.journal_source_name,
        journal_entry_line.currency_id,
        currency.currency_code,
        ledger_company.currency_id as ledger_currency_id,
        ledger_currency.currency_code as ledger_currency_code,
        journal_entry_line.currency_rate,
        journal_entry_line.debit_amount,
        journal_entry_line.credit_amount,
        coalesce(journal_entry_line.debit_amount, 0) - coalesce(journal_entry_line.credit_amount, 0) as net_amount,
        journal_entry_line.ledger_debit_amount,
        journal_entry_line.ledger_credit_amount,
        coalesce(journal_entry_line.ledger_debit_amount, 0) - coalesce(journal_entry_line.ledger_credit_amount, 0) as ledger_net_amount,
        journal_entry_line.quantity,
        journal_entry_line.journal_line_number,
        journal_entry_line.line_order,
        journal_entry.journal_entry_memo,
        journal_entry_line.journal_entry_line_memo,
        journal_entry.external_reference_id,
        journal_entry_line.exclude_from_spend_report,
        journal_entry.cancel_reverses_journal_entry_id,
        journal_entry.cancel_reversed_by_journal_entry_id,
        journal_entry.functional_reverses_journal_entry_id,
        journal_entry.functional_reversed_by_journal_entry_id,
        company.is_debit_credit_reversed,
        company.is_sign_reversed

        {% if using_worktags and worktag_types | length > 0 %}
            -- Every non-worktag column produced by this CTE. A worktag type can be named  after one of them, so any collision gets a pivoted_ prefix rather than silently producing a duplicate column name.
            
            {%- set line_columns = ['source_relation', 'general_ledger_id', 'journal_entry_id', 'journal_entry_line_index', 'budget_date', 'line_company_id', 'ledger_account_id', 'ledger_account_code', 'account_set_name', 'currency_id', 'currency_rate', 'debit_amount', 'credit_amount', 'net_amount', 'ledger_debit_amount', 'ledger_credit_amount', 'ledger_net_amount', 'quantity', 'journal_line_number', 'line_order', 'journal_entry_line_memo', 'exclude_from_spend_report'] -%}
            {%- set header_columns = ['journal_number', 'journal_sequence_number', 'journal_entry_status', 'book_code', 'accounting_date', 'transaction_date', 'created_at', 'company_id', 'ledger_id', 'journal_source_id', 'journal_entry_memo', 'external_reference_id', 'cancel_reverses_journal_entry_id', 'cancel_reversed_by_journal_entry_id', 'functional_reverses_journal_entry_id', 'functional_reversed_by_journal_entry_id'] -%}
            {%- set fiscal_columns = ['fiscal_schedule_code', 'fiscal_year_name', 'fiscal_period_id', 'fiscal_posting_interval_code', 'fiscal_period_start_date', 'fiscal_period_end_date'] if using_fiscal_calendar else [] -%}
            {%- set dimension_columns = ['company_name', 'company_code', 'ledger_code', 'ledger_type', 'ledger_account_name', 'ledger_account_type', 'account_set_id', 'journal_source_name', 'currency_code', 'ledger_currency_id', 'ledger_currency_code', 'is_debit_credit_reversed', 'is_sign_reversed'] + fiscal_columns -%}
            {%- set joined_columns = line_columns + header_columns + dimension_columns -%}

            {% for worktag in worktag_types %}
                , pivoted_worktags.{{ worktag.column_name }} {{ 'as pivoted_' ~ worktag.column_name if worktag.column_name in joined_columns }}
            {% endfor %}
        {% endif %}

    from journal_entry_line

    join journal_entry
        on journal_entry_line.journal_entry_id = journal_entry.journal_entry_id
        and journal_entry_line.source_relation = journal_entry.source_relation

    left join company
        on journal_entry.company_id = company.company_id
        and journal_entry.source_relation = company.source_relation

    left join ledger
        on journal_entry.ledger_id = ledger.ledger_id
        and journal_entry.source_relation = ledger.source_relation

    left join unambiguous_ledger_account
        on journal_entry_line.ledger_account_code = unambiguous_ledger_account.ledger_account_id
        and journal_entry_line.source_relation = unambiguous_ledger_account.source_relation

    left join journal_source
        on journal_entry.journal_source_id = journal_source.journal_source_id
        and journal_entry.source_relation = journal_source.source_relation

    left join currency
        on journal_entry_line.currency_id = currency.currency_id
        and journal_entry_line.source_relation = currency.source_relation

    left join ledger_company
        on ledger.company_id = ledger_company.company_id
        and ledger.source_relation = ledger_company.source_relation

    left join ledger_currency
        on ledger_company.currency_id = ledger_currency.currency_id
        and ledger_company.source_relation = ledger_currency.source_relation

    {% if using_fiscal_calendar %}
    left join company_fiscal_period
        on journal_entry.company_id = company_fiscal_period.company_id
        and journal_entry.source_relation = company_fiscal_period.source_relation
        and journal_entry.accounting_date >= company_fiscal_period.fiscal_period_start_date
        and journal_entry.accounting_date <= company_fiscal_period.fiscal_period_end_date
    {% endif %}

    {% if using_worktags %}
    left join pivoted_worktags
        on journal_entry_line.journal_entry_id = pivoted_worktags.journal_entry_id
        and journal_entry_line.journal_entry_line_index = pivoted_worktags.journal_entry_line_index
        and journal_entry_line.source_relation = pivoted_worktags.source_relation
    {% endif %}

),

final as (

    select *
    from joined

)

select *
from final
