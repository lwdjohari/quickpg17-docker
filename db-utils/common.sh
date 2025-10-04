#!/usr/bin/env bash
# db-utils/common.sh

set -euo pipefail
: "${ENVIRONMENT:=dev}"          # dev|staging|prod
: "${BOOTSTRAP_ENABLE:=false}"   # must be true to apply
: "${BOOTSTRAP_DRY_RUN:=false}"  # true => print & exit

get_secret(){ local v="$1" f="${1}_FILE"; if [ -n "${!f-}" ]; then cat "${!f}"; else printf '%s' "${!v-}"; fi; }
need(){ [ -n "${!1-}" ] || { echo "Missing $1 (or ${1}_FILE)"; exit 2; }; }

psql_cmd(){ local sql="$1"; shift; local args=(-v "ON_ERROR_STOP=1" "$@" -f "$sql"); if [ -n "${PGURL-}" ]; then psql "${args[@]}" "${PGURL}"; else psql "${args[@]}"; fi; }

prod_guard(){
  echo "[db-utils] env=${ENVIRONMENT} enable=${BOOTSTRAP_ENABLE} dry=${BOOTSTRAP_DRY_RUN}"
  if [ "${ENVIRONMENT}" = "prod" ] && [ "${BOOTSTRAP_ENABLE}" != "true" ]; then
    echo "[db-utils] In prod with BOOTSTRAP_ENABLE=false → refusing."; exit 0
  fi
  if [ "${BOOTSTRAP_DRY_RUN}" = "true" ]; then
    echo "[db-utils] DRY RUN — no changes."; exit 0
  fi
}
