/*
 * Policy-complexity workload.
 *
 * This benchmark enables multiple rules for the same table.
 *
 * The ABAC engine must evaluate:
 *
 *   Rule 1:
 *     dept_name = user.department
 *     AND region = user.region
 *     AND user.status = 'active'
 *
 *   OR Rule 2:
 *     user.clearance = 'high'
 *     AND user.status = 'active'
 *
 *   OR Rule 3:
 *     amount <= user.spend_limit
 *     AND user.status = 'active'
 *
 * Run as:
 *
 *   pgbench -U bench_cs_user -d university_abac -n -M prepared -f benchmark/policy_complexity.sql -c 5 -j 2 -T 30
 */

SELECT COUNT(*)
FROM bench_docs_abac;