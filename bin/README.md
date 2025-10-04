# 📦 pg-docker CLI

`pg-docker` is a colorful, ops-first command-line wrapper to manage a
PostgreSQL 17 Docker stack with backups, extensions, and operational
utilities.

It is designed to be **safe for production-like workflows** with:

- **Dual logging**: logs every command both on the host and inside the
  container.
- **Consent prompts**: destructive/heavy commands require explicit
  typing of YES.
- **Sudo control**: run docker via sudo with `--sudo-docker` (optional
  `--sudo-presupply`).
- **Ops-first defaults**: prompts for DB credentials (hidden), never
  logs passwords.

---

## 🚀 Usage

```bash
./bin/pg-docker [--sudo-docker] [--sudo-presupply] <command>
```

Flags: - `--sudo-docker` → Run docker/compose commands via `sudo` -
`--sudo-presupply` → Prompt for sudo password (hidden, twice) and cache
with `sudo -v`

---

## 🔹 Docker Lifecycle

---

Command Description Example

---

`up` Start containers [`./bin/pg-docker up`](#start--rebuild--stop)

`up:rebuild` Rebuild images (no cache), then start [`./bin/pg-docker up:rebuild`](#start--rebuild--stop)

`down` Stop & remove containers [`./bin/pg-docker down`](#start--rebuild--stop)

`stop` Stop containers only [`./bin/pg-docker stop`](#start--rebuild--stop)

`restart` Restart the `pg` container [`./bin/pg-docker restart`](#start--rebuild--stop)

`ps` / `status` Show container status [`./bin/pg-docker status`](#inspect--shell)

`logs` Follow Postgres logs [`./bin/pg-docker logs`](#inspect--shell)

`logs:backup` Follow backup sidecar logs [`./bin/pg-docker logs:backup`](#inspect--shell)

`shell` Open shell inside Postgres container [`./bin/pg-docker shell`](#inspect--shell)

`psql` Open psql inside container [`./bin/pg-docker psql`](#inspect--shell)

---

## 🔹 Database Utilities

---

Command Description Example

---

`create-db <db>` Create new database [`./bin/pg-docker create-db mydb`](#create-a-database)

`create-dba <db> <user>` Create DBA user (with [`./bin/pg-docker create-dba mydb dba_user`](#create-dba--rw--ro-users-with-password-prompts)
 password)

`create-rw <db> <user>` Create read/write user [`./bin/pg-docker create-rw mydb app_rw`](#create-dba--rw--ro-users-with-password-prompts)

`create-ro <db> <user>` Create read-only user [`./bin/pg-docker create-ro mydb app_ro`](#create-dba--rw--ro-users-with-password-prompts)

`add-ext <db> "exts"` Add extensions [`./bin/pg-docker add-ext mydb "pgcrypto,uuid-ossp"`](#manage-extensions)

`drop-ext <db> "exts"` Drop extensions [`./bin/pg-docker drop-ext mydb "uuid-ossp"`](#manage-extensions)

`list-ext <db>` List extensions [`./bin/pg-docker list-ext mydb`](#manage-extensions)

`dbutils:present` Check if db-utils is present [`./bin/pg-docker dbutils:present`](#db-utils-helper)

`dbutils:attach` Attach db-utils [`./bin/pg-docker dbutils:attach`](#db-utils-helper)

`dbutil ...` Run dbutil subcommand [`./bin/pg-docker dbutil create-db mydb`](#db-utils-helper)

---

## 🔹 Ops Suite

Includes: stats, maintenance, connections, backups, cron jobs, timescale
policies, partition management.

See examples in:\

- [Health & Stats](#-health--stats)\
- [Maintenance](#-maintenance)\
- [Connections](#-connections)\
- [WAL & Backups](#-wal--backups)\
- [Cron Jobs](#-cron-jobs-pg_cron)\
- [TimescaleDB Policies](#-timescaledb-policies)\
- [Partition Maintenance](#-partition-maintenance-pg_partman)

---

## 🔹 Backup Controls

---

Command Description Example

---

`backup:on` Enable backups profile [`./bin/pg-docker backup:on`](#-backup-controls-profiles)

`backup:off` Disable backups profile [`./bin/pg-docker backup:off`](#-backup-controls-profiles)

---

## 🔹 Project Utilities

---

Command Description Example

---

`check` Show project summary [`./bin/pg-docker check`](#-project-utilities)

`wipe:danger` Delete all data dir (⚠ destructive) [`./bin/pg-docker wipe:danger`](#-project-utilities)

`help` Show help / usage overview [`./bin/pg-docker help`](#-project-utilities)

---

# 📖 Examples

All examples are linked in the tables above:

- [Start / Rebuild / Stop](#-setup--basics)\
- [Inspect & Shell](#-setup--basics)\
- [Create a Database](#-database-utilities)\
- [Create DBA / RW / RO Users](#-database-utilities)\
- [Manage Extensions](#-database-utilities)\
- [db-utils Helper](#-database-utilities)\
- [Health & Stats](#-health--stats)\
- [Maintenance](#-maintenance)\
- [Connections](#-connections)\
- [WAL & Backups](#-wal--backups)\
- [Cron Jobs](#-cron-jobs-pg_cron)\
- [TimescaleDB Policies](#-timescaledb-policies)\
- [Partition Maintenance](#-partition-maintenance-pg_partman)\
- [Backup Controls](#-backup-controls-profiles)\
- [Project Utilities](#-project-utilities)

---

## 📝 Logging & Safety

- **Host log:** `logs/cli/pg-docker-usage.log`\
- **Container log:** `/opt/db-utils/logs/pg-docker-ops.log`\
- Sensitive values (passwords) are never written to logs; common
  secret patterns are scrubbed.
- Destructive/heavy actions display a red risk banner and require
  typing **YES**.