{{ config(enabled=var('workday_financial_management_using_fiscal_calendar', True)) }}

with base as (

    select *
    from {{ ref('stg_workday_financial_management__fiscal_year_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_workday_financial_management__fiscal_year_tmp')),
                staging_columns=get_fiscal_year_columns()
            )
        }}
        {{ fivetran_utils.apply_source_relation(package_name='workday_financial_management') }}
    from base

),

final as (

    select
        source_relation,
        cast(fiscal_year_id as {{ dbt.type_string() }}) as fiscal_year_id,
        cast(fiscal_schedule_id as {{ dbt.type_string() }}) as fiscal_schedule_id,
        fiscal_schedule_code,
        cast(fiscal_year_name as {{ dbt.type_string() }}) as fiscal_year_name,
        fiscal_year_code,
        fiscal_year_number,
        fiscal_year_start_date,
        fiscal_year_end_date,
        _fivetran_synced
    from fields
    where not coalesce(_fivetran_deleted, false)

)

select *
from final
