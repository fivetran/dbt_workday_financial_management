{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

-- Guards the two assumptions the fiscal calendar joins rest on.

with fiscal_period as (

    select *
    from {{ ref('stg_workday_financial_management__fiscal_period') }}

),

fiscal_year as (

    select *
    from {{ ref('stg_workday_financial_management__fiscal_year') }}

),

business_plan_detail as (

    select *
    from {{ ref('stg_workday_financial_management__business_plan_detail') }}

),

company as (

    select *
    from {{ ref('stg_workday_financial_management__company') }}

),

schedule_by_code as (

    select distinct
        source_relation,
        fiscal_schedule_code,
        fiscal_schedule_id
    from fiscal_year

),

overlapping_periods as (

    select
        'two fiscal periods of the same schedule overlap' as failure_reason,
        earlier.source_relation,
        earlier.fiscal_schedule_id,
        earlier.fiscal_period_id,
        later.fiscal_period_id as conflicting_key
    from fiscal_period as earlier

    join fiscal_period as later
        on earlier.fiscal_schedule_id = later.fiscal_schedule_id
        and earlier.source_relation = later.source_relation
        and earlier.fiscal_period_id < later.fiscal_period_id
        and earlier.fiscal_month_start_date <= later.fiscal_month_end_date
        and later.fiscal_month_start_date <= earlier.fiscal_month_end_date

),

plan_schedule_conflicts as (

    select
        'a business plan dates against a schedule its company does not report on' as failure_reason,
        business_plan_detail.source_relation,
        fiscal_period.fiscal_schedule_id,
        fiscal_period.fiscal_period_id,
        business_plan_detail.business_plan_detail_id as conflicting_key
    from business_plan_detail

    join fiscal_period
        on business_plan_detail.fiscal_time_interval_id = fiscal_period.fiscal_posting_interval_id
        and cast(business_plan_detail.plan_year as {{ dbt.type_string() }}) = fiscal_period.fiscal_year_name
        and business_plan_detail.source_relation = fiscal_period.source_relation

    join company
        on business_plan_detail.company_id = company.company_id
        and business_plan_detail.source_relation = company.source_relation

    join schedule_by_code
        on company.fiscal_schedule_code = schedule_by_code.fiscal_schedule_code
        and company.source_relation = schedule_by_code.source_relation

    where fiscal_period.fiscal_schedule_id != schedule_by_code.fiscal_schedule_id

),

final as (

    select *
    from overlapping_periods

    union all

    select *
    from plan_schedule_conflicts

)

select *
from final
