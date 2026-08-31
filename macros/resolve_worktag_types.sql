{% macro resolve_worktag_types(default_types=none, additional_types=none) %}

{#- Defaults to the general ledger's worktag column set. Callers that need a different set, such as
    the budget vs actuals pairing key, pass their own. -#}

{%- set default_worktag_types = default_types if default_types is not none else [
    'Organization_Reference_ID',
    'Custom_Organization_Reference_ID',
    'Cost_Center_Reference_ID',
    'Region_Reference_ID',
    'Spend_Category_ID',
    'Revenue_Category_ID'
] -%}

{%- set extra_worktag_types = additional_types if additional_types is not none else var('workday_financial_management__worktag_types', []) -%}

{%- set configured_worktag_types = default_worktag_types + extra_worktag_types -%}

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
