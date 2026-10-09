{% macro get_journal_source_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "enable_suspense_processing_for_web_service", "datatype": "boolean"},
    {"name": "id", "datatype": dbt.type_string()},
    {"name": "journal_source_id", "datatype": dbt.type_string()},
    {"name": "journal_source_name", "datatype": dbt.type_string()},
    {"name": "process_award_costs", "datatype": "boolean"},
    {"name": "source_for_accounting_journal", "datatype": "boolean"},
    {"name": "source_for_ad_hoc_bank_transaction", "datatype": "boolean"},
    {"name": "source_for_workday_operational_journal", "datatype": "boolean"},
    {"name": "suspense_threshold_percent", "datatype": dbt.type_float()}
] %}

{{ return(columns) }}

{% endmacro %}
