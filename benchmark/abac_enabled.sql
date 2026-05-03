-- ABAC enabled: PostgreSQL RLS calls abac_check_access for current_user.
SET ROLE cs_user;
SELECT COUNT(*) FROM student;
RESET ROLE;
