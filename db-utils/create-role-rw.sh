#!/usr/bin/env bash
# db-utils/create-role-rw.sh

set -euo pipefail
. "$(dirname "$0")/common.sh"
need DB_NAME; need RW_USER; need RW_PASSWORD
: "${SCHEMAS:=public}"
DB_NAME="$(get_secret DB_NAME)"
RW_USER="$(get_secret RW_USER)"
RW_PASSWORD="$(get_secret RW_PASSWORD)"
prod_guard
psql_cmd "$(dirname "$0")/sql/create-role-rw.sql" \
  -v "DB_NAME=${DB_NAME}" -v "RW_USER=${RW_USER}" -v "RW_PASSWORD=${RW_PASSWORD}" -v "SCHEAS=${SCHEMAS}" -v "SCHEMAS=${SCHEMAS}"
