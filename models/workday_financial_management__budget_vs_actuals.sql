{{ config(enabled=var('workday_financial_management_using_business_plans', True) and var('workday_financial_management_using_fiscal_calendar', True)) }}

{%- set worktag_types = workday_financial_management.resolve_budget_worktag_types() -%}
{%- set using_worktags = worktag_types | length > 0 -%}

{#- Worktags are part of the grain, so they belong in the surrogate key alongside it. -#}
{%- set budget_vs_actuals_key = ['paired.company_id', 'paired.ledger_account_id', 'paired.currency_id', 'paired.fiscal_period_id', 'paired.source_relation'] -%}
{%- for worktag in worktag_types -%}
    {%- do budget_vs_actuals_key.append('paired.' ~ worktag.column_name) -%}
{%- endfor %}

-- One row per company, ledger account, currency, fiscal period, and configured worktag in which either a budget or actual activity exists.
-- Periods where neither side has anything are not emitted.

with business_plan_detail as (

    select *
    from {{ ref('stg_workday_financial_management__business_plan_detail') }}

),

business_plan_entry_line as (

    select *
    from {{ ref('stg_workday_financial_management__business_plan_entry_line') }}

),

{% if using_worktags -%}
bp_worktags as (

    select *
    from {{ ref('int_workday_financial_management__bp_worktags') }}

),
{%- endif %}

fiscal_period as (

    select *
    from {{ ref('stg_workday_financial_management__fiscal_period') }}

),

fiscal_year as (

    select *
    from {{ ref('stg_workday_financial_management__fiscal_year') }}

),

general_ledger as (

    select *
    from {{ ref('workday_financial_management__general_ledger') }}

),

company as (

    select *
    from {{ ref('stg_workday_financial_management__company') }}

),

currency as (

    select *
    from {{ ref('stg_workday_financial_management__currency') }}

),

ledger_account as (

    select *
    from {{ ref('stg_workday_financial_management__ledger_account') }}

),

-- An account code that appears in more than one account set cannot be resolved to a single name, so it resolves to none.
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

-- A tenant names its fiscal years freely -- "FY26", "2026", "FY25-26" -- so the name cannot be
-- compared to a plan's numeric year. The periods carry real dates, so the year is derived from
-- them as a fallback for tenants that leave fiscal_year_number unpopulated.
fiscal_year_bounds as (

    select
        source_relation,
        fiscal_schedule_id,
        fiscal_year_name,
        min(fiscal_month_start_date) as fiscal_year_start_date,
        max(fiscal_month_end_date) as fiscal_year_end_date
    from fiscal_period
    {{ dbt_utils.group_by(3) }}

),

-- A fiscal year is numbered by the calendar year it ends in, on calendar and non-calendar
-- schedules alike.
fiscal_year_derived as (

    select
        source_relation,
        fiscal_schedule_id,
        fiscal_year_name,
        fiscal_year_start_date,
        fiscal_year_end_date,
        -- dbt has no cross-database date_part macro. Every destination this package supports
        -- accepts extract, and Postgres returns it as a float, so the cast is explicit.
        cast(extract(year from fiscal_year_end_date) as {{ dbt.type_int() }}) as fiscal_year_number
    from fiscal_year_bounds

),

-- Period dates and the fiscal year they roll up to, joined once and reused by both sides.
fiscal_period_detail as (

    select
        fiscal_period.source_relation,
        fiscal_period.fiscal_period_id,
        fiscal_period.fiscal_schedule_id,
        fiscal_year.fiscal_schedule_code,
        fiscal_period.fiscal_year_name,
        -- Prefer the year the tenant declares; fall back to the year its periods imply. The
        -- declared value honours a tenant's own numbering, and the derived value covers a missing
        -- or unpopulated fiscal_year row. One of the two is always present.
        coalesce(fiscal_year.fiscal_year_number, fiscal_year_derived.fiscal_year_number) as fiscal_year_number,
        fiscal_period.fiscal_posting_interval_id,
        fiscal_period.fiscal_posting_interval_code,
        fiscal_period.fiscal_month_start_date,
        fiscal_period.fiscal_month_end_date,
        coalesce(fiscal_year.fiscal_year_start_date, fiscal_year_derived.fiscal_year_start_date) as fiscal_year_start_date,
        coalesce(fiscal_year.fiscal_year_end_date, fiscal_year_derived.fiscal_year_end_date) as fiscal_year_end_date
    from fiscal_period

    -- Built from fiscal_period itself, so every period has a row and this join drops nothing.
    join fiscal_year_derived
        on fiscal_period.fiscal_schedule_id = fiscal_year_derived.fiscal_schedule_id
        and fiscal_period.fiscal_year_name = fiscal_year_derived.fiscal_year_name
        and fiscal_period.source_relation = fiscal_year_derived.source_relation

    -- Only the schedule's display code now depends on this join, so a tenant missing rows in
    -- fiscal_year loses a label rather than a period.
    left join fiscal_year
        on fiscal_period.fiscal_schedule_id = fiscal_year.fiscal_schedule_id
        and fiscal_period.fiscal_year_name = fiscal_year.fiscal_year_name
        and fiscal_period.source_relation = fiscal_year.source_relation

),

-- A posting interval names a position in the year and repeats every year, so the plan's year is part of the key. 
budget_placed as (

    select
        business_plan_entry_line.source_relation,
        business_plan_detail.company_id,
        business_plan_entry_line.ledger_account_id,
        business_plan_detail.currency_id,
        fiscal_period_detail.fiscal_period_id,
        {%- for worktag in worktag_types %}
        bp_worktags.{{ worktag.column_name }},
        {%- endfor %}
        coalesce(business_plan_entry_line.debit_amount, 0) - coalesce(business_plan_entry_line.credit_amount, 0) as budget_amount
    from business_plan_entry_line

    join business_plan_detail
        on business_plan_entry_line.business_plan_detail_id = business_plan_detail.business_plan_detail_id
        and business_plan_entry_line.business_plan_detail_index = business_plan_detail.business_plan_detail_index
        and business_plan_entry_line.source_relation = business_plan_detail.source_relation

    {% if using_worktags -%}
    -- Left joined: a plan line with no worktag still carries a budget, and drops into the null bucket.
    left join bp_worktags
        on business_plan_entry_line.business_plan_detail_id = bp_worktags.business_plan_detail_id
        and business_plan_entry_line.business_plan_detail_index = bp_worktags.business_plan_detail_index
        and business_plan_entry_line.business_plan_entry_line_index = bp_worktags.business_plan_entry_line_index
        and business_plan_entry_line.source_relation = bp_worktags.source_relation
    {%- endif %}

    -- The posting interval also implicitly selects the schedule -- business_plan_detail carries no
    -- fiscal_schedule_id, so it is the only route to one.
    -- Plans carrying no period at all have a plan_year of 0, which matches no fiscal year, so this join is what excludes them.
    join fiscal_period_detail
        on business_plan_detail.fiscal_time_interval_id = fiscal_period_detail.fiscal_posting_interval_id
        and business_plan_detail.plan_year = fiscal_period_detail.fiscal_year_number
        and business_plan_detail.source_relation = fiscal_period_detail.source_relation

    -- A plan with no company is kept and pairs into the unassigned company bucket, so budget totals
    -- still reconcile to the plan lines.
    where business_plan_entry_line.ledger_account_id is not null

),

budget as (

    select
        source_relation,
        company_id,
        ledger_account_id,
        currency_id,
        fiscal_period_id,
        {%- for worktag in worktag_types %}
        {{ worktag.column_name }},
        {%- endfor %}
        sum(budget_amount) as budget_amount
    from budget_placed
    {{ dbt_utils.group_by(5 + worktag_types | length) }}

),

-- The general ledger already places each line on a fiscal period, so actuals read it from there rather than repeating the date-range join.
actuals_placed as (

    select
        general_ledger.source_relation,
        general_ledger.company_id,
        general_ledger.ledger_account_code as ledger_account_id,
        general_ledger.ledger_currency_id as currency_id,
        general_ledger.fiscal_period_id,
        {%- for worktag in worktag_types %}
        general_ledger.{{ worktag.column_name }},
        {%- endfor %}
        general_ledger.ledger_net_amount as actual_amount
    from general_ledger

    -- A line with no company is not filtered here, to match the budget side. In practice the general
    -- ledger finds a line's period through its company's schedule, so these lines have no period and
    -- the fiscal_period_id filter drops them.
    where general_ledger.ledger_account_code is not null
        and general_ledger.fiscal_period_id is not null

),

actuals as (

    select
        source_relation,
        company_id,
        ledger_account_id,
        currency_id,
        fiscal_period_id,
        {%- for worktag in worktag_types %}
        {{ worktag.column_name }},
        {%- endfor %}
        sum(actual_amount) as actual_amount
    from actuals_placed
    {{ dbt_utils.group_by(5 + worktag_types | length) }}

),

-- Currency is part of the key rather than an attribute. Budget and actuals stated in different currencies are not comparable, so they stay as separate unpaired rows.
paired as (

    select
        coalesce(budget.source_relation, actuals.source_relation) as source_relation,
        coalesce(budget.company_id, actuals.company_id) as company_id,
        coalesce(budget.ledger_account_id, actuals.ledger_account_id) as ledger_account_id,
        coalesce(budget.currency_id, actuals.currency_id) as currency_id,
        coalesce(budget.fiscal_period_id, actuals.fiscal_period_id) as fiscal_period_id,
        {%- for worktag in worktag_types %}
        coalesce(budget.{{ worktag.column_name }}, actuals.{{ worktag.column_name }}) as {{ worktag.column_name }},
        {%- endfor %}
        coalesce(budget.budget_amount, 0) as budget_amount,
        coalesce(actuals.actual_amount, 0) as actual_amount,
        case when budget.budget_amount is not null then true else false end as has_budget,
        case when actuals.actual_amount is not null then true else false end as has_actuals
    from budget

    full outer join actuals
        on budget.source_relation = actuals.source_relation
        and coalesce(budget.company_id, '') = coalesce(actuals.company_id, '')
        and budget.ledger_account_id = actuals.ledger_account_id
        -- Company, currency, and the worktags are the nullable parts of the key, and a plain equality would
        -- leave a budget and an actual that are both missing one as two unpaired rows sharing one
        -- surrogate key. An untagged budget line pairs with an untagged actual.
        and coalesce(budget.currency_id, '') = coalesce(actuals.currency_id, '')
        and budget.fiscal_period_id = actuals.fiscal_period_id
        {%- for worktag in worktag_types %}
        and coalesce(budget.{{ worktag.column_name }}, '') = coalesce(actuals.{{ worktag.column_name }}, '')
        {%- endfor %}

),

joined as (

    select
        paired.source_relation,
        {{ dbt_utils.generate_surrogate_key(budget_vs_actuals_key) }} as budget_vs_actuals_id,
        paired.company_id,
        -- Labels the unassigned bucket. A company_id missing from the company table stays null.
        case when paired.company_id is null then 'Unassigned' else company.company_name end as company_name,
        company.company_code,
        case when paired.company_id is not null then true else false end as has_company,
        paired.ledger_account_id,
        unambiguous_ledger_account.ledger_account_name,
        unambiguous_ledger_account.ledger_account_type,
        paired.currency_id,
        currency.currency_code,
        {%- for worktag in worktag_types %}
        paired.{{ worktag.column_name }},
        {%- endfor %}
        fiscal_period_detail.fiscal_schedule_code,
        fiscal_period_detail.fiscal_year_name,
        fiscal_period_detail.fiscal_year_start_date,
        fiscal_period_detail.fiscal_year_end_date,
        paired.fiscal_period_id,
        fiscal_period_detail.fiscal_posting_interval_code as fiscal_month_name,
        fiscal_period_detail.fiscal_month_start_date,
        fiscal_period_detail.fiscal_month_end_date,
        paired.has_budget,
        paired.has_actuals,
        paired.budget_amount,
        paired.actual_amount,
        paired.actual_amount - paired.budget_amount as variance_amount
    from paired

    left join company
        on paired.company_id = company.company_id
        and paired.source_relation = company.source_relation

    left join unambiguous_ledger_account
        on paired.ledger_account_id = unambiguous_ledger_account.ledger_account_id
        and paired.source_relation = unambiguous_ledger_account.source_relation

    left join currency
        on paired.currency_id = currency.currency_id
        and paired.source_relation = currency.source_relation

    left join fiscal_period_detail
        on paired.fiscal_period_id = fiscal_period_detail.fiscal_period_id
        and paired.source_relation = fiscal_period_detail.source_relation

),

-- Year to date accumulates within the fiscal year the period belongs to, which is not the calendar year for a company on a non-calendar schedule.
year_to_date as (

    select
        joined.*,
        case
            when joined.budget_amount = 0 then null
            else (joined.actual_amount - joined.budget_amount) / abs(joined.budget_amount)
        end as variance_percent,
        sum(joined.budget_amount) over (
            partition by joined.source_relation, joined.company_id, joined.ledger_account_id, joined.currency_id, joined.fiscal_year_name
                {%- for worktag in worktag_types %}, joined.{{ worktag.column_name }}{% endfor %}
            order by joined.fiscal_month_start_date
            rows between unbounded preceding and current row
        ) as budget_amount_year_to_date,
        sum(joined.actual_amount) over (
            partition by joined.source_relation, joined.company_id, joined.ledger_account_id, joined.currency_id, joined.fiscal_year_name
                {%- for worktag in worktag_types %}, joined.{{ worktag.column_name }}{% endfor %}
            order by joined.fiscal_month_start_date
            rows between unbounded preceding and current row
        ) as actual_amount_year_to_date
    from joined

),

final as (

    select
        year_to_date.*,
        year_to_date.actual_amount_year_to_date - year_to_date.budget_amount_year_to_date as variance_amount_year_to_date
    from year_to_date

)

select *
from final
