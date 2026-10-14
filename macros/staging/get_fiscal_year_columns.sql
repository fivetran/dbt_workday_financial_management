{% macro get_fiscal_year_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "fiscal_schedule_code", "datatype": dbt.type_string()},
    {"name": "fiscal_schedule_id", "datatype": dbt.type_string()},
    {"name": "fiscal_year_code", "datatype": dbt.type_string()},
    {"name": "fiscal_year_end_date", "datatype": "date"},
    {"name": "fiscal_year_id", "datatype": dbt.type_string()},
    {"name": "fiscal_year_name", "datatype": dbt.type_string()},
    {"name": "fiscal_year_number", "datatype": dbt.type_float()},
    {"name": "fiscal_year_start_date", "datatype": "date"}
] %}

{{ return(columns) }}

{% endmacro %}
