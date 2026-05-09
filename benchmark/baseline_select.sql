/*
 * Baseline workload.
 *
 * This query performs the equivalent filtering explicitly in SQL without RLS.
 * It represents what the application would need to do manually without ABAC.
 */

SELECT COUNT(*)
FROM bench_docs_baseline
WHERE dept_name = 'Comp. Sci.'
  AND region = 'US';