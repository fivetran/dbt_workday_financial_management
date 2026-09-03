{{ config(enabled=var('workday_financial_management_using_worktags', True)) }}

-- Workday splits worktags across two dimensions, and a bridge's worktag_id resolves against either, so they are unioned into a single lookup. 
-- Both the journal line pivot and the business plan pivot read this, so budget and actuals resolve the same worktag to the same value.

with worktag as (

    select
        source_relation,
        worktag_id,
        worktag_type,
        worktag_value
    from {{ ref('stg_workday_financial_management__worktag') }}

),

custom_worktag as (

    select
        source_relation,
        custom_worktag_id as worktag_id,
        configuration_code as worktag_type,
        custom_worktag_value as worktag_value
    from {{ ref('stg_workday_financial_management__custom_worktag') }}

),

final as (

    select *
    from worktag

    union all

    select *
    from custom_worktag

)

select *
from final
