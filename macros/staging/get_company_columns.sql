{% macro get_company_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "account_set_id", "datatype": dbt.type_string()},
    {"name": "currency_id", "datatype": dbt.type_string()},
    {"name": "default_reporting_book_code", "datatype": dbt.type_string()},
    {"name": "fiscal_schedule_code", "datatype": dbt.type_string()},
    {"name": "id", "datatype": dbt.type_string()},
    {"name": "keep_debit_credit_and_reverse_sign", "datatype": "boolean"},
    {"name": "organization_active", "datatype": "boolean"},
    {"name": "organization_code", "datatype": dbt.type_string()},
    {"name": "organization_name", "datatype": dbt.type_string()},
    {"name": "reverse_debit_credit", "datatype": "boolean"}
] %}

{{ return(columns) }}

{% endmacro %}
