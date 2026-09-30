-- One row per ledger account code, per source relation. An account code that appears in more than
-- one account set cannot be resolved to a single name, so it is dropped here and resolves to none downstream.

with ledger_account as (

    select *
    from {{ ref('stg_workday_financial_management__ledger_account') }}

),

ledger_account_code_counts as (

    select
        ledger_account_id,
        source_relation,
        count(*) as accounts_sharing_code
    from ledger_account
    {{ dbt_utils.group_by(2) }}

),

unambiguous_ledger_account as (

    select ledger_account.*
    from ledger_account

    inner join ledger_account_code_counts
        on ledger_account.ledger_account_id = ledger_account_code_counts.ledger_account_id
        and ledger_account.source_relation = ledger_account_code_counts.source_relation

    where ledger_account_code_counts.accounts_sharing_code = 1

)

select *
from unambiguous_ledger_account
