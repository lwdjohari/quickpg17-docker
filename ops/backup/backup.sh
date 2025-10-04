#!/usr/bin/env sh
set -eu
STAMP="$(date -u +'%Y%m%dT%H%M%SZ')"
BASE="/backups/${APP_DB}-${STAMP}"
mkdir -p /backups
pg_dump -Fc -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$APP_DB" -f "${BASE}.dump"
pg_dump    -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$APP_DB" > "${BASE}.sql"
# keep 21 newest
ls -1t /backups/*.dump 2>/dev/null | sed -e '1,21d' | xargs -r rm -f
ls -1t /backups/*.sql  2>/dev/null | sed -e '1,21d' | xargs -r rm -f
