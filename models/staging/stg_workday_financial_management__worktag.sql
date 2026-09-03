{{ config(enabled=var('workday_financial_management_using_worktags', True)) }}

with base as (

    select *
    from {{ ref('stg_workday_financial_management__worktag_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_workday_financial_management__worktag_tmp')),
                staging_columns=get_worktag_columns()
            )
        }}
        {{ fivetran_utils.apply_source_relation(package_name='workday_financial_management') }}
    from base

),

final as (

    select
        source_relation,
        cast(id as {{ dbt.type_string() }}) as worktag_id,
        attribute as worktag_type,
        descriptor as worktag_name,
        value as worktag_value,
        _fivetran_synced
    from fields
    where not coalesce(_fivetran_deleted, false)

)

select *
from final
