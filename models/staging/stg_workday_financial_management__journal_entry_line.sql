with base as (

    select *
    from {{ ref('stg_workday_financial_management__journal_entry_line_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_workday_financial_management__journal_entry_line_tmp')),
                staging_columns=get_journal_entry_line_columns()
            )
        }}
        {{ fivetran_utils.apply_source_relation(package_name='workday_financial_management') }}
    from base

),

final as (

    select
        source_relation,
        {{ dbt_utils.generate_surrogate_key(['journal_entry_id', 'index', 'source_relation']) }} as journal_entry_line_id,
        cast(journal_entry_id as {{ dbt.type_string() }}) as journal_entry_id,
        index as journal_entry_line_index,
        line_order,
        journal_line_number,
        cast(ledger_account_id as {{ dbt.type_string() }}) as ledger_account_id,
        cast(ledger_account_code as {{ dbt.type_string() }}) as ledger_account_code,
        account_set_name,
        cast(line_company_id as {{ dbt.type_string() }}) as line_company_id,
        cast(currency_id as {{ dbt.type_string() }}) as currency_id,
        debit_amount,
        credit_amount,
        ledger_debit_amount,
        ledger_credit_amount,
        currency_rate,
        quantity,
        budget_date,
        memo as journal_entry_line_memo,
        exclude_from_spend_report,
        _fivetran_synced
    from fields
    where not coalesce(_fivetran_deleted, false)

)

select *
from final
