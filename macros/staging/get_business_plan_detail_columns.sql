{% macro get_business_plan_detail_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "award_contract_id", "datatype": dbt.type_string()},
    {"name": "award_posting_interval_code", "datatype": dbt.type_string()},
    {"name": "award_proposal_code", "datatype": dbt.type_string()},
    {"name": "business_plan_details_ref_id", "datatype": dbt.type_string()},
    {"name": "business_plan_structure_id", "datatype": dbt.type_string()},
    {"name": "company_id", "datatype": dbt.type_string()},
    {"name": "currency_id", "datatype": dbt.type_string()},
    {"name": "fiscal_posting_interval_code", "datatype": dbt.type_string()},
    {"name": "fiscal_time_interval_id", "datatype": dbt.type_string()},
    {"name": "id", "datatype": dbt.type_string()},
    {"name": "index", "datatype": dbt.type_int()},
    {"name": "organizing_dimension_id", "datatype": dbt.type_string()},
    {"name": "plan_memo", "datatype": dbt.type_string()},
    {"name": "project_budget_code", "datatype": dbt.type_string()},
    {"name": "year", "datatype": dbt.type_int()}
] %}

{{ return(columns) }}

{% endmacro %}
