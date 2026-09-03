{{ config(enabled=var('workday_financial_management_using_business_plans', True)) }}

with base as (

    select *
    from {{ ref('stg_workday_financial_management__business_plan_detail_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_workday_financial_management__business_plan_detail_tmp')),
                staging_columns=get_business_plan_detail_columns()
            )
        }}
        {{ fivetran_utils.apply_source_relation(package_name='workday_financial_management') }}
    from base

),

final as (

    select
        source_relation,
        {{ dbt_utils.generate_surrogate_key(['id', 'index', 'source_relation']) }} as business_plan_detail_key,
        cast(id as {{ dbt.type_string() }}) as business_plan_detail_id,
        index as business_plan_detail_index,
        cast(business_plan_details_ref_id as {{ dbt.type_string() }}) as business_plan_reference_id,
        cast(company_id as {{ dbt.type_string() }}) as company_id,
        cast(currency_id as {{ dbt.type_string() }}) as currency_id,
        cast(business_plan_structure_id as {{ dbt.type_string() }}) as business_plan_structure_id,
        cast(organizing_dimension_id as {{ dbt.type_string() }}) as organizing_dimension_id,
        year as plan_year,
        cast(fiscal_time_interval_id as {{ dbt.type_string() }}) as fiscal_time_interval_id,
        fiscal_posting_interval_code,
        award_posting_interval_code,
        cast(award_contract_id as {{ dbt.type_string() }}) as award_contract_id,
        award_proposal_code,
        project_budget_code,
        plan_memo as business_plan_memo,
        _fivetran_synced
    from fields
    where not coalesce(_fivetran_deleted, false)

)

select *
from final
