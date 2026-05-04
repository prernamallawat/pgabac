
\x auto
\pset border 2
\pset linestyle unicode
\pset format wrapped
\pset pager on

SELECT rolname FROM pg_roles;

\echo '1) Show metadata: user attributes'
SELECT * from abac_user_attributes;

\echo '2) Show rule table: multiple rules per table are OR-ed'
SELECT * from abac_rules;

\echo ') Show conditions: conditions within same rule_id are AND-ed'
SELECT r.table_name, r.rule_name, c.condition_order, c.column_name, c.user_attribute,
       c.operator, c.constant_value, c.value_type
FROM abac_rules r
JOIN abac_rule_conditions c ON c.rule_id = r.rule_id
ORDER BY r.table_name, r.rule_id, c.condition_order;

\echo '4) Admin baseline: all student departments in database'
RESET ROLE;
SELECT dept_name, COUNT(*) AS rows_visible
FROM student
GROUP BY dept_name
ORDER BY dept_name;

\echo '5) cs_user runs the SAME query. Expected: only Comp. Sci. students because department matches and status is active.'
SET ROLE cs_user;
SELECT dept_name, COUNT(*) AS rows_visible
FROM student
GROUP BY dept_name
ORDER BY dept_name;

\echo '6) bio_user runs the SAME query. Expected: only Biology students.'
RESET ROLE;
SET ROLE bio_user;
SELECT dept_name, COUNT(*) AS rows_visible
FROM student
GROUP BY dept_name
ORDER BY dept_name;

\echo '7) inactive_user has high clearance but inactive status. Expected: 0 student rows because active status is required.'
RESET ROLE;
SET ROLE inactive_user;
SELECT COUNT(*) AS inactive_student_rows_visible
FROM student;

\echo '8) registrar has high clearance and active status. Expected: all student departments visible through override rule.'
RESET ROLE;
SET ROLE registrar;
SELECT dept_name, COUNT(*) AS rows_visible
FROM student
GROUP BY dept_name
ORDER BY dept_name;

\echo '10) Instructor numeric operator test. Rule includes salary > user.salary_threshold AND status = active.'
\echo 'cs_user has salary_threshold = 70000. This demonstrates support for > operator.'
RESET ROLE;
SET ROLE cs_user;
SELECT MIN(salary) AS min_visible_salary, MAX(salary) AS max_visible_salary, COUNT(*) AS visible_instructors
FROM instructor;
SELECT ID, name, dept_name, salary
FROM instructor
ORDER BY salary DESC
LIMIT 10;

\echo 'Check course without ABAC'
RESET ROLE;
SELECT count(*) from course where credits >= 3 and dept_name = 'Comp. Sci.';

\echo 'Check course with ABAC (dept_name = Comp. Sci and credits >=3)'
RESET ROLE;
SET ROLE cs_user;
SELECT * from course;

-- ─────────────────────────────────────────────────────────────
\echo '11) LIKE operator — direct predicate tests'
-- ─────────────────────────────────────────────────────────────
RESET ROLE;

\echo '    abac_text_like: Comp. Sci. matches Comp% -> true'
SELECT abac_text_like('Comp. Sci.', 'Comp%') AS like_match;

\echo '    abac_text_like: Biology does not match Comp% -> false'
SELECT abac_text_like('Biology', 'Comp%') AS no_match;

\echo '    abac_text_not_like: Biology does not match Comp% -> true'
SELECT abac_text_not_like('Biology', 'Comp%') AS not_like_match;

\echo '    abac_compare_values with LIKE through the policy engine'
SELECT abac_compare_values('Comp. Sci.', 'LIKE', 'Comp%', 'text') AS engine_like;
SELECT abac_compare_values('Biology',    'NOT LIKE', 'Comp%', 'text') AS engine_not_like;

-- ─────────────────────────────────────────────────────────────
\echo '12) LIKE operator — live RLS rule using dept_name pattern'
\echo '    Give cs_user a dept_pattern attribute: Comp%'
\echo '    Add a LIKE rule on the department table and verify filtering.'
-- ─────────────────────────────────────────────────────────────
RESET ROLE;

-- Set a pattern attribute on cs_user
SELECT abac_set_user_attribute('cs_user', 'dept_pattern', 'Comp%');

-- Create a LIKE-based rule on the course table
SELECT abac_add_rule('course_dept_like', 'course', 'LIKE rule: dept_name matches user dept_pattern');
SELECT abac_add_condition('course_dept_like', 'dept_name', 'dept_pattern', 'LIKE');

-- Enable RLS on department (uses existing abac_course_select policy)
\echo '    cs_user queries courses — only dept_name matching Comp% visible via LIKE rule'
SET ROLE cs_user;
SELECT DISTINCT dept_name FROM course ORDER BY dept_name;

-- Clean up: remove the demo rule so it does not interfere with existing setup
RESET ROLE;
SELECT abac_disable_rule('course_dept_like');
\echo '    LIKE demo rule disabled. Setup rules restored.'





