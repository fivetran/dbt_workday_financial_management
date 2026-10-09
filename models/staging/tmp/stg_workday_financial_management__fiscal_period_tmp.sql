{{ config(enabled=var('workday_financial_management__using_fiscal_calendar', False)) }}

{{
    fivetran_utils.union_connections(
        connection_dictionary='workday_financial_management_sources',
        single_source_name='workday_financial_management',
        single_table_name='fiscal_period'
    )
}}
