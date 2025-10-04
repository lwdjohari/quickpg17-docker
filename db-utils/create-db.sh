#!/usr/bin/env bash
# db-utils/create-db.sh

set -euo pipefail
. "$(dirname "$0")/common.sh"
need DB_NAME
DB_NAME="$(get_secret DB_NAME)"
prod_guard
psql_cmd "$(dirname "$0")/sql/create-db.sql" -v "DB_NAME=${DB_NAME}"
