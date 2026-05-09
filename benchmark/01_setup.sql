\set ON_ERROR_STOP 1

/*
 * Benchmark setup for pg_abac.
 *
 * This creates two equivalent benchmark tables:
 *
 *   1. bench_docs_baseline
 *      - No RLS
 *      - Used for baseline WHERE-filter performance
 *
 *   2. bench_docs_abac
 *      - Same data
 *      - Protected by PostgreSQL RLS
 *      - Uses abac_check_access(...)
 *
 * Run:
 *
 *   psql -U postgres -d university_abac -f benchmark/01_setup.sql
 */

CREATE EXTENSION IF NOT EXISTS pg_abac;

DROP TABLE IF EXISTS bench_docs_baseline CASCADE;
DROP TABLE IF EXISTS bench_docs_abac CASCADE;

DELETE FROM abac_rules
WHERE table_name = 'bench_docs_abac';

DELETE FROM abac_user_attributes
WHERE username IN (
    'bench_cs_user',
    'bench_bio_user',
    'bench_registrar',
    'bench_inactive_user'
);

/* 
 * Benchmark roles
 */
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bench_cs_user') THEN
        CREATE ROLE bench_cs_user LOGIN PASSWORD 'bench_cs_user';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bench_bio_user') THEN
        CREATE ROLE bench_bio_user LOGIN PASSWORD 'bench_bio_user';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bench_registrar') THEN
        CREATE ROLE bench_registrar LOGIN PASSWORD 'bench_registrar';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bench_inactive_user') THEN
        CREATE ROLE bench_inactive_user LOGIN PASSWORD 'bench_inactive_user';
    END IF;
END $$;

GRANT USAGE ON SCHEMA public
TO bench_cs_user, bench_bio_user, bench_registrar, bench_inactive_user;

GRANT SELECT ON abac_user_attributes, abac_rules, abac_rule_conditions, abac_policies
TO bench_cs_user, bench_bio_user, bench_registrar, bench_inactive_user;

GRANT EXECUTE ON FUNCTION abac_get_user_attribute(text, text)
TO bench_cs_user, bench_bio_user, bench_registrar, bench_inactive_user;

GRANT EXECUTE ON FUNCTION abac_check_access(text, jsonb)
TO bench_cs_user, bench_bio_user, bench_registrar, bench_inactive_user;

GRANT EXECUTE ON FUNCTION abac_compare_values(text, text, text, text)
TO bench_cs_user, bench_bio_user, bench_registrar, bench_inactive_user;

/*
 * Synthetic benchmark data
 *
 * 100,000 rows is enough for a class project benchmark.
 * Increase to 1,000,000 if your machine can handle it.
 */
CREATE TABLE bench_docs_baseline (
    doc_id integer PRIMARY KEY,
    dept_name text NOT NULL,
    region text NOT NULL,
    classification text NOT NULL,
    lifecycle text NOT NULL,
    amount numeric NOT NULL,
    title text NOT NULL
);

INSERT INTO bench_docs_baseline
SELECT
    gs AS doc_id,
    CASE
        WHEN gs % 4 = 0 THEN 'Comp. Sci.'
        WHEN gs % 4 = 1 THEN 'Biology'
        WHEN gs % 4 = 2 THEN 'Finance'
        ELSE 'Math'
    END AS dept_name,
    CASE
        WHEN gs % 3 = 0 THEN 'US'
        WHEN gs % 3 = 1 THEN 'EU'
        ELSE 'APAC'
    END AS region,
    CASE
        WHEN gs % 10 = 0 THEN 'confidential'
        WHEN gs % 5 = 0 THEN 'restricted'
        ELSE 'public'
    END AS classification,
    CASE
        WHEN gs % 20 = 0 THEN 'archived'
        ELSE 'active'
    END AS lifecycle,
    (gs % 10000)::numeric AS amount,
    'Benchmark document ' || gs AS title
FROM generate_series(1, 100000) AS gs;

CREATE TABLE bench_docs_abac AS
SELECT *
FROM bench_docs_baseline;

ALTER TABLE bench_docs_abac
ADD PRIMARY KEY (doc_id);

CREATE INDEX idx_bench_docs_baseline_dept_region
ON bench_docs_baseline(dept_name, region);

CREATE INDEX idx_bench_docs_abac_dept_region
ON bench_docs_abac(dept_name, region);

CREATE INDEX idx_bench_docs_baseline_amount
ON bench_docs_baseline(amount);

CREATE INDEX idx_bench_docs_abac_amount
ON bench_docs_abac(amount);

GRANT SELECT ON bench_docs_baseline
TO bench_cs_user, bench_bio_user, bench_registrar, bench_inactive_user;

GRANT SELECT ON bench_docs_abac
TO bench_cs_user, bench_bio_user, bench_registrar, bench_inactive_user;

/*
 * User attributes
 */
SELECT abac_set_user_attribute('bench_cs_user', 'department', 'Comp. Sci.');
SELECT abac_set_user_attribute('bench_cs_user', 'region', 'US');
SELECT abac_set_user_attribute('bench_cs_user', 'status', 'active');
SELECT abac_set_user_attribute('bench_cs_user', 'clearance', 'normal');
SELECT abac_set_user_attribute('bench_cs_user', 'spend_limit', '5000');

SELECT abac_set_user_attribute('bench_bio_user', 'department', 'Biology');
SELECT abac_set_user_attribute('bench_bio_user', 'region', 'EU');
SELECT abac_set_user_attribute('bench_bio_user', 'status', 'active');
SELECT abac_set_user_attribute('bench_bio_user', 'clearance', 'normal');
SELECT abac_set_user_attribute('bench_bio_user', 'spend_limit', '3000');

SELECT abac_set_user_attribute('bench_registrar', 'department', 'Registrar');
SELECT abac_set_user_attribute('bench_registrar', 'region', 'US');
SELECT abac_set_user_attribute('bench_registrar', 'status', 'active');
SELECT abac_set_user_attribute('bench_registrar', 'clearance', 'high');
SELECT abac_set_user_attribute('bench_registrar', 'spend_limit', '999999');

SELECT abac_set_user_attribute('bench_inactive_user', 'department', 'Comp. Sci.');
SELECT abac_set_user_attribute('bench_inactive_user', 'region', 'US');
SELECT abac_set_user_attribute('bench_inactive_user', 'status', 'inactive');
SELECT abac_set_user_attribute('bench_inactive_user', 'clearance', 'high');
SELECT abac_set_user_attribute('bench_inactive_user', 'spend_limit', '999999');

/* 
 * ABAC rules for benchmark table
 *
 * Rule 1:
 *   row.dept_name = user.department
 *   AND row.region = user.region
 *   AND user.status = 'active'
 *
 */
SELECT abac_add_rule(
    'bench_docs_dept_region_active',
    'bench_docs_abac',
    'Benchmark rule: department and region match, and user is active'
);

SELECT abac_add_condition(
    'bench_docs_dept_region_active',
    'dept_name',
    'department',
    '=',
    NULL,
    'text',
    1
);

SELECT abac_add_condition(
    'bench_docs_dept_region_active',
    'region',
    'region',
    '=',
    NULL,
    'text',
    2
);

SELECT abac_add_condition(
    'bench_docs_dept_region_active',
    NULL,
    'status',
    '=',
    'active',
    'text',
    3
);

/*
 * The setup keeps only the simple rule active for the simple ABAC benchmark.
 * run_benchmark.sh adds the extra rules later before the policy-complexity run.
 */

ALTER TABLE bench_docs_abac ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bench_docs_abac_select ON bench_docs_abac;

CREATE POLICY bench_docs_abac_select
ON bench_docs_abac
FOR SELECT
USING (
    abac_check_access(
        'bench_docs_abac',
        jsonb_build_object(
            'dept_name', dept_name,
            'region', region,
            'classification', classification,
            'lifecycle', lifecycle,
            'amount', amount
        )
    )
);

ANALYZE bench_docs_baseline;
ANALYZE bench_docs_abac;
ANALYZE abac_user_attributes;
ANALYZE abac_rules;
ANALYZE abac_rule_conditions;

\echo 'Benchmark setup complete.'
\echo 'Created bench_docs_baseline and bench_docs_abac with 100,000 rows.'