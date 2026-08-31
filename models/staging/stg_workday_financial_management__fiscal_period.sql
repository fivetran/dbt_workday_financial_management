{{ config(enabled=var('workday_financial_management_using_fiscal_calendar', True)) }}

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
        -- The source carries no key of its own. A posting interval identifies a position in the
        -- year, such as the third month, so it repeats across years and schedules -- all three
        -- parts are needed to land on one period.
        {{ dbt_utils.generate_surrogate_key(['fiscal_schedule_id', 'fiscal_year_name', 'fiscal_posting_interval_id', 'source_relation']) }} as fiscal_period_id,
        cast(fiscal_schedule_id as {{ dbt.type_string() }}) as fiscal_schedule_id,
        cast(fiscal_year_name as {{ dbt.type_string() }}) as fiscal_year_name,
        cast(fiscal_posting_interval_id as {{ dbt.type_string() }}) as fiscal_posting_interval_id,
        fiscal_posting_interval_code,
        fiscal_period_start_date,
        fiscal_period_end_date,
        _fivetran_synced
    from fields
    where not coalesce(_fivetran_deleted, false)

)

select *
from final
