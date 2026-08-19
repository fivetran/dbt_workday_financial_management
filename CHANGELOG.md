# dbt_workday_financial_management v0.1.0

This is the initial release of the `dbt_workday_financial_management` dbt package.

## Initial Release

This package models data from Fivetran's [Workday Financial Management connector](https://fivetran.com/docs/connectors/applications/workday-financial-management) and produces the following analytics-ready tables:

- **workday_financial_management__general_ledger** — Transaction-level general ledger detail. One row per journal entry line, with journal header, company, ledger, ledger account, journal source, and currency context denormalized onto every line, plus one column per configured worktag type.
- **workday_financial_management__general_ledger_by_period** — Monthly general ledger rollup. One row per company, ledger account, and calendar month, including months with no activity, which carry the last known balance forward.
