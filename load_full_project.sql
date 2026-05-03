\set ON_ERROR_STOP 1
\echo 'Step 1: create or refresh extension'
DROP EXTENSION IF EXISTS pg_abac CASCADE;
CREATE EXTENSION pg_abac;

\echo 'Step 2: load complete University DB schema'
\i 'DDL+drop.sql'

\echo 'Step 3: load complete University DB data'
\i 'largeRelationsInsertFile.sql'

\echo 'Step 4: apply ABAC metadata, roles, rules, and RLS policies'
\i 'demo/setup_abac_university.sql'

\echo 'Full ABAC University project loaded successfully.'
