{{ config(enabled=var('workday_financial_management_using_worktags', True)) }}

{%- set worktag_types = workday_financial_management.resolve_worktag_types() %}

-- One row per journal entry line that carries at least one configured worktag, with one column per configured worktag type.

with journal_entry_line_worktag as (

    select *
    from {{ ref('stg_workday_financial_management__journal_entry_line_worktag') }}

),

-- Workday splits worktags across two dimensions, and the bridge's worktag_id resolves against either one, so they are unioned into a single lookup.
worktag as (

    select
        source_relation,
        worktag_id,
        worktag_type,
        worktag_value
    from {{ ref('stg_workday_financial_management__worktag') }}

    union all

    select
        source_relation,
        custom_worktag_id as worktag_id,
        configuration_code as worktag_type,
        custom_worktag_value as worktag_value
    from {{ ref('stg_workday_financial_management__custom_worktag') }}

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

    {% if worktag_types | length > 0 -%}
    where lower(worktag.worktag_type) in (
        {% for worktag in worktag_types %}
        '{{ worktag.worktag_type | lower | replace("'", "''") }}'
        {% if not loop.last %},{% endif %}
        {% endfor %}
    )
    {%- endif %}

),

-- A single journal line can have multiple worktags of the same type with different values.
final as (

    select
        journal_entry_id,
        journal_entry_line_index,
        source_relation
        {%- for worktag in worktag_types %}
        , {{ dbt.listagg(
                measure="case when lower(worktag_type) = '" ~ worktag.worktag_type | lower | replace("'", "''") ~ "' then worktag_value end",
                delimiter_text="' | '",
                order_by_clause="order by worktag_value"
            ) }} as {{ worktag.column_name }}
        {%- endfor %}
    from line_worktags
    {{ dbt_utils.group_by(3) }}

)

select *
from final
