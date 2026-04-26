# ABAC-PG University Database Project

ABAC-PG is a PostgreSQL extension that implements an Attribute-Based Access Control policy engine using PostgreSQL Row Level Security. The demonstration is built on the University Database schema from *Database System Concepts*.

## What This Project Builds

The extension controls row visibility using:

- **Subject attributes**: attributes of the logged-in PostgreSQL role, such as department, status, and clearance.
- **Object attributes**: values stored in protected table rows, such as `student.dept_name`, `course.dept_name`, and `instructor.dept_name`.
- **Metadata-driven policies**: policies are stored in `abac_policies` instead of being hard-coded only in RLS.
- **Boolean AND logic**: all enabled policies for a table must pass before a row is visible.

Example policy:

```text
current_user.department = student.dept_name
AND current_user.status = 'active'
```

## Project Structure

```text
pg_abac_university/
├── Makefile
├── pg_abac.control
├── pg_abac.c
├── sql/
│   └── pg_abac--1.0.sql
├── demo/
│   ├── university_schema.sql
│   └── setup_abac_university.sql
├── test/
│   └── test_abac.sql
└── benchmark/
    ├── baseline.sql
    ├── abac_enabled.sql
    └── README.md
```

## University DB Tables Used

The demo uses these tables:

- `department`
- `instructor`
- `student`
- `course`
- `section`
- `teaches`
- `takes`
- `advisor`

The most important protected tables are:

- `student`
- `course`
- `instructor`

## Core Extension Tables

### `abac_user_attributes`

Stores subject attributes.

```sql
username | attribute_name | attribute_value
```

Example:

```sql
SELECT abac_set_user_attribute('alice_cs', 'department', 'Comp. Sci.');
SELECT abac_set_user_attribute('alice_cs', 'status', 'active');
```

### `abac_policies`

Stores policy rules.

```sql
policy_name | table_name | column_name | user_attribute | operator | constant_value
```

Two rule types are supported:

1. Row attribute rule:

```text
user.attribute = row.column_value
```

2. Nominal constant rule:

```text
user.attribute = constant_value
```

## Important Functions

### C Functions

```sql
abac_text_equals(left_value text, right_value text)
abac_text_not_equals(left_value text, right_value text)
abac_text_compare(left_value text, operator_value text, right_value text)
```

These functions provide the predicate support layer for the extension.

### SQL/PLpgSQL Functions

```sql
abac_set_user_attribute(username, attribute_name, attribute_value)
abac_get_user_attribute(username, attribute_name)
abac_add_policy(policy_name, table_name, column_name, user_attribute, operator, constant_value)
abac_check_text(table_name, column_name, row_value)
```

`abac_check_text()` is the main function used inside RLS policies.

## Installation

From the project directory:

```bash
make
sudo make install
```

Then create a database:

```bash
createdb university_abac
```

Inside the database:

```bash
psql -d university_abac -f demo/university_schema.sql
psql -d university_abac -c "CREATE EXTENSION pg_abac;"
psql -d university_abac -f demo/setup_abac_university.sql
```

## Running the Demo

```bash
psql -d university_abac
```

Then:

```sql
SET ROLE alice_cs;
SELECT ID, name, dept_name FROM student;
RESET ROLE;
```

Expected result: Alice sees only `Comp. Sci.` students.

```sql
SET ROLE bob_bio;
SELECT ID, name, dept_name FROM student;
RESET ROLE;
```

Expected result: Bob sees only `Biology` students.

```sql
SET ROLE eve_inactive;
SELECT ID, name, dept_name FROM student;
RESET ROLE;
```

Expected result: Eve sees no rows because her status is inactive.

## RLS Policy Example

```sql
ALTER TABLE student ENABLE ROW LEVEL SECURITY;

CREATE POLICY abac_student_select
ON student
FOR SELECT
USING (abac_check_text('student', 'dept_name', dept_name::text));
```

This single RLS policy checks both:

```text
user.department = student.dept_name
AND user.status = 'active'
```

because both rules are stored in `abac_policies`.

## Running Tests

```bash
psql -d university_abac -f test/test_abac.sql
```

The test file creates the University DB, installs ABAC demo policies, and checks three users:

- `alice_cs`: active Comp. Sci. user
- `bob_bio`: active Biology user
- `eve_inactive`: inactive Comp. Sci. user

## Benchmark

The project compares normal PostgreSQL filtering against ABAC-protected RLS access.

Baseline:

```bash
pgbench -n -T 30 -f benchmark/baseline.sql university_abac
```

ABAC-enabled:

```bash
pgbench -n -T 30 -f benchmark/abac_enabled.sql university_abac
```

Metrics to report:

- Average latency
- Transactions per second
- ABAC overhead percentage
- TPS drop percentage

## Why This Matches the Assignment

This project satisfies the ABAC topic because it includes:

- Attribute management through `abac_user_attributes`
- Rule specification through `abac_policies`
- Equality predicate support through C helper functions
- Nominal constant checks such as `status = active`
- Boolean AND logic because every enabled policy must pass
- PostgreSQL RLS integration for query-time enforcement
- Benchmarks using `pgbench`
- A C extension build using PGXS

## AI Disclosure

AI assistance was used to generate and organize the initial project structure, SQL scripts, C helper functions, tests, benchmark files, and documentation. The team is responsible for reviewing, testing, explaining, and defending every design choice and line of code.
