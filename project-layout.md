```
quickpg17-docker/
├─ docker-compose.yaml
├─ .env.example               # template; copy to .env
├─ .env.local.example         # template; copy to .env.local
├─ .env                       # committed defaults (safe, non-secrets)
├─ .env.local                 # git-ignored overrides per env/user
├─ Makefile
├─ README.md
├─ bin/
│  └─ pg-docker               # quickpg CLI (no compose knowledge required)
├─ docker/
│  ├─ Dockerfile              # build targets: core / core_dbutils
│  └─ conf/
│     ├─ postgresql.conf
│     └─ pg_hba.conf
├─ initdb/                    # first-boot SQL/SH scripts
│  ├─ 00_roles_databases.sql
│  ├─ 01_extensions.sql
│  ├─ 02_schema_timeseries.sql
│  ├─ 03_search_vector_gis_examples.sql
│  ├─ 04_pg_cron_jobs.sql
│  └─ 99_hardening.sh
├─ db-utils/                  # shipped into image if enabled; can attach at runtime
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