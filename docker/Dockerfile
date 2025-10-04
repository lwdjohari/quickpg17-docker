# ===== Base with all extensions =====
FROM postgres:17 AS core

RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-contrib \
    postgresql-17-postgis-3 postgresql-17-postgis-3-scripts \
    timescaledb-2-postgresql-17 \
    postgresql-pg-uuidv7  \
    postgresql-17-pgvector \
    postgresql-17-partman \
    postgresql-17-cron \
    postgresql-17-repack \
    postgresql-17-pg-stat-kcache \
    postgresql-17-pg-buffercache \
    postgresql-17-pgstattuple \
    postgresql-17-hypopg \
    postgresql-17-pg-trgm \
    postgresql-17-unaccent \
    postgresql-17-pgcrypto \
    postgresql-17-hstore \
 && rm -rf /var/lib/apt/lists/*

COPY docker/conf/postgresql.conf /etc/postgresql/postgresql.conf
COPY docker/conf/pg_hba.conf      /etc/postgresql/pg_hba.conf

# ===== Optional layer with db-utils baked in =====
FROM core AS core_dbutils
# copy from repo root because build context is "."
COPY db-utils /opt/db-utils
RUN chmod -R a+rX /opt/db-utils && \
    ln -sf /opt/db-utils/dbutil.sh /usr/local/bin/dbutil && \
    chmod +x /usr/local/bin/dbutil /opt/db-utils/*.sh
