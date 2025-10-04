# ------------------------------------------------------------
# Runtime base: Debian 12 + PGDG + Timescale repos
# ------------------------------------------------------------
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

# PostgreSQL 17 + runtime extensions (no compilers)
RUN set -e \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      gosu \
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

ENV PG_MAJOR=17
ENV PGBIN=/usr/lib/postgresql/17/bin
# Official default:
ENV PGDATA=/var/lib/postgresql/data

# ------------------------------------------------------------
# Builder stage for pg_uuidv7 (kept out of final image)
# ------------------------------------------------------------
FROM runtime-base AS uuidv7-builder

RUN set -e \
 && apt-get update \
 && apt-get install -y --no-install-recommends build-essential git postgresql-server-dev-17 \
 && git clone --depth=1 https://github.com/fboulnois/pg_uuidv7 /tmp/pg_uuidv7 \
 && make -C /tmp/pg_uuidv7 \
 && make -C /tmp/pg_uuidv7 install \
 && rm -rf /var/lib/apt/lists/*

# Stage artifacts (use pg_config so paths are always correct)
RUN set -e; \
  libdir="$(pg_config --pkglibdir)"; \
  sharedir="$(pg_config --sharedir)"; \
  mkdir -p /staging/lib /staging/extension; \
  cp -av "$libdir/pg_uuidv7.so" /staging/lib/; \
  cp -av "$sharedir/extension/pg_uuidv7"* /staging/extension/

# ------------------------------------------------------------
# Final image (production)
# ------------------------------------------------------------
FROM runtime-base AS core

# Copy pg_uuidv7 artifacts only (no compilers in final)
COPY --from=uuidv7-builder /staging/lib/pg_uuidv7.so \
  /usr/lib/postgresql/17/lib/pg_uuidv7.so
COPY --from=uuidv7-builder /staging/extension/pg_uuidv7* \
  /usr/share/postgresql/17/extension/

# Your config + init scripts baked in (compose mounts can override)
COPY docker/conf/ /etc/postgresql/
RUN chmod 0644 /etc/postgresql/*

# Official-like entrypoint that honors *_FILE and runs initdb.d
# --- bake default init scripts (will be overridden by a bind mount) ---
# copy everything from repo initdb/ into the default init directory
COPY initdb/ /docker-entrypoint-initdb.d/

# sane perms: shell is executable; SQL files are read-only
RUN find /docker-entrypoint-initdb.d -type f -name "*.sh"     -exec chmod 0755 {} \; && \
    find /docker-entrypoint-initdb.d -type f -name "*.sql"    -exec chmod 0644 {} \; && \
    find /docker-entrypoint-initdb.d -type f -name "*.sql.gz" -exec chmod 0644 {} \;

# Official-compatible entrypoint
COPY docker/pg-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Pre-create common dirs (compose mounts may replace)
RUN set -e \
 && install -d -m 0700 -o postgres -g postgres /var/lib/postgresql/data \
 && install -d -m 0755 -o postgres -g postgres /var/log/postgresql /var/run/postgresql

 # Your hardened configs are mounted by compose (RO) to /etc/postgresql
# Your init scripts are mounted by compose to /docker-entrypoint-initdb.d

VOLUME ["/var/lib/postgresql/17/main", "/var/log/postgresql"]
EXPOSE 5432

HEALTHCHECK --interval=10s --timeout=5s --retries=20 \
  CMD /usr/lib/postgresql/17/bin/pg_isready -U postgres -h 127.0.0.1 -p 5432 || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["postgres"]


FROM core AS core_dbutils
# copy from repo root because build context is "."
COPY db-utils /opt/db-utils

# Make all scripts executable and create a stable /usr/local/bin/dbutil shim
RUN set -e; \
  install -d /usr/local/bin; \
  chmod -R a+rX /opt/db-utils; \
  find /opt/db-utils -type f -name '*.sh' -exec chmod +x {} +; \
  # pick the correct entry script (repo uses db-utils.sh; some repos use dbutil.sh)
  entry=""; \
  for c in dbutil.sh db-utils.sh dbutils.sh; do \
    if [ -f "/opt/db-utils/$c" ]; then entry="/opt/db-utils/$c"; break; fi; \
  done; \
  [ -n "$entry" ] || { echo "ERROR: no dbutils entry script found in /opt/db-utils"; ls -la /opt/db-utils; exit 1; }; \
  ln -sf "$entry" /usr/local/bin/dbutil
