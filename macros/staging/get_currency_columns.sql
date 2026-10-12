{% macro get_currency_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "currency_code", "datatype": dbt.type_string()},
    {"name": "description", "datatype": dbt.type_string()},
    {"name": "id", "datatype": dbt.type_string()},
    {"name": "numeric_code", "datatype": dbt.type_string()},
    {"name": "symbol", "datatype": dbt.type_string()}
] %}

{% if target.type == 'snowflake' and not var('fivetran_using_source_casing', false) %}
    {{ columns.append({"name": "PRECISION", "datatype": dbt.type_float(), "quote": True, "alias": "currency_precision"}) }}
{% else %}
    {{ columns.append({"name": "precision", "datatype": dbt.type_float(), "quote": True, "alias": "currency_precision"}) }}
{% endif %}

{{ return(columns) }}

{% endmacro %}
