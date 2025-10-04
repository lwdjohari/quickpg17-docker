#!/usr/bin/env bash
set -Eeuo pipefail

: "${PGDATA:=/var/lib/postgresql/17/main}"
: "${PGBIN:=/usr/lib/postgresql/17/bin}"

# ---------- helpers ----------
log(){ echo "[entrypoint] $*"; }

# Read secret: inline wins; else *_FILE; trims trailing whitespace
read_secret() {
  local var="$1" filevar="$2"
  local v="${!var-}"
  local f="${!filevar-}"
  if [[ -n "$v" ]]; then printf "%s" "$v"; return 0; fi
  if [[ -n "${f:-}" && -r "$f" ]]; then sed -e 's/[[:space:]]*$//' "$f"; return 0; fi
  printf ""
}

# If VAR empty and VAR_FILE readable, export VAR=<file contents>
resolve_file_to_inline() {
  local var="$1" filevar="${1}_FILE"
  if [[ -z "${!var-}" && -n "${!filevar-}" && -r "${!filevar}" ]]; then
    # shellcheck disable=SC2086
    export "$var"="$(sed -e 's/[[:space:]]*$//' "${!filevar}")"
  fi
}

# ---------- dirs ----------
install -d -o postgres -g postgres -m 700 "$PGDATA"
install -d -o postgres -g postgres -m 775 /var/run/postgresql || true

# ---------- env compatibility (official-like) ----------
POSTGRES_USER="${POSTGRES_USER:-postgres}"
# Official default: if POSTGRES_DB not set, default to POSTGRES_USER
POSTGRES_DB="${POSTGRES_DB:-$POSTGRES_USER}"

# Superuser password: prefer official env names, then your aliases
SU_PASS="$( read_secret POSTGRES_PASSWORD POSTGRES_PASSWORD_FILE )"
if [[ -z "$SU_PASS" ]]; then
  SU_PASS="$( read_secret POSTGRES_SUPERUSER_PASSWORD POSTGRES_SUPERUSER_PASSWORD_FILE )"
fi

# Make downstream init scripts happy: expose effective inline values for app roles if *_FILE was used
resolve_file_to_inline DBA_PASSWORD
resolve_file_to_inline RW_PASSWORD
resolve_file_to_inline RO_PASSWORD

# Optional extras like official image
POSTGRES_INITDB_ARGS="${POSTGRES_INITDB_ARGS:-}"
POSTGRES_INITDB_WALDIR="${POSTGRES_INITDB_WALDIR:-}"

# ---------- first-boot ----------
if [[ ! -s "$PGDATA/PG_VERSION" ]]; then
  if [[ -z "$SU_PASS" ]]; then
    echo >&2 "ERROR: first run requires POSTGRES_PASSWORD or POSTGRES_PASSWORD_FILE (for ${POSTGRES_USER})."
    exit 1
  fi

  log "Initializing cluster in $PGDATA (user=${POSTGRES_USER})"
  tmp_pw="$(mktemp)"; chmod 600 "$tmp_pw"; printf "%s" "$SU_PASS" > "$tmp_pw"

  # initdb args
  initdb_args=( -D "$PGDATA" --username="$POSTGRES_USER" --pwfile="$tmp_pw"
                --auth-local=scram-sha-256 --auth-host=scram-sha-256 )
  if [[ -n "$POSTGRES_INITDB_WALDIR" ]]; then
    install -d -o postgres -g postgres -m 700 "$POSTGRES_INITDB_WALDIR"
    initdb_args+=( -X "$POSTGRES_INITDB_WALDIR" )
  fi
  if [[ -n "$POSTGRES_INITDB_ARGS" ]]; then
    # split POSTGRES_INITDB_ARGS into array respecting spaces
    # shellcheck disable=SC2206
    extra_args=( $POSTGRES_INITDB_ARGS )
    initdb_args+=( "${extra_args[@]}" )
  fi

  su -s /bin/sh -c "'$PGBIN/initdb' ${initdb_args[*]@Q}" postgres
  rm -f "$tmp_pw"

  # Start temporary server (socket only) for init scripts
  # Use PGPASSWORD to authenticate with SCRAM
  export PGPASSWORD="$SU_PASS"
  su -s /bin/sh -c \
    "'$PGBIN/pg_ctl' -D '$PGDATA' -o \"-c listen_addresses='' -c unix_socket_directories=/var/run/postgresql\" -w start" postgres

  # Create POSTGRES_DB when not "postgres" (official behavior creates when different)
  if [[ "$POSTGRES_DB" != "postgres" ]]; then
    log "Creating database ${POSTGRES_DB} owned by ${POSTGRES_USER}"
    "$PGBIN/psql" -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d postgres -Atc \
      "CREATE DATABASE \"${POSTGRES_DB}\" OWNER \"${POSTGRES_USER}\";"
  fi

  # Run init scripts (official semantics)
  if [[ -d /docker-entrypoint-initdb.d ]]; then
    log "Running /docker-entrypoint-initdb.d scripts"
    for f in /docker-entrypoint-initdb.d/*; do
      case "$f" in
        *.sh)
          log "Executing $f"
          # shellcheck disable=SC1090
          . "$f"
          ;;
        *.sql)
          log "Running $f"
          "$PGBIN/psql" -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "${POSTGRES_DB:-postgres}" -f "$f"
          ;;
        *.sql.gz)
          log "Running $f (gz)"
          gunzip -c "$f" | "$PGBIN/psql" -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "${POSTGRES_DB:-postgres}"
          ;;
        *) log "Ignoring $f" ;;
      esac
    done
  fi

  su -s /bin/sh -c "'$PGBIN/pg_ctl' -D '$PGDATA' -m fast -w stop" postgres
  unset PGPASSWORD
fi

# ---------- final server ----------
# If you bind-mount /etc/postgresql, it wins; else baked config is used.
if [[ -f /etc/postgresql/postgresql.conf ]]; then
  exec "$PGBIN/postgres" -D "$PGDATA" -c config_file=/etc/postgresql/postgresql.conf
else
  exec "$PGBIN/postgres" -D "$PGDATA"
fi
