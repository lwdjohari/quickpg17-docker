# ===== Runtime base (Bookworm everywhere; PGDG + Timescale repos) =====
FROM debian:bookworm-slim AS runtime-base
ARG DEBIAN_FRONTEND=noninteractive

RUN set -e \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg locales \
 && sed -i 's/# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen \
 && install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /etc/apt/keyrings/pgdg.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list \
 && curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
    | gpg --dearmor -o /etc/apt/keyrings/timescaledb.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/debian/ bookworm main" \
    > /etc/apt/sources.list.d/timescaledb.list

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# PostgreSQL 17 + runtime extensions only (no toolchains)
RUN set -e \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      postgresql-17 postgresql-client-17 postgresql-contrib-17 \
      postgresql-17-postgis-3 postgresql-17-postgis-3-scripts \
      timescaledb-2-postgresql-17 \
      postgresql-17-pgvector \
      postgresql-17-partman \
      postgresql-17-cron \
      postgresql-17-repack \
      postgresql-17-pg-stat-kcache \
      postgresql-17-hypopg \
 && rm -rf /var/lib/apt/lists/*

ENV PG_MAJOR=17 \
    PGBIN=/usr/lib/postgresql/17/bin \
    PGDATA=/var/lib/postgresql/17/main

# ===== Builder for pg_uuidv7 (kept out of final image) =====
FROM runtime-base AS uuidv7-builder
RUN set -e \
 && apt-get update \
 && apt-get install -y --no-install-recommends build-essential git postgresql-server-dev-17 \
 && git clone --depth=1 https://github.com/fboulnois/pg_uuidv7 /tmp/pg_uuidv7 \
 && make -C /tmp/pg_uuidv7 \
 && make -C /tmp/pg_uuidv7 install \
 && rm -rf /var/lib/apt/lists/*

# Stage artifacts
RUN mkdir -p /staging \
 && cp -a /usr/lib/postgresql/17/lib/uuidv7.so /staging/ \
 && cp -a /usr/share/postgresql/17/extension/uuidv7* /staging/

# ===== Final image =====
FROM runtime-base AS core

# Add pg_uuidv7 artifacts only
COPY --from=uuidv7-builder /staging/uuidv7.so /usr/lib/postgresql/17/lib/uuidv7.so
COPY --from=uuidv7-builder /staging/uuidv7*   /usr/share/postgresql/17/extension/

# Official-like entrypoint that honors *_FILE and runs initdb.d
# --- bake default init scripts (will be overridden by a bind mount) ---
# copy everything from repo initdb/ into the default init directory
COPY initdb/ /docker-entrypoint-initdb.d/

# sane perms: shell is executable; SQL files are read-only
RUN find /docker-entrypoint-initdb.d -type f -name "*.sh"     -exec chmod 0755 {} \; && \
    find /docker-entrypoint-initdb.d -type f -name "*.sql"    -exec chmod 0644 {} \; && \
    find /docker-entrypoint-initdb.d -type f -name "*.sql.gz" -exec chmod 0644 {} \;


# --- COPY config defaults from repo (can be overridden by bind-mount) ---
# copies *contents* of repo ./docker/conf into /etc/postgresql
COPY docker/conf/ /etc/postgresql/
RUN chmod 0644 /etc/postgresql/*

# --- Our entrypoint emulates the official flow (initdb + run hook scripts) ---
# and always points postgres at the external conf path. If a bind-mount
# overrides /etc/postgresql, that config wins automatically.
COPY docker/pg-entrypoint.sh /usr/local/bin/pg-entrypoint
RUN chmod +x /usr/local/bin/pg-entrypoint

# Your hardened configs are mounted by compose (RO) to /etc/postgresql
# Your init scripts are mounted by compose to /docker-entrypoint-initdb.d

VOLUME ["/var/lib/postgresql/17/main", "/var/log/postgresql"]
EXPOSE 5432

HEALTHCHECK --interval=10s --timeout=5s --retries=20 \
  CMD /usr/lib/postgresql/17/bin/pg_isready -U postgres -h 127.0.0.1 -p 5432 || exit 1

# Always use external config path; bind-mount can override the files at runtime
CMD ["/usr/local/bin/pg-entrypoint", "-c", "config_file=/etc/postgresql/postgresql.conf"

ENTRYPOINT ["/usr/local/bin/pg-entrypoint"]

