# ABAC-PG University Project

## Overview

This project implements an Attribute-Based Access Control (ABAC) policy engine as a PostgreSQL extension on the complete University Database from *Database System Concepts*.

The project uses PostgreSQL Row-Level Security (RLS) to restrict rows based on user attributes and row attributes.

Core idea:

```text
Subject attributes + Object attributes + Policy rules = access decision
```

Example:

```text
student.dept_name = current_user.department
AND current_user.status = 'active'
```

## Professor Feedback Addressed

This version explicitly supports the design points requested in feedback:

1. **AND-ed conditions inside one rule**
   - Stored in `abac_rule_conditions`.
   - All conditions with the same `rule_id` are combined using AND.

2. **Multiple rules per table with OR semantics**
   - Stored in `abac_rules`.
   - Access is granted if any enabled rule for the table succeeds.

3. **Attribute-to-attribute comparison**
   - Example: `student.dept_name = user.department`.

4. **Attribute-to-constant comparison**
   - Example: `user.status = 'active'` and `user.clearance = 'high'`.

5. **Numeric comparison support**
   - Example: `instructor.salary > user.salary_threshold`.
   - Operators supported: `=`, `==`, `!=`, `<>`, `>`, `<`, `>=`, `<=`.

6. **Evaluation plan**
   - Includes correctness demo and pgbench benchmarks.

## Project Structure

```text
pg_abac_university/
├── pg_abac.c
├── pg_abac.control
├── sql/pg_abac--1.0.sql
├── Makefile
├── DDL+drop.sql
├── largeRelationsInsertFile.sql
├── load_full_project.sql
├── demo/
│   ├── setup_abac_university.sql
│   ├── demo_script.sql
│   └── verify_abac.sql
├── benchmark/
│   ├── baseline.sql
│   ├── abac_enabled.sql
│   ├── policy_complexity.sql
│   └── README.md
└── docker-run.txt
```

## ABAC Metadata Schema

### `abac_user_attributes`

Stores subject/user attributes.

| Column | Purpose |
|---|---|
| `username` | PostgreSQL role name, such as `cs_user`. |
| `attribute_name` | Attribute name, such as `department`, `status`, `clearance`, or `salary_threshold`. |
| `attribute_value` | Attribute value, such as `Comp. Sci.`, `active`, or `70000`. |
| `created_at` | Audit timestamp for creation. |
| `updated_at` | Audit timestamp for updates. |

### `abac_rules`

Stores one rule for one table.

| Column | Purpose |
|---|---|
| `rule_id` | Unique rule identifier. |
| `rule_name` | Human-readable rule name. |
| `table_name` | Table protected by the rule. |
| `description` | Explanation of the rule. |
| `is_enabled` | Allows enabling/disabling a rule without deleting it. |
| `created_at` | Audit timestamp. |

Multiple enabled rules for the same table are evaluated using OR semantics.

### `abac_rule_conditions`

Stores conditions inside a rule.

| Column | Purpose |
|---|---|
| `condition_id` | Unique condition identifier. |
| `rule_id` | Parent rule. Conditions with the same `rule_id` are AND-ed. |
| `condition_order` | Display/evaluation order. |
| `column_name` | Object/table column, such as `dept_name` or `salary`. NULL means user attribute is compared to a constant. |
| `user_attribute` | Subject/user attribute, such as `department`, `status`, or `salary_threshold`. |
| `operator` | Comparison operator. Supports `=`, `!=`, `>`, `<`, `>=`, `<=`. |
| `constant_value` | Constant value for rules like `user.status = 'active'`. |
| `value_type` | `text` or `numeric`, used for correct comparison. |
| `created_at` | Audit timestamp. |

## Implemented Policies

### Student table

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

### Course table

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

### Instructor table

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

This demonstrates support for professor's example-style question: `user.dept = table.dept AND user.salary > 70k`.

## Run with Docker

From the project folder:

```bash
docker run --name pg-abac-final \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=university_abac \
  -p 5434:5432 \
  -v "$PWD":/pg_abac \
  -d postgres:15
```

Enter container:

```bash
docker exec -it pg-abac-final bash
```

Install build tools:

```bash
apt update
apt install -y build-essential postgresql-server-dev-15
```

Build and install extension:

```bash
cd /pg_abac
make clean
make PG_CONFIG=/usr/lib/postgresql/15/bin/pg_config
make install PG_CONFIG=/usr/lib/postgresql/15/bin/pg_config
```

Load complete project:

```bash
psql -U postgres -d university_abac -f load_full_project.sql
```

Run demo:

```bash
psql -U postgres -d university_abac -f demo/demo_script.sql
```

Run verification:

```bash
psql -U postgres -d university_abac -f demo/verify_abac.sql
```

## Benchmarking

Baseline:

```bash
pgbench -U postgres -d university_abac -f benchmark/baseline.sql -T 30
```

ABAC enabled:

```bash
pgbench -U postgres -d university_abac -f benchmark/abac_enabled.sql -T 30
```

Policy complexity:

```bash
pgbench -U postgres -d university_abac -f benchmark/policy_complexity.sql -T 30
```

## AI Disclosure

AI tools were used as a support aid for brainstorming, debugging, and drafting parts of the project structure. The team reviewed, modified, tested, and owns the final design and implementation. Team members are responsible for explaining every table, function, policy, and design decision.
