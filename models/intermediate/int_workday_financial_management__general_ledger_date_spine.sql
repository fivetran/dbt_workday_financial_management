-- depends_on: {{ ref('workday_financial_management__general_ledger') }}

-- A monthly spine crossed with every company and ledger account that has activity, so that
-- downstream period balances are densified across months with no journal activity.
--
-- Periods are calendar months. The connector syncs no fiscal calendar table -- journal_entry
-- carries a ledger_period_id with nothing to join to, and company.fiscal_schedule_code is a bare
-- code that resolves to nothing -- so a calendar month is the only period grain available.

with spine as (

    {% if execute and flags.WHICH in ('run', 'build') %}

        {%- set first_date_query %}
        select
            coalesce(
                min(cast(accounting_date as date)),
                cast({{ dbt.dateadd("month", -1, "current_date") }} as date)
                ) as min_date
        from {{ ref('workday_financial_management__general_ledger') }}
        {% endset -%}

        {%- set last_date_query %}
        select
            coalesce(
                max(cast(accounting_date as date)),
                cast(current_date as date)
                ) as max_date
        from {{ ref('workday_financial_management__general_ledger') }}
        {% endset -%}

    {# When only compiling, fall back to a one year range so the spine does not query a relation
       that may not exist yet. #}
    {% else %}
        {%- set first_date_query %}
            select cast({{ dbt.dateadd("year", -1, "current_date") }} as date) as min_date
        {% endset -%}

        {%- set last_date_query %}
            select current_date as max_date
        {% endset -%}

    {% endif %}

    {%- set first_date = dbt_utils.get_single_value(first_date_query) %}
    {%- set last_date = dbt_utils.get_single_value(last_date_query) %}

    {{ dbt_utils.date_spine(
        datepart="month",
        start_date="cast('" ~ first_date ~ "' as date)",
        end_date=dbt.dateadd("month", 1, "cast('" ~ last_date ~ "' as date)")
        )
    }}

),

general_ledger as (

    select *
    from {{ ref('workday_financial_management__general_ledger') }}

),

date_spine as (

    select
        cast({{ dbt.date_trunc("year", "date_month") }} as date) as date_year,
        cast({{ dbt.date_trunc("month", "date_month") }} as date) as period_first_day,
        {{ dbt.last_day("date_month", "month") }} as period_last_day,
        row_number() over (order by cast({{ dbt.date_trunc("month", "date_month") }} as date)) as period_index
    from spine

),

final as (

    select distinct
        general_ledger.source_relation,
        general_ledger.company_id,
        general_ledger.company_name,
        general_ledger.ledger_account_id,
        general_ledger.ledger_account_name,
        general_ledger.ledger_account_type,
        general_ledger.ledger_currency_id,
        general_ledger.ledger_currency_code,
        date_spine.date_year,
        date_spine.period_first_day,
        date_spine.period_last_day,
        date_spine.period_index
    from general_ledger

    cross join date_spine

)

select *
from final
