-- The company source table carries 63 columns, roughly two thirds of which configure
-- procurement, expenses, and business processes that a general ledger never reads. This macro
-- declares only the accounting-relevant subset. 

{% macro get_company_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "account_set_id", "datatype": dbt.type_string()},
    {"name": "accounting_date_required", "datatype": "boolean"},
    {"name": "alternate_account_set_id", "datatype": dbt.type_string()},
    {"name": "availability_date", "datatype": "date"},
    {"name": "currency_id", "datatype": dbt.type_string()},
    {"name": "currency_rate_type_code", "datatype": dbt.type_string()},
    {"name": "default_account_set_id", "datatype": dbt.type_string()},
    {"name": "default_reporting_book_code", "datatype": dbt.type_string()},
    {"name": "enable_automatic_journal_line_numbering", "datatype": "boolean"},
    {"name": "fiscal_schedule_code", "datatype": dbt.type_string()},
    {"name": "id", "datatype": dbt.type_string()},
    {"name": "keep_debit_credit_and_reverse_sign", "datatype": "boolean"},
    {"name": "organization_active", "datatype": "boolean"},
    {"name": "organization_code", "datatype": dbt.type_string()},
    {"name": "organization_name", "datatype": dbt.type_string()},
    {"name": "organization_phonetic_name", "datatype": dbt.type_string()},
    {"name": "reverse_debit_credit", "datatype": "boolean"}
] %}

{{ return(columns) }}

{% endmacro %}
