{{ config(enabled=var('workday_financial_management_using_business_plans', True)) }}

{{
    fivetran_utils.union_connections(
        connection_dictionary='workday_financial_management_sources',
        single_source_name='workday_financial_management',
        single_table_name='business_plan_detail'
    )
}}
