#!/usr/bin/env bash
# db-utils/create-role-dba.sh

set -euo pipefail
. "$(dirname "$0")/common.sh"
need DB_NAME; need DBA_USER; need DBA_PASSWORD
: "${SCHEMAS:=public}"
DB_NAME="$(get_secret DB_NAME)"
DBA_USER="$(get_secret DBA_USER)"
DBA_PASSWORD="$(get_secret DBA_PASSWORD)"
prod_guard
psql_cmd "$(dirname "$0")/sql/create-role-dba.sql" \
  -v "DB_NAME=${DB_NAME}" -v "DBA_USER=${DBA_USER}" -v "DBA_PASSWORD=${DBA_PASSWORD}" -v "SCHEMAS=${SCHEMAS}"
