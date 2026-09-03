{% macro get_journal_entry_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "accounting_date", "datatype": "date"},
    {"name": "book_code", "datatype": dbt.type_string()},
    {"name": "cancel_reversed_by_journal_entry_id", "datatype": dbt.type_string()},
    {"name": "cancel_reverses_journal_entry_id", "datatype": dbt.type_string()},
    {"name": "company_id", "datatype": dbt.type_string()},
    {"name": "creation_date", "datatype": dbt.type_timestamp()},
    {"name": "currency_id", "datatype": dbt.type_string()},
    {"name": "display_account_set_id", "datatype": dbt.type_string()},
    {"name": "document_link", "datatype": dbt.type_string()},
    {"name": "external_reference_id", "datatype": dbt.type_string()},
    {"name": "functional_reversed_by_journal_entry_id", "datatype": dbt.type_string()},
    {"name": "functional_reverses_journal_entry_id", "datatype": dbt.type_string()},
    {"name": "id", "datatype": dbt.type_string()},
    {"name": "journal_entry_status", "datatype": dbt.type_string()},
    {"name": "journal_number", "datatype": dbt.type_string()},
    {"name": "journal_sequence_number", "datatype": dbt.type_int()},
    {"name": "journal_source_id", "datatype": dbt.type_string()},
    {"name": "last_updated_date", "datatype": dbt.type_timestamp()},
    {"name": "ledger_id", "datatype": dbt.type_string()},
    {"name": "ledger_period_id", "datatype": dbt.type_string()},
    {"name": "memo", "datatype": dbt.type_string()},
    {"name": "operational_transaction_id", "datatype": dbt.type_string()},
    {"name": "operational_transaction_reference", "datatype": dbt.type_string()},
    {"name": "record_quantity", "datatype": dbt.type_float()},
    {"name": "total_ledger_credits", "datatype": dbt.type_float()},
    {"name": "total_ledger_debits", "datatype": dbt.type_float()},
    {"name": "transaction_date", "datatype": "date"}
] %}

{{ return(columns) }}

{% endmacro %}
