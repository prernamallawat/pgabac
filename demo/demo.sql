
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

\echo 'LIKE operator on building'
RESET ROLE;
select * from classroom where building like '%Ga%';

RESET ROLE;
SET ROLE registrar;
SELECT * from classroom;



