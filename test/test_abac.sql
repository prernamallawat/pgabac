\set ON_ERROR_STOP 1
\pset pager off

/*
 * This file uses assertions. Any failed expectation raises an exception and
 * causes psql to exit with a non-zero status.
 */

CREATE EXTENSION IF NOT EXISTS pg_abac;

/*
 * Assertion helpers
*/
CREATE OR REPLACE FUNCTION pg_temp.assert_eq_bigint(
    p_actual bigint,
    p_expected bigint,
    p_test_name text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_actual IS DISTINCT FROM p_expected THEN
        RAISE EXCEPTION 'FAILED: %. Expected %, got %',
            p_test_name, p_expected, p_actual;
    END IF;

    RAISE NOTICE 'PASSED: % => %', p_test_name, p_actual;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.assert_true(
    p_actual boolean,
    p_test_name text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_actual IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'FAILED: %. Expected TRUE, got %',
            p_test_name, p_actual;
    END IF;

    RAISE NOTICE 'PASSED: %', p_test_name;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.assert_false(
    p_actual boolean,
    p_test_name text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_actual IS DISTINCT FROM false THEN
        RAISE EXCEPTION 'FAILED: %. Expected FALSE, got %',
            p_test_name, p_actual;
    END IF;

    RAISE NOTICE 'PASSED: %', p_test_name;
END;
$$;

/*
 * Test roles
*/
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'abac_alice') THEN
        CREATE ROLE abac_alice LOGIN PASSWORD 'abac_alice';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'abac_bob') THEN
        CREATE ROLE abac_bob LOGIN PASSWORD 'abac_bob';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'abac_carol') THEN
        CREATE ROLE abac_carol LOGIN PASSWORD 'abac_carol';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'abac_dana') THEN
        CREATE ROLE abac_dana LOGIN PASSWORD 'abac_dana';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'abac_erin') THEN
        CREATE ROLE abac_erin LOGIN PASSWORD 'abac_erin';
    END IF;
END $$;

GRANT USAGE ON SCHEMA public
TO abac_alice, abac_bob, abac_carol, abac_dana, abac_erin;

GRANT SELECT ON abac_user_attributes, abac_rules, abac_rule_conditions, abac_policies
TO abac_alice, abac_bob, abac_carol, abac_dana, abac_erin;

GRANT EXECUTE ON FUNCTION abac_get_user_attribute(text, text)
TO abac_alice, abac_bob, abac_carol, abac_dana, abac_erin;

GRANT EXECUTE ON FUNCTION abac_check_access(text, jsonb)
TO abac_alice, abac_bob, abac_carol, abac_dana, abac_erin;

GRANT EXECUTE ON FUNCTION abac_compare_values(text, text, text, text)
TO abac_alice, abac_bob, abac_carol, abac_dana, abac_erin;

/*
 * Clean fixture data so the test is repeatable
*/
DROP TABLE IF EXISTS abac_test_documents CASCADE;

DELETE FROM abac_rules
WHERE table_name = 'abac_test_documents';

DELETE FROM abac_user_attributes
WHERE username IN (
    'abac_alice',
    'abac_bob',
    'abac_carol',
    'abac_dana',
    'abac_erin'
);

CREATE TABLE abac_test_documents (
    doc_id integer PRIMARY KEY,
    dept text NOT NULL,
    region text NOT NULL,
    classification text NOT NULL,
    lifecycle text NOT NULL,
    amount numeric NOT NULL,
    title text NOT NULL
);

INSERT INTO abac_test_documents
    (doc_id, dept, region, classification, lifecycle, amount, title)
VALUES
    (1, 'CS',      'US', 'public',       'active',   100,  'AI intro'),
    (2, 'CS',      'EU', 'public',       'active',   300,  'AI Europe'),
    (3, 'Biology', 'EU', 'restricted',   'active',   150,  'Bio lab'),
    (4, 'HR',      'US', 'confidential', 'active',   5000, 'Payroll'),
    (5, 'CS',      'US', 'public',       'archived', 50,   'Legacy AI archive'),
    (6, 'Math',    'US', 'public',       'active',   75,   'Calculus');

GRANT SELECT ON abac_test_documents
TO abac_alice, abac_bob, abac_carol, abac_dana, abac_erin;

ALTER TABLE abac_test_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS abac_test_documents_select ON abac_test_documents;

CREATE POLICY abac_test_documents_select
ON abac_test_documents
FOR SELECT
USING (
    abac_check_access(
        'abac_test_documents',
        jsonb_build_object(
            'dept', dept,
            'region', region,
            'classification', classification,
            'lifecycle', lifecycle,
            'amount', amount,
            'title', title
        )
    )
);

/* 
 * Subject/user attributes
*/
SELECT abac_set_user_attribute('abac_alice', 'department', 'CS');
SELECT abac_set_user_attribute('abac_alice', 'region', 'US');
SELECT abac_set_user_attribute('abac_alice', 'status', 'active');
SELECT abac_set_user_attribute('abac_alice', 'clearance', 'normal');
SELECT abac_set_user_attribute('abac_alice', 'spend_limit', '1000');
SELECT abac_set_user_attribute('abac_alice', 'title_pattern', '%AI%');

SELECT abac_set_user_attribute('abac_bob', 'department', 'Biology');
SELECT abac_set_user_attribute('abac_bob', 'region', 'EU');
SELECT abac_set_user_attribute('abac_bob', 'status', 'active');
SELECT abac_set_user_attribute('abac_bob', 'clearance', 'normal');
SELECT abac_set_user_attribute('abac_bob', 'spend_limit', '200');
SELECT abac_set_user_attribute('abac_bob', 'title_pattern', 'Bio%');

SELECT abac_set_user_attribute('abac_carol', 'department', 'CS');
SELECT abac_set_user_attribute('abac_carol', 'region', 'US');
SELECT abac_set_user_attribute('abac_carol', 'status', 'inactive');
SELECT abac_set_user_attribute('abac_carol', 'clearance', 'high');
SELECT abac_set_user_attribute('abac_carol', 'spend_limit', '9999');
SELECT abac_set_user_attribute('abac_carol', 'title_pattern', '%');

SELECT abac_set_user_attribute('abac_dana', 'department', 'HR');
SELECT abac_set_user_attribute('abac_dana', 'region', 'US');
SELECT abac_set_user_attribute('abac_dana', 'status', 'active');
SELECT abac_set_user_attribute('abac_dana', 'clearance', 'high');
SELECT abac_set_user_attribute('abac_dana', 'spend_limit', '5000');

/*
 * Erin intentionally has missing region, clearance, spend_limit,
 * and title_pattern attributes.
 */
SELECT abac_set_user_attribute('abac_erin', 'department', 'CS');
SELECT abac_set_user_attribute('abac_erin', 'status', 'active');


/*
 * ABAC rules for fixture table
 *
 * Since rule activation is not stored in abac_rules, this test isolates
 * each scenario by deleting the current fixture-table rules and recreating
 * only the rule or rules needed for that scenario.
 */
CREATE OR REPLACE FUNCTION pg_temp.clear_doc_rules()
RETURNS void
LANGUAGE sql
AS $$
    DELETE FROM abac_rules
    WHERE table_name = 'abac_test_documents';
$$;

CREATE OR REPLACE FUNCTION pg_temp.create_dept_region_rule()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM abac_add_rule(
        't_doc_dept_region_active',
        'abac_test_documents',
        'row.dept = user.department AND row.region = user.region AND user.status = active'
    );

    PERFORM abac_add_condition(
        't_doc_dept_region_active',
        'dept',
        'department',
        '=',
        NULL,
        'text',
        1
    );

    PERFORM abac_add_condition(
        't_doc_dept_region_active',
        'region',
        'region',
        '=',
        NULL,
        'text',
        2
    );

    PERFORM abac_add_condition(
        't_doc_dept_region_active',
        NULL,
        'status',
        '=',
        'active',
        'text',
        3
    );
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.create_high_clearance_rule()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM abac_add_rule(
        't_doc_high_clearance_active',
        'abac_test_documents',
        'user.clearance = high AND user.status = active'
    );

    PERFORM abac_add_condition(
        't_doc_high_clearance_active',
        NULL,
        'clearance',
        '=',
        'high',
        'text',
        1
    );

    PERFORM abac_add_condition(
        't_doc_high_clearance_active',
        NULL,
        'status',
        '=',
        'active',
        'text',
        2
    );
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.create_amount_limit_rule()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM abac_add_rule(
        't_doc_amount_under_limit_active',
        'abac_test_documents',
        'row.amount <= user.spend_limit AND user.status = active'
    );

    PERFORM abac_add_condition(
        't_doc_amount_under_limit_active',
        'amount',
        'spend_limit',
        '<=',
        NULL,
        'numeric',
        1
    );

    PERFORM abac_add_condition(
        't_doc_amount_under_limit_active',
        NULL,
        'status',
        '=',
        'active',
        'text',
        2
    );
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.create_title_like_rule()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM abac_add_rule(
        't_doc_title_like_active',
        'abac_test_documents',
        'row.title LIKE user.title_pattern AND user.status = active'
    );

    PERFORM abac_add_condition(
        't_doc_title_like_active',
        'title',
        'title_pattern',
        'LIKE',
        NULL,
        'text',
        1
    );

    PERFORM abac_add_condition(
        't_doc_title_like_active',
        NULL,
        'status',
        '=',
        'active',
        'text',
        2
    );
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.create_missing_json_rule()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM abac_add_rule(
        't_doc_missing_json_attribute',
        'abac_test_documents',
        'references a row attribute not supplied in the RLS JSON object'
    );

    PERFORM abac_add_condition(
        't_doc_missing_json_attribute',
        'not_in_policy_json',
        'department',
        '=',
        NULL,
        'text',
        1
    );
END;
$$;

/*
 * Core function/operator tests
*/
SELECT pg_temp.assert_true(
    abac_compare_values('CS', '=', 'CS', 'text'),
    'text equality operator'
);

SELECT pg_temp.assert_true(
    abac_compare_values('CS', '!=', 'HR', 'text'),
    'text inequality operator'
);

SELECT pg_temp.assert_true(
    abac_compare_values('500', '<=', '1000', 'numeric'),
    'numeric <= operator'
);

SELECT pg_temp.assert_true(
    abac_compare_values('1001', '>', '1000', 'numeric'),
    'numeric > operator'
);

SELECT pg_temp.assert_true(
    abac_compare_values('AI intro', 'LIKE', '%AI%', 'text'),
    'LIKE operator'
);

SELECT pg_temp.assert_true(
    abac_compare_values('Payroll', 'NOT LIKE', '%AI%', 'text'),
    'NOT LIKE operator'
);

SELECT pg_temp.assert_false(
    abac_compare_values(NULL, '=', 'CS', 'text'),
    'NULL comparison fails closed'
);

SELECT pg_temp.assert_false(
    abac_compare_values('abc', '<=', '100', 'numeric'),
    'invalid numeric cast fails closed'
);

/* 
 * Test 1: fail closed when no rule exists for an RLS-protected table
 */
SELECT pg_temp.clear_doc_rules();

SET ROLE abac_alice;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    0,
    'fail closed when no table rules exist'
);

/* 
 * Test 2: equality + constant/literal + AND semantics
 *
 * Expected:
 * Alice sees CS + US rows.
 * Bob sees Biology + EU rows.
 * Carol is inactive, so she sees nothing.
 * Erin is missing region, so she sees nothing.
 */
SELECT pg_temp.clear_doc_rules();
SELECT pg_temp.create_dept_region_rule();

SET ROLE abac_alice;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    2,
    'AND rule: Alice sees only CS + US documents'
);

SET ROLE abac_bob;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    1,
    'AND rule: Bob sees only Biology + EU documents'
);

SET ROLE abac_carol;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    0,
    'constant literal condition denies inactive user'
);

SET ROLE abac_erin;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    0,
    'missing user attribute denies access'
);

/* 
 * Test 3: multiple rules per table are OR-ed
 *
 * Expected:
 * Dana has high clearance and active status, so she sees all rows.
 * Carol has high clearance but inactive status, so she still sees no rows.
 */
SELECT pg_temp.clear_doc_rules();
SELECT pg_temp.create_dept_region_rule();
SELECT pg_temp.create_high_clearance_rule();

SET ROLE abac_dana;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    6,
    'OR override: active high-clearance user sees all documents'
);

SET ROLE abac_carol;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    0,
    'OR override still requires active status'
);

/*
 * Test 4: numeric comparison against user attribute
*/
SELECT pg_temp.clear_doc_rules();
SELECT pg_temp.create_amount_limit_rule();

SET ROLE abac_alice;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    5,
    'numeric <= rule: Alice spend_limit 1000'
);

SET ROLE abac_bob;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    4,
    'numeric <= rule: Bob spend_limit 200'
);

SELECT abac_set_user_attribute('abac_alice', 'spend_limit', 'not_a_number');

SET ROLE abac_alice;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    0,
    'invalid numeric user attribute denies access without crashing'
);

SELECT abac_set_user_attribute('abac_alice', 'spend_limit', '1000');

/*
 * Test 5: LIKE pattern comparison against user attribute
*/
SELECT pg_temp.clear_doc_rules();
SELECT pg_temp.create_title_like_rule();

SET ROLE abac_alice;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    3,
    'LIKE rule: Alice title_pattern %AI%'
);

SET ROLE abac_bob;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    1,
    'LIKE rule: Bob title_pattern Bio%'
);

/*
 * Test 6: missing row attribute in jsonb payload fails closed
 */
SELECT pg_temp.clear_doc_rules();
SELECT pg_temp.create_missing_json_rule();

SET ROLE abac_alice;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    0,
    'missing row attribute in policy JSON denies access'
);

/*
 * Test 7: policy metadata constraints reject invalid definitions
*/
SELECT pg_temp.clear_doc_rules();
SELECT pg_temp.create_dept_region_rule();

DO $$
BEGIN
    BEGIN
        PERFORM abac_add_condition(
            't_doc_dept_region_active',
            'dept',
            'department',
            'BETWEEN',
            NULL,
            'text',
            99
        );

        RAISE EXCEPTION 'FAILED: invalid operator was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASSED: invalid operator rejected by CHECK constraint';
    END;

    BEGIN
        PERFORM abac_add_condition(
            't_doc_dept_region_active',
            'dept',
            'department',
            '=',
            'CS',
            'text',
            99
        );

        RAISE EXCEPTION 'FAILED: condition with both column_name and constant_value was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASSED: condition cannot use both column_name and constant_value';
    END;

    BEGIN
        PERFORM abac_add_condition(
            't_doc_dept_region_active',
            NULL,
            'department',
            '=',
            NULL,
            'text',
            99
        );

        RAISE EXCEPTION 'FAILED: condition with neither column_name nor constant_value was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASSED: condition must use either column_name or constant_value';
    END;
END $$;

/*
 * Test 8: backward-compatible single-condition policy helper
*/
SELECT pg_temp.clear_doc_rules();

SELECT abac_add_policy(
    't_doc_legacy_single_condition_policy',
    'abac_test_documents',
    'dept',
    'department',
    '=',
    NULL
);

SET ROLE abac_alice;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    3,
    'legacy abac_add_policy helper: Alice sees all CS docs'
);

/*
 * Additional coverage tests
*/

SELECT pg_temp.assert_true(
    abac_compare_values('50', '<', '100', 'numeric'),
    'numeric < operator'
);

SELECT pg_temp.assert_true(
    abac_compare_values('100', '>=', '100', 'numeric'),
    'numeric >= operator equal boundary'
);

SELECT pg_temp.assert_false(
    abac_compare_values('100', '<', '50', 'numeric'),
    'numeric < negative case'
);

SELECT pg_temp.assert_false(
    abac_compare_values('cs', '=', 'CS', 'text'),
    'text comparison is case-sensitive'
);

SELECT pg_temp.assert_false(
    abac_compare_values('', '=', 'CS', 'text'),
    'empty string does not match non-empty text'
);

SELECT pg_temp.assert_false(
    abac_check_access(
        'table_that_has_no_rules',
        jsonb_build_object('dept', 'CS')
    ),
    'unknown table with no rules denies access'
);

/* Deleted rule removes access */
SELECT pg_temp.clear_doc_rules();
SELECT pg_temp.create_dept_region_rule();

SET ROLE abac_alice;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    2,
    'Alice has access before deleting the rule'
);

DELETE FROM abac_rules
WHERE rule_name = 't_doc_dept_region_active';

SET ROLE abac_alice;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    0,
    'Alice loses access after deleting the rule'
);

/* Attribute update dynamically changes access */
SELECT pg_temp.clear_doc_rules();
SELECT pg_temp.create_dept_region_rule();

SELECT abac_set_user_attribute('abac_alice', 'region', 'EU');

SET ROLE abac_alice;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    1,
    'dynamic attribute update changes Alice visible rows to EU'
);

SELECT abac_set_user_attribute('abac_alice', 'region', 'US');

SET ROLE abac_alice;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    2,
    'dynamic attribute update restores Alice visible rows to US'
);

/* Attribute overwrite behavior */
SELECT abac_set_user_attribute('abac_alice', 'department', 'Math');

SELECT pg_temp.assert_true(
    abac_get_user_attribute('abac_alice', 'department') = 'Math',
    'attribute overwrite updates department to Math'
);

SET ROLE abac_alice;
SELECT COUNT(*) AS actual FROM abac_test_documents \gset
RESET ROLE;

SELECT pg_temp.assert_eq_bigint(
    :actual,
    1,
    'attribute overwrite affects RLS visibility immediately'
);

SELECT abac_set_user_attribute('abac_alice', 'department', 'CS');

/*
 * Final summary
 */
\echo 'All ABAC tests passed.'
