````markdown
# pg_abac Benchmark Methodology

This folder contains a `pgbench`-based performance evaluation for the PostgreSQL ABAC/RLS policy engine.

## Goal

The benchmark measures the performance overhead of enforcing metadata-driven Attribute-Based Access Control (ABAC) policies through PostgreSQL Row-Level Security (RLS).

The benchmark compares a normal PostgreSQL table against an equivalent table protected by RLS and the `abac_check_access(...)` function.

The comparison uses two tables with identical data:

| Table                 | Purpose |
|-----------------------| ---------------------------------------------------------|
| `bench_docs_baseline` | Baseline table without RLS                               |
| `bench_docs_abac`     | Same data, protected by RLS and `abac_check_access(...)` |

Both tables contain 100,000 synthetic rows with object attributes such as department, region, classification, lifecycle status, and amount.

## Files

| File                            | Description                                                                   |
| --------------------------------|-------------------------------------------------------------------------------|
| `01_setup.sql`                  | Creates benchmark roles, tables, data, indexes, user attributes, ABAC rules, and  RLS policies |
| `baseline_select.sql`           | Baseline workload using explicit SQL predicates on the unprotected table      |
| `abac_select.sql`               | ABAC workload executed as `bench_cs_user` on the RLS-protected table          |
| `abac_select_with_set_role.sql` | Convenience workload for running pgbench as a superuser or admin role         |
| `policy_complexity.sql`         | ABAC workload for testing multiple rules and more complex policy evaluation   |
| `run_benchmark.sh`              | Runs all benchmark scenarios and stores pgbench output files                  |

## Benchmark Scenarios

### 1. Baseline Query Without RLS

The baseline workload queries the unprotected table using normal SQL predicates:

```sql
SELECT COUNT(*)
FROM bench_docs_baseline
WHERE dept_name = 'Comp. Sci.'
  AND region = 'US';
````

This scenario represents a traditional application-side or query-side filtering approach without PostgreSQL RLS.

It provides the reference throughput and latency used to compare the ABAC-protected workloads.

### 2. Simple ABAC Policy With RLS

The simple ABAC workload queries the RLS-protected table:

```sql
SELECT COUNT(*)
FROM bench_docs_abac;
```

The filtering logic is not written directly in the query. Instead, PostgreSQL applies the RLS policy automatically.

The RLS policy calls:

```sql
abac_check_access(...)
```

The policy compares subject attributes stored in the ABAC metadata tables against object attributes from each row.

Example attributes include:

| Subject Attribute | Row/Object Attribute              |
| ----------------- | --------------------------------- |
| `department`      | `dept_name`                       |
| `region`          | `region`                          |
| `status`          | constant value such as `'active'` |

This scenario measures the overhead of enforcing a metadata-driven ABAC rule through RLS.

### 3. Complex ABAC Policy With Multiple Rules

The complex ABAC workload evaluates access using multiple ABAC rules for the same table.

Inside one rule, multiple conditions are combined using logical `AND`.

Across multiple rules for the same table, the engine allows access if at least one rule is satisfied.

This creates the following logical structure:

```text
(rule_1_condition_1 AND rule_1_condition_2 AND ...)
OR
(rule_2_condition_1 AND rule_2_condition_2 AND ...)
```

This scenario measures the additional cost of evaluating more complex metadata-driven policies.

## Setup Instructions

Run the setup script before executing the benchmark:

```bash
psql -U postgres -d university_abac -f benchmark/01_setup.sql
```

The setup script performs the following tasks:

1. Creates benchmark roles.
2. Creates baseline and ABAC benchmark tables.
3. Inserts 100,000 synthetic rows.
4. Creates indexes for commonly filtered columns.
5. Defines user attributes for benchmark users.
6. Defines ABAC rules and conditions.
7. Enables Row-Level Security on the protected benchmark table.
8. Creates the RLS policy that invokes `abac_check_access(...)`.

## Running the Benchmark

From the project root directory, run:

```bash
chmod +x benchmark/run_benchmark.sh
./benchmark/run_benchmark.sh university_abac
```

The script runs all benchmark scenarios and stores the results in:

```text
benchmark/results/
```

Expected output files include:

```text
benchmark/results/baseline.txt
benchmark/results/abac_simple.txt
benchmark/results/abac_complex.txt
```

## Optional Configuration

The benchmark script can be customized using environment variables.

Example:

```bash
DURATION=60 CLIENTS=10 JOBS=4 ./benchmark/run_benchmark.sh university_abac
```

| Variable   | Description                                    | Example |
| ---------- | ---------------------------------------------- | ------- |
| `DURATION` | Number of seconds to run each pgbench workload | `60`    |
| `CLIENTS`  | Number of concurrent pgbench clients           | `10`    |
| `JOBS`     | Number of pgbench worker threads               | `4`     |

If these variables are not provided, the script uses its default values.

## Recommended Benchmark Command

For a more stable measurement, use a longer duration:

```bash
DURATION=60 CLIENTS=10 JOBS=4 ./benchmark/run_benchmark.sh university_abac
```

Longer runs reduce noise and produce more reliable throughput and latency measurements.

## Metrics Collected

The benchmark uses standard `pgbench` output metrics.

Important metrics include:

| Metric                                      | Meaning                          |
| ------------------------------------------- | -------------------------------- |
| `tps`                                       | Transactions per second          |
| `latency average`                           | Average time per transaction     |
| `number of transactions actually processed` | Total completed transactions     |
| `number of failed transactions`             | Failed transaction count         |
| `scaling factor`                            | pgbench scale value, if reported |
| `query mode`                                | pgbench query execution mode     |

The most important comparison is the difference in throughput and latency between the baseline and ABAC/RLS workloads.

## Result Interpretation

The baseline workload is expected to have the highest throughput because it performs direct filtering on an unprotected table.

The ABAC workloads are expected to have lower throughput because PostgreSQL must evaluate the RLS policy for visible rows. The policy invokes `abac_check_access(...)`, which checks metadata tables and evaluates rule conditions dynamically.

The complex ABAC workload is expected to be slower than the simple ABAC workload because it evaluates more policy rules and conditions.

## Example Result Table

After running the benchmark, record the observed results below.

| Scenario                 |  TPS         |  Average Latency  | Notes                               |
| -------------------------| ------------ | ----------------- | ------------------------------------|
| Baseline explicit filter | 14661.776280 | 0.682 ms          | No RLS                              |
| ABAC simple policy       | 4.884729     | 2047.196 ms       | RLS with metadata-driven ABAC check |
| ABAC complex policy      | 2.097811     | 4766.873 ms       | Multiple ABAC rules and conditions  |

## Example Analysis Format

Use the following format when reporting the final benchmark analysis:

```text
The baseline workload achieved the highest throughput because it used direct SQL predicates without invoking RLS or metadata-driven policy checks.

The simple ABAC workload showed additional overhead because each query was filtered by PostgreSQL Row-Level Security using the abac_check_access function.

The complex ABAC workload had the highest overhead because the policy engine evaluated multiple rules and multiple conditions before determining row visibility.

Overall, the results demonstrate that the ABAC/RLS approach provides flexible, centralized authorization at the cost of additional query-time policy evaluation.
```

## Environment Details

Record the environment used for the benchmark.

| Item               | Value        |
| ------------------ | ------------ |
| PostgreSQL version | 15.6         |
| Benchmark duration | 60 s         |
| Number of clients  | 10           |
| Number of jobs     | 4            |

## Notes and Assumptions

The benchmark focuses on read performance for `SELECT COUNT(*)` workloads.

The baseline workload uses explicit SQL predicates, while the ABAC workloads rely on PostgreSQL RLS to apply access-control logic automatically.

The benchmark is intended to quantify the relative overhead of the ABAC policy engine, not to represent every possible production workload.

Actual performance may vary depending on hardware, PostgreSQL configuration, indexing strategy, dataset size, policy complexity, and query shape.

## Cleanup

To remove benchmark objects manually, drop the benchmark tables and roles if needed:

```sql
DROP TABLE IF EXISTS bench_docs_baseline CASCADE;
DROP TABLE IF EXISTS bench_docs_abac CASCADE;

DROP ROLE IF EXISTS bench_cs_user;
DROP ROLE IF EXISTS bench_admin_user;
```

If the ABAC metadata tables contain benchmark rules or attributes, remove those entries as needed:

```sql
DELETE FROM abac_user_attributes
WHERE username IN ('bench_cs_user', 'bench_admin_user');

DELETE FROM abac_rules
WHERE table_name = 'bench_docs_abac';
```

## Summary

This benchmark evaluates the cost of enforcing ABAC policies through PostgreSQL Row-Level Security.

It compares:

1. A baseline table without RLS.
2. A simple ABAC/RLS-protected table.
3. A more complex ABAC/RLS policy configuration.

The results help quantify the tradeoff between flexible, centralized database-level authorization and the additional runtime overhead introduced by dynamic policy evaluation.
