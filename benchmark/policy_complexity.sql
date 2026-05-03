-- Policy-complexity benchmark: instructor uses multiple rules and numeric comparison.
SET ROLE cs_user;
SELECT COUNT(*) FROM instructor;
RESET ROLE;
