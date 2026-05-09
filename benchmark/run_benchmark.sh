#!/bin/bash
set -e

DB_NAME="${1:-university_abac}"
PGUSER_ADMIN="${PGUSER_ADMIN:-postgres}"
DURATION="${DURATION:-30}"
CLIENTS="${CLIENTS:-5}"
JOBS="${JOBS:-2}"

RESULT_DIR="benchmark/results"
mkdir -p "$RESULT_DIR"

echo "Database: $DB_NAME"
echo "Duration: ${DURATION}s"
echo "Clients: $CLIENTS"
echo "Jobs: $JOBS"
echo

echo "Step 1: Preparing benchmark schema and data..."
psql -U "$PGUSER_ADMIN" -d "$DB_NAME" -f benchmark/01_setup.sql

echo
echo "Step 2: Running baseline benchmark without ABAC/RLS..."
pgbench \
  -U "$PGUSER_ADMIN" \
  -d "$DB_NAME" \
  -n \
  -M prepared \
  -f benchmark/baseline_select.sql \
  -c "$CLIENTS" \
  -j "$JOBS" \
  -T "$DURATION" \
  | tee "$RESULT_DIR/baseline.txt"

echo
echo "Step 3: Running ABAC benchmark with simple department/region/status rule..."

psql -U "$PGUSER_ADMIN" -d "$DB_NAME" <<SQL
SELECT abac_enable_rule('bench_docs_dept_region_active');
SELECT abac_disable_rule('bench_docs_high_clearance_active');
SELECT abac_disable_rule('bench_docs_amount_under_limit_active');
SQL

pgbench \
  -U bench_cs_user \
  -d "$DB_NAME" \
  -n \
  -M prepared \
  -f benchmark/abac_select.sql \
  -c "$CLIENTS" \
  -j "$JOBS" \
  -T "$DURATION" \
  | tee "$RESULT_DIR/abac_simple.txt"

echo
echo "Step 4: Running ABAC benchmark with multiple enabled rules..."

psql -U "$PGUSER_ADMIN" -d "$DB_NAME" <<SQL
SELECT abac_enable_rule('bench_docs_dept_region_active');
SELECT abac_enable_rule('bench_docs_high_clearance_active');
SELECT abac_enable_rule('bench_docs_amount_under_limit_active');
SQL

pgbench \
  -U bench_cs_user \
  -d "$DB_NAME" \
  -n \
  -M prepared \
  -f benchmark/policy_complexity.sql \
  -c "$CLIENTS" \
  -j "$JOBS" \
  -T "$DURATION" \
  | tee "$RESULT_DIR/abac_complex.txt"

echo
echo "Step 5: Benchmark files written to $RESULT_DIR"
echo
echo "Review:"
echo "  $RESULT_DIR/baseline.txt"
echo "  $RESULT_DIR/abac_simple.txt"
echo "  $RESULT_DIR/abac_complex.txt"
echo
echo "Use TPS and average latency from these files in README.md."