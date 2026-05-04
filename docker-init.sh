#!/bin/bash
set -e
cd /pg_abac
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f load_initial_project.sql
