\set ON_ERROR_STOP 1

CREATE EXTENSION IF NOT EXISTS pg_abac;

/* Demo roles */
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cs_user') THEN
        CREATE ROLE cs_user LOGIN PASSWORD 'cs_user';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bio_user') THEN
        CREATE ROLE bio_user LOGIN PASSWORD 'bio_user';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'registrar') THEN
        CREATE ROLE registrar LOGIN PASSWORD 'registrar';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'inactive_user') THEN
        CREATE ROLE inactive_user LOGIN PASSWORD 'inactive_user';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'title_user') THEN
        CREATE ROLE title_user LOGIN PASSWORD 'title_user';
    END IF;
END $$;

GRANT USAGE ON SCHEMA public TO cs_user, bio_user, registrar, inactive_user, title_user;
GRANT SELECT ON department, instructor, student, course, section, teaches, takes, advisor, prereq, classroom, time_slot TO cs_user, bio_user, registrar, inactive_user, title_user;
GRANT SELECT ON abac_user_attributes, abac_rules, abac_rule_conditions, abac_policies TO cs_user, bio_user, registrar, inactive_user, title_user;
GRANT EXECUTE ON FUNCTION abac_get_user_attribute(text, text) TO cs_user, bio_user, registrar, inactive_user, title_user;
GRANT EXECUTE ON FUNCTION abac_check_access(text, jsonb) TO cs_user, bio_user, registrar, inactive_user, title_user;
GRANT EXECUTE ON FUNCTION abac_compare_values(text, text, text, text) TO cs_user, bio_user, registrar, inactive_user, title_user;

/* Subject attributes used by ABAC. */
SELECT abac_set_user_attribute('cs_user', 'department', 'Comp. Sci.');
SELECT abac_set_user_attribute('cs_user', 'status', 'active');
SELECT abac_set_user_attribute('cs_user', 'clearance', 'normal');
SELECT abac_set_user_attribute('cs_user', 'salary_threshold', '70000');
SELECT abac_set_user_attribute('cs_user', 'credits', '3');

SELECT abac_set_user_attribute('bio_user', 'department', 'Biology');
SELECT abac_set_user_attribute('bio_user', 'status', 'active');
SELECT abac_set_user_attribute('bio_user', 'clearance', 'normal');
SELECT abac_set_user_attribute('bio_user', 'salary_threshold', '70000');

SELECT abac_set_user_attribute('registrar', 'department', 'Registrar');
SELECT abac_set_user_attribute('registrar', 'status', 'active');
SELECT abac_set_user_attribute('registrar', 'clearance', 'high');
SELECT abac_set_user_attribute('registrar', 'salary_threshold', '70000');

SELECT abac_set_user_attribute('inactive_user', 'department', 'Comp. Sci.');
SELECT abac_set_user_attribute('inactive_user', 'status', 'inactive');
SELECT abac_set_user_attribute('inactive_user', 'clearance', 'high');
SELECT abac_set_user_attribute('inactive_user', 'salary_threshold', '70000');

/* title_user: ONLY has a title pattern — no dept, no status, no clearance.
   This ensures access is granted exclusively through the LIKE rule on course.title. */
SELECT abac_set_user_attribute('title_user', 'title_pattern', '%Systems%');

/* Reset rules so this script can be rerun. */
DELETE FROM abac_rules;

/*
 * STUDENT rules:
 * Rule 1: normal department user. AND conditions: same dept AND active.
 * Rule 2: registrar/high-clearance override. AND conditions: clearance high AND active.
 * Multiple rules on the same table are OR-ed by abac_check_access.
 */
SELECT abac_add_rule('student_dept_active', 'student', 'Students visible when row dept matches user department and user is active');
SELECT abac_add_condition('student_dept_active', 'dept_name', 'department', '=', NULL, 'text', 1);
SELECT abac_add_condition('student_dept_active', NULL, 'status', '=', 'active', 'text', 2);

SELECT abac_add_rule('student_high_clearance_active', 'student', 'High-clearance active users can see all student rows');
SELECT abac_add_condition('student_high_clearance_active', NULL, 'clearance', '=', 'high', 'text', 1);
SELECT abac_add_condition('student_high_clearance_active', NULL, 'status', '=', 'active', 'text', 2);

/* COURSE rules */
SELECT abac_add_rule('course_dept_active', 'course', 'Courses visible when row dept matches user department and user is active');
SELECT abac_add_condition('course_dept_active', 'dept_name', 'department', '=', NULL, 'text', 1);
SELECT abac_add_condition('course_dept_active', NULL, 'status', '=', 'active', 'text', 2);

SELECT abac_add_rule('course_high_clearance_active', 'course', 'High-clearance active users can see all courses');
SELECT abac_add_condition('course_high_clearance_active', NULL, 'clearance', '=', 'high', 'text', 1);
SELECT abac_add_condition('course_high_clearance_active', NULL, 'status', '=', 'active', 'text', 2);

SELECT abac_add_rule('course_credit', 'course', 'Courses visible when row dept matches user department and credit is >= 3');
SELECT abac_add_condition('course_credit', 'dept_name', 'department', '=', NULL, 'text', 1);
SELECT abac_add_condition('course_credit', 'credits', 'credits', '>=', NULL, 'text', 2);

/* LIKE rule: grants access based on course title matching a user-defined pattern.
   title_user has title_pattern = '%Systems%' so they see only courses with Systems in the title.
   No other rules apply to title_user, making this a pure LIKE demonstration. */
SELECT abac_add_rule('course_title_like', 'course', 'LIKE rule: course title matches user title_pattern attribute');
SELECT abac_add_condition('course_title_like', 'title', 'title_pattern', 'LIKE', NULL, 'text', 1);

/*
 * INSTRUCTOR rules:
 * Rule 1: sensitive table requiring dept match, active status, and high clearance.
 * Rule 2: numeric comparison demo requested by professor: row salary > user.salary_threshold.
 */
SELECT abac_add_rule('instructor_dept_active_high_clearance', 'instructor', 'Instructor rows require same department, active status, and high clearance');
SELECT abac_add_condition('instructor_dept_active_high_clearance', 'dept_name', 'department', '=', NULL, 'text', 1);
SELECT abac_add_condition('instructor_dept_active_high_clearance', NULL, 'status', '=', 'active', 'text', 2);
SELECT abac_add_condition('instructor_dept_active_high_clearance', NULL, 'clearance', '=', 'high', 'text', 3);

SELECT abac_add_rule('instructor_salary_above_threshold_active', 'instructor', 'Numeric operator demo: instructor.salary > user.salary_threshold, only for active users');
SELECT abac_add_condition('instructor_salary_above_threshold_active', 'salary', 'salary_threshold', '>', NULL, 'numeric', 1);
SELECT abac_add_condition('instructor_salary_above_threshold_active', NULL, 'status', '=', 'active', 'text', 2);

ALTER TABLE student ENABLE ROW LEVEL SECURITY;
ALTER TABLE course ENABLE ROW LEVEL SECURITY;
ALTER TABLE instructor ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS abac_student_select ON student;
CREATE POLICY abac_student_select
ON student
FOR SELECT
USING (
    abac_check_access('student', jsonb_build_object('dept_name', dept_name))
);

DROP POLICY IF EXISTS abac_course_select ON course;
CREATE POLICY abac_course_select
ON course
FOR SELECT
USING (
    abac_check_access('course', jsonb_build_object('dept_name', dept_name, 'credits', credits, 'title', title))
);

DROP POLICY IF EXISTS abac_instructor_select ON instructor;
CREATE POLICY abac_instructor_select
ON instructor
FOR SELECT
USING (
    abac_check_access('instructor', jsonb_build_object('dept_name', dept_name, 'salary', salary))
);

\echo 'ABAC setup complete: metadata rules loaded and RLS policies enabled.'
