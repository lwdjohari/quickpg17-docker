#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/common.sh"
need DB_NAME
DB_NAME="$(get_secret DB_NAME)"
if [ -n "${PGURL-}" ]; then
  psql -v "ON_ERROR_STOP=1" "${PGURL}" -c "\connect :DB_NAME" -v "DB_NAME=${DB_NAME}" >/dev/null
  psql -v "ON_ERROR_STOP=1" "${PGURL}" -c "SELECT extname AS name, extversion AS version, extnamespace::regnamespace AS schema, extrelocatable AS relocatable FROM pg_extension ORDER BY 1;"
else
  psql -v "ON_ERROR_STOP=1" -c "\connect :DB_NAME" -v "DB_NAME=${DB_NAME}" >/dev/null
  psql -v "ON_ERROR_STOP=1" -c "SELECT extname AS name, extversion AS version, extnamespace::regnamespace AS schema, extrelocatable AS relocatable FROM pg_extension ORDER BY 1;"
fi
