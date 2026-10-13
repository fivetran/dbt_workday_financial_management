{% macro resolve_worktag_types() %}
    {{ return(adapter.dispatch('resolve_worktag_types', 'workday_financial_management')()) }}
{% endmacro %}

{% macro default__resolve_worktag_types() %}

{#-
    The worktag types that become columns on the general ledger.

    Nothing is included by default. A tenant can define dozens of worktag types, and which of them
    carry meaning is a question only that tenant can answer, so the package adds a column only for
    a type you name. An empty list means the general ledger carries no worktag columns at all.

    Budget worktag types are not included. Budget vs actuals reads its worktags from the pivot
    directly, so the budget list never adds columns to the general ledger.
-#}

{%- set configured_worktag_types = var('workday_financial_management__worktag_types', []) -%}

{%- set resolved_worktag_types = [] -%}
{%- set claimed_column_names = [] -%}

{%- for worktag_type in configured_worktag_types -%}
    {%- if worktag_type is not none and worktag_type | trim != '' -%}
        {%- set column_name = dbt_utils.slugify(worktag_type | trim) -%}

        {%- if column_name not in claimed_column_names -%}
            {%- do claimed_column_names.append(column_name) -%}
            {%- do resolved_worktag_types.append({'worktag_type': worktag_type | trim, 'column_name': column_name}) -%}
        {%- endif -%}
    {%- endif -%}
{%- endfor -%}

{{ return(resolved_worktag_types) }}

{% endmacro %}
