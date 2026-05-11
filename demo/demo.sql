\x auto
\pset border 2
\pset linestyle unicode
\pset format wrapped
\pset pager on

\echo 'ABAC PostgreSQL Extension Demo'

\echo '1) Show metadata: user attributes'
SELECT username, attribute_name, attribute_value
FROM abac_user_attributes LIMIT 10;

\echo '2) Show rule table: multiple rules per table are OR-ed'
SELECT rule_id, rule_name, table_name, description, created_at
FROM abac_rules;

\echo '3) Show conditions: conditions within the same rule_id are AND-ed'
SELECT
    r.table_name,
    r.rule_name,
    c.condition_order,
    c.column_name,
    c.user_attribute,
    c.operator,
    c.constant_value,
    c.value_type
FROM abac_rules r
JOIN abac_rule_conditions c
    ON c.rule_id = r.rule_id;

\echo '4) Admin baseline: all student departments in database'
RESET ROLE;

SELECT dept_name, COUNT(*) AS rows_visible
FROM student
GROUP BY dept_name
ORDER BY dept_name;

\echo '5) cs_user runs the SAME query. Expected: only Comp. Sci. students because department matches and status is active.'
RESET ROLE;
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

\echo '9) Course baseline as admin: Comp. Sci. courses with credits >= 3'
RESET ROLE;

SELECT course_id, title, dept_name, credits
FROM course;

\echo '10) Course with ABAC as cs_user. Same query. Expected: Comp. Sci. courses with credits >= 3.'
RESET ROLE;
SET ROLE cs_user;

SELECT course_id, title, dept_name, credits
FROM course;

\echo '11) Course with ABAC as bio_user. Same query. Expected: 0 rows because bio_user cannot see Comp. Sci. courses.'
RESET ROLE;
SET ROLE bio_user;

SELECT course_id, title, dept_name, credits
FROM course;

\echo '12) Instructor numeric operator test. Rule includes salary > user.salary_threshold AND status = active.'
\echo 'cs_user has salary_threshold = 70000. This demonstrates support for the > operator.'
RESET ROLE;
SET ROLE cs_user;

SELECT
    MIN(salary) AS min_visible_salary,
    MAX(salary) AS max_visible_salary,
    COUNT(*) AS visible_instructors
FROM instructor;

SELECT ID, name, dept_name, salary
FROM instructor
ORDER BY salary DESC
LIMIT 10;

\echo '13) Classroom baseline as admin: buildings matching LIKE pattern %Ga%'
RESET ROLE;

SELECT building, room_number, capacity
FROM classroom
WHERE building LIKE '%Ga%'
ORDER BY building, room_number;

\echo '14) Classroom with ABAC as registrar. Expected: registrar sees classroom rows allowed by ABAC rules.'
RESET ROLE;
SET ROLE registrar;

SELECT building, room_number, capacity
FROM classroom
ORDER BY building, room_number;

RESET ROLE;

\echo 'ABAC demo completed.'
