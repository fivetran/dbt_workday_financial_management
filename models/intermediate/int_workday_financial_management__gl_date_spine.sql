-- depends_on: {{ ref('workday_financial_management__general_ledger') }}

-- A monthly spine crossed with every company and ledger account that has activity, so that downstream period balances are densified across months with no journal activity.

-- Periods are calendar months. The connector syncs no fiscal calendar table 

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

-- Reduced to the distinct combinations before the cross join. Crossing the journal line detail with the
-- spine first and deduplicating after produces the same rows, but materializes one per line per month.
gl_company_account as (

    select distinct
        source_relation,
        company_id,
        company_name,
        ledger_account_id,
        ledger_account_name,
        ledger_account_type,
        ledger_currency_id,
        ledger_currency_code
    from general_ledger

),

final as (

    select
        gl_company_account.source_relation,
        gl_company_account.company_id,
        gl_company_account.company_name,
        gl_company_account.ledger_account_id,
        gl_company_account.ledger_account_name,
        gl_company_account.ledger_account_type,
        gl_company_account.ledger_currency_id,
        gl_company_account.ledger_currency_code,
        date_spine.date_year,
        date_spine.period_first_day,
        date_spine.period_last_day,
        date_spine.period_index
    from gl_company_account

    cross join date_spine

)

select *
from final
