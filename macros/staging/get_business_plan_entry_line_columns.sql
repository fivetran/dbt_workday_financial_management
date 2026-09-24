{% macro get_business_plan_entry_line_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "business_plan_detail_id", "datatype": dbt.type_string()},
    {"name": "business_plan_detail_index", "datatype": dbt.type_int()},
    {"name": "credit_amount", "datatype": dbt.type_float()},
    {"name": "debit_amount", "datatype": dbt.type_float()},
    {"name": "index", "datatype": dbt.type_int()},
    {"name": "ledger_account_id", "datatype": dbt.type_string()},
    {"name": "ledger_account_summary_id", "datatype": dbt.type_string()},
    {"name": "line_memo", "datatype": dbt.type_string()},
    {"name": "line_order", "datatype": dbt.type_string()}
] %}

{{ return(columns) }}

{% endmacro %}
