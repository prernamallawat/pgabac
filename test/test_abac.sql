\set ON_ERROR_STOP 1

\i demo/university_schema.sql
\i demo/setup_abac_university.sql

\echo 'Test 1: alice_cs should see only Comp. Sci. students'
SET ROLE alice_cs;
SELECT current_user AS user_name, ID, name, dept_name FROM student ORDER BY ID;
SELECT current_user AS user_name, course_id, title, dept_name FROM course ORDER BY course_id;
RESET ROLE;

\echo 'Test 2: bob_bio should see only Biology students/courses/instructors'
SET ROLE bob_bio;
SELECT current_user AS user_name, ID, name, dept_name FROM student ORDER BY ID;
SELECT current_user AS user_name, course_id, title, dept_name FROM course ORDER BY course_id;
RESET ROLE;

\echo 'Test 3: eve_inactive has matching department but inactive status, so she should see no protected rows'
SET ROLE eve_inactive;
SELECT current_user AS user_name, ID, name, dept_name FROM student ORDER BY ID;
SELECT current_user AS user_name, course_id, title, dept_name FROM course ORDER BY course_id;
RESET ROLE;

\echo 'Test 4: C helper predicate checks'
SELECT abac_text_equals('Comp. Sci.', 'Comp. Sci.') AS should_be_true;
SELECT abac_text_equals('Comp. Sci.', 'Biology') AS should_be_false;
SELECT abac_text_compare('active', '=', 'active') AS status_true;

\echo 'ABAC tests completed.'
