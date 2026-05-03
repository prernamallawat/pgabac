\set ON_ERROR_STOP 1
\echo '========== ABAC PROJECT DEMO =========='

\echo ''
\echo '1) Show metadata: user attributes'
TABLE abac_user_attributes;

\echo ''
\echo '2) Show rule table: multiple rules per table are OR-ed'
SELECT rule_id, rule_name, table_name, is_enabled, description
FROM abac_rules
ORDER BY table_name, rule_id;

\echo ''
\echo '3) Show conditions: conditions within same rule_id are AND-ed'
SELECT r.table_name, r.rule_name, c.condition_order, c.column_name, c.user_attribute,
       c.operator, c.constant_value, c.value_type
FROM abac_rules r
JOIN abac_rule_conditions c ON c.rule_id = r.rule_id
ORDER BY r.table_name, r.rule_id, c.condition_order;

\echo ''
\echo '4) Admin baseline: all student departments in database'
RESET ROLE;
SELECT dept_name, COUNT(*) AS rows_visible
FROM student
GROUP BY dept_name
ORDER BY dept_name;

\echo ''
\echo '5) alice_cs runs the SAME query. Expected: only Comp. Sci. students because department matches and status is active.'
SET ROLE alice_cs;
SELECT dept_name, COUNT(*) AS rows_visible
FROM student
GROUP BY dept_name
ORDER BY dept_name;

\echo ''
\echo '6) bob_bio runs the SAME query. Expected: only Biology students.'
RESET ROLE;
SET ROLE bob_bio;
SELECT dept_name, COUNT(*) AS rows_visible
FROM student
GROUP BY dept_name
ORDER BY dept_name;

\echo ''
\echo '7) eve_inactive has high clearance but inactive status. Expected: 0 student rows because active status is required.'
RESET ROLE;
SET ROLE eve_inactive;
SELECT COUNT(*) AS eve_student_rows_visible
FROM student;

\echo ''
\echo '8) charlie_registrar has high clearance and active status. Expected: all student departments visible through override rule.'
RESET ROLE;
SET ROLE charlie_registrar;
SELECT dept_name, COUNT(*) AS rows_visible
FROM student
GROUP BY dept_name
ORDER BY dept_name;

\echo ''
\echo '9) Course policy test for alice_cs. Expected: Comp. Sci. courses only.'
RESET ROLE;
SET ROLE alice_cs;
SELECT dept_name, COUNT(*) AS rows_visible
FROM course
GROUP BY dept_name
ORDER BY dept_name;

\echo ''
\echo '10) Instructor numeric operator test. Rule includes salary > user.salary_threshold AND status = active.'
\echo 'alice_cs has salary_threshold = 70000. This demonstrates support for > operator.'
RESET ROLE;
SET ROLE alice_cs;
SELECT MIN(salary) AS min_visible_salary, MAX(salary) AS max_visible_salary, COUNT(*) AS visible_instructors
FROM instructor;
SELECT ID, name, dept_name, salary
FROM instructor
ORDER BY salary DESC
LIMIT 10;

\echo ''
\echo '11) Disable numeric salary rule to show rule-level control; alice_cs should lose instructor visibility because she does not have high clearance.'
RESET ROLE;
SELECT abac_disable_rule('instructor_salary_above_threshold_active');
SET ROLE alice_cs;
SELECT COUNT(*) AS visible_instructors_after_rule_disabled
FROM instructor;

\echo ''
\echo '12) Re-enable numeric salary rule for final state.'
RESET ROLE;
SELECT abac_enable_rule('instructor_salary_above_threshold_active');

\echo ''
\echo '========== DEMO COMPLETE =========='
