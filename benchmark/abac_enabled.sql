-- ABAC enabled: PostgreSQL RLS calls abac_check_access for current_user.
SET ROLE alice_cs;
SELECT COUNT(*) FROM student;
RESET ROLE;
