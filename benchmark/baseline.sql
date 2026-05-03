-- Baseline: explicit WHERE condition, not RLS user-attribute based authorization.
SELECT COUNT(*) FROM student WHERE dept_name = 'Comp. Sci.';
