with base as (

    select *
    from {{ ref('stg_workday_financial_management__journal_entry_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_workday_financial_management__journal_entry_tmp')),
                staging_columns=get_journal_entry_columns()
            )
        }}
        {{ fivetran_utils.apply_source_relation(package_name='workday_financial_management') }}
    from base

),

final as (

    select
        source_relation,
        cast(id as {{ dbt.type_string() }}) as journal_entry_id,
        cast(company_id as {{ dbt.type_string() }}) as company_id,
        cast(ledger_id as {{ dbt.type_string() }}) as ledger_id,
        cast(journal_source_id as {{ dbt.type_string() }}) as journal_source_id,
        cast(currency_id as {{ dbt.type_string() }}) as currency_id,
        cast(ledger_period_id as {{ dbt.type_string() }}) as ledger_period_id,
        accounting_date,
        transaction_date,
        cast(creation_date as {{ dbt.type_timestamp() }}) as created_at,
        journal_number,
        journal_sequence_number,
        journal_entry_status,
        book_code,
        memo as journal_entry_memo,
        external_reference_id,
        total_ledger_debits,
        total_ledger_credits,
        cast(cancel_reverses_journal_entry_id as {{ dbt.type_string() }}) as cancel_reverses_journal_entry_id,
        cast(cancel_reversed_by_journal_entry_id as {{ dbt.type_string() }}) as cancel_reversed_by_journal_entry_id,
        cast(functional_reverses_journal_entry_id as {{ dbt.type_string() }}) as functional_reverses_journal_entry_id,
        cast(functional_reversed_by_journal_entry_id as {{ dbt.type_string() }}) as functional_reversed_by_journal_entry_id,
        _fivetran_synced
    from fields
    where not coalesce(_fivetran_deleted, false)

)

select *
from final
