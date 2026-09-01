{{ config(enabled=var('workday_financial_management_using_business_plans', True) and var('workday_financial_management_using_fiscal_calendar', True)) }}

-- One row per company, ledger account, currency, and fiscal period in which either a budget or actual activity exists.
-- Periods where neither side has anything are not emitted.

with business_plan_detail as (

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

-- Period dates and the fiscal year they roll up to, joined once and reused by both sides.
fiscal_period_detail as (

    select
        fiscal_period.source_relation,
        fiscal_period.fiscal_period_id,
        fiscal_period.fiscal_schedule_id,
        fiscal_year.fiscal_schedule_code,
        fiscal_period.fiscal_year_name,
        fiscal_period.fiscal_posting_interval_id,
        fiscal_period.fiscal_posting_interval_code,
        fiscal_period.fiscal_month_start_date,
        fiscal_period.fiscal_month_end_date,
        fiscal_year.fiscal_year_start_date,
        fiscal_year.fiscal_year_end_date
    from fiscal_period

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
        fiscal_period.fiscal_period_id,
        coalesce(business_plan_entry_line.debit_amount, 0) - coalesce(business_plan_entry_line.credit_amount, 0) as budget_amount
    from business_plan_entry_line

    join business_plan_detail
        on business_plan_entry_line.business_plan_detail_id = business_plan_detail.business_plan_detail_id
        and business_plan_entry_line.business_plan_detail_index = business_plan_detail.business_plan_detail_index
        and business_plan_entry_line.source_relation = business_plan_detail.source_relation

    -- Plans carrying no period at all have a plan_year of 0, which matches no fiscal year, so this join is what excludes them.
    join fiscal_period
        on business_plan_detail.fiscal_time_interval_id = fiscal_period.fiscal_posting_interval_id
        and cast(business_plan_detail.plan_year as {{ dbt.type_string() }}) = fiscal_period.fiscal_year_name
        and business_plan_detail.source_relation = fiscal_period.source_relation

    where business_plan_entry_line.ledger_account_id is not null
        and business_plan_detail.company_id is not null

),

budget as (

    select
        source_relation,
        company_id,
        ledger_account_id,
        currency_id,
        fiscal_period_id,
        sum(budget_amount) as budget_amount
    from budget_placed
    {{ dbt_utils.group_by(5) }}

),

-- The general ledger already places each line on a fiscal period, so actuals read it from there rather than repeating the date-range join.
actuals_placed as (

    select
        general_ledger.source_relation,
        general_ledger.company_id,
        general_ledger.ledger_account_code as ledger_account_id,
        general_ledger.ledger_currency_id as currency_id,
        general_ledger.fiscal_period_id,
        general_ledger.ledger_net_amount as actual_amount
    from general_ledger

    where general_ledger.ledger_account_code is not null
        and general_ledger.fiscal_period_id is not null
        -- A line with no company cannot be attributed to a plan, and company is part of the key.
        -- The budget side already drops these.
        and general_ledger.company_id is not null

),

actuals as (

    select
        source_relation,
        company_id,
        ledger_account_id,
        currency_id,
        fiscal_period_id,
        sum(actual_amount) as actual_amount
    from actuals_placed
    {{ dbt_utils.group_by(5) }}

),

-- Currency is part of the key rather than an attribute. Budget and actuals stated in different currencies are not comparable, so they stay as separate unpaired rows.
paired as (

    select
        coalesce(budget.source_relation, actuals.source_relation) as source_relation,
        coalesce(budget.company_id, actuals.company_id) as company_id,
        coalesce(budget.ledger_account_id, actuals.ledger_account_id) as ledger_account_id,
        coalesce(budget.currency_id, actuals.currency_id) as currency_id,
        coalesce(budget.fiscal_period_id, actuals.fiscal_period_id) as fiscal_period_id,
        coalesce(budget.budget_amount, 0) as budget_amount,
        coalesce(actuals.actual_amount, 0) as actual_amount,
        case when budget.budget_amount is not null then true else false end as has_budget,
        case when actuals.actual_amount is not null then true else false end as has_actuals
    from budget

    full outer join actuals
        on budget.source_relation = actuals.source_relation
        and budget.company_id = actuals.company_id
        and budget.ledger_account_id = actuals.ledger_account_id
        -- Currency is the one part of the key that is nullable, and a plain equality would leave a
        -- budget and an actual that are both missing it as two unpaired rows sharing one surrogate key.
        and coalesce(budget.currency_id, '') = coalesce(actuals.currency_id, '')
        and budget.fiscal_period_id = actuals.fiscal_period_id

),

joined as (

    select
        paired.source_relation,
        {{ dbt_utils.generate_surrogate_key(['paired.company_id', 'paired.ledger_account_id', 'paired.currency_id', 'paired.fiscal_period_id', 'paired.source_relation']) }} as budget_vs_actuals_id,
        paired.company_id,
        company.company_name,
        company.company_code,
        paired.ledger_account_id,
        unambiguous_ledger_account.ledger_account_name,
        unambiguous_ledger_account.ledger_account_type,
        paired.currency_id,
        currency.currency_code,
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
            order by joined.fiscal_month_start_date
            rows between unbounded preceding and current row
        ) as budget_amount_year_to_date,
        sum(joined.actual_amount) over (
            partition by joined.source_relation, joined.company_id, joined.ledger_account_id, joined.currency_id, joined.fiscal_year_name
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
