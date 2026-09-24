{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
        and workday_financial_management.resolve_budget_worktag_types() | length > 0
) }}

-- int_workday_financial_management__bp_worktags pivots with max(), which is only correct while a
-- budget line carries at most one worktag of each configured type. Where that does not hold, max()
-- silently keeps one value and discards the rest, and the budget attributed to the discarded ones
-- lands on the wrong row. This turns that assumption into something enforced.
--
-- Organization worktags genuinely carry several values per line, which is why
-- resolve_budget_worktag_types() refuses them. Anything this test reports is a type that was
-- allowed in on the understanding it behaves differently.

{%- set worktag_types = workday_financial_management.resolve_budget_worktag_types() %}

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
        business_plan_line_worktag.source_relation,
        business_plan_line_worktag.business_plan_detail_id,
        business_plan_line_worktag.business_plan_detail_index,
        business_plan_line_worktag.business_plan_entry_line_index,
        worktag.worktag_type,
        worktag.worktag_value
    from business_plan_line_worktag

    join worktag
        on business_plan_line_worktag.worktag_id = worktag.worktag_id
        and business_plan_line_worktag.source_relation = worktag.source_relation

    where lower(worktag.worktag_type) in (
        {% for worktag in worktag_types %}
        '{{ dbt.escape_single_quotes(worktag.worktag_type | lower) }}'
        {% if not loop.last %},{% endif %}
        {% endfor %}
    )

),

final as (

    select
        'a budget line carries more than one worktag of a single type' as failure_reason,
        source_relation,
        business_plan_detail_id,
        business_plan_detail_index,
        business_plan_entry_line_index,
        worktag_type,
        count(distinct worktag_value) as distinct_worktag_values
    from line_worktags
    {{ dbt_utils.group_by(6) }}
    having count(distinct worktag_value) > 1

)

select *
from final
