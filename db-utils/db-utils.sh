#!/usr/bin/env bash
# db-utils/db-utils.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cmd="${1-}"; shift || true
case "${cmd}" in
  create-db)   DB_NAME="${1:?DB_NAME required}"; ENVIRONMENT="${ENVIRONMENT:-dev}" BOOTSTRAP_ENABLE="${BOOTSTRAP_ENABLE:-true}" DB_NAME="${DB_NAME}" "${ROOT}/create-db.sh" ;;
  create-dba)  DB_NAME="${1:?DB_NAME}"; DBA="${2:?DBA_USER}"; PASS="${3:?DBA_PASSWORD}"; ENVIRONMENT="${ENVIRONMENT:-dev}" BOOTSTRAP_ENABLE=true DB_NAME="${DB_NAME}" DBA_USER="${DBA}" DBA_PASSWORD="${PASS}" "${ROOT}/create-role-dba.sh" ;;
  create-rw)   DB_NAME="${1:?DB_NAME}"; RW="${2:?RW_USER}"; PASS="${3:?RW_PASSWORD}"; ENVIRONMENT="${ENVIRONMENT:-dev}" BOOTSTRAP_ENABLE=true DB_NAME="${DB_NAME}" RW_USER="${RW}"  RW_PASSWORD="${PASS}" "${ROOT}/create-role-rw.sh" ;;
  create-ro)   DB_NAME="${1:?DB_NAME}"; RO="${2:?RO_USER}"; PASS="${3:?RO_PASSWORD}"; ENVIRONMENT="${ENVIRONMENT:-dev}" BOOTSTRAP_ENABLE=true DB_NAME="${DB_NAME}" RO_USER="${RO}"  RO_PASSWORD="${PASS}" "${ROOT}/create-role-ro.sh" ;;
  add-ext)     DB_NAME="${1:?DB_NAME}"; EXTS="${2:?extensions,csv}"; ENVIRONMENT="${ENVIRONMENT:-dev}" BOOTSTRAP_ENABLE=true DB_NAME="${DB_NAME}" EXTENSIONS="${EXTS}" "${ROOT}/add-ext.sh" ;;
  drop-ext)    DB_NAME="${1:?DB_NAME}"; EXTS="${2:?extensions,csv}"; ENVIRONMENT="${ENVIRONMENT:-dev}" BOOTSTRAP_ENABLE=true DB_NAME="${DB_NAME}" EXTENSIONS="${EXTS}" "${ROOT}/drop-ext.sh" ;;
  list-ext)    DB_NAME="${1:?DB_NAME}"; DB_NAME="${DB_NAME}" "${ROOT}/list-ext.sh" ;;
  *) cat <<'EOF'
Usage:
  dbutil.sh create-db <db>
  dbutil.sh create-dba <db> <DBA_USER> <DBA_PASSWORD>
  dbutil.sh create-rw  <db> <RW_USER>  <RW_PASSWORD>
  dbutil.sh create-ro  <db> <RO_USER>  <RO_PASSWORD>
  dbutil.sh add-ext    <db> "postgis,pgvector,pg_partman:partman,pg_cron"
  dbutil.sh drop-ext   <db> "pg_cron"
  dbutil.sh list-ext   <db>
EOF
  ;;
esac
