{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

-- Guards the assumptions the fiscal calendar joins rest on.

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

fiscal_year_bounds as (

    select
        source_relation,
        fiscal_schedule_id,
        fiscal_year_name,
        max(fiscal_month_end_date) as fiscal_year_end_date
    from fiscal_period
    {{ dbt_utils.group_by(3) }}

),

-- A fiscal year is numbered by the calendar year it ends in.
fiscal_year_derived as (

    select
        source_relation,
        fiscal_schedule_id,
        fiscal_year_name,
        cast(extract(year from fiscal_year_end_date) as {{ dbt.type_int() }}) as fiscal_year_number
    from fiscal_year_bounds

),

-- The year a plan is placed on: declared when the tenant populates it, derived otherwise.
fiscal_year_resolved as (

    select
        fiscal_year_derived.source_relation,
        fiscal_year_derived.fiscal_schedule_id,
        fiscal_year_derived.fiscal_year_name,
        coalesce(fiscal_year.fiscal_year_number, fiscal_year_derived.fiscal_year_number) as fiscal_year_number
    from fiscal_year_derived

    left join fiscal_year
        on fiscal_year_derived.fiscal_schedule_id = fiscal_year.fiscal_schedule_id
        and fiscal_year_derived.fiscal_year_name = fiscal_year.fiscal_year_name
        and fiscal_year_derived.source_relation = fiscal_year.source_relation

),

-- A tenant's declared fiscal year number should agree with the year its own periods end in. When
-- the two disagree, either the tenant numbers its years against convention or periods are missing
-- from the sync. Both place a budget on the wrong fiscal year.
year_number_conflicts as (

    select
        'the declared fiscal year number disagrees with the year its periods end in' as failure_reason,
        fiscal_year.source_relation,
        fiscal_year.fiscal_schedule_id,
        cast(null as {{ dbt.type_string() }}) as fiscal_period_id,
        fiscal_year.fiscal_year_name as conflicting_key
    from fiscal_year

    join fiscal_year_derived
        on fiscal_year.fiscal_schedule_id = fiscal_year_derived.fiscal_schedule_id
        and fiscal_year.fiscal_year_name = fiscal_year_derived.fiscal_year_name
        and fiscal_year.source_relation = fiscal_year_derived.source_relation

    where fiscal_year.fiscal_year_number is not null
        and fiscal_year.fiscal_year_number != fiscal_year_derived.fiscal_year_number

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
        and business_plan_detail.source_relation = fiscal_period.source_relation

    join fiscal_year_resolved
        on fiscal_period.fiscal_schedule_id = fiscal_year_resolved.fiscal_schedule_id
        and fiscal_period.fiscal_year_name = fiscal_year_resolved.fiscal_year_name
        and fiscal_period.source_relation = fiscal_year_resolved.source_relation
        and business_plan_detail.plan_year = fiscal_year_resolved.fiscal_year_number

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

    union all

    select *
    from year_number_conflicts

)

select *
from final
