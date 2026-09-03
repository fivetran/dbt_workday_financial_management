with base as (

    select *
    from {{ ref('stg_workday_financial_management__journal_source_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_workday_financial_management__journal_source_tmp')),
                staging_columns=get_journal_source_columns()
            )
        }}
        {{ fivetran_utils.apply_source_relation(package_name='workday_financial_management') }}
    from base

),

final as (

    select
        source_relation,
        cast(id as {{ dbt.type_string() }}) as journal_source_id,
        cast(journal_source_id as {{ dbt.type_string() }}) as journal_source_reference_id,
        journal_source_name,
        _fivetran_synced
    from fields
    where not coalesce(_fivetran_deleted, false)

)

select *
from final
