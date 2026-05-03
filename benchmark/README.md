# Benchmark and Evaluation Plan

The professor asked for systematic evaluation. We evaluate both correctness and performance.

## Experiment 1: Baseline vs ABAC Overhead

Baseline:
```bash
pgbench -U postgres -d university_abac -f benchmark/baseline.sql -T 30
```

ABAC:
```bash
pgbench -U postgres -d university_abac -f benchmark/abac_enabled.sql -T 30
```

Metrics: TPS, average latency, and percent overhead.

## Experiment 2: Correctness

Run:
```bash
psql -U postgres -d university_abac -f demo/demo_script.sql
```

Correctness criterion: the same query returns different row sets for different users based on attributes.

## Experiment 3: Policy Complexity

Run:
```bash
pgbench -U postgres -d university_abac -f benchmark/policy_complexity.sql -T 30
```

This tests a table with multiple rules, AND conditions, and numeric comparison.
