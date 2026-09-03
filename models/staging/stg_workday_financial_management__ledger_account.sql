with base as (

    select *
    from {{ ref('stg_workday_financial_management__ledger_account_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_workday_financial_management__ledger_account_tmp')),
                staging_columns=get_ledger_account_columns()
            )
        }}
        {{ fivetran_utils.apply_source_relation(package_name='workday_financial_management') }}
    from base

),

final as (

    select
        source_relation,
        cast(id as {{ dbt.type_string() }}) as ledger_account_id,
        cast(account_set_id as {{ dbt.type_string() }}) as account_set_id,
        name as ledger_account_name,
        type as ledger_account_type,
        retired as is_retired,
        _fivetran_synced
    from fields
    where not coalesce(_fivetran_deleted, false)

)

select *
from final
