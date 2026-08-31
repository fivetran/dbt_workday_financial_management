{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

-- Reconciles both sides of the pairing back to the detail they are built from. Catches a join that
-- drops rows as readily as one that duplicates them.

{% set tolerance = 0.01 %}

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

general_ledger as (

    select *
    from {{ ref('workday_financial_management__general_ledger') }}

),

budget_source as (

    select
        business_plan_entry_line.source_relation,
        business_plan_detail.company_id,
        business_plan_entry_line.ledger_account_id,
        business_plan_detail.currency_id,
        fiscal_period.fiscal_period_id,
        sum(coalesce(business_plan_entry_line.debit_amount, 0) - coalesce(business_plan_entry_line.credit_amount, 0)) as source_budget_amount
    from business_plan_entry_line

    join business_plan_detail
        on business_plan_entry_line.business_plan_detail_id = business_plan_detail.business_plan_detail_id
        and business_plan_entry_line.business_plan_detail_index = business_plan_detail.business_plan_detail_index
        and business_plan_entry_line.source_relation = business_plan_detail.source_relation

    join fiscal_period
        on business_plan_detail.fiscal_time_interval_id = fiscal_period.fiscal_posting_interval_id
        and cast(business_plan_detail.plan_year as {{ dbt.type_string() }}) = fiscal_period.fiscal_year_name
        and business_plan_detail.source_relation = fiscal_period.source_relation

    where business_plan_entry_line.ledger_account_id is not null
        and business_plan_detail.company_id is not null

    {{ dbt_utils.group_by(5) }}

),

actual_source as (

    select
        source_relation,
        company_id,
        ledger_account_code as ledger_account_id,
        ledger_currency_id as currency_id,
        fiscal_period_id,
        sum(ledger_net_amount) as source_actual_amount
    from general_ledger
    where ledger_account_code is not null
        and fiscal_period_id is not null

    {{ dbt_utils.group_by(5) }}

),

source_combined as (

    select
        coalesce(budget_source.source_relation, actual_source.source_relation) as source_relation,
        coalesce(budget_source.company_id, actual_source.company_id) as company_id,
        coalesce(budget_source.ledger_account_id, actual_source.ledger_account_id) as ledger_account_id,
        coalesce(budget_source.currency_id, actual_source.currency_id) as currency_id,
        coalesce(budget_source.fiscal_period_id, actual_source.fiscal_period_id) as fiscal_period_id,
        coalesce(budget_source.source_budget_amount, 0) as source_budget_amount,
        coalesce(actual_source.source_actual_amount, 0) as source_actual_amount
    from budget_source

    full outer join actual_source
        on budget_source.source_relation = actual_source.source_relation
        and budget_source.company_id = actual_source.company_id
        and budget_source.ledger_account_id = actual_source.ledger_account_id
        and budget_source.currency_id = actual_source.currency_id
        and budget_source.fiscal_period_id = actual_source.fiscal_period_id

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
        and source_combined.company_id = budget_vs_actuals.company_id
        and source_combined.ledger_account_id = budget_vs_actuals.ledger_account_id
        and source_combined.currency_id = budget_vs_actuals.currency_id
        and source_combined.fiscal_period_id = budget_vs_actuals.fiscal_period_id

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
