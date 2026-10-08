{{ config(enabled=var('workday_financial_management__using_fiscal_calendar', False)) }}

with base as (

    select *
    from {{ ref('stg_workday_financial_management__fiscal_period_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_workday_financial_management__fiscal_period_tmp')),
                staging_columns=get_fiscal_period_columns()
            )
        }}
        {{ fivetran_utils.apply_source_relation(package_name='workday_financial_management') }}
    from base

),

final as (

    select
        source_relation,
        cast(fiscal_schedule_id as {{ dbt.type_string() }}) as fiscal_schedule_id,
        cast(fiscal_year_name as {{ dbt.type_string() }}) as fiscal_year_name,
        cast(fiscal_posting_interval_id as {{ dbt.type_string() }}) as fiscal_posting_interval_id,
        fiscal_posting_interval_code,
        fiscal_period_start_date as fiscal_month_start_date,
        fiscal_period_end_date as fiscal_month_end_date,
        _fivetran_synced
    from fields
    where not coalesce(_fivetran_deleted, false)

)

select *
from final
