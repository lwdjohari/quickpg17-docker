# 📦 pg-docker Examples

This document contains full examples for using `pg-docker` commands.\
Each section includes copy-paste ready examples.

---

# 📑 Table of Contents

- [🚀 Start / Rebuild / Stop](#-start--rebuild--stop)
- [🔍 Inspect & Shell](#-inspect--shell)
- [🗄️ Create a Database](#-create-a-database)
- [👤 Create DBA / RW / RO Users](#-create-dba--rw--ro-users)
- [📦 Manage Extensions](#-manage-extensions)
- [🔧 db-utils Helper](#-db-utils-helper)
- [📊 Health & Stats](#-health--stats)
- [🧹 Maintenance](#-maintenance)
- [👥 Connections](#-connections)
- [📜 WAL & Backups](#-wal--backups)
- [⏰ Cron Jobs](#-cron-jobs-pg_cron)
- [⏳ TimescaleDB Policies](#-timescaledb-policies)
- [🧩 Partition Maintenance](#-partition-maintenance-pg_partman)
- [💾 Backup Controls](#-backup-controls)
- [🧰 Project Utilities](#-project-utilities)

---

# 🚀 Start / Rebuild / Stop

```bash
./bin/pg-docker up
./bin/pg-docker up:rebuild
./bin/pg-docker down
./bin/pg-docker stop
./bin/pg-docker restart
```

---

# 🔍 Inspect & Shell

```bash
./bin/pg-docker status
./bin/pg-docker logs
./bin/pg-docker logs:backup
./bin/pg-docker shell
./bin/pg-docker psql
```

---

# 🗄️ Create a Database

```bash
./bin/pg-docker create-db mydb
```

---

# 👤 Create DBA / RW / RO Users

```bash
./bin/pg-docker create-dba mydb dba_user
./bin/pg-docker create-rw mydb app_rw
./bin/pg-docker create-ro mydb app_ro
```

---

# 📦 Manage Extensions

```bash
./bin/pg-docker add-ext mydb "pgcrypto,uuid-ossp"
./bin/pg-docker drop-ext mydb "uuid-ossp"
./bin/pg-docker list-ext mydb
```

---

# 🔧 db-utils Helper

```bash
./bin/pg-docker dbutils:present
./bin/pg-docker dbutils:attach
./bin/pg-docker dbutil create-db mydb
```

---

# 📊 Health & Stats

```bash
./bin/pg-docker ops:health mydb
./bin/pg-docker ops:stats:top mydb 15
./bin/pg-docker ops:stats:reset mydb
```

---

# 🧹 Maintenance

```bash
./bin/pg-docker ops:analyze mydb
./bin/pg-docker ops:analyze mydb public.devices
./bin/pg-docker ops:vacuum:analyze mydb
./bin/pg-docker ops:vacuum:analyze mydb public.events
./bin/pg-docker ops:reindex mydb public
./bin/pg-docker ops:reindex mydb public.events
./bin/pg-docker ops:repack mydb public.big_table
./bin/pg-docker ops:bloat:estimate mydb public.big_table
```

---

# 👥 Connections

```bash
./bin/pg-docker ops:conn:list mydb
./bin/pg-docker ops:kill:idle mydb 30
```

---

# 📜 WAL & Backups

```bash
./bin/pg-docker ops:wal:switch mydb
./bin/pg-docker ops:backup:now mydb
./bin/pg-docker ops:restore:file mydb /path/to/mydb-20250101T000000Z.dump
```

---

# ⏰ Cron Jobs (pg_cron)

```bash
./bin/pg-docker ops:cron:list mydb
./bin/pg-docker ops:cron:add mydb 'daily_maint' '5 1 * * *' 'VACUUM (ANALYZE);'
./bin/pg-docker ops:cron:remove mydb 42
```

---

# ⏳ TimescaleDB Policies

```bash
./bin/pg-docker ops:timescale:jobs mydb
./bin/pg-docker ops:timescale:policy:compress  mydb public.metrics '30 days'
./bin/pg-docker ops:timescale:policy:retention mydb public.metrics '90 days'
./bin/pg-docker ops:timescale:compress-now mydb public.metrics
```

---

# 🧩 Partition Maintenance (pg_partman)

```bash
./bin/pg-docker ops:partman:run mydb
```

---

# 💾 Backup Controls

```bash
./bin/pg-docker backup:on
./bin/pg-docker backup:off
```

---

# 🧰 Project Utilities

```bash
./bin/pg-docker check
./bin/pg-docker wipe:danger
./bin/pg-docker help
```