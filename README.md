# Quickpg17 Docker 
PostgreSQL 17 in a quick ready to use Docker Container (PostGIS • TimescaleDB • pgvector • Partman • Cron • Repack)

> **Goal:** a production-grade Postgres 17 in Docker with the right extensions, **compose-immutable** (nobody needs to touch `docker-compose.yml`).  
> **Control everything via** `.env` / `.env.local` + `./bin/pg-docker` + `Makefile`.

---

## 🔥 TL;DR

```bash
# Clone repo, enter folder
cp .env.example .env                # then edit .env
cp .env.local.example .env.local    # create .env.local for overrides
                                    # never commit the .env.local 
                                    # git-ignored overrides per env/user

# use `pg-docker.sh`
./bin/pg-docker-docker up                  # start DB (compose stays untouched)
./bin/pg-docker-docker psql                # psql into $APP_DB

# Optional: turn on backup sidecar (no compose edits)
./bin/pg-docker-docker backup:on
./bin/pg-docker-docker logs:backup

# Optional: manage DBs/roles/extensions *inside* the container
./bin/pg-docker-docker create-db telemetry
./bin/pg-docker-docker create-dba telemetry app_dba 'strong_pw'
./bin/pg-docker-docker add-ext   telemetry "postgis,pgvector,pg_partman:partman,pg_cron"
./bin/pg-docker-docker list-ext  telemetry
```

---

## ✅ What You Get

- **PostgreSQL 17** built with:
  - **PostGIS** (core, topology, raster)
  - **TimescaleDB 2.x** (for PG17)
  - **pgvector**, **pg_partman**, **pg_cron**, **pg_repack**
  - **pg_stat_statements**, **pg_stat_kcache**, **pg_buffercache**, **pgstattuple**
  - **pgcrypto**, **hstore**, **pg_trgm**, **unaccent**, **hypopg**
- **Compose-immutable workflow**: behavior driven by env + CLI, not compose edits
- **All volumes configurable via env** (host ↔ container)
- **Optional backup sidecar** with retention (enabled by env/CLI)
- **Optional db-utils baked into the image** (or attach at runtime)
- **Security defaults**: SCRAM, remote superuser blocked, least-privilege roles

---

## 🗂 Project Layout

```
quickpg17-docker/
├─ docker-compose.yaml
├─ .env.example        # template; copy to .env
├─ .env.local.example  # template; copy to .env.local
├─ .env                # committed defaults (safe, non-secrets)
├─ .env.local          # git-ignored overrides per env/user
├─ Makefile
├─ README.md
├─ bin/
│  └─ pg-docker        # quickpg CLI (no compose knowledge required)
├─ docker/
│  ├─ Dockerfile       # build targets: core / core_dbutils
│  └─ conf/
│     ├─ postgresql.conf
│     └─ pg_hba.conf
├─ initdb/             # first-boot SQL/SH scripts
│  ├─ 00_roles_databases.sql
│  ├─ 01_extensions.sql
│  ├─ 02_schema_timeseries.sql
│  ├─ 03_search_vector_gis_examples.sql
│  ├─ 04_pg_cron_jobs.sql
│  └─ 99_hardening.sh
├─ db-utils/           # shipped into image if enabled; can attach at runtime
│   ├── add-extensions.sh
│   ├── add-extensions.sql
│   ├── common.sh
│   ├── create-db.sh
│   ├── create-db.sql
│   ├── create-role-ro.sh
│   ├── create-role-ro.sql
│   ├── create-role-rw.sh
│   ├── create-role-rw.sql
│   ├── create-role.sh
│   ├── create-role.sql
│   ├── db-utils.sh
│   ├── drop-extensions.sh
│   ├── drop-extensions.sql
│   └── list-extensions.sh
└─ ops/backup/
   ├─ backup.sh
   └─ crontab
```

---

## 🧩 Don't Touch Compose Rules

- **Do not edit** `docker-compose.yml`.
- Configure everything via:
  - `.env` (defaults) + `.env.local` (overrides, git-ignored)
  - `./bin/pg-docker` (team CLI) and/or `make` targets
- You can change data/logs/backups/config/initdb **paths** via env only.

---

## ⚙️ Configuration (Env)

Create `.env` from `.env.example`, then override safely in `.env.local`.

### Core

| Variable | Meaning | Example |
| --- | --- | --- |
| `PROJECT_NAME` | Compose project/container name | `pg17` |
| `PG_PORT` | Host port → container 5432 | `5432` |
| `TZ` | Timezone | `Asia/Jakarta` |
| `POSTGRES_SUPERUSER_PASSWORD` | Password for `postgres` | `strong_pw` |
| `APP_DB` | Default DB created on init | `appdb` |
| `DBA_USER` / `DBA_PASSWORD` | DBA role (owner) | `app_dba` |
| `RW_USER` / `RW_PASSWORD` | RW role | `app_rw` |
| `RO_USER` / `RO_PASSWORD` | RO role | `app_ro` |
| `BACKUP_ENABLED` | Toggle backup sidecar | `true` / `false` |
| `BACKUP_PORT` | Backup PG port | `5433` |


### Volume Mapping (Host ↔ Container)

All configurable; **no compose edits** required.

| Host Var | Default | Container Var | Default | Purpose |
| --- | --- | --- | --- | --- |
| `HOST_DATA_DIR` | `./data` | `CONTAINER_DATA_DIR` | `/var/lib/postgresql/data` | PGDATA (tables, WAL) |
| `HOST_LOG_DIR` | `./logs` | `CONTAINER_LOG_DIR` | `/var/log/postgresql` | Logs |
| `HOST_BACKUP_DIR` | `./backups` | `CONTAINER_BACKUP_DIR` | `/backups` | Dumps (sidecar) |
| `HOST_CONF_DIR` | `./docker/conf` | `CONTAINER_CONF_DIR` | `/etc/postgresql` | Config files |
| `HOST_INITDB_DIR` | `./initdb` | `CONTAINER_INITDB_DIR` | `/docker-entrypoint-initdb.d` | Init scripts |

**Example (`.env.local`)** - store data on a separate disk:

```dotenv
HOST_DATA_DIR=/mnt/pg17/data
HOST_LOG_DIR=/mnt/pg17/logs
HOST_BACKUP_DIR=/mnt/pg17/backups
BACKUP_ENABLED=true
```

---

## 🧱 Building the Image (db-utils optional)

This Dockerfile has **two targets**:

- `core` → minimal image (no db-utils baked in)
- `core_dbutils` → includes `/opt/db-utils` and `/usr/local/bin/dbutil`

Choose target with env:

```dotenv
# .env.local
DBUTILS_BUILD_TARGET=core_dbutils   # or 'core'
```

Then:

```bash
./bin/pg-docker up:rebuild
```

**If you built minimal (`core`) but need db-utils now:**

```bash
./bin/pg-docker dbutils:attach    # copies host ./db-utils into the running container
./bin/pg-docker dbutils:present   # verify
```

---

## 🚀 Start / Stop

```bash
# bring up
./bin/pg-docker up
./bin/pg-docker status
./bin/pg-docker logs

# psql into $APP_DB as postgres (local dev)
./bin/pg-docker psql

# restart / down
./bin/pg-docker restart
./bin/pg-docker down
```

**Makefile equivalents (optional):**

```bash
make up
make status
make logs
make psql
```

---

## 🔄 Backups (Sidecar)

- Cron runs daily at **03:15 UTC**
- Produces both `.dump` (custom) and `.sql` files
- Keeps the **latest 21** for each format
- Controlled by env `BACKUP_ENABLED=true` (no compose edits)

```bash
./bin/pg-docker backup:on
./bin/pg-docker logs:backup
ls -lah backups/
```

**Restore test:**

```bash
createdb restoretest
pg_restore -d restoretest backups/appdb-YYYYmmddTHHMMSSZ.dump
```

---

## 🛠 DB-Utils (Inside Container)

Run via `./bin/pg-docker` (which `docker exec`s as `postgres`):

```bash
# Presence / attach (if you built minimal image)
./bin/pg-docker dbutils:present
./bin/pg-docker dbutils:attach

# Create DB + roles
./bin/pg-docker create-db telemetry
./bin/pg-docker create-dba telemetry tms_dba 'dba_pw'
./bin/pg-docker create-rw  telemetry tms_rw  'rw_pw'
./bin/pg-docker create-ro  telemetry tms_ro  'ro_pw'

# Extensions (schema override with :schemaname)
./bin/pg-docker add-ext telemetry "postgis,postgis_topology,postgis_raster,timescaledb,pgvector,pg_partman:partman,pg_cron"
./bin/pg-docker list-ext telemetry
./bin/pg-docker drop-ext telemetry "pg_cron"
```

**Safety rails:**

- Scripts are **idempotent**
- Production guard via `ENVIRONMENT` + `BOOTSTRAP_ENABLE`
- Supports `*_FILE` secret pattern if you adopt it

---

## 🧠 Extensions Catalog (What/Why/How)

| Extension | Use it for | Example snippet |
| --- | --- | --- |
| **pg_uuidv7** | Crypto/UUID | `SELECT uuid_generate_v7();` |
| **postgis** | Spatial types/ops | `SELECT ST_Distance(a.geom,b.geom);` |
| **postgis_topology** | Network/topology | `TopoGeo_AddPoint(...)` |
| **postgis_raster** | Raster imagery | `ST_Value(rast, x, y)` |
| **timescaledb** | Time-series, retention, compression | `SELECT create_hypertable('metrics','ts');` |
| **pgvector** | Vector embeddings & similarity | `ORDER BY embedding <-> '[...]'` |
| **pg_partman** | Partition automation | `partman.create_parent(...)` |
| **pg_cron** | In-DB cron jobs | `cron.schedule('nightly','0 3 * * *','ANALYZE');` |
| **pg_repack** | Online reorg, fix bloat | `pg_repack --table=mybigtable` |
| **pg_stat_statements** | Query performance | `SELECT * FROM pg_stat_statements;` |
| **pg_stat_kcache** | CPU/IO syscall stats | `SELECT * FROM pg_stat_kcache;` |
| **pg_buffercache** | Buffer cache inspection | `SELECT * FROM pg_buffercache;` |
| **pgstattuple** | Bloat estimation | `SELECT * FROM pgstattuple('t');` |
| **pgcrypto** | Crypto/UUID | `SELECT digest('abc','sha256');` |
| **hstore** | Key/value | `INSERT INTO kv (h) VALUES ('a=>1');` |
| **pg_trgm** | Fuzzy search | `col % 'helo'` |
| **unaccent** | Accent stripping | `unaccent('café')` |
| **hypopg** | Hypothetical indexes | `hypopg_create_index('CREATE INDEX ...')` |

> Preload-required libs are already configured in `postgresql.conf`:  
> `timescaledb, pg_cron, pg_stat_statements, pg_partman_bgw`

---

## 🧩 Init Scripts (first boot)

Executed from `./initdb/`:

1. **00_roles_databases.sql** - create `$APP_DB` and roles (DBA/RW/RO), grants
2. **01_extensions.sql** - install available extensions (with checks), FTS `simple_unaccent`
3. **02_schema_timeseries.sql** - example hypertable, retention, compression; partman sample
4. **03_search_vector_gis_examples.sql** - FTS + trigram; GIS sanity distance
5. **04_pg_cron_jobs.sql** - nightly `ANALYZE`, weekly bloat snapshot, hourly partman maintenance
6. **99_hardening.sh** - include configs; (optional) SSL lines to uncomment after you mount certs

> If you start with an **existing `./data`**, init scripts **won't re-run**. Use db-utils to retrofit.

---

## 🧭 Operations

### Daily

- **Health**: `pg_isready -h 127.0.0.1 -p ${PG_PORT}`
- **Logs**: `tail -f ./logs/postgresql-*.log`
- **Backups**: check `./backups` (if enabled)
- **Performance** (top queries):
  
  ```sql
  SELECT query, total_exec_time, calls
  FROM pg_stat_statements
  ORDER BY total_exec_time DESC
  LIMIT 10;
  ```
  

### Weekly

- **Bloat**: read `admin.tbl_bloat_report` (created by cron)
- **Repack** (if bloat > ~20%):
  
  ```bash
  # from host (psql auth env required) or inside container with psql + pg_repack installed
  pg_repack --table=public.big_table --dbname=$APP_DB --host=127.0.0.1 --port=${PG_PORT} --username=postgres
  ```
  
- **Timescale jobs**:
  
  ```sql
  SELECT * FROM timescaledb_information.jobs;
  ```
  

### Monthly

- **Password rotation** (DBA/RW/RO)
- **Restore test** from latest dump
- **Review `pg_hba.conf`** and logs for auth anomalies

---

## 🔒 Security Defaults

- **Remote superuser (`postgres`) is blocked** in `pg_hba.conf`
- All users authenticate with **SCRAM-SHA-256**
- Least-privilege roles: **DBA / RW / RO**
- Supports **Docker secrets** with `*_FILE` if you adopt that pattern
- (Optional) **TLS**: mount certs and uncomment in `99_hardening.sh` (plus set `hostssl` rules already present)

---

## 🧱 Volumes: Verify & Move

**Verify mounts:**

```bash
docker inspect ${PROJECT_NAME:-pg17} --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{printf "\n"}}{{end}}'
```

**Move to another disk without compose edits**  
(Option A) set env paths in `.env.local` (recommended)  
(Option B) symlink `./data`, `./logs`, `./backups` to real locations

**SELinux (RHEL/Fedora):** label directories you mapped:

```bash
sudo chcon -Rt svirt_sandbox_file_t "$HOST_DATA_DIR" "$HOST_LOG_DIR" "$HOST_BACKUP_DIR"
```

---

## 🧪 Health & Debug

```bash
./bin/pg-docker status
./bin/pg-docker logs
./bin/pg-docker shell                # bash into container
./bin/pg-docker psql                 # psql into $APP_DB as postgres
./bin/pg-docker check                # prints effective config + mounts
```

---

## 🧯 Troubleshooting Matrix

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Container restart loop at init | `POSTGRES_SUPERUSER_PASSWORD` missing/empty | Set it in `.env.local`, `./bin/pg-docker down; ./bin/pg-docker up` (if first init failed, wipe data to re-init) |
| Extensions missing | Started with existing `./data`, init scripts didn't run | Use `./bin/pg-docker add-ext $DB "ext1,ext2"`; or `./bin/pg-docker wipe` (danger) then `up` |
| No backups showing up | Sidecar disabled | `./bin/pg-docker backup:on`; `./bin/pg-docker logs:backup` |
| Can't connect as `postgres` remotely | Blocked by `pg_hba.conf` | Use DBA/RW/RO roles |
| Cron jobs not running | preload missing / wrong DB | `SHOW shared_preload_libraries;` (should include `pg_cron`), `cron.database_name='postgres'` |
| Disk bloat | Heavy updates/deletes | Run `pg_repack` (online), schedule off-hours |
| “permission denied” writing to `data/` | Host dir perms/SELinux | `chmod 700 data`; apply `chcon` on SELinux |

---

## 🧩 Common Recipes

**Enable backups (prod/stage)**

```bash
echo "BACKUP_ENABLED=true" >> .env.local
./bin/pg-docker restart
```

**Change host port**

```bash
echo "PG_PORT=55432" >> .env.local
./bin/pg-docker restart
```

**Put data/logs/backups on /mnt**

```bash
cat >> .env.local <<EOF
HOST_DATA_DIR=/mnt/pg17/data
HOST_LOG_DIR=/mnt/pg17/logs
HOST_BACKUP_DIR=/mnt/pg17/backups
EOF
./bin/pg-docker restart
```

**Build minimal image (no db-utils), attach later**

```bash
echo "DBUTILS_BUILD_TARGET=core" >> .env.local
./bin/pg-docker up:rebuild
./bin/pg-docker dbutils:present   # NOT present
./bin/pg-docker dbutils:attach    # copies into running container
```

---

## 🧪 Sanity Queries

**Timescale hypertable present?**

```sql
SELECT * FROM timescaledb_information.hypertables;
```

**Cron job history**

```sql
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
```

**Bloat snapshot**

```sql
SELECT * FROM admin.tbl_bloat_report ORDER BY run_at DESC LIMIT 10;
```

**Top queries**

```sql
SELECT query, total_exec_time, calls
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

---

## 🧾 FAQ

**Q: Why can't I SSH as postgres or connect remotely as postgres?**  
A: Remote superuser is blocked by design in `pg_hba.conf`. Use DBA/RW/RO roles.

**Q: I changed env but nothing happened.**  
A: Run `./bin/pg-docker restart`. For mount path changes, ensure directories exist and have correct permissions/labels.

**Q: Init scripts didn't create extensions.**  
A: You likely used an existing `./data`. Use `./bin/pg-docker add-ext $DB "exts..."` or wipe (danger) and re-init.

**Q: How do I ensure preload-required extensions are active?**  
A: `SHOW shared_preload_libraries;` should include: `timescaledb,pg_cron,pg_stat_statements,pg_partman_bgw`.

**Q: Where are logs?**  
A: On host: `${HOST_LOG_DIR}`. Inside container: `${CONTAINER_LOG_DIR}`.

---

## 🧰 Production Checklist

- [ ] `POSTGRES_SUPERUSER_PASSWORD` set (and vaulted)
- [ ] Data/logs/backups mapped to the correct storage
- [ ] `BACKUP_ENABLED=true` and restore test successful
- [ ] `SHOW shared_preload_libraries;` includes all required libs
- [ ] Roles created (DBA/RW/RO), least-privilege enforced
- [ ] Monitoring hooked (log shipper, metrics)
- [ ] Password rotation calendarized

---

## 🔚 Notes

- This stack is designed for **PostgreSQL 17**.
- If you upgrade Postgres major version, **plan a dump/restore** and check extension compatibility.

---

### That's it.

- **Do not edit compose.**
- Configure via **env** and run with **`./bin/pg-docker`**.
- Use **db-utils inside the container** to manage DBs/roles/extensions.
- Turn on **backups** with a single flag and **verify restores** monthly.

## 🧾 License

MIT License

Copyright (c) 2025 Linggawasistha Djohari

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.