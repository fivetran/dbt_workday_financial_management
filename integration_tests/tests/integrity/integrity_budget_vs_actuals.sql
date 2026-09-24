{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

{%- set tolerance = 0.01 -%}
{%- set worktag_types = workday_financial_management.resolve_budget_worktag_types() -%}
{%- set using_worktags = worktag_types | length > 0 -%}

-- Reconciles both sides of the pairing back to the detail they are built from. Catches a join that
-- drops rows as readily as one that duplicates them.

with budget_vs_actuals as (

    select *
    from {{ ref('workday_financial_management__budget_vs_actuals') }}

),

business_plan_detail as (

    select *
    from {{ ref('stg_workday_financial_management__business_plan_detail') }}

),

business_plan_entry_line as (

    select *
    from {{ ref('stg_workday_financial_management__business_plan_entry_line') }}

),

fiscal_period as (

    select *
    from {{ ref('stg_workday_financial_management__fiscal_period') }}

),

fiscal_year as (

    select *
    from {{ ref('stg_workday_financial_management__fiscal_year') }}

),

fiscal_year_bounds as (

    select
        source_relation,
        fiscal_schedule_id,
        fiscal_year_name,
        max(fiscal_month_end_date) as fiscal_year_end_date
    from fiscal_period
    {{ dbt_utils.group_by(3) }}

),

-- This test reconciles amounts, so it has to place a budget on the same period the model does.
-- Whether that placement is itself correct is guarded separately, by integrity_fiscal_calendar.
fiscal_year_resolved as (

    select
        fiscal_year_bounds.source_relation,
        fiscal_year_bounds.fiscal_schedule_id,
        fiscal_year_bounds.fiscal_year_name,
        coalesce(
            fiscal_year.fiscal_year_number,
            cast(extract(year from fiscal_year_bounds.fiscal_year_end_date) as {{ dbt.type_int() }})
        ) as fiscal_year_number
    from fiscal_year_bounds

    left join fiscal_year
        on fiscal_year_bounds.fiscal_schedule_id = fiscal_year.fiscal_schedule_id
        and fiscal_year_bounds.fiscal_year_name = fiscal_year.fiscal_year_name
        and fiscal_year_bounds.source_relation = fiscal_year.source_relation

),

general_ledger as (

    select *
    from {{ ref('workday_financial_management__general_ledger') }}

),
{%- if using_worktags %}

-- Pivoted here rather than read from int_..._bp_worktags, so a fault in that pivot shows up as a
-- reconciliation failure instead of being reproduced identically on both sides of the comparison.
budget_worktags as (

    select
        business_plan_line_worktag.source_relation,
        business_plan_line_worktag.business_plan_detail_id,
        business_plan_line_worktag.business_plan_detail_index,
        business_plan_line_worktag.business_plan_entry_line_index
        {%- for worktag in worktag_types %}
        , max(case when lower(worktag.worktag_type) = '{{ dbt.escape_single_quotes(worktag.worktag_type | lower) }}' then worktag.worktag_value end) as {{ worktag.column_name }}
        {%- endfor %}
    from {{ ref('stg_workday_financial_management__business_plan_line_worktag') }} as business_plan_line_worktag

    join {{ ref('int_workday_financial_management__worktag_lookup') }} as worktag
        on business_plan_line_worktag.worktag_id = worktag.worktag_id
        and business_plan_line_worktag.source_relation = worktag.source_relation

    {{ dbt_utils.group_by(4) }}

),
{%- endif %}

budget_source as (

    select
        business_plan_entry_line.source_relation,
        business_plan_detail.company_id,
        business_plan_entry_line.ledger_account_id,
        business_plan_detail.currency_id,
        fiscal_period.fiscal_period_id,
        {%- for worktag in worktag_types %}
        budget_worktags.{{ worktag.column_name }},
        {%- endfor %}
        sum(coalesce(business_plan_entry_line.debit_amount, 0) - coalesce(business_plan_entry_line.credit_amount, 0)) as source_budget_amount
    from business_plan_entry_line

    join business_plan_detail
        on business_plan_entry_line.business_plan_detail_id = business_plan_detail.business_plan_detail_id
        and business_plan_entry_line.business_plan_detail_index = business_plan_detail.business_plan_detail_index
        and business_plan_entry_line.source_relation = business_plan_detail.source_relation

    join fiscal_period
        on business_plan_detail.fiscal_time_interval_id = fiscal_period.fiscal_posting_interval_id
        and business_plan_detail.source_relation = fiscal_period.source_relation

    join fiscal_year_resolved
        on fiscal_period.fiscal_schedule_id = fiscal_year_resolved.fiscal_schedule_id
        and fiscal_period.fiscal_year_name = fiscal_year_resolved.fiscal_year_name
        and fiscal_period.source_relation = fiscal_year_resolved.source_relation
        and business_plan_detail.plan_year = fiscal_year_resolved.fiscal_year_number
    {%- if using_worktags %}

    left join budget_worktags
        on business_plan_entry_line.business_plan_detail_id = budget_worktags.business_plan_detail_id
        and business_plan_entry_line.business_plan_detail_index = budget_worktags.business_plan_detail_index
        and business_plan_entry_line.business_plan_entry_line_index = budget_worktags.business_plan_entry_line_index
        and business_plan_entry_line.source_relation = budget_worktags.source_relation
    {%- endif %}

    where business_plan_entry_line.ledger_account_id is not null

    {{ dbt_utils.group_by(5 + worktag_types | length) }}

),

actual_source as (

    select
        source_relation,
        company_id,
        ledger_account_code as ledger_account_id,
        ledger_currency_id as currency_id,
        fiscal_period_id,
        {%- for worktag in worktag_types %}
        {{ worktag.column_name }},
        {%- endfor %}
        sum(ledger_net_amount) as source_actual_amount
    from general_ledger

    where ledger_account_code is not null
        and fiscal_period_id is not null

    {{ dbt_utils.group_by(5 + worktag_types | length) }}

),

source_combined as (

    select
        coalesce(budget_source.source_relation, actual_source.source_relation) as source_relation,
        coalesce(budget_source.company_id, actual_source.company_id) as company_id,
        coalesce(budget_source.ledger_account_id, actual_source.ledger_account_id) as ledger_account_id,
        coalesce(budget_source.currency_id, actual_source.currency_id) as currency_id,
        coalesce(budget_source.fiscal_period_id, actual_source.fiscal_period_id) as fiscal_period_id,
        {%- for worktag in worktag_types %}
        coalesce(budget_source.{{ worktag.column_name }}, actual_source.{{ worktag.column_name }}) as {{ worktag.column_name }},
        {%- endfor %}
        coalesce(budget_source.source_budget_amount, 0) as source_budget_amount,
        coalesce(actual_source.source_actual_amount, 0) as source_actual_amount
    from budget_source

    full outer join actual_source
        on budget_source.source_relation = actual_source.source_relation
        -- Company and currency are nullable, so nulls have to pair with nulls the same way the model does.
        and coalesce(budget_source.company_id, '') = coalesce(actual_source.company_id, '')
        and budget_source.ledger_account_id = actual_source.ledger_account_id
        and coalesce(budget_source.currency_id, '') = coalesce(actual_source.currency_id, '')
        and budget_source.fiscal_period_id = actual_source.fiscal_period_id
        {%- for worktag in worktag_types %}
        and coalesce(budget_source.{{ worktag.column_name }}, '') = coalesce(actual_source.{{ worktag.column_name }}, '')
        {%- endfor %}

),

compared as (

    select
        coalesce(source_combined.source_relation, budget_vs_actuals.source_relation) as source_relation,
        coalesce(source_combined.company_id, budget_vs_actuals.company_id) as company_id,
        coalesce(source_combined.ledger_account_id, budget_vs_actuals.ledger_account_id) as ledger_account_id,
        coalesce(source_combined.fiscal_period_id, budget_vs_actuals.fiscal_period_id) as fiscal_period_id,
        source_combined.source_budget_amount,
        source_combined.source_actual_amount,
        budget_vs_actuals.budget_amount,
        budget_vs_actuals.actual_amount
    from source_combined

    full outer join budget_vs_actuals
        on source_combined.source_relation = budget_vs_actuals.source_relation
        and coalesce(source_combined.company_id, '') = coalesce(budget_vs_actuals.company_id, '')
        and source_combined.ledger_account_id = budget_vs_actuals.ledger_account_id
        and coalesce(source_combined.currency_id, '') = coalesce(budget_vs_actuals.currency_id, '')
        and source_combined.fiscal_period_id = budget_vs_actuals.fiscal_period_id
        {%- for worktag in worktag_types %}
        and coalesce(source_combined.{{ worktag.column_name }}, '') = coalesce(budget_vs_actuals.{{ worktag.column_name }}, '')
        {%- endfor %}

),

final as (

    select
        source_relation,
        company_id,
        ledger_account_id,
        fiscal_period_id,
        source_budget_amount,
        budget_amount,
        source_actual_amount,
        actual_amount,
        case
            when budget_amount is null then 'combination exists in the source but not in the model'
            when source_budget_amount is null then 'combination exists in the model but not in the source'
            when abs(source_budget_amount - budget_amount) > {{ tolerance }} then 'budget does not match the plan lines'
            else 'actuals do not match the general ledger'
        end as failure_reason
    from compared

    where budget_amount is null
        or source_budget_amount is null
        or abs(source_budget_amount - budget_amount) > {{ tolerance }}
        or abs(source_actual_amount - actual_amount) > {{ tolerance }}

)

select *
from final
