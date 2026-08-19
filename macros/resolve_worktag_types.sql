{% macro resolve_worktag_types() %}

{#-
    Returns the worktag types that become columns on the general ledger, as a list of
    {'worktag_type': <value as the connector reports it>, 'column_name': <that value slugified>}.

    Both the pivot and the general ledger call this, so the two agree on the column set without
    either one having to read the other's columns back out of the warehouse. That keeps the
    general ledger's schema knowable at parse time, before the pivot has ever been built.
-#}

{#-
    Worktag types the package always includes -- Workday-delivered worktags that reach general
    ledger journal lines in most tenants. A type your tenant does not use still produces a column;
    it is simply null.

    These are spelled the way the Fivetran connector reports them, which is Workday's reference-ID
    naming rather than the display names in Workday's own worktag documentation: the connector
    sends Cost_Center_Reference_ID, not Cost Center. Match that convention when adding your own.
-#}
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
