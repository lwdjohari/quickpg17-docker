#!/usr/bin/env bash
# db-utils/create-role-ro.sh

set -euo pipefail
. "$(dirname "$0")/common.sh"
need DB_NAME; need RO_USER; need RO_PASSWORD
: "${SCHEMAS:=public}"
DB_NAME="$(get_secret DB_NAME)"
RO_USER="$(get_secret RO_USER)"
RO_PASSWORD="$(get_secret RO_PASSWORD)"
prod_guard
psql_cmd "$(dirname "$0")/sql/create-role-ro.sql" \
  -v "DB_NAME=${DB_NAME}" -v "RO_USER=${RO_USER}" -v "RO_PASSWORD=${RO_PASSWORD}" -v "SCHEMAS=${SCHEMAS}"
