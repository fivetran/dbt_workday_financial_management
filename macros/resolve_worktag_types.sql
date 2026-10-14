{% macro resolve_worktag_types(include_budget=false) %}
    {{ return(adapter.dispatch('resolve_worktag_types', 'workday_financial_management')(include_budget)) }}
{% endmacro %}

{% macro default__resolve_worktag_types(include_budget=false) %}

{#-
    The worktag types that become columns on the general ledger.

    Nothing is included by default. A tenant can define dozens of worktag types, and which of them
    carry meaning is a question only that tenant can answer, so the package adds a column only for
    a type you name. An empty list means the general ledger carries no worktag columns at all.

    The worktag pivot passes include_budget=true to add the budget worktag types as well, so one
    pivot serves both end models. The budget types are added only while budget vs actuals is
    enabled. The general ledger leaves include_budget off, so the budget list never adds columns there.
-#}

{%- set configured_worktag_types = var('workday_financial_management__worktag_types', []) -%}

{%- set resolved_worktag_types = [] -%}
{%- set claimed_worktag_types = {} -%}

{%- for worktag_type in configured_worktag_types -%}
    {%- if worktag_type is not none and worktag_type | trim != '' -%}
        {%- set column_name = dbt_utils.slugify(worktag_type | trim) -%}

        {%- if column_name not in claimed_worktag_types -%}
            {%- do claimed_worktag_types.update({column_name: worktag_type | trim}) -%}
            {%- do resolved_worktag_types.append({'worktag_type': worktag_type | trim, 'column_name': column_name}) -%}
        {%- endif -%}
    {%- endif -%}
{%- endfor -%}

{%- set using_budget_vs_actuals = var('workday_financial_management__using_business_plans', False) and var('workday_financial_management__using_fiscal_calendar', False) -%}

{%- if include_budget and using_budget_vs_actuals -%}
    {%- for worktag in workday_financial_management.resolve_budget_worktag_types() -%}

        {#-
            The same type in both lists shares one column. Two different types with the same column
            name cannot, because one end model would read the values of the other type.
        -#}
        {%- if worktag.column_name not in claimed_worktag_types -%}
            {%- do claimed_worktag_types.update({worktag.column_name: worktag.worktag_type}) -%}
            {%- do resolved_worktag_types.append(worktag) -%}
        {%- elif claimed_worktag_types[worktag.column_name] | lower != worktag.worktag_type | lower -%}
            {{ exceptions.raise_compiler_error(
                "workday_financial_management__budget_worktag_types includes '" ~ worktag.worktag_type ~ "' and "
                ~ "workday_financial_management__worktag_types includes '" ~ claimed_worktag_types[worktag.column_name] ~ "'. "
                ~ "Both become the column " ~ worktag.column_name ~ ". Use the same spelling in both lists."
            ) }}
        {%- endif -%}
    {%- endfor -%}
{%- endif -%}

{{ return(resolved_worktag_types) }}

{% endmacro %}
