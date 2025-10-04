#!/usr/bin/env bash
# db-utils/add-ext.sh

set -euo pipefail
. "$(dirname "$0")/common.sh"
need DB_NAME; need EXTENSIONS
DB_NAME="$(get_secret DB_NAME)"
EXTENSIONS="$(get_secret EXTENSIONS)"   # "postgis,pgvector,pg_partman:partman,pg_cron"
: "${REQUIRE_PRELOAD:=false}"
prod_guard
psql_cmd "$(dirname "$0")/sql/add-ext-sql" \
  -v "DB_NAME=${DB_NAME}" -v "EXTENSIONS=${EXTENSIONS}" -v "REQUIRE_PRELOAD=${REQUIRE_PRELOAD}"
