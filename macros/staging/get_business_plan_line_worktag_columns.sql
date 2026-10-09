{% macro get_business_plan_line_worktag_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "business_plan_detail_id", "datatype": dbt.type_string()},
    {"name": "business_plan_detail_index", "datatype": dbt.type_int()},
    {"name": "business_plan_entry_line_index", "datatype": dbt.type_int()},
    {"name": "worktag_id", "datatype": dbt.type_string()}
] %}

{{ return(columns) }}

{% endmacro %}
