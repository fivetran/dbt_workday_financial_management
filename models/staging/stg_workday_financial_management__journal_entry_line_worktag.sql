{{ config(enabled=var('workday_financial_management_using_worktags', True)) }}

with base as (

    select *
    from {{ ref('stg_workday_financial_management__je_line_worktag_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_workday_financial_management__je_line_worktag_tmp')),
                staging_columns=get_journal_entry_line_worktag_columns()
            )
        }}
        {{ fivetran_utils.apply_source_relation(package_name='workday_financial_management') }}
    from base

),

final as (

    select
        source_relation,
        {{ dbt_utils.generate_surrogate_key(['journal_entry_id', 'journal_entry_line_index', 'worktag_id', 'source_relation']) }} as journal_entry_line_worktag_id,
        cast(journal_entry_id as {{ dbt.type_string() }}) as journal_entry_id,
        journal_entry_line_index,
        cast(worktag_id as {{ dbt.type_string() }}) as worktag_id,
        _fivetran_synced
    from fields
    where not coalesce(_fivetran_deleted, false)

)

select *
from final
