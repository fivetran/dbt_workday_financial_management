with base as (

    select *
    from {{ ref('stg_workday_financial_management__company_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_workday_financial_management__company_tmp')),
                staging_columns=get_company_columns()
            )
        }}
        {{ fivetran_utils.apply_source_relation(package_name='workday_financial_management') }}
    from base

),

final as (

    select
        source_relation,
        cast(id as {{ dbt.type_string() }}) as company_id,
        cast(currency_id as {{ dbt.type_string() }}) as currency_id,
        cast(account_set_id as {{ dbt.type_string() }}) as account_set_id,
        organization_name as company_name,
        organization_code as company_code,
        organization_active as is_active,
        fiscal_schedule_code,
        default_reporting_book_code,
        reverse_debit_credit as is_debit_credit_reversed,
        keep_debit_credit_and_reverse_sign as is_sign_reversed,
        _fivetran_synced
    from fields
    where not coalesce(_fivetran_deleted, false)

)

select *
from final
