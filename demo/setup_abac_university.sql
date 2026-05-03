\set ON_ERROR_STOP 1

CREATE EXTENSION IF NOT EXISTS pg_abac;

/* Demo roles */
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'alice_cs') THEN
        CREATE ROLE alice_cs LOGIN PASSWORD 'alice_cs';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bob_bio') THEN
        CREATE ROLE bob_bio LOGIN PASSWORD 'bob_bio';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'charlie_registrar') THEN
        CREATE ROLE charlie_registrar LOGIN PASSWORD 'charlie_registrar';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'eve_inactive') THEN
        CREATE ROLE eve_inactive LOGIN PASSWORD 'eve_inactive';
    END IF;
END $$;

GRANT USAGE ON SCHEMA public TO alice_cs, bob_bio, charlie_registrar, eve_inactive;
GRANT SELECT ON department, instructor, student, course, section, teaches, takes, advisor, prereq, classroom, time_slot TO alice_cs, bob_bio, charlie_registrar, eve_inactive;
GRANT SELECT ON abac_user_attributes, abac_rules, abac_rule_conditions, abac_policies TO alice_cs, bob_bio, charlie_registrar, eve_inactive;
GRANT EXECUTE ON FUNCTION abac_get_user_attribute(text, text) TO alice_cs, bob_bio, charlie_registrar, eve_inactive;
GRANT EXECUTE ON FUNCTION abac_check_access(text, jsonb) TO alice_cs, bob_bio, charlie_registrar, eve_inactive;
GRANT EXECUTE ON FUNCTION abac_compare_values(text, text, text, text) TO alice_cs, bob_bio, charlie_registrar, eve_inactive;

/* Subject attributes used by ABAC. */
SELECT abac_set_user_attribute('alice_cs', 'department', 'Comp. Sci.');
SELECT abac_set_user_attribute('alice_cs', 'status', 'active');
SELECT abac_set_user_attribute('alice_cs', 'clearance', 'normal');
SELECT abac_set_user_attribute('alice_cs', 'salary_threshold', '70000');

SELECT abac_set_user_attribute('bob_bio', 'department', 'Biology');
SELECT abac_set_user_attribute('bob_bio', 'status', 'active');
SELECT abac_set_user_attribute('bob_bio', 'clearance', 'normal');
SELECT abac_set_user_attribute('bob_bio', 'salary_threshold', '70000');

SELECT abac_set_user_attribute('charlie_registrar', 'department', 'Registrar');
SELECT abac_set_user_attribute('charlie_registrar', 'status', 'active');
SELECT abac_set_user_attribute('charlie_registrar', 'clearance', 'high');
SELECT abac_set_user_attribute('charlie_registrar', 'salary_threshold', '70000');

SELECT abac_set_user_attribute('eve_inactive', 'department', 'Comp. Sci.');
SELECT abac_set_user_attribute('eve_inactive', 'status', 'inactive');
SELECT abac_set_user_attribute('eve_inactive', 'clearance', 'high');
SELECT abac_set_user_attribute('eve_inactive', 'salary_threshold', '70000');

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
    abac_check_access('course', jsonb_build_object('dept_name', dept_name, 'credits', credits))
);

DROP POLICY IF EXISTS abac_instructor_select ON instructor;
CREATE POLICY abac_instructor_select
ON instructor
FOR SELECT
USING (
    abac_check_access('instructor', jsonb_build_object('dept_name', dept_name, 'salary', salary))
);

\echo 'ABAC setup complete: metadata rules loaded and RLS policies enabled.'
