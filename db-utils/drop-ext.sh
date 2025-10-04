#!/usr/bin/env bash
# db-utils/drop-ext.sh

set -euo pipefail
. "$(dirname "$0")/common.sh"
need DB_NAME; need EXTENSIONS
DB_NAME="$(get_secret DB_NAME)"
EXTENSIONS="$(get_secret EXTENSIONS)"   # "pg_cron,pg_partman"
: "${DROP_CASCADE:=false}"
: "${DANGEROUS_OK:=false}"
prod_guard
psql_cmd "$(dirname "$0")/sql/drop-ext.sql" \
  -v "DB_NAME=${DB_NAME}" -v "EXTENSIONS=${EXTENSIONS}" \
  -v "DROP_CASCADE=${DROP_CASCADE}" -v "DANGEROUS_OK=${DANGEROUS_OK}"
