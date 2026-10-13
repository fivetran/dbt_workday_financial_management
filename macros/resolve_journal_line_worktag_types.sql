{% macro resolve_journal_line_worktag_types() %}
    {{ return(adapter.dispatch('resolve_journal_line_worktag_types', 'workday_financial_management')()) }}
{% endmacro %}

{% macro default__resolve_journal_line_worktag_types() %}

{#-
    The worktag types pivoted onto journal lines: the general ledger list and the budget list
    together, deduped. Only int_workday_financial_management__worktags_pivoted uses this. The
    general ledger and budget vs actuals each read their own list's columns from that one pivot,
    so neither list adds columns to the other model.

    A pivot column holds one type, so two types that slugify to the same column name cannot both
    be pivoted. The same type named in both lists is fine. Two different types colliding across
    the lists is refused, because one of the two models would silently read the other's values.
-#}

{%- set resolved_worktag_types = workday_financial_management.resolve_worktag_types() | list -%}
{%- set claimed_worktag_types = {} -%}
{%- for worktag in resolved_worktag_types -%}
    {%- do claimed_worktag_types.update({worktag.column_name: worktag.worktag_type}) -%}
{%- endfor -%}

{%- for worktag in workday_financial_management.resolve_budget_worktag_types() -%}
    {%- if worktag.column_name not in claimed_worktag_types -%}
        {%- do claimed_worktag_types.update({worktag.column_name: worktag.worktag_type}) -%}
        {%- do resolved_worktag_types.append(worktag) -%}
    {%- elif claimed_worktag_types[worktag.column_name] | lower != worktag.worktag_type | lower -%}
        {{ exceptions.raise_compiler_error(
            "workday_financial_management__budget_worktag_types includes '" ~ worktag.worktag_type ~ "' and "
            ~ "workday_financial_management__worktag_types includes '" ~ claimed_worktag_types[worktag.column_name] ~ "'. "
            ~ "Both become the column " ~ worktag.column_name ~ ", so the general ledger and budget vs actuals "
            ~ "would read different types from one column. Use the same spelling in both lists."
        ) }}
    {%- endif -%}
{%- endfor -%}

{{ return(resolved_worktag_types) }}

{% endmacro %}
