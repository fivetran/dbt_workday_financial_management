{% macro get_journal_entry_line_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "account_set_name", "datatype": dbt.type_string()},
    {"name": "alternate_ledger_account_id", "datatype": dbt.type_string()},
    {"name": "budget_date", "datatype": "date"},
    {"name": "credit_amount", "datatype": dbt.type_float()},
    {"name": "currency_id", "datatype": dbt.type_string()},
    {"name": "currency_rate", "datatype": dbt.type_float()},
    {"name": "debit_amount", "datatype": dbt.type_float()},
    {"name": "exclude_from_spend_report", "datatype": "boolean"},
    {"name": "external_reference_id", "datatype": dbt.type_string()},
    {"name": "index", "datatype": dbt.type_int()},
    {"name": "journal_entry_id", "datatype": dbt.type_string()},
    {"name": "journal_line_number", "datatype": dbt.type_int()},
    {"name": "ledger_account_code", "datatype": dbt.type_string()},
    {"name": "ledger_account_id", "datatype": dbt.type_string()},
    {"name": "ledger_credit_amount", "datatype": dbt.type_float()},
    {"name": "ledger_debit_amount", "datatype": dbt.type_float()},
    {"name": "line_company_id", "datatype": dbt.type_string()},
    {"name": "line_order", "datatype": dbt.type_int()},
    {"name": "memo", "datatype": dbt.type_string()},
    {"name": "quantity", "datatype": dbt.type_float()},
    {"name": "quantity_2", "datatype": dbt.type_float()}
] %}

{{ return(columns) }}

{% endmacro %}
