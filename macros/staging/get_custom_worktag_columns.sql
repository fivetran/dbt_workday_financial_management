{% macro get_custom_worktag_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "configuration_code", "datatype": dbt.type_string()},
    {"name": "id", "datatype": dbt.type_string()},
    {"name": "inactive", "datatype": "boolean"},
    {"name": "value", "datatype": dbt.type_string()},
    {"name": "worktag_code", "datatype": dbt.type_string()}
] %}

{{ return(columns) }}

{% endmacro %}
