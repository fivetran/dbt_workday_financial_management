{% macro get_fiscal_period_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "fiscal_period_end_date", "datatype": "date"},
    {"name": "fiscal_period_start_date", "datatype": "date"},
    {"name": "fiscal_posting_interval_code", "datatype": dbt.type_string()},
    {"name": "fiscal_posting_interval_id", "datatype": dbt.type_string()},
    {"name": "fiscal_schedule_id", "datatype": dbt.type_string()},
    {"name": "fiscal_year_name", "datatype": dbt.type_string()}
] %}

{{ return(columns) }}

{% endmacro %}
