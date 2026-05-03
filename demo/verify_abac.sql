\set ON_ERROR_STOP 1
\echo 'Verify ABAC extension objects'
SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_abac';

\echo 'Verify rules and condition counts'
SELECT r.table_name, r.rule_name, COUNT(c.condition_id) AS and_conditions
FROM abac_rules r
LEFT JOIN abac_rule_conditions c ON c.rule_id = r.rule_id
GROUP BY r.table_name, r.rule_name
ORDER BY r.table_name, r.rule_name;

\echo 'Verify RLS policies'
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('student', 'course', 'instructor')
ORDER BY tablename;

\echo 'Verify role-specific row counts'
RESET ROLE;
SET ROLE alice_cs;
SELECT 'alice_cs student rows' AS test, COUNT(*) AS count FROM student;
RESET ROLE;
SET ROLE bob_bio;
SELECT 'bob_bio student rows' AS test, COUNT(*) AS count FROM student;
RESET ROLE;
SET ROLE eve_inactive;
SELECT 'eve_inactive student rows' AS test, COUNT(*) AS count FROM student;
RESET ROLE;
SET ROLE charlie_registrar;
SELECT 'charlie_registrar student rows' AS test, COUNT(*) AS count FROM student;
RESET ROLE;
