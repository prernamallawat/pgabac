# Benchmark Method

Run each workload for the same duration and compare TPS and average latency.

```bash
createdb university_abac
psql -d university_abac -f demo/university_schema.sql
make && sudo make install
psql -d university_abac -f demo/setup_abac_university.sql

pgbench -n -T 30 -f benchmark/baseline.sql university_abac
pgbench -n -T 30 -f benchmark/abac_enabled.sql university_abac
```

Baseline measures a direct SQL filter without RLS. ABAC-enabled measures the same logical access pattern through row-level security and ABAC metadata checks.

Report:

```text
Overhead % = ((ABAC latency - Baseline latency) / Baseline latency) * 100
TPS drop % = ((Baseline TPS - ABAC TPS) / Baseline TPS) * 100
```
