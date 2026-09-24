{{ config(enabled=workday_financial_management.resolve_worktag_types() | length > 0) }}

{%- set worktag_types = workday_financial_management.resolve_worktag_types() %}

-- One row per journal entry line that carries at least one configured worktag, with one column per configured worktag type.
-- No worktag type is configured by default, so this model is only built once you name one in workday_financial_management__worktag_types.

with journal_entry_line_worktag as (

    select *
    from {{ ref('stg_workday_financial_management__journal_entry_line_worktag') }}

),

worktag as (

    select *
    from {{ ref('int_workday_financial_management__worktag_lookup') }}

),

line_worktags as (

    select
        journal_entry_line_worktag.journal_entry_id,
        journal_entry_line_worktag.journal_entry_line_index,
        journal_entry_line_worktag.source_relation,
        worktag.worktag_type,
        worktag.worktag_value
    from journal_entry_line_worktag

    join worktag
        on journal_entry_line_worktag.worktag_id = worktag.worktag_id
        and journal_entry_line_worktag.source_relation = worktag.source_relation

    where lower(worktag.worktag_type) in (
        {% for worktag in worktag_types %}
        '{{ dbt.escape_single_quotes(worktag.worktag_type | lower) }}'
        {% if not loop.last %},{% endif %}
        {% endfor %}
    )

),

-- A single journal line can have multiple worktags of the same type with different values.
final as (

    select
        journal_entry_id,
        journal_entry_line_index,
        source_relation
        {%- for worktag in worktag_types %}
        , {{ dbt.listagg(
                measure="case when lower(worktag_type) = '" ~ dbt.escape_single_quotes(worktag.worktag_type | lower) ~ "' then worktag_value end",
                delimiter_text="' | '",
                order_by_clause="order by worktag_value"
            ) }} as {{ worktag.column_name }}
        {%- endfor %}
    from line_worktags
    {{ dbt_utils.group_by(3) }}

)

select *
from final
