#!/usr/bin/env bash
set -Eeuo pipefail

# ---------- defaults for ALL envs we reference (safe for `set -u`) ----------
: "${PGDATA:=/var/lib/postgresql/data}"
: "${PGBIN:=/usr/lib/postgresql/17/bin}"
export PATH="${PGBIN}:${PATH}"

# Logging toggles (safe defaults)
: "${PG_LOG_CONNECTIONS:=on}"
: "${PG_LOG_DISCONNECTIONS:=on}"
: "${PG_LOG_LINE_PREFIX:=%m [%p] %u@%d %r }"
: "${PG_LOG_STATEMENT:=none}"
: "${PG_INIT_SUMMARY:=1}"

# Official PG image envs (initialize everything to avoid 'unbound variable')
: "${POSTGRES_USER:=postgres}"
# : "${POSTGRES_DB:=}"                       # (= POSTGRES_USER by official semantics if unset)
# : "${POSTGRES_PASSWORD:=}"
# : "${POSTGRES_PASSWORD_FILE:=}"
# : "${POSTGRES_HOST_AUTH_METHOD:=}"         # e.g. "trust"
# : "${POSTGRES_INITDB_ARGS:=}"
# : "${POSTGRES_INITDB_WALDIR:=}"
# : "${TZ:=UTC}"

# Your aliases and app vars (also default to empty)
# : "${POSTGRES_SUPERUSER_PASSWORD:=}"
# : "${POSTGRES_SUPERUSER_PASSWORD_FILE:=}"
# : "${APP_DB:=}"
# : "${DBA_USER:=}"
# : "${DBA_PASSWORD:=}"
# : "${DBA_PASSWORD_FILE:=}"
# : "${RW_USER:=}"
# : "${RW_PASSWORD:=}"
# : "${RW_PASSWORD_FILE:=}"
# : "${RO_USER:=}"
# : "${RO_PASSWORD:=}"
# : "${RO_PASSWORD_FILE:=}"

log(){ echo "[entrypoint] $*"; }
die(){ echo >&2 "error: $*"; exit 1; }

# Hard fail early if PGBIN looks wrong
[ -x "${PGBIN}/postgres" ] || die "postgres binary not found at ${PGBIN}/postgres (PGBIN='${PGBIN}')"

# ---------- make sure file_env exists (official-style) ----------
if ! declare -F file_env >/dev/null 2>&1; then
  file_env() {
    local var="$1"; local def="${2-}"; local fileVar="${var}_FILE"
    local val="${!var-}"; local file="${!fileVar-}"
    if [ -n "${val}" ] && [ -n "${file}" ]; then
      echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
      exit 1
    fi
    if [ -n "${val}" ]; then
      export "$var"="$val"
    elif [ -n "${file}" ]; then
      export "$var"="$(< "$file")"
    elif [ -n "${def}" ]; then
      export "$var"="$def"
    fi
    unset "$fileVar"
  }
fi


# Drop root to postgres (official images do this with gosu)
if [ "$(id -u)" = '0' ]; then
  # PGDATA (may be a volume)
  install -d -m 0700 -o postgres -g postgres "$PGDATA"
  # socket dir
  install -d -m 0755 -o postgres -g postgres /var/run/postgresql
  # log dir (is a volume -> must be (re)chowned every boot)
  install -d -m 0755 -o postgres -g postgres /var/log/postgresql

  # redirect PG log file to container stdout (PID 1)
  ln -sf /proc/1/fd/1 /var/log/postgresql/postgresql-current.log

  exec gosu postgres "$0" "$@"
fi

# Re-ensure PATH after gosu (important!)
export PATH="${PGBIN}:${PATH}"

# Support official envs
file_env 'POSTGRES_PASSWORD'
file_env 'POSTGRES_DB'

# app-level vars (enable *_FILE support for all)
file_env 'DBA_PASSWORD'
file_env 'RW_PASSWORD'
file_env 'RO_PASSWORD'

# Normalize command:
# - If arg starts with '-', prepend the absolute postgres path
# - If the user typed 'postgres', rewrite it to the absolute path
if [ "${#}" -gt 0 ]; then
  case "${1:-}" in
    -*)
      set -- "${PGBIN}/postgres" "$@"
      ;;
    postgres)
      shift
      set -- "${PGBIN}/postgres" "$@"
      ;;
  esac
fi

wantHelp=
for arg; do
  case "$arg" in
    -h|--help|--version) wantHelp=1 ;;
  esac
done

# Helper: detect if we're launching the server binary (absolute path or not)
is_postgres_cmd=false
if [ "${1:-}" = "${PGBIN}/postgres" ] || [ "${1:-}" = "postgres" ]; then
  is_postgres_cmd=true
fi

# --- resolve psql path robustly (Debian puts it in /usr/bin) ---
PSQL_BIN="$(command -v psql || true)"
if [ -z "${PSQL_BIN}" ] && [ -x "${PGBIN}/psql" ]; then
  PSQL_BIN="${PGBIN}/psql"
fi
# tiny helpers for psql with consistent flags & nice logging (fail fast if no password available)
_psql(){ "${PSQL_BIN}" --no-password -v ON_ERROR_STOP=1 "$@"; }
_psqlA(){ "${PSQL_BIN}" --no-password -v ON_ERROR_STOP=1 -At "$@"; }
_psql_log(){
  local heading="$1"; shift
  log "$heading"
  _psql "$@" | sed 's/^/  /'
}

# Only init when running the server
if $is_postgres_cmd && [ -z "$wantHelp" ]; then
  # Empty data dir?
  if [ ! -s "$PGDATA/PG_VERSION" ]; then
    if [ -z "${POSTGRES_PASSWORD:-}" ] && [ "${POSTGRES_HOST_AUTH_METHOD:-}" != 'trust' ]; then
      echo >&2 "error: database is uninitialized and POSTGRES_PASSWORD not set"
      echo >&2 "  You must set POSTGRES_PASSWORD (or POSTGRES_PASSWORD_FILE) for the superuser."
      echo >&2 "  Or set POSTGRES_HOST_AUTH_METHOD=trust (NOT recommended for production)."
      exit 1
    fi

    log "Initializing database in $PGDATA (user=$POSTGRES_USER)"
    # auth method selection per official semantics
    authArgs=( --auth-local=scram-sha-256 --auth-host=scram-sha-256 )
    if [ "${POSTGRES_HOST_AUTH_METHOD:-}" = 'trust' ]; then
      authArgs=( --auth-local=trust --auth-host=trust )
    fi

    initArgs=( -D "$PGDATA" -U "$POSTGRES_USER" )
    [ -n "${POSTGRES_INITDB_WALDIR:-}" ] && initArgs+=( --waldir "$POSTGRES_INITDB_WALDIR" )
    if [ -n "${POSTGRES_PASSWORD:-}" ]; then
      pwfile="$(mktemp)"; chmod 600 "$pwfile"; printf '%s' "$POSTGRES_PASSWORD" > "$pwfile"
      initArgs+=( --pwfile="$pwfile" )
    fi
    if [ -n "${POSTGRES_INITDB_ARGS:-}" ]; then
      # shellsplit POSTGRES_INITDB_ARGS safely
      # shellcheck disable=SC2206
      extra=( $POSTGRES_INITDB_ARGS )
      initArgs+=( "${extra[@]}" )
    fi

    "${PGBIN}/initdb" "${authArgs[@]}" "${initArgs[@]}"
    [ -n "${pwfile:-}" ] && rm -f "$pwfile"

    # Make psql non-interactive for init time (SCRAM)
    if [ -n "${POSTGRES_PASSWORD:-}" ]; then
      export PGPASSWORD="${POSTGRES_PASSWORD}"
    fi

    # Start temp server for init scripts (socket-only)
    log "Starting temporary server for init scripts"
    "${PGBIN}/pg_ctl" -D "$PGDATA" -o "-c listen_addresses='' -c unix_socket_directories=/var/run/postgresql" -w start

    # Create POSTGRES_DB if set and != postgres
    if [ -n "${POSTGRES_DB:-}" ] && [ "$POSTGRES_DB" != 'postgres' ]; then
      log "Creating database $POSTGRES_DB owned by $POSTGRES_USER"
      _psql -U "$POSTGRES_USER" -d postgres -Atc "CREATE DATABASE \"${POSTGRES_DB}\" OWNER \"${POSTGRES_USER}\";"
    fi

    # Make them available to shell init scripts, too
    export APP_DB DBA_USER DBA_PASSWORD RW_USER RW_PASSWORD RO_USER RO_PASSWORD

    # Common psql args: ON_ERROR_STOP, superuser, target DB = ${POSTGRES_DB:-postgres}
    _psql_common_args=(
      --username "${POSTGRES_USER:-postgres}"
      -d "${POSTGRES_DB:-postgres}"
      --set=APP_DB="${APP_DB:-}"
      --set=DBA_USER="${DBA_USER:-}"
      --set=DBA_PASSWORD="${DBA_PASSWORD:-}"
      --set=RW_USER="${RW_USER:-}"
      --set=RW_PASSWORD="${RW_PASSWORD:-}"
      --set=RO_USER="${RO_USER:-}"
      --set=RO_PASSWORD="${RO_PASSWORD:-}"
    )

    process_init_file() {
      local f="$1"
      case "$f" in
        *.sh)
          log "Running $f"
          TARGET_DB="${POSTGRES_DB:-postgres}" INITDB_USER="${POSTGRES_USER:-postgres}" . "$f"
          ;;
        *.sql)
          log "Running $f (db=${POSTGRES_DB:-postgres})"
          _psql "${_psql_common_args[@]}" -f "$f"
          ;;
        *.sql.gz)
          log "Running $f (gz) (db=${POSTGRES_DB:-postgres})"
          gunzip -c "$f" | _psql "${_psql_common_args[@]}"
          ;;
        *)
          log "Ignoring $f"
          ;;
      esac
    }

    if [ -d /docker-entrypoint-initdb.d ]; then
      log "Processing /docker-entrypoint-initdb.d"
      find /docker-entrypoint-initdb.d -mindepth 1 -maxdepth 1 -print0 \
      | sort -z \
      | while IFS= read -r -d '' f; do process_init_file "$f"; done
    fi

    # ----- INIT SUMMARY (safe, no secrets) -----
    if [ "${PG_INIT_SUMMARY}" = "1" ]; then
      log "----- Initialization Summary -----"
      # Show key settings
      _psql_log "Server settings:" \
        -U "$POSTGRES_USER" -d "${POSTGRES_DB:-postgres}" -c \
        "select name, setting from pg_settings
         where name in ('listen_addresses','port','ssl','max_connections','shared_buffers','unix_socket_directories')
         order by name;"

      # Effective HBA rules
      _psql_log "Effective pg_hba.conf rules:" \
        -U "$POSTGRES_USER" -d "${POSTGRES_DB:-postgres}" -c \
        "select type, database, user_name, address, netmask, auth_method, options, error
         from pg_hba_file_rules
         order by line_number;"

      # Roles (safe flags only; no password info)
      _psql_log "Roles:" \
        -U "$POSTGRES_USER" -d "${POSTGRES_DB:-postgres}" -c \
        "select rolname, rolsuper, rolcreaterole, rolcreatedb, rolreplication, rolbypassrls
         from pg_roles
         order by rolname;"

      # Databases (non-templates)
      _psql_log "Databases:" \
        -U "$POSTGRES_USER" -d "${POSTGRES_DB:-postgres}" -c \
        "select datname, datdba::regrole as owner, pg_size_pretty(pg_database_size(datname)) as size
         from pg_database
         where datistemplate=false
         order by datname;"

      # Extensions
      _psql_log "Installed extensions (in target DB):" \
        -U "$POSTGRES_USER" -d "${POSTGRES_DB:-postgres}" -c \
        "select extname, extversion from pg_extension order by extname;"

      log "----- End of Initialization Summary -----"
    fi

    # Stop temp server; do not leak password env into runtime
    "${PGBIN}/pg_ctl" -D "$PGDATA" -m fast -w stop
    unset PGPASSWORD
    log "Initialization complete"
  fi

  # Build logging flags (always apply)
  log_flags=(
    -c "log_connections=${PG_LOG_CONNECTIONS}"
    -c "log_disconnections=${PG_LOG_DISCONNECTIONS}"
    -c "log_line_prefix=${PG_LOG_LINE_PREFIX}"
    -c "log_statement=${PG_LOG_STATEMENT}"
    # collector ON, writing to the symlinked file -> appears in docker logs
    -c "logging_collector=on"
    -c "log_destination=csvlog"                 # or 'stderr' if you prefer plain text
    -c "log_directory=/var/log/postgresql"
    -c "log_filename=postgresql-current.log"    # <- fixed name (symlinked to /proc/1/fd/1)
    -c "log_rotation_age=0"                     # disable time-based rotation
    -c "log_rotation_size=0"                    # disable size-based rotation
  )

  # Apply regardless of mounted config
  if [ -f /etc/postgresql/postgresql.conf ]; then
    exec "${PGBIN}/postgres" -D "$PGDATA" -c config_file=/etc/postgresql/postgresql.conf "${log_flags[@]}"
  else
    exec "${PGBIN}/postgres" -D "$PGDATA" "${log_flags[@]}"
  fi
fi

# Fall-through: run what the user asked for (already normalized if postgres)
exec "$@"