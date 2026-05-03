-- Policy-complexity benchmark: instructor uses multiple rules and numeric comparison.
SET ROLE alice_cs;
SELECT COUNT(*) FROM instructor;
RESET ROLE;
