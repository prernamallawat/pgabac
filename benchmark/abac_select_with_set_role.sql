/*
 * ABAC workload using SET ROLE.
 *
 * This is convenient when running pgbench as postgres:
 *
 *   pgbench -U postgres -d university_abac -n -M prepared -f benchmark/abac_select_with_set_role.sql -c 5 -j 2 -T 30
 *
 * Note:
 * This includes SET ROLE / RESET ROLE overhead in each transaction.
 * For cleaner ABAC-only measurement, prefer abac_select.sql with:
 *
 *   -U bench_cs_user
 */

SET ROLE bench_cs_user;

SELECT COUNT(*)
FROM bench_docs_abac;

RESET ROLE;