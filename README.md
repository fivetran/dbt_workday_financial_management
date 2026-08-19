<!--section="workday_financial_management_transformation_model"-->
# Workday Financial Management Transformation dbt Package ([Docs](https://fivetran.github.io/dbt_workday_financial_management/))

<p align="left">
    <a alt="License"
        href="https://github.com/fivetran/dbt_workday_financial_management/blob/main/LICENSE">
        <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" /></a>
    <a alt="dbt-core">
        <img src="https://img.shields.io/badge/dbt_Core%E2%84%A2%20version->=1.3.0%20<3.0.0-orange.svg" /></a>
    <a alt="Maintained by Fivetran">
        <img src="https://img.shields.io/badge/Maintained%20by-Fivetran-blue.svg" /></a>
</p>

## What does this dbt package do?
This package models Workday Financial Management data from [Fivetran's Workday Financial Management connector](https://fivetran.com/docs/connectors/applications/workday-financial-management). It uses data in the format described by [this ERD](https://fivetran.com/docs/connectors/applications/workday-financial-management#schemainformation).

The package produces a transaction-level general ledger and a monthly rollup of it, both ready for analysis. It:

- Restricts both output models to posted journal entries, so canceled and errored journals do not contaminate your balances. The staging models keep the full journal history.
- Denormalizes journal header, company, ledger, ledger account, journal source, and currency context onto every journal entry line, so you do not have to join them back yourself.
- Resolves Workday worktags, delivered and custom alike, into one column per worktag type — six by default, plus any you configure.
- Produces a signed `net_amount` alongside the native debit and credit amounts.
- Rolls activity up to a monthly grain with beginning balance, net change, and ending balance, including months with no journal activity.
- Generates a comprehensive data dictionary of your source and modeled Workday Financial Management data through the [dbt docs site](https://fivetran.github.io/dbt_workday_financial_management/).

<!--section="workday_financial_management_transformation_model"-->
The following table provides a detailed list of all models materialized within this package by default.

> TIP: See more details about these models in the package's [dbt docs site](https://fivetran.github.io/dbt_workday_financial_management/#!/overview?g_v=1).

| **model**                                              | **description**                                                                                                                                                                                                 |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [workday_financial_management__general_ledger](https://fivetran.github.io/dbt_workday_financial_management/#!/model/model.workday_financial_management.workday_financial_management__general_ledger) | Each record represents a single journal entry line, enriched with journal, company, ledger, ledger account, journal source, currency, and worktag context. |
| [workday_financial_management__general_ledger_by_period](https://fivetran.github.io/dbt_workday_financial_management/#!/model/model.workday_financial_management.workday_financial_management__general_ledger_by_period) | Each record represents one company, ledger account, and calendar month, with the beginning balance, net change, and ending balance for that month. |

### Example questions these models answer

**`workday_financial_management__general_ledger`**
- What did we post to a given ledger account last quarter, and which journal source produced it?
- How is spend distributed across cost centers, projects, or any other worktag our tenant uses?
- Which journal entries have been reversed, and what were the original entries?

**`workday_financial_management__general_ledger_by_period`**
- What is the month-end balance of each balance sheet account, by company?
- How has net activity in an expense account trended over the last twelve months?
- Which accounts had no activity in a given month?

## How do I use the dbt package?

### Step 1: Prerequisites
To use this dbt package, you must have the following:

- At least one Fivetran Workday Financial Management connection syncing into your destination.
- A **BigQuery**, **Snowflake**, **Redshift**, **PostgreSQL**, or **Databricks** destination.

#### Databricks dispatch configuration
If you are using a Databricks destination with this package, you must add the following (or a variation of the following) dispatch configuration within your `dbt_project.yml`. This is required in order for the package to accurately search for macros within the `dbt-labs/spark_utils` then the `dbt-labs/dbt_utils` packages respectively.
```yml
dispatch:
  - macro_namespace: dbt_utils
    search_order: ['spark_utils', 'dbt_utils']
```

### Step 2: Install the package
Include the following package version in your `packages.yml` file:
> TIP: Check [dbt Hub](https://hub.getdbt.com/) for the latest installation instructions or [read the dbt docs](https://docs.getdbt.com/docs/package-management) for more information on installing packages.
```yaml
packages:
  - package: fivetran/workday_financial_management
    version: [">=0.1.0", "<0.2.0"]
```

### Step 3: Define database and schema variables
#### Option A: Single connection
By default, this package runs using your destination and the `workday_financial_management` schema. If this is not where your Workday Financial Management data is (for example, if your Workday Financial Management schema is named `workday_financial_management_fivetran`), add the following configuration to your root `dbt_project.yml` file:

```yml
vars:
    workday_financial_management_database: your_destination_name
    workday_financial_management_schema: your_schema_name
```

#### Option B: Union multiple connections
If you have multiple Workday Financial Management connections in Fivetran and would like to use this package on all of them simultaneously, we have provided functionality to do so. The package will union all of the data together and pass the unioned table into the transformations. You will be able to see which source it came from in the `source_relation` column of each model. To use this functionality, you will need to set the `workday_financial_management_sources` variable in your root `dbt_project.yml` file:

```yml
vars:
    workday_financial_management_sources:
      - database: connection_1_destination_name
        schema: connection_1_schema_name
        name: connection_1_source_name

      - database: connection_2_destination_name
        schema: connection_2_schema_name
        name: connection_2_source_name
```

### (Optional) Step 4: Additional configurations

#### Disable models for non-existent sources
This package reads ten source tables. Seven of them are required. The three worktag tables — `worktag`, `custom_worktag`, and `journal_entry_line_worktag` — are gated behind a single variable. If your Workday Financial Management connection does not sync them, or your tenant does not use worktags, add the following configuration to your root `dbt_project.yml` file:

```yml
vars:
    workday_financial_management_using_worktags: false
```

This disables the staging models for all three tables and the worktag pivot, and drops the worktag columns from `workday_financial_management__general_ledger`. Every other model builds as normal.

#### Change which journal entry statuses count as posted
Both output models include only journal entries whose status is `POSTED`. If your Workday tenant uses different status values, add the following configuration to your root `dbt_project.yml` file:

```yml
vars:
    workday_financial_management__posted_statuses: ['POSTED', 'YOUR_STATUS']
```

The staging models are never filtered, so `stg_workday_financial_management__journal_entry` always carries the complete journal history.

#### Configure worktag columns
This package resolves your Workday worktags into one column per worktag type on `workday_financial_management__general_ledger`. Worktag types you do not name explicitly are left out, so the general ledger does not grow a column for every worktag type your tenant happens to define.

Six delivered worktag types are always included, because they are the ones that reach general ledger journal lines in most tenants:

| **worktag type** | **column** |
| ---------------- | ---------- |
| `Organization_Reference_ID` | `organization_reference_id` |
| `Custom_Organization_Reference_ID` | `custom_organization_reference_id` |
| `Cost_Center_Reference_ID` | `cost_center_reference_id` |
| `Region_Reference_ID` | `region_reference_id` |
| `Spend_Category_ID` | `spend_category_id` |
| `Revenue_Category_ID` | `revenue_category_id` |

Note that the connector reports worktag types using Workday's reference-ID naming rather than the display names in Workday's worktag documentation. The type is `Cost_Center_Reference_ID`, not `Cost Center`. The suffix is not always `_Reference_ID` — spend and revenue category arrive as `Spend_Category_ID` and `Revenue_Category_ID` — so check your own `worktag` table's `attribute` column before adding a type. A type your tenant does not use still produces a column; it is simply null.

To add worktag types of your own, add the following configuration to your root `dbt_project.yml` file:

```yml
vars:
    workday_financial_management__worktag_types: ['Project_Reference_ID', 'Fund_Reference_ID', 'Grant_Reference_ID']
```

Each value must match either the `attribute` column of your `worktag` table or the `configuration_code` column of your `custom_worktag` table, so you can name delivered and custom worktags in the same list. Matching is case-insensitive. Each value becomes its own column, named after the value slugified — `Fund_Reference_ID` becomes `fund_reference_id`. The six defaults above are always kept, whatever you put here.

Two notes on the resulting columns:

- A journal line often carries several worktags of the same type, because they are different allocations rather than duplicates. The column holds every value, joined by ` | `. Treat it as something to read, not something to parse.
- If a worktag type shares a name with a column the model already produces, we prefix the worktag column with `pivoted_`.

#### Change the build schema
By default, this package builds the Workday Financial Management staging models within a schema titled (<target_schema> + `_workday_financial_management_staging`), the intermediate models within (<target_schema> + `_workday_financial_management_intermediate`), and the final models within (<target_schema> + `_workday_financial_management_reports`) in your destination. If this is not where you would like your data to be written, add the following configuration to your root `dbt_project.yml` file:

```yml
models:
    workday_financial_management:
      +schema: my_new_schema_name # leave blank for just the target_schema
      staging:
        +schema: my_new_staging_schema_name
      intermediate:
        +schema: my_new_intermediate_schema_name
```

#### Change the source table references
If an individual source table has a different name than expected, add the relevant variable to your root `dbt_project.yml` file:

> IMPORTANT: See this project's [`dbt_project.yml`](https://github.com/fivetran/dbt_workday_financial_management/blob/main/dbt_project.yml) variable declarations to see the expected names.

```yml
vars:
    workday_financial_management_<default_source_table_name>_identifier: your_table_name
```

## Does this package have dependencies?
This dbt package is dependent on the following dbt packages. These dependencies are installed by default within this package. For more information on the below packages, refer to the [dbt hub](https://hub.getdbt.com/) site.
> IMPORTANT: If you have any of these dependent packages in your own `packages.yml` file, we highly recommend that you remove them from your root `packages.yml` to avoid package version conflicts.

```yml
packages:
    - package: fivetran/fivetran_utils
      version: [">=0.4.12", "<0.5.0"]

    - package: dbt-labs/dbt_utils
      version: [">=1.0.0", "<2.0.0"]
```

## How is this package maintained and can I contribute?
### Package Maintenance
The Fivetran team maintaining this package _only_ maintains the latest version of the package. We highly recommend that you stay consistent with the [latest version](https://hub.getdbt.com/fivetran/workday_financial_management/latest/) of the package and refer to the [CHANGELOG](https://github.com/fivetran/dbt_workday_financial_management/blob/main/CHANGELOG.md) and release notes for more information on changes across versions.

### Opinionated modeling decisions
This package takes opinionated stances on how Workday worktags, fiscal periods, running balances, and reversal conventions are modeled. Review the [DECISIONLOG](https://github.com/fivetran/dbt_workday_financial_management/blob/main/DECISIONLOG.md) before you use the output models — some of these decisions affect how you should read the balance columns and the debit and credit amounts.

### Contributions
A small team of analytics engineers at Fivetran develops these dbt packages. However, the packages are made better by community contributions.

We highly encourage and welcome contributions to this package. Check out [this dbt Discourse article](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) on the best workflow for contributing to a package.

## Are there any resources available?
- If you have questions or want to reach out for help, see the [GitHub Issue](https://github.com/fivetran/dbt_workday_financial_management/issues/new/choose) section to find the right avenue of support for you.
- If you would like to provide feedback to the dbt package team at Fivetran or would like to request a new dbt package, fill out our [Feedback Form](https://www.surveymonkey.com/r/DQ7K7WW).
