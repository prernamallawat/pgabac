\set ON_ERROR_STOP 1

\i demo/university_schema.sql
\i demo/setup_abac_university.sql

\echo 'Test 1: cs_user should see only Comp. Sci. students'
SET ROLE cs_user;
SELECT current_user AS user_name, ID, name, dept_name FROM student ORDER BY ID;
SELECT current_user AS user_name, course_id, title, dept_name FROM course ORDER BY course_id;
RESET ROLE;

\echo 'Test 2: bio_user should see only Biology students/courses/instructors'
SET ROLE bio_user;
SELECT current_user AS user_name, ID, name, dept_name FROM student ORDER BY ID;
SELECT current_user AS user_name, course_id, title, dept_name FROM course ORDER BY course_id;
RESET ROLE;

\echo 'Test 3: inactive_user has matching department but inactive status, so she should see no protected rows'
SET ROLE inactive_user;
SELECT current_user AS user_name, ID, name, dept_name FROM student ORDER BY ID;
SELECT current_user AS user_name, course_id, title, dept_name FROM course ORDER BY course_id;
RESET ROLE;

\echo 'Test 4: C helper predicate checks'
SELECT abac_text_equals('Comp. Sci.', 'Comp. Sci.') AS should_be_true;
SELECT abac_text_equals('Comp. Sci.', 'Biology') AS should_be_false;
SELECT abac_text_compare('active', '=', 'active') AS status_true;

\echo 'ABAC tests completed.'
