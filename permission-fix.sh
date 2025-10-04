#!/usr/bin/env bash
set -euo pipefail

# Scripts should be owner-only exec/read
chmod 700 quickpg-build 2>/dev/null || true
chmod 700 permission-fix.sh 2>/dev/null || true
chmod 700 bin/pg-docker 2>/dev/null || true
chmod 700 db-utils/*.sh 2>/dev/null || true
chmod 700 ops/backup/*.sh 2>/dev/null || true

# SQL & config files (readable, not executable)
chmod 600 initdb/*.sql 2>/dev/null || true
chmod 600 docker/conf/*.conf 2>/dev/null || true

# Local env & secrets (owner read/write only)
chmod 600 .env.local 2>/dev/null || true
chmod 600 .secrets 2>/dev/null || true

# Logs & backups (owner read/write; dirs 700 if present)
[ -d logs ] && chmod -R u=rwX,go= logs || true
[ -d backups ] && chmod -R u=rwX,go= backups || true

exit 0
