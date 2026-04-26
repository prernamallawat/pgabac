\set ON_ERROR_STOP 1

CREATE EXTENSION IF NOT EXISTS pg_abac;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'alice_cs') THEN
        CREATE ROLE alice_cs LOGIN PASSWORD 'alice_cs';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bob_bio') THEN
        CREATE ROLE bob_bio LOGIN PASSWORD 'bob_bio';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'eve_inactive') THEN
        CREATE ROLE eve_inactive LOGIN PASSWORD 'eve_inactive';
    END IF;
END $$;

GRANT USAGE ON SCHEMA public TO alice_cs, bob_bio, eve_inactive;
GRANT SELECT ON department, instructor, student, course, section, teaches, takes, advisor TO alice_cs, bob_bio, eve_inactive;
GRANT SELECT ON abac_user_attributes, abac_policies TO alice_cs, bob_bio, eve_inactive;

SELECT abac_set_user_attribute('alice_cs', 'department', 'Comp. Sci.');
SELECT abac_set_user_attribute('alice_cs', 'status', 'active');
SELECT abac_set_user_attribute('alice_cs', 'clearance', 'normal');

SELECT abac_set_user_attribute('bob_bio', 'department', 'Biology');
SELECT abac_set_user_attribute('bob_bio', 'status', 'active');
SELECT abac_set_user_attribute('bob_bio', 'clearance', 'normal');

SELECT abac_set_user_attribute('eve_inactive', 'department', 'Comp. Sci.');
SELECT abac_set_user_attribute('eve_inactive', 'status', 'inactive');
SELECT abac_set_user_attribute('eve_inactive', 'clearance', 'normal');

SELECT abac_add_policy('student_department_match', 'student', 'dept_name', 'department', '=', NULL);
SELECT abac_add_policy('student_active_users_only', 'student', NULL, 'status', '=', 'active');
SELECT abac_add_policy('course_department_match', 'course', 'dept_name', 'department', '=', NULL);
SELECT abac_add_policy('course_active_users_only', 'course', NULL, 'status', '=', 'active');
SELECT abac_add_policy('instructor_department_match', 'instructor', 'dept_name', 'department', '=', NULL);
SELECT abac_add_policy('instructor_active_users_only', 'instructor', NULL, 'status', '=', 'active');

ALTER TABLE student ENABLE ROW LEVEL SECURITY;
ALTER TABLE course ENABLE ROW LEVEL SECURITY;
ALTER TABLE instructor ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS abac_student_select ON student;
CREATE POLICY abac_student_select
ON student
FOR SELECT
USING (abac_check_text('student', 'dept_name', dept_name::text));

DROP POLICY IF EXISTS abac_course_select ON course;
CREATE POLICY abac_course_select
ON course
FOR SELECT
USING (abac_check_text('course', 'dept_name', dept_name::text));

DROP POLICY IF EXISTS abac_instructor_select ON instructor;
CREATE POLICY abac_instructor_select
ON instructor
FOR SELECT
USING (abac_check_text('instructor', 'dept_name', dept_name::text));
