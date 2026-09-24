{% macro resolve_budget_worktag_types() %}

{#-
    The worktag types that become part of the budget vs actuals grain.

    Nothing is included by default, the same as resolve_worktag_types(). The difference is what a
    type costs you once you name it. There a worktag type is a display attribute, so a line
    carrying several values of one type can be collapsed into a delimited string. Here a worktag
    type is part of the key, so it splits a budget row away from the actual it would otherwise
    have paired with wherever only one side records it. Add types deliberately.
-#}

{#-
    Workday allows a line to carry several organization worktags at once, and they collapse several
    dimensions -- cost center, region, pay group, industry -- into a single type, with nothing in the
    connector to say which is which. Using one as a key part splits the amount of a line across
    rows, so they are refused outright. The data in a given tenant may happen to hold one value per
    line today; that is not a guarantee the next sync keeps to it.
-#}
{%- set denied_worktag_types = [
    'organization_reference_id',
    'custom_organization_reference_id'
] -%}

{%- set configured_budget_worktag_types = var('workday_financial_management__budget_worktag_types', []) -%}

{%- set resolved_worktag_types = [] -%}
{%- set claimed_column_names = [] -%}

{%- for worktag_type in configured_budget_worktag_types -%}
    {%- if worktag_type is not none and worktag_type | trim != '' -%}
        {%- set column_name = dbt_utils.slugify(worktag_type | trim) -%}

        {%- if column_name in denied_worktag_types -%}
            {{ exceptions.raise_compiler_error(
                "workday_financial_management__budget_worktag_types cannot include '" ~ worktag_type | trim ~ "'. "
                ~ "Workday allows a line to carry several organization worktags at once, so using one as part "
                ~ "of the budget vs actuals key splits the amount of that line across rows. Use "
                ~ "Cost_Center_Reference_ID or Region_Reference_ID, which hold the same values and carry one "
                ~ "per line."
            ) }}
        {%- endif -%}

        {%- if column_name not in claimed_column_names -%}
            {%- do claimed_column_names.append(column_name) -%}
            {%- do resolved_worktag_types.append({'worktag_type': worktag_type | trim, 'column_name': column_name}) -%}
        {%- endif -%}
    {%- endif -%}

{%- endfor -%}

{{ return(resolved_worktag_types) }}

{% endmacro %}
