{% macro resolve_worktag_types() %}

{%- set default_worktag_types = [
    'Organization_Reference_ID',
    'Custom_Organization_Reference_ID',
    'Cost_Center_Reference_ID',
    'Region_Reference_ID',
    'Spend_Category_ID',
    'Revenue_Category_ID'
] -%}

{%- set configured_worktag_types = default_worktag_types + var('workday_financial_management__worktag_types', []) -%}

{%- set resolved_worktag_types = [] -%}
{%- set claimed_column_names = [] -%}

{%- for worktag_type in configured_worktag_types -%}
    {%- if worktag_type is not none and worktag_type | trim != '' -%}
        {%- set column_name = dbt_utils.slugify(worktag_type | trim) -%}

        {#- Two types that slugify to the same name would be a duplicate column and a compile
            error, so the first one wins. In practice this only fires when a configured type
            repeats a default, differing by case at most, which is the same column either way. -#}
        {%- if column_name not in claimed_column_names -%}
            {%- do claimed_column_names.append(column_name) -%}
            {%- do resolved_worktag_types.append({'worktag_type': worktag_type | trim, 'column_name': column_name}) -%}
        {%- endif -%}
    {%- endif -%}
{%- endfor -%}

{{ return(resolved_worktag_types) }}

{% endmacro %}
