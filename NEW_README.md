````markdown
# ABAC-PG University Project

## Overview

This project implements an Attribute-Based Access Control (ABAC) policy engine as a PostgreSQL extension.

The project uses PostgreSQL Row-Level Security (RLS) to restrict table rows based on user attributes and row attributes. User attributes are stored in metadata tables, while object attributes are represented by table columns.

Core idea:

```text
Subject attributes + Object attributes + Policy rules = access decision
````

Example policy condition:

```text
student.dept_name = current_user.department
AND current_user.status = 'active'
```

The extension provides a metadata-driven authorization framework where access rules can be defined and updated without rewriting every application query.

## Project Goals

The main goals of this project are:

1. Build a PostgreSQL extension that supports ABAC-style authorization.
2. Use PostgreSQL Row-Level Security to enforce row filtering automatically.
3. Store user attributes and access rules in database metadata tables.
4. Support attribute-to-attribute and attribute-to-constant comparisons.
5. Support multiple conditions per rule using logical AND.
6. Support multiple rules per table using OR semantics.
7. Evaluate correctness using SQL test cases.
8. Evaluate performance overhead using `pgbench`.

## Key Features

### Attribute Management

The extension stores user attributes in the `abac_user_attributes` table.

Example attributes include:

```text
department
region
status
clearance
salary_threshold
```

Example:

```text
user.department = 'Comp. Sci.'
user.status = 'active'
user.clearance = 'high'
```

### Rule Specification

Rules are defined in metadata tables.

A rule maps object attributes, such as table columns, to subject attributes, such as user metadata.

Example:

```text
student.dept_name = user.department
```

### Predicate Support

The extension supports the following comparison operators:

```text
=
==
!=
<>
>
<
>=
<=
LIKE
NOT LIKE
```

Equality comparisons are supported for text and numeric values.

Ordered comparisons are supported for numeric values.

Pattern matching is supported through `LIKE` and `NOT LIKE`.

### Nominal Value Support

The extension supports comparing a user attribute against a constant value.

Example:

```text
user.status = 'active'
```

This allows policies to require fixed user states such as active status, high clearance, or a specific role classification.

### Boolean Logic

The policy engine supports Boolean logic in the following way:

```text
Conditions inside one rule are combined with AND.
Multiple rules for the same table are combined with OR.
```

Example:

```text
Rule 1:
student.dept_name = user.department
AND user.status = 'active'

OR

Rule 2:
user.clearance = 'high'
AND user.status = 'active'
```

This allows both restrictive department-based policies and override-style access rules.

## Project Structure

```text
pgabac/
├── Makefile
├── README.md
├── pg_abac.c
├── pg_abac.h
├── pg_abac.control
├── sql/
│   └── pg_abac--1.0.sql
├── database/
│   ├── university_schema.sql
│   └── university_data.sql
├── abac/
│   └── setup_abac.sql
├── demo/
│   └── demo.sql
├── test/
│   └── test_abac.sql
├── benchmark/
│   ├── 01_setup.sql
│   ├── baseline_select.sql
│   ├── abac_select.sql
│   ├── abac_select_with_set_role.sql
│   ├── policy_complexity.sql
│   ├── run_benchmark.sh
│   └── README.md
└── load_initial_project.sql
```

## Main Files

| File                             | Purpose                                                                 |
| -------------------------------- | ----------------------------------------------------------------------- |
| `pg_abac.c`                      | C source file for PostgreSQL extension functions                        |
| `pg_abac.h`                      | Header file for extension function declarations                         |
| `pg_abac.control`                | PostgreSQL extension control file                                       |
| `sql/pg_abac--1.0.sql`           | SQL extension file containing metadata tables and SQL/PLpgSQL functions |
| `Makefile`                       | PGXS build script for compiling and installing the extension            |
| `database/university_schema.sql` | University database schema                                              |
| `database/university_data.sql`   | University database sample data                                         |
| `abac/setup_abac.sql`            | ABAC roles, attributes, rules, and RLS policy setup                     |
| `demo/demo.sql`                  | Demonstration script showing ABAC access behavior                       |
| `test/test_abac.sql`             | Test suite for correctness and edge cases                               |
| `benchmark/`                     | pgbench performance evaluation scripts                                  |
| `load_initial_project.sql`       | Main loading script for extension, schema, data, and ABAC setup         |

## ABAC Metadata Schema

### `abac_user_attributes`

Stores subject/user attributes.

| Column            | Purpose                                                                            |
| ----------------- | ---------------------------------------------------------------------------------- |
| `username`        | PostgreSQL role name, such as `cs_user`                                            |
| `attribute_name`  | Attribute name, such as `department`, `status`, `clearance`, or `salary_threshold` |
| `attribute_value` | Attribute value, such as `Comp. Sci.`, `active`, or `70000`                        |
| `created_at`      | Timestamp when the attribute was created                                           |
| `updated_at`      | Timestamp when the attribute was last updated                                      |

Example:

```sql
SELECT abac_set_user_attribute('cs_user', 'department', 'Comp. Sci.');
SELECT abac_set_user_attribute('cs_user', 'status', 'active');
SELECT abac_set_user_attribute('cs_user', 'clearance', 'normal');
```

### `abac_rules`

Stores one logical rule for one protected table.

| Column        | Purpose                              |
| ------------- | ------------------------------------ |
| `rule_id`     | Unique rule identifier               |
| `rule_name`   | Human-readable rule name             |
| `table_name`  | Table protected by the rule          |
| `description` | Description of the rule              |
| `is_enabled`  | Indicates whether the rule is active |
| `created_at`  | Timestamp when the rule was created  |

Multiple enabled rules for the same table are evaluated using OR semantics.

### `abac_rule_conditions`

Stores conditions inside a rule.

| Column            | Purpose                                                                       |
| ----------------- | ----------------------------------------------------------------------------- |
| `condition_id`    | Unique condition identifier                                                   |
| `rule_id`         | Parent rule identifier                                                        |
| `condition_order` | Display or evaluation order                                                   |
| `column_name`     | Object/table column, such as `dept_name` or `salary`                          |
| `user_attribute`  | Subject/user attribute, such as `department`, `status`, or `salary_threshold` |
| `operator`        | Comparison operator                                                           |
| `constant_value`  | Constant value for attribute-to-literal comparisons                           |
| `value_type`      | Value type, such as `text` or `numeric`                                       |
| `created_at`      | Timestamp when the condition was created                                      |

Conditions with the same `rule_id` are combined using logical AND.

## Core Functions

### `abac_set_user_attribute`

Stores or updates a user attribute.

```sql
SELECT abac_set_user_attribute(
    'cs_user',
    'department',
    'Comp. Sci.'
);
```

### `abac_get_user_attribute`

Returns the value of a user attribute.

```sql
SELECT abac_get_user_attribute(
    'cs_user',
    'department'
);
```

### `abac_add_rule`

Creates an ABAC rule for a table.

```sql
SELECT abac_add_rule(
    'student_department_rule',
    'student',
    'Allow users to view students from their own department'
);
```

### `abac_add_condition`

Adds a condition to an ABAC rule.

Example attribute-to-attribute condition:

```sql
SELECT abac_add_condition(
    'student_department_rule',
    'dept_name',
    'department',
    '=',
    NULL,
    'text',
    1
);
```

Example attribute-to-constant condition:

```sql
SELECT abac_add_condition(
    'student_department_rule',
    NULL,
    'status',
    '=',
    'active',
    'text',
    2
);
```

### `abac_check_access`

Evaluates whether the current user can access a row.

This function is used inside RLS policies.

Example:

```sql
CREATE POLICY abac_student_select
ON student
FOR SELECT
USING (
    abac_check_access(
        'student',
        jsonb_build_object(
            'dept_name', dept_name
        )
    )
);
```

## Implemented Policies

### Student Table

Rule 1: Department and active status

```text
student.dept_name = user.department
AND user.status = 'active'
```

Rule 2: High-clearance override

```text
user.clearance = 'high'
AND user.status = 'active'
```

### Course Table

Rule 1: Department and active status

```text
course.dept_name = user.department
AND user.status = 'active'
```

Rule 2: High-clearance override

```text
user.clearance = 'high'
AND user.status = 'active'
```

### Instructor Table

Rule 1: Department, active status, and high clearance

```text
instructor.dept_name = user.department
AND user.status = 'active'
AND user.clearance = 'high'
```

Rule 2: Numeric comparison demo

```text
instructor.salary > user.salary_threshold
AND user.status = 'active'
```

This demonstrates numeric comparison support through metadata-driven ABAC rules.

## Row-Level Security Design

PostgreSQL Row-Level Security intercepts queries on protected tables.

When a user runs a query such as:

```sql
SELECT * FROM student;
```

PostgreSQL automatically applies the table's RLS policy.

The policy calls:

```sql
abac_check_access(...)
```

The function receives:

1. The table name being protected.
2. A JSONB object containing row attributes.
3. The current PostgreSQL role as the subject.

The function then checks the ABAC metadata tables to decide whether the row should be visible.

## Access Decision Logic

The ABAC decision process is:

```text
1. Identify the current PostgreSQL user.
2. Load enabled ABAC rules for the requested table.
3. For each rule:
   a. Load all conditions for the rule.
   b. Evaluate each condition.
   c. Combine conditions using AND.
4. If any rule succeeds, allow access.
5. If no rule succeeds, deny access.
```

In logical form:

```text
allow access =
    rule_1_success
    OR rule_2_success
    OR rule_3_success
```

Where each rule is:

```text
rule_success =
    condition_1
    AND condition_2
    AND condition_3
```

The engine follows a fail-closed approach. If required user attributes or row attributes are missing, the access check fails.

## Installation Guide

### Option 1: Run with Docker

From the project folder, start a PostgreSQL container:

```bash
docker run --name pg-abac-final \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=university_abac \
  -p 5434:5432 \
  -v "$PWD":/pg_abac \
  -d postgres:15
```

Enter the container:

```bash
docker exec -it pg-abac-final bash
```

Install build tools:

```bash
apt update
apt install -y build-essential postgresql-server-dev-15
```

Go to the project directory:

```bash
cd /pg_abac
```

Build the extension:

```bash
make clean
make PG_CONFIG=/usr/lib/postgresql/15/bin/pg_config
```

Install the extension:

```bash
make install PG_CONFIG=/usr/lib/postgresql/15/bin/pg_config
```

Load the complete project:

```bash
psql -U postgres -d university_abac -f load_initial_project.sql
```

### Option 2: Local PostgreSQL Installation

Install PostgreSQL server development files.

For PostgreSQL 15 on Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y build-essential postgresql-server-dev-15
```

Build and install:

```bash
make clean
make PG_CONFIG=/usr/lib/postgresql/15/bin/pg_config
sudo make install PG_CONFIG=/usr/lib/postgresql/15/bin/pg_config
```

Create or select a database:

```bash
createdb university_abac
```

Load the project:

```bash
psql -U postgres -d university_abac -f load_initial_project.sql
```

## Usage Examples

### Create Extension

```sql
CREATE EXTENSION IF NOT EXISTS pg_abac;
```

### Set User Attributes

```sql
SELECT abac_set_user_attribute('cs_user', 'department', 'Comp. Sci.');
SELECT abac_set_user_attribute('cs_user', 'region', 'US');
SELECT abac_set_user_attribute('cs_user', 'status', 'active');
SELECT abac_set_user_attribute('cs_user', 'clearance', 'normal');
```

### Create an ABAC Rule

```sql
SELECT abac_add_rule(
    'student_department_access',
    'student',
    'Allow active users to view students in their own department'
);
```

### Add Attribute-to-Attribute Condition

```sql
SELECT abac_add_condition(
    'student_department_access',
    'dept_name',
    'department',
    '=',
    NULL,
    'text',
    1
);
```

This means:

```text
student.dept_name = user.department
```

### Add Attribute-to-Constant Condition

```sql
SELECT abac_add_condition(
    'student_department_access',
    NULL,
    'status',
    '=',
    'active',
    'text',
    2
);
```

This means:

```text
user.status = 'active'
```

### Enable Row-Level Security

```sql
ALTER TABLE student ENABLE ROW LEVEL SECURITY;
```

### Create RLS Policy

```sql
CREATE POLICY abac_student_select
ON student
FOR SELECT
USING (
    abac_check_access(
        'student',
        jsonb_build_object(
            'dept_name', dept_name
        )
    )
);
```

### Test as a User

```sql
SET ROLE cs_user;

SELECT *
FROM student;

RESET ROLE;
```

The result will only include rows allowed by the ABAC policy.

## Running the Demo

Run the demo script:

```bash
psql -U postgres -d university_abac -f demo/demo.sql
```

The demo shows how different users see different rows based on their attributes.

Example users may include:

```text
cs_user
bio_user
registrar
inactive_user
```

Expected behavior:

| User            | Expected Access                               |
| --------------- | --------------------------------------------- |
| `cs_user`       | Rows matching the Computer Science department |
| `bio_user`      | Rows matching the Biology department          |
| `registrar`     | Broader access through high clearance         |
| `inactive_user` | No access because status is not active        |

## Running the Test Suite

Run the test script:

```bash
psql -U postgres -d university_abac -f test/test_abac.sql
```

The test suite verifies:

1. Equality comparisons.
2. Inequality comparisons.
3. Numeric comparisons.
4. LIKE and NOT LIKE comparisons.
5. Attribute-to-attribute rules.
6. Attribute-to-constant rules.
7. Multiple AND conditions.
8. Multiple OR rules.
9. Missing user attributes.
10. Missing row attributes.
11. Fail-closed behavior.
12. Attribute updates.
13. Rule deletion.
14. Legacy helper behavior, if included.

Expected final output:

```text
All ABAC tests passed.
```

## Benchmarking

The benchmark folder contains a `pgbench`-based performance evaluation.

The benchmark compares:

1. A baseline table without RLS.
2. An ABAC-protected table using RLS and `abac_check_access(...)`.
3. A more complex ABAC policy configuration.

Run benchmark setup:

```bash
psql -U postgres -d university_abac -f benchmark/01_setup.sql
```

Run all benchmark scenarios:

```bash
chmod +x benchmark/run_benchmark.sh
./benchmark/run_benchmark.sh university_abac
```

Optional longer benchmark:

```bash
DURATION=60 CLIENTS=10 JOBS=4 ./benchmark/run_benchmark.sh university_abac
```

Benchmark results are stored in:

```text
benchmark/results/
```

Expected result files:

```text
benchmark/results/baseline.txt
benchmark/results/abac_simple.txt
benchmark/results/abac_complex.txt
```

## Benchmark Methodology

The benchmark measures the performance overhead introduced by PostgreSQL RLS and metadata-driven ABAC evaluation.

The baseline workload uses direct SQL predicates:

```sql
SELECT COUNT(*)
FROM bench_docs_baseline
WHERE dept_name = 'Comp. Sci.'
  AND region = 'US';
```

The ABAC workload queries the protected table without manually writing the access-control predicate:

```sql
SELECT COUNT(*)
FROM bench_docs_abac;
```

PostgreSQL applies the RLS policy automatically.

The RLS policy invokes:

```sql
abac_check_access(...)
```

The ABAC function then evaluates metadata rules and user attributes to determine row visibility.

## Benchmark Results

Fill in this table after running the benchmark.

| Scenario                 |       TPS | Average Latency | Notes                                  |
| ------------------------ | --------: | --------------: | -------------------------------------- |
| Baseline explicit filter | *Fill in* |       *Fill in* | No RLS                                 |
| ABAC simple policy       | *Fill in* |       *Fill in* | RLS with metadata-driven policy check  |
| ABAC complex policy      | *Fill in* |       *Fill in* | Multiple rules and multiple conditions |

## Benchmark Environment

Fill in the environment used for the final benchmark run.

| Item               | Value        |
| ------------------ | ------------ |
| PostgreSQL version | *Fill in*    |
| Operating system   | *Fill in*    |
| CPU                | *Fill in*    |
| RAM                | *Fill in*    |
| Dataset size       | 100,000 rows |
| Benchmark duration | *Fill in*    |
| Number of clients  | *Fill in*    |
| Number of jobs     | *Fill in*    |

## Benchmark Analysis

The baseline workload is expected to achieve the highest throughput because it does not invoke RLS or metadata-driven policy checks.

The simple ABAC workload is expected to have additional overhead because PostgreSQL evaluates an RLS policy and calls `abac_check_access(...)`.

The complex ABAC workload is expected to have the highest overhead because the policy engine evaluates multiple rules and multiple conditions.

Overall, the benchmark demonstrates the tradeoff between flexible centralized authorization and additional runtime policy evaluation cost.

## AI Usage Disclosure

Generative AI tools were used as a support aid during this project.

AI assistance was used for:

1. Brainstorming the project structure.
2. Reviewing ABAC and RLS design ideas.
3. Drafting parts of the README documentation.
4. Suggesting test cases and benchmark organization.
5. Helping identify documentation inconsistencies and cleanup tasks.

The final design, source code, SQL scripts, testing, execution, debugging, and benchmark verification were reviewed and completed by the project team.

The team is responsible for understanding and explaining all implementation details, including:

1. PostgreSQL extension structure.
2. C source code.
3. SQL metadata schema.
4. ABAC rule evaluation logic.
5. Row-Level Security policies.
6. Test suite behavior.
7. Benchmark methodology and results.

## Limitations

This project is a working academic prototype of an ABAC policy engine.

Current limitations include:

1. Policies are evaluated dynamically through metadata tables, which introduces runtime overhead.
2. The current implementation focuses mainly on row-level read access.
3. Complex production authorization systems may require caching, indexing improvements, auditing, and administrative interfaces.
4. The current benchmark focuses on selected read workloads and does not represent every possible production query pattern.

## Future Improvements

Possible future enhancements include:

1. Support for set inclusion operators such as `IN`.
2. Support for more advanced pattern matching.
3. Support for richer Boolean logic such as nested AND/OR groups.
4. Policy caching for improved performance.
5. Admin views for easier policy inspection.
6. Audit logging for access decisions.
7. More extensive benchmarks with different query types and table sizes.
8. Integration with application-level identity providers.

## Conclusion

This project demonstrates a metadata-driven Attribute-Based Access Control policy engine implemented inside PostgreSQL.

It uses PostgreSQL Row-Level Security to automatically enforce access decisions based on user attributes, table row attributes, and configurable ABAC rules.

The extension supports:

1. User attribute management.
2. Rule-based policy specification.
3. Attribute-to-attribute comparisons.
4. Attribute-to-constant comparisons.
5. Equality, inequality, numeric, and pattern comparisons.
6. Multiple AND conditions inside a rule.
7. Multiple OR rules per table.
8. Correctness testing.
9. pgbench-based performance evaluation.

The result is a flexible database-level authorization engine that centralizes row-level access control inside PostgreSQL.

```
```
