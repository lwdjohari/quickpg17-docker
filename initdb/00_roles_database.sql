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

\echo :ts '=== 00 DB & Roles init starting ==='
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
  SELECT 1 FROM pg_roles WHERE rolname = :'RO_USER'
))::boolean AS has_rouser \gset

-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

-- Create application database
\if :db_exists
  \echo :ts 'DB::CREATE: DB ':APP_DB' is already exists.'
\else
  CREATE DATABASE :"APP_DB";
  \echo :ts 'DB::CREATE: Creating DB ' :"APP_DB"
\endif

-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

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

-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

-- Make DBA the owner of the app database
ALTER DATABASE :"APP_DB" OWNER TO :"DBA_USER";
\echo :ts 'DB::ALTER_OWNER: DB ':"APP_DB"' OWNER ':"DBA_USER"

GRANT CONNECT ON DATABASE :"APP_DB" TO :"DBA_USER", :"RW_USER", :"RO_USER";

-- Connect to the app DB
\connect :"APP_DB"
SET ROLE :"DBA_USER";

-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

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

-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset


-- Public + partman schema usage
GRANT ALL ON SCHEMA public TO :"DBA_USER";
GRANT USAGE ON SCHEMA public TO :"RW_USER", :"RO_USER";
GRANT USAGE ON SCHEMA partman TO :"RW_USER", :"RO_USER";

\echo :ts 'SCHEMA::GRANT: Grant Public & PARTMAN TO ':"DBA_USER"', ':"RW_USER"', ':"RO_USER"

-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

SET ROLE :"DBA_USER";


-- ======================================================================
-- Default privileges (future-proofed for all object types)
-- These ensure any new objects created by DBA_USER automatically
-- grant the right privileges to RW_USER and RO_USER.
-- ======================================================================

-- Tables & Views
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO :"RO_USER", :"RW_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT INSERT, UPDATE, DELETE ON TABLES TO :"RW_USER";

-- Materialized Views
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON MATERIALIZED VIEWS TO :"RO_USER", :"RW_USER";

-- Sequences (identity/serial)
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO :"RO_USER", :"RW_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT UPDATE ON SEQUENCES TO :"RW_USER";

-- Functions / Procedures
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO :"RO_USER", :"RW_USER";

-- Types (domains, enums, composite types)
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE ON TYPES TO :"RO_USER", :"RW_USER";


-- refresh [ts] and finish
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset
\echo :ts '=== 00 DB & Roles init finished ==='