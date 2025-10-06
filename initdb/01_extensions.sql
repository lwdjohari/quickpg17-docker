-- ==================================================================================================
-- PostgreSQL Initialization Script
-- File: 01_extensions.sql
-- --------------------------------------------------------------------------------------------------
-- Description:
--   Installs and configures all database extensions and related utilities required
--   by the application database defined in :APP_DB. This script is fully idempotent
--   and designed for execution under psql (e.g., Docker initdb phase).
--
-- Features:
--   - Conditional installation of core and optional extensions:
--       - PostGIS suite: postgis, postgis_topology, postgis_raster
--       - Generic utilities: pgcrypto, hstore, pg_trgm, unaccent, pg_stat_statements,
--         pgstattuple, pgvector, pg_partman, pg_cron, pg_repack, pg_stat_kcache,
--         pg_buffercache, hypopg, pg_uuidv7
--       - TimescaleDB (if available)
--   - Conditional creation of `simple_unaccent` text search configuration
--   - Automatic configuration of pg_partman background worker (pg_partman_bgw.*)
--   - Outputs current installed versions for verification
--
-- Usage:
--   This script expects to run after `00_roles_database.sql` and to connect
--   automatically to the database `:"APP_DB"`. Variables can be overridden via psql:
--
--     psql -v ON_ERROR_STOP=1 \
--          -v IS_INIT_DB=1 \
--          -v APP_DB=app_db \
--          -v DBA_USER=dba_user \
--          -f 01_extensions.sql
--
-- Notes:
--   - All extension creation is guarded by EXISTS() checks.
--   - No DO blocks or transaction-wrapped CREATEs are used — fully psql-native.
--   - Compatible with PostgreSQL 15–17, including Docker entrypoint environments.
--
-- Logging Convention:
--   [ts] EXT::<CATEGORY>: <message>
--   Example:
--     [25.10.05 21:07:13.241 +07] EXT::CREATE: postgis (ok/exists)
--
-- Dependencies:
--   Requires the database and roles created by `00_roles_database.sql`.
--
-- Author: Linggawasistha Djohari
-- Date:   2025-10-05
-- ==================================================================================================
\set ON_ERROR_STOP 1

-- compute a boolean in SQL and capture it
SELECT (:IS_INIT_DB::int = 0) AS init_disabled \gset

-- Only for script development
-- When init_db = 0
\if :init_disabled
  \set APP_DB 'app_db'
  \set DBA_USER 'dba_user'
  \set RW_USER 'rw_user'
  \set RO_USER 'ro_user'
\endif

-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset
\echo :ts '=== 01 EXTENSIONS init starting ==='
\echo :ts 'Values'
\echo '         IS_INIT_DB =' :IS_INIT_DB
\echo '         APP_DB     =' :"APP_DB"
\echo '         DBA_USER   =' :"DBA_USER"
\echo '         RW_USER    =' :"RW_USER"
\echo '         RO_USER    =' :"RO_USER"

\connect :"APP_DB"
-- show where we really are
SELECT current_database() AS cur_db,
       current_setting('search_path') AS cur_search_path
\gset
\echo :ts 'DB::INFO: DB=':"cur_db"' search_path=':cur_search_path


-- refresh [ts] 
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset
-- --- Verification: list installed versions ---
\echo :ts 'EXT::LIST: installed versions (selected set)'
\echo ''
SELECT name AS extname,
       installed_version,
       default_version
FROM pg_available_extensions
WHERE name IN (
  'postgis','postgis_topology','postgis_raster','vector',
  'pgcrypto','hstore','pg_trgm','unaccent','pg_stat_statements',
  'pgstattuple','pgvector','pg_partman','pg_cron','pg_repack',
  'pg_stat_kcache','pg_buffercache','hypopg','pg_uuidv7','timescaledb'
)
ORDER BY name;

-- --- PostGIS stack -- 
-- postgis
SELECT EXISTS (
  SELECT 1 FROM pg_available_extensions 
    WHERE name='postgis') 
  AS has_postgis \gset

SELECT EXISTS (
  SELECT 1 FROM pg_extension 
  WHERE extname = 'postgis'
) AS has_postgis_installed \gset

\if :has_postgis_installed
  \echo :ts 'EXT::CREATE: postgis (installed)'
\elif :has_postgis
  CREATE EXTENSION IF NOT EXISTS postgis;
  \echo :ts 'EXT::CREATE: postgis (added - OK)'
\else
  \echo :ts 'EXT::SKIP: postgis not available'
\endif

-- postgis_topology
SELECT EXISTS (
  SELECT 1 FROM pg_available_extensions 
    WHERE name='postgis_topology') 
  AS has_postgis_topology \gset

SELECT EXISTS (
  SELECT 1 FROM pg_extension 
  WHERE extname = 'postgis_topology'
) AS has_postgis_topology_installed \gset

\if :has_postgis_topology_installed
  \echo :ts 'EXT::CREATE: postgis_topology (installed)'
\elif :has_postgis_topology
  CREATE EXTENSION IF NOT EXISTS postgis_topology;
  \echo :ts 'EXT::CREATE: postgis_topology (added - OK)'
\else
  \echo :ts 'EXT::SKIP: postgis_topology not available'
\endif

-- postgis_raster
SELECT EXISTS (
  SELECT 1 FROM pg_available_extensions 
    WHERE name='postgis_raster') 
  AS has_postgis_raster \gset

SELECT EXISTS (
  SELECT 1 FROM pg_extension 
  WHERE extname = 'postgis_raster'
) AS has_postgis_raster_installed \gset

\if :has_postgis_raster_installed
  \echo :ts 'EXT::CREATE: postgis_raster (installed)'
\elif :has_postgis_raster
  CREATE EXTENSION IF NOT EXISTS postgis_raster;
  \echo :ts 'EXT::CREATE: postgis_raster (added - OK)'
\else
  \echo :ts 'EXT::SKIP: postgis_raster not available'
\endif


-- refresh [ts] 
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset
-- pg_vector
SELECT EXISTS (
  SELECT 1 FROM pg_available_extensions 
    WHERE name='vector') 
  AS has_vector \gset

SELECT EXISTS (
  SELECT 1 FROM pg_extension 
  WHERE extname = 'vector'
) AS has_vector_installed \gset

\if :has_vector_installed
  \echo :ts 'EXT::CREATE: pg_vector (installed)'
\elif :has_vector
  CREATE EXTENSION IF NOT EXISTS vector;
  \echo :ts 'EXT::CREATE: pg_vector (added - OK)'
\else
  \echo :ts 'EXT::SKIP: pg_vector not available'
\endif


-- refresh [ts] 
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset
-- --- Text search config: simple_unaccent (quiet & safe) ---------------------

-- 1) Make sure the unaccent extension exists here
SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname='unaccent') AS has_unaccent \gset
\if :has_unaccent
  \echo :ts 'TS::UNACCENT: extension present'
\else
  SELECT EXISTS (SELECT 1 FROM pg_available_extensions WHERE name='unaccent') AS unaccent_avail \gset
  \if :unaccent_avail
    CREATE EXTENSION unaccent;
    \echo :ts 'TS::UNACCENT: extension created'
  \else
    \echo :ts 'TS::CFG: SKIP — unaccent not available on this server'
    \endif
\endif

-- 2) Find the fully-qualified dictionary name (e.g., public.unaccent)
SELECT n.nspname || '.' || d.dictname AS unaccent_dict
FROM pg_ts_dict d
JOIN pg_namespace n ON n.oid = d.dictnamespace
WHERE d.dictname = 'unaccent'
LIMIT 1
\gset

\if :{?unaccent_dict}
  -- 3) Ensure the config exists
  SELECT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname='simple_unaccent') AS has_simple_unaccent \gset
  \if :has_simple_unaccent
    \echo :ts 'TS::CFG: simple_unaccent already exists'
  \else
    CREATE TEXT SEARCH CONFIGURATION simple_unaccent (COPY = simple);
    \echo :ts 'TS::CFG: created simple_unaccent'
  \endif

  -- 4) Set mapping using schema-qualified dictionary (no search_path surprises)
  SELECT format($f$
    ALTER TEXT SEARCH CONFIGURATION simple_unaccent
      ALTER MAPPING FOR hword, hword_part, word
      WITH %s, simple;
  $f$, :'unaccent_dict') AS _sql \gset
  :_sql
  \echo :ts 'TS::CFG: mapping set to ' :unaccent_dict ', simple'
\else
  \echo :ts 'TS::CFG: SKIP — unaccent dictionary not found (extension not created?)'
\endif



-- refresh [ts] 
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset
-- --- TimescaleDB ---
SELECT EXISTS (
  SELECT 1 FROM pg_available_extensions 
    WHERE name='timescaledb') 
  AS has_timescaledb \gset

SELECT EXISTS (
  SELECT 1 FROM pg_extension 
  WHERE extname = 'timescaledb'
) AS has_timescaledb_installed \gset

\if :has_timescaledb_installed
  \echo :ts 'EXT::CREATE: timescaledb (installed)'
\elif :has_timescaledb
  CREATE EXTENSION IF NOT EXISTS timescaledb;
  \echo :ts 'EXT::CREATE: timescaledb (added - OK)'
\else
  \echo :ts 'EXT::SKIP: timescaledb not available'
\endif





-- refresh [ts] 
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

-- --- pg_partman bgw config ----
-- SELECT set_config('pg_partman_bgw.interval','3600',false);
-- SELECT set_config('pg_partman_bgw.role', :'DBA_USER', false);
-- \echo :ts 'PG_PARTMAN::BGW: interval=3600, role=' :DBA_USER



-- refresh [ts] 
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

-- === Safe Extension Creation (filtered for preload requirements) ===
\echo :ts 'EXT::CREATE: EXTENSION INSTALLED (safe mode)'

-- read preload list once
SELECT current_setting('shared_preload_libraries', true) AS spl \gset

-- 1) CREATE ONLY SAFE TARGETS (no warnings)
WITH wanted(name) AS (
  VALUES
    ('pgcrypto'),('hstore'),('pg_trgm'),('unaccent'),('pg_stat_statements'),
    ('pgstattuple'),('pg_partman'),
    ('pg_repack'),('pg_stat_kcache'),('pg_buffercache'),
    ('hypopg'),('pg_uuidv7')
),
preload_req(name) AS (
  VALUES ('pg_stat_statements'),('timescaledb'),
         ('pg_stat_kcache'),('pg_uuidv7')
),
avail AS (SELECT name FROM pg_available_extensions),
installed AS (SELECT extname AS name FROM pg_extension),
to_create AS (
  SELECT w.name
  FROM wanted w
  JOIN avail a USING (name)
  LEFT JOIN installed i USING (name)
  WHERE i.name IS NULL
    AND (
      w.name NOT IN (SELECT name FROM preload_req)
      OR (COALESCE(:'spl','') ILIKE '%' || w.name || '%')
    )
)
SELECT 'CREATE EXTENSION ' || quote_ident(name) || ';'
FROM to_create
\gexec

-- 2) SUMMARY (one item per line, no timestamps)
\echo ''
--\pset format unaligned
\pset tuples_only on
WITH wanted(name) AS (
  VALUES
    ('pgcrypto'),('hstore'),('pg_trgm'),('unaccent'),('pg_stat_statements'),
    ('pgstattuple'),('pg_partman'),
    ('pg_repack'),('pg_stat_kcache'),('pg_buffercache'),
    ('hypopg'),('pg_uuidv7')
),
preload_req(name) AS (
  VALUES ('pg_stat_statements'),('timescaledb'),
         ('pg_stat_kcache'),('pg_uuidv7')
),
avail AS (SELECT name FROM pg_available_extensions),
installed AS (SELECT extname AS name FROM pg_extension),
classify AS (
  SELECT w.name,
         CASE
           WHEN NOT EXISTS (SELECT 1 FROM avail a WHERE a.name = w.name)
             THEN 'not_available'
           WHEN EXISTS (SELECT 1 FROM installed i WHERE i.name = w.name)
             THEN 'already_installed'
           WHEN w.name IN (SELECT name FROM preload_req)
                AND (COALESCE(:'spl','') NOT ILIKE '%' || w.name || '%')
             THEN 'needs_preload'
           ELSE 'create_now'
         END AS status
  FROM wanted w
)
SELECT CASE status
         WHEN 'create_now'         THEN '[CREATED  ] ' || name
         WHEN 'already_installed'  THEN '[INSTALLED] ' || name
         WHEN 'needs_preload'      THEN '[PRELOAD  ] ' || name
         WHEN 'not_available'      THEN '[MISSING  ] ' || name
       END
FROM classify
ORDER BY
  CASE status
    WHEN 'needs_preload'     THEN 1
    WHEN 'not_available'     THEN 2
    WHEN 'create_now'        THEN 3
    WHEN 'already_installed' THEN 4
  END,
  name;
\pset tuples_only off
--\pset format aligned

-- refresh [ts] 
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset
-- --- Verification: list installed versions ---
\echo :ts 'EXT::LIST: installed versions (selected set)'
\echo ''
SELECT name AS extname,
       installed_version,
       default_version
FROM pg_available_extensions
WHERE name IN (
  'postgis','postgis_topology','postgis_raster','vector',
  'pgcrypto','hstore','pg_trgm','unaccent','pg_stat_statements',
  'pgstattuple','pgvector','pg_partman','pg_cron','pg_repack',
  'pg_stat_kcache','pg_buffercache','hypopg','pg_uuidv7','timescaledb'
)
ORDER BY name;

SET ROLE :"DBA_USER";

-- Tables & Views
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO :"RO_USER", :"RW_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT INSERT, UPDATE, DELETE ON TABLES TO :"RW_USER";

-- -- Materialized Views
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public
--   GRANT SELECT ON MATERIALIZED VIEWS TO :"RO_USER", :"RW_USER";

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
\echo :ts '=== 01 EXTENSIONS init finished ==='