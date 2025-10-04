# ===== Base with all extensions =====
FROM postgres:17 AS core

# Add PGDG apt repo + install extensions
RUN set -e \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates gnupg wget build-essential \
 && install -m 0755 -d /etc/apt/keyrings \
 && wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /etc/apt/keyrings/postgresql.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list \
 && apt-get update \
 # ---- PGDG-packaged extensions for Postgres 17 ----
 && apt-get install -y --no-install-recommends \
      postgresql-17-postgis-3 \
      postgresql-17-postgis-3-scripts \
      postgresql-17-pgvector \
      postgresql-17-partman \
      postgresql-17-cron \
      postgresql-17-repack \
      postgresql-17-timescaledb \
      postgresql-server-dev-17 \
      make git \
 # ---- Build pg_uuidv7 from source (no apt package) ----
 && git clone --depth=1 https://github.com/fboulnois/pg_uuidv7 /tmp/pg_uuidv7 \
 && make -C /tmp/pg_uuidv7 \
 && make -C /tmp/pg_uuidv7 install \
 && rm -rf /tmp/pg_uuidv7 \
 # cleanup
 && apt-get purge -y --auto-remove make git build-essential \
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
