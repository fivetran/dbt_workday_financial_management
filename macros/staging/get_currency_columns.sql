{% macro get_currency_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": "boolean"},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "currency_code", "datatype": dbt.type_string()},
    {"name": "delivered_currency_precision", "datatype": dbt.type_int()},
    {"name": "description", "datatype": dbt.type_string()},
    {"name": "id", "datatype": dbt.type_string()},
    {"name": "is_precision_overridden", "datatype": "boolean"},
    {"name": "numeric_code", "datatype": dbt.type_string()},
    {"name": "override_currency_precision", "datatype": dbt.type_int()},
    {"name": "retired", "datatype": "boolean"},
    {"name": "symbol", "datatype": dbt.type_string()}
] %}

-- `precision` is a reserved word on Redshift, so it is quoted and aliased rather than selected
-- bare. Snowflake stores unquoted identifiers uppercase unless the connector was configured to
-- preserve source casing, so the name has to be cased to match.
{% if target.type == 'snowflake' and not var('fivetran_using_source_casing', false) %}
    {{ columns.append({"name": "PRECISION", "datatype": dbt.type_int(), "quote": True, "alias": "currency_precision"}) }}
{% else %}
    {{ columns.append({"name": "precision", "datatype": dbt.type_int(), "quote": True, "alias": "currency_precision"}) }}
{% endif %}

{{ return(columns) }}

{% endmacro %}
