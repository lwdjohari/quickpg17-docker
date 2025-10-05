-- ==================================================================================================
-- PostgreSQL Initialization Script
-- File: 00_roles_database.sql
-- --------------------------------------------------------------------------------------------------
-- Description:
--   This script bootstraps an application database and its roles in a PostgreSQL instance.
--   It is designed for execution via psql (e.g., Docker initdb) and is idempotent:
--   existing databases, roles, or schemas will be detected and skipped gracefully.
--
-- Features:
--   - Safe psql variable usage (no server-side DO blocks)
--   - Conditional creation of:
--       - Application database  (:APP_DB)
--       - DBA user              (:DBA_USER)
--       - Read/Write user       (:RW_USER)
--       - Read-Only user        (:RO_USER)
--   - Automatic privilege setup for schemas and default privileges
--
-- Usage:
--   Run this script via psql, optionally overriding variables:
--     psql -v ON_ERROR_STOP=1 \
--          -v IS_INIT_DB=1 \
--          -v APP_DB=app_db \
--          -v DBA_USER=dba_usr \
--          -v DBA_PASSWORD=dba_pass \
--          -v RW_USER=rw_usr \
--          -v RW_PASSWORD=rw_pass \
--          -v RO_USER=ro_usr \
--          -v RO_PASSWORD=ro_pass \
--          -f 00_roles_database.sql
--
-- Notes:
--   - Works cleanly under /docker-entrypoint-initdb.d/
--   - All object creation is guarded by EXISTS() checks (no "already exists" errors)
--   - Timestamp format: [YY.MM.DD HH24:MI:SS.MS TZ]
--
-- Logging Convention:
--   [ts] <CATEGORY>::<SECTION>: <message>
--   Example:
--     [25.10.05 20:41:32.217 +07] DB::CREATE: DB tfx is already exists.
--
-- Author: Linggawasistha Djohari
-- Date:   2025-10-05
-- ==================================================================================================

\set ON_ERROR_STOP 1
\set IS_INIT_DB 0 

-- Refresh timestamp
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

-- compute a boolean in SQL and capture it
SELECT (:IS_INIT_DB::int = 0) AS init_disabled \gset

-- Only for script development
-- When init_db = 0
\if :init_disabled
  \set APP_DB 'app_db'
  \set DBA_USER 'dba_user'
  \set DBA_PASSWORD 'changeitlater'
  \set RW_USER 'rw_user'
  \set RW_PASSWORD 'changeitlater'
  \set RO_USER 'ro_user'
  \set RO_PASSWORD 'changeitlater'
\endif

\echo '=== PostgreSQL init 00 starting ==='
\echo ''
\echo :ts 'Values'
\echo '         IS_INIT_DB =' :IS_INIT_DB
\echo '         APP_DB     =' :"APP_DB"
\echo '         DBA_USER   =' :"DBA_USER"
\echo '         RW_USER    =' :"RW_USER"
\echo '         RO_USER    =' :"RO_USER"

SELECT (EXISTS(
  SELECT 1 FROM pg_database WHERE datname = :'APP_DB'
))::boolean AS db_exists \gset

SELECT (EXISTS(
  SELECT 1 FROM pg_roles WHERE rolname = :'DBA_USER'
))::boolean AS has_dba \gset

SELECT (EXISTS(
  SELECT 1 FROM pg_roles WHERE rolname = :'RW_USER'
))::boolean AS has_rwuser \gset

SELECT (EXISTS(
  SELECT 1 FROM pg_roles WHERE rolname = :'RW_USER'
))::boolean AS has_rouser \gset


-- Create application database
\if :db_exists
  \echo :ts 'DB::CREATE: DB ':APP_DB' is already exists.'
\else
  CREATE DATABASE :"APP_DB";
  \echo :ts 'DB::CREATE: Creating DB ' :"APP_DB"
\endif

-- Create roles (safe with IF NOT EXISTS in PG 17)
\if :has_dba
  \echo :ts 'DB::DBA: User '":DBA_USER"' is already exists.'
\else
  CREATE ROLE :"DBA_USER"
  LOGIN PASSWORD :'DBA_PASSWORD'
  CREATEDB CREATEROLE;
  \echo :ts 'DB::DBA: Create user ':"DBA_USER"
\endif

\if :has_rwuser
  \echo :ts 'DB::RWUSER: User ':"RW_USER"' is already exists.'
\else
  CREATE ROLE :"RW_USER"
  LOGIN PASSWORD :'RW_PASSWORD';
  \echo :ts 'DB::RWUSER: Create user ':"RW_USER"
\endif

\if :has_rouser
  \echo :ts 'DB::ROUSER: User ':"RO_USER"' is already exists.'
\else
  CREATE ROLE :"RO_USER"
  LOGIN PASSWORD :'RO_PASSWORD';
  \echo :ts 'DB::ROUSER: Create user ':"RO_USER"
\endif


-- Make DBA the owner of the app database
ALTER DATABASE :"APP_DB" OWNER TO :"DBA_USER";
\echo :ts 'DB::ALTER_OWNER: DB ':"APP_DB"' OWNER ':"DBA_USER"

-- Connect to the app DB
\connect :"APP_DB"

-- find partman schema
SELECT (EXISTS(
  SELECT 1 FROM pg_namespace WHERE nspname = 'partman'
))::boolean AS is_schema_partman_exist \gset

-- Schemas
\if  :is_schema_partman_exist
  \echo :ts 'SCHEMA::PARTMAN: Schema "partman" is already exists.'
\else
  CREATE SCHEMA partman AUTHORIZATION :"DBA_USER";
  \echo :ts 'SCHEMA::PARTMAN: Create schema "partman" on ':"APP_DB"' with user ':"APP_DB"
\endif

-- Public + partman schema usage
GRANT ALL ON SCHEMA public TO :"DBA_USER";
GRANT USAGE ON SCHEMA public TO :"RW_USER", :"RO_USER";
GRANT USAGE ON SCHEMA partman TO :"RW_USER", :"RO_USER";

\echo :ts 'SCHEMA::GRANT: Grant PARTMAN TO ':"DBA_USER"', ':"RW_USER"', ':"RO_USER"

-- Default privileges
-- Future tables in public, created by DBA_USER
ALTER DEFAULT PRIVILEGES FOR ROLE :"DBA_USER" IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"RW_USER";
\echo :ts 'SCHEMA::GRANT: GRANT SELECT, INSERT, UPDATE, DELETE to ':"RW_USER"

ALTER DEFAULT PRIVILEGES FOR ROLE :"DBA_USER" IN SCHEMA public
  GRANT SELECT ON TABLES TO :"RO_USER";
\echo :ts 'SCHEMA::GRANT: GRANT SELECT to ':"RO_USER"

-- Future schemas created by DBA_USER (global, no IN SCHEMA here!)
ALTER DEFAULT PRIVILEGES FOR ROLE :"DBA_USER"
  GRANT USAGE, CREATE ON SCHEMAS TO :"DBA_USER";
\echo :ts 'SCHEMA::GRANT: GRANT USAGE, CREATE ON SCHEMAS to ':"DBA_USER"

\echo '=== PostgreSQL init 00 finished ==='