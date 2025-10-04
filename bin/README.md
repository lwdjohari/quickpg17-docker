# pg-docker CLI for quickpg Docker Stack

**PostGIS • TimescaleDB • pgvector • Partman • Cron • Repack**

This is a **production-grade** Postgres 17 stack designed so **no one edits `docker-compose.yml`**.  
Everything is controlled by **env files** and a **single CLI**: `bin/pg-docker`.

---

## 🔑 What’s new in this edition

- **Ops command suite** under `ops:*` (health, stats, vacuum/analyze, reindex, repack, connections, WAL, backup/restore, cron, timescale, partman).
- Every ops command **prompts for DB username + hidden password** (never echoed, never stored, never in process args).
- **Risk-gated commands**: disruptive/destructive operations print a clear risk summary and **require typing `YES`** to continue.
- **Sudo-aware**: add `--sudo-docker` (and optional `--sudo-presupply`) to run all Docker/Compose commands with sudo.
- **Create-role commands** prompt for passwords **hidden and confirmed twice** (no plaintext on CLI).

---

## 🧩 Features

- **PostgreSQL 17** with common production extensions:
  - PostGIS (core, topology, raster), TimescaleDB 2.x, pgvector, pg_partman, pg_cron, pg_repack
  - pg_stat_statements, pg_stat_kcache, pg_buffercache, pgstattuple, pgcrypto, hstore, pg_trgm, unaccent, hypopg
- **Compose-immutable**: all behavior via `.env` / `.env.local` + `bin/pg-docker`.
- **Configurable host↔container volumes** (data, logs, backups, config, initdb).
- **Optional backup sidecar** (cron-based snapshots, retention).
- **db-utils baked-in or attachable** at runtime (no compose edits).

---

## 📦 Requirements

- Docker (Engine) and **Docker Compose v2** (`docker compose`).
- Linux/macOS/WSL. (Windows Powershell/Command Prompt is not supported; use WSL.)

---

## 🚀 Quick Start

```bash
# 0) Clone & enter repo
cp .env.example .env

# 1) Put only your real secrets/overrides here:
$EDITOR .env.local
# at minimum set:
# POSTGRES_SUPERUSER_PASSWORD=change_me

# 2) Start (add --sudo-docker if docker needs sudo on your host)
./bin/pg-docker up
# or
./bin/pg-docker --sudo-docker up

# 3) psql as postgres into $APP_DB
./bin/pg-docker psql
```

### Optional: enable backups (no compose edits)

```bash
echo "BACKUP_ENABLED=true" >> .env.local
./bin/pg-docker restart
```

---

## ⚙️ Configuration (env)

Create `.env` from `.env.example` and override safely in `.env.local` (git-ignored).

### Core

| Variable | Meaning | Example |
| --- | --- | --- |
| `PROJECT_NAME` | Compose project/container name | `pg17` |
| `PG_PORT` | Host port → container 5432 | `5432` |
| `TZ` | Timezone | `Asia/Jakarta` |
| `POSTGRES_SUPERUSER_PASSWORD` | password for `postgres` | `strong_pw` |
| `APP_DB` | Default DB created on first boot | `appdb` |

### Default roles (created by init scripts; rotate as needed)

| Variable | Meaning |
| --- | --- |
| `DBA_USER`, `DBA_PASSWORD` | Owner-level role for app DB |
| `RW_USER`, `RW_PASSWORD` | Read/Write role |
| `RO_USER`, `RO_PASSWORD` | Read-Only role |

### Volume mapping (host ↔ container)

| Host Var | Default | Container Var | Default | Purpose |
| --- | --- | --- | --- | --- |
| `HOST_DATA_DIR` | `./data` | `CONTAINER_DATA_DIR` | `/var/lib/postgresql/data` | PGDATA (tables, WAL) |
| `HOST_LOG_DIR` | `./logs` | `CONTAINER_LOG_DIR` | `/var/log/postgresql` | DB logs |
| `HOST_BACKUP_DIR` | `./backups` | `CONTAINER_BACKUP_DIR` | `/backups` | Dumps (sidecar + on-demand) |
| `HOST_CONF_DIR` | `./docker/conf` | `CONTAINER_CONF_DIR` | `/etc/postgresql` | Config files |
| `HOST_INITDB_DIR` | `./initdb` | `CONTAINER_INITDB_DIR` | `/docker-entrypoint-initdb.d` | First-boot scripts |

### Build target (db-utils in image or not)

| Var | Values | Effect |
| --- | --- | --- |
| `DBUTILS_BUILD_TARGET` | `core_dbutils` (default) \\| `core` | Include `/opt/db-utils` and `dbutil` in image, or build minimal and **attach later** |

---

## 🛠 CLI Overview (`bin/pg-docker`)

All commands accept **flags anywhere**:

- `--sudo-docker` : run Docker/Compose via `sudo`
- `--sudo-presupply` : prompt for sudo password (hidden + twice) and cache with `sudo -v`

### Lifecycle

```bash
./bin/pg-docker up            # start
./bin/pg-docker up:rebuild    # rebuild image & start
./bin/pg-docker down|stop|restart|status|logs
./bin/pg-docker shell         # bash into container
./bin/pg-docker psql          # psql as postgres into $APP_DB
```

### Postgres Utilities (no plaintext passwords on CLI)

```bash
./bin/pg-docker create-db <db>

./bin/pg-docker create-dba <db> <user>   # prompts hidden, confirm twice
./bin/pg-docker create-rw  <db> <user>   # prompts hidden, confirm twice
./bin/pg-docker create-ro  <db> <user>   # prompts hidden, confirm twice

./bin/pg-docker add-ext  <db> "postgis,pgvector,pg_partman:partman,pg_cron"
./bin/pg-docker drop-ext <db> "pg_cron"
./bin/pg-docker list-ext <db>

./bin/pg-docker dbutils:present
./bin/pg-docker dbutils:attach          # copies ./db-utils into live container if needed
```

> Password prompts use `/dev/tty` so input is hidden even when piping/redirecting. Nothing is stored.

---

## 🧪 Postgres Ops Suite (fool-proof)

Every `ops:*` command prompts for **DB username** and **hidden password**.  
Commands that can disrupt workloads or change data will **print a risk summary** and require you to **type `YES`** before execution.

### Health & Stats

```bash
./bin/pg-docker ops:health <db>
# Checks connectivity and basic queries.

./bin/pg-docker ops:stats:top <db> [N]
# Top N queries from pg_stat_statements.

./bin/pg-docker ops:stats:reset <db>     # consent required
# Resets accumulated query stats (irreversible for the current window).
```

### Maintenance

```bash
./bin/pg-docker ops:analyze <db> [schema.table]         # consent required
./bin/pg-docker ops:vacuum:analyze <db> [schema.table]  # consent required
./bin/pg-docker ops:reindex <db> <schema|schema.table>  # consent required
./bin/pg-docker ops:repack <db> <schema.table>          # consent required
./bin/pg-docker ops:bloat:estimate <db> <schema.table>
```

- **ANALYZE**: safe; IO/CPU heavy on large DBs.
- **VACUUM (ANALYZE)**: safe; may briefly lock catalogs.
- **REINDEX**: acquires locks; run off-hours.
- **pg_repack**: online reorg; brief locks at start/end; ensure extension/binary present.
- **pgstattuple**: estimation only; safe.

### Connections & WAL

```bash
./bin/pg-docker ops:conn:list <db>
./bin/pg-docker ops:kill:idle <db> <minutes>   # consent required
./bin/pg-docker ops:wal:switch <db>            # consent required
```

- **kill:idle**: terminates idle backends; may interrupt users.
- **wal:switch**: forces a new WAL; can spike replication/archival traffic.

### Backups & Restore

```bash
./bin/pg-docker ops:backup:now <db>            # consent required
# Produces ${HOST_BACKUP_DIR}/${db}-YYYYmmddTHHMMSSZ.dump

./bin/pg-docker ops:restore:file <db> <host_path|filename>  # consent required
# Restores .dump (pg_restore --clean --if-exists) or .sql into <db>.
```

- Always test restores regularly.
- Restoring can **drop/recreate** objects; run off-hours with consent.

### Cron (pg_cron)

```bash
./bin/pg-docker ops:cron:list <db>
./bin/pg-docker ops:cron:add <db> '<name>' '<sched>' '<sql>'   # consent
./bin/pg-docker ops:cron:remove <db> <jobid>                   # consent
```

### TimescaleDB

```bash
./bin/pg-docker ops:timescale:jobs <db>
./bin/pg-docker ops:timescale:policy:compress  <db> <table> <interval>  # consent
./bin/pg-docker ops:timescale:policy:retention <db> <table> <interval>  # consent (DATA LOSS beyond window)
./bin/pg-docker ops:timescale:compress-now     <db> <table>             # consent
```

### Partman

```bash
./bin/pg-docker ops:partman:run <db>           # consent
# Runs partman maintenance; may create/lock partitions briefly.
```

---

## 🔒 Security Defaults

- Remote superuser (`postgres`) blocked in `pg_hba.conf` by default. Use DBA/RW/RO roles.
- SCRAM-SHA-256 auth.
- Least-privilege roles by design.
- Supports the standard `*_FILE` secrets pattern if you adopt it.
- TLS is optional: mount certs and enable in `initdb/99_hardening.sh` + `pg_hba.conf` `hostssl` entries.

---

## 🔄 Backups

- Sidecar cron (if `BACKUP_ENABLED=true`) dumps daily at 03:15 UTC with retention.
- On-demand backups via `ops:backup:now`.
- Restores via `ops:restore:file` (consent required).

**Always** run periodic restore tests in a throwaway DB.

---

## 🧱 Volumes (host ↔ container)

Verify mounts:

```bash
docker inspect ${PROJECT_NAME:-pg17} --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{printf "\n"}}{{end}}'
```

Move to another disk by changing `HOST_*_DIR` in `.env.local` (or use symlinks).  
On SELinux systems, label dirs with:  
`sudo chcon -Rt svirt_sandbox_file_t "$HOST_DATA_DIR" "$HOST_LOG_DIR" "$HOST_BACKUP_DIR"`.

---

## 🧯 Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Can’t start: init loop | `POSTGRES_SUPERUSER_PASSWORD` missing | Set in `.env.local`; if first init failed, wipe data dir and re-init |
| Extensions “missing” | Started with existing data dir | Use `add-ext` to install into DB; init scripts run only on first boot |
| No backups | Sidecar disabled | `echo BACKUP_ENABLED=true >> .env.local && ./bin/pg-docker restart` |
| Permission denied on data dir | Host perms/SELinux | `chmod 700 data/`; apply `chcon` on SELinux |
| “Why did X change?” | Someone ran a risky op | Risk-gated ops require consent; check command history and ops logs |

---

## ❓FAQ

**Why do ops commands ask for my DB username/password?**  
So we can audit privileges and avoid running everything as superuser. Password input is hidden and not stored.

**Why do I have to type `YES`?**  
To ensure you consciously accept risk for disruptive/destructive operations. This prevents accidental outages.

**Can I still edit `docker-compose.yml`?**  
No. All behavior is env-driven. Use `--sudo-docker` if your Docker requires sudo.

**What about TimescaleDB on PG18?**  
This stack targets **PG17** for compatibility. When TimescaleDB for PG18 is GA, we can bump versions cleanly.

---

## ✅ Production Checklist

- [ ] `POSTGRES_SUPERUSER_PASSWORD` is set and vaulted.
- [ ] Data/logs/backups mapped to correct storage & labeled (SELinux).
- [ ] `BACKUP_ENABLED=true` and restore test performed.
- [ ] `SHOW shared_preload_libraries;` includes required libs.
- [ ] Application uses DBA/RW/RO roles (no superuser).
- [ ] Monitoring & alerting wired (logs, stats, backups).
- [ ] Password rotation policy in place.

---

### One-liners Example

```bash
# Start with sudo and see live logs
./bin/pg-docker --sudo-docker up && ./bin/pg-docker logs

# Add GIS/vector/cron extensions into appdb
./bin/pg-docker add-ext appdb "postgis,pgvector,pg_cron"

# Check health and top queries
./bin/pg-docker ops:health appdb
./bin/pg-docker ops:stats:top appdb 15

# Safe maintenance
./bin/pg-docker ops:analyze appdb public.big_table
./bin/pg-docker ops:bloat:estimate appdb public.big_table

# Risk-gated maintenance (requires typing YES)
./bin/pg-docker ops:reindex appdb public.big_table
./bin/pg-docker ops:repack  appdb public.big_table
./bin/pg-docker ops:kill:idle appdb 30
```