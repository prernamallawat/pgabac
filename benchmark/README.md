# pg_abac Benchmark Methodology

This folder contains a `pgbench`-based performance evaluation for the PostgreSQL ABAC/RLS policy engine.

## Goal

The benchmark measures the overhead of enforcing metadata-driven ABAC policies through PostgreSQL Row-Level Security.

The comparison uses two tables with identical data:

| Table | Purpose |
|---|---|
| `bench_docs_baseline` | Baseline table without RLS |
| `bench_docs_abac` | Same data, protected by RLS and `abac_check_access(...)` |

Both tables contain 100,000 synthetic rows with object attributes such as department, region, classification, lifecycle, and amount.

## Files

| File | Description |
|---|---|
| `01_setup.sql` | Creates benchmark roles, tables, data, indexes, user attributes, ABAC rules, and RLS policy |
| `baseline_select.sql` | Baseline query using explicit SQL predicates |
| `abac_select.sql` | ABAC query executed as `bench_cs_user` |
| `abac_select_with_set_role.sql` | Convenience workload if running pgbench as `postgres` |
| `policy_complexity.sql` | ABAC query with multiple enabled policy rules |
| `run_benchmark.sh` | Runs all benchmark scenarios and stores output |

## Benchmark Scenarios

### 1. Baseline

The baseline query uses a normal table without RLS:

```sql
SELECT COUNT(*)
FROM bench_docs_baseline
WHERE dept_name = 'Comp. Sci.'
  AND region = 'US';