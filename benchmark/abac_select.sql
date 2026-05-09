/*
 * ABAC workload.
 *
 * Recommended usage:
 *
 *   pgbench -U bench_cs_user -d university_abac -n -M prepared -f benchmark/abac_select.sql -c 5 -j 2 -T 30
 *
 * The current database user is bench_cs_user, so PostgreSQL RLS calls:
 *
 *   abac_check_access('bench_docs_abac', ...)
 *
 * for each row.
 */

SELECT COUNT(*)
FROM bench_docs_abac;