{% macro get_journal_entry_line_worktag_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "journal_entry_id", "datatype": dbt.type_string()},
    {"name": "journal_entry_line_index", "datatype": dbt.type_int()},
    {"name": "worktag_id", "datatype": dbt.type_string()}
] %}

{{ return(columns) }}

{% endmacro %}
