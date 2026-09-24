with base as (

    select *
    from {{ ref('stg_workday_financial_management__currency_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_workday_financial_management__currency_tmp')),
                staging_columns=get_currency_columns()
            )
        }}
        {{ fivetran_utils.apply_source_relation(package_name='workday_financial_management') }}
    from base

),

final as (

    select
        source_relation,
        cast(id as {{ dbt.type_string() }}) as currency_id,
        currency_code,
        description as currency_name,
        numeric_code as currency_numeric_code,
        symbol as currency_symbol,
        currency_precision,
        _fivetran_synced
    from fields
    where not coalesce(_fivetran_deleted, false)

)

select *
from final
