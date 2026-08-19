{% macro get_ledger_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "can_view_budget_date", "datatype": "boolean"},
    {"name": "company_id", "datatype": dbt.type_string()},
    {"name": "id", "datatype": dbt.type_string()},
    {"name": "ledger_code", "datatype": dbt.type_string()},
    {"name": "ledger_type", "datatype": dbt.type_string()}
] %}

{{ return(columns) }}

{% endmacro %}
