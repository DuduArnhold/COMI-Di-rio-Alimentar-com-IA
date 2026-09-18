#!/usr/bin/env bash
set -euo pipefail

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required to run database validation." >&2
  exit 1
fi

DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"

if [[ "${APPLY_MIGRATIONS:-0}" == "1" ]]; then
  for migration in supabase/migrations/*.sql; do
    echo "Applying ${migration}"
    psql "$DATABASE_URL" --set ON_ERROR_STOP=1 --file "$migration"
  done
fi

psql "$DATABASE_URL" --set ON_ERROR_STOP=1 --file supabase/tests/database_invariants.sql
