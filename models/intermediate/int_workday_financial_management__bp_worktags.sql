{{ config(
    enabled=workday_financial_management.resolve_budget_worktag_types() | length > 0
        and var('workday_financial_management_using_business_plans', True)
) }}

{%- set worktag_types = workday_financial_management.resolve_budget_worktag_types() %}

-- One row per business plan entry line that carries at least one configured worktag, with one column per configured worktag type.
-- The journal side has its own pivot in int_workday_financial_management__worktags_pivoted. Both read the same lookup, so a worktag resolves to the same value on budget and actuals alike.

with business_plan_line_worktag as (

    select *
    from {{ ref('stg_workday_financial_management__business_plan_line_worktag') }}

),

worktag as (

    select *
    from {{ ref('int_workday_financial_management__worktag_lookup') }}

),

line_worktags as (

    select
        business_plan_line_worktag.business_plan_detail_id,
        business_plan_line_worktag.business_plan_detail_index,
        business_plan_line_worktag.business_plan_entry_line_index,
        business_plan_line_worktag.source_relation,
        worktag.worktag_type,
        worktag.worktag_value
    from business_plan_line_worktag

    join worktag
        on business_plan_line_worktag.worktag_id = worktag.worktag_id
        and business_plan_line_worktag.source_relation = worktag.source_relation

    {% if worktag_types | length > 0 -%}
    where lower(worktag.worktag_type) in (
        {% for worktag in worktag_types %}
        '{{ dbt.escape_single_quotes(worktag.worktag_type | lower) }}'
        {% if not loop.last %},{% endif %}
        {% endfor %}
    )
    {%- endif %}

),

-- Each of these types carries one value per line, so max() reads that single value rather than
-- picking a winner from several. The journal pivot uses listagg because it also carries the
-- organization types, which do not have that property. integrity_budget_worktag_cardinality
-- enforces the assumption rather than leaving it stated.
final as (

    select
        business_plan_detail_id,
        business_plan_detail_index,
        business_plan_entry_line_index,
        source_relation
        {%- for worktag in worktag_types %}
        , max(case when lower(worktag_type) = '{{ dbt.escape_single_quotes(worktag.worktag_type | lower) }}' then worktag_value end) as {{ worktag.column_name }}
        {%- endfor %}
    from line_worktags
    {{ dbt_utils.group_by(4) }}

)

select *
from final
