{{ config(enabled=var('workday_financial_management_using_fiscal_calendar', True)) }}

-- One row per company and fiscal period, resolving each company's fiscal schedule into the dated
-- periods it reports on. Journal activity is placed on a fiscal period by finding the period whose
-- date range contains the accounting date.

with company as (

    select *
    from {{ ref('stg_workday_financial_management__company') }}

),

fiscal_year as (

    select *
    from {{ ref('stg_workday_financial_management__fiscal_year') }}

),

fiscal_period as (

    select *
    from {{ ref('stg_workday_financial_management__fiscal_period') }}

),

-- A company names its schedule by code, so the schedule identifier has to come from the fiscal
-- year, which carries both.
company_schedule as (

    select distinct
        company.source_relation,
        company.company_id,
        fiscal_year.fiscal_schedule_id,
        fiscal_year.fiscal_schedule_code
    from company

    join fiscal_year
        on company.fiscal_schedule_code = fiscal_year.fiscal_schedule_code
        and company.source_relation = fiscal_year.source_relation

),

final as (

    select
        company_schedule.source_relation,
        company_schedule.company_id,
        company_schedule.fiscal_schedule_id,
        company_schedule.fiscal_schedule_code,
        fiscal_period.fiscal_period_id,
        fiscal_period.fiscal_year_name,
        fiscal_period.fiscal_posting_interval_id,
        fiscal_period.fiscal_posting_interval_code,
        fiscal_period.fiscal_period_start_date,
        fiscal_period.fiscal_period_end_date,
        fiscal_year.fiscal_year_start_date,
        fiscal_year.fiscal_year_end_date
    from company_schedule

    join fiscal_period
        on company_schedule.fiscal_schedule_id = fiscal_period.fiscal_schedule_id
        and company_schedule.source_relation = fiscal_period.source_relation

    join fiscal_year
        on fiscal_period.fiscal_schedule_id = fiscal_year.fiscal_schedule_id
        and fiscal_period.fiscal_year_name = fiscal_year.fiscal_year_name
        and fiscal_period.source_relation = fiscal_year.source_relation

)

select *
from final
