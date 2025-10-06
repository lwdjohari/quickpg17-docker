-- =============================================================================
-- 02_schema_timeseries.sql
-- =============================================================================
-- Purpose
--   Initialize time-series objects for the application database:
--     - Create/ensure table public.metrics_ts
--         - Hypertable on ts (TimescaleDB), 7-day chunks
--         - Compression enabled (segmentby = device_id)
--         - Retention policy      : 180 days
--         - Compression policy    : 30 days
--         - Supporting indexes    : (device_id, ts desc), BRIN(ts), GIST(loc)
--     - Create/ensure public.metrics_part (daily partitions) — pg_partman section
--       is currently stubbed with a clear log line (no-op) to avoid version drift.
--
-- How it works (quiet & idempotent)
--   - Uses psql meta-commands (\gset, \if, \echo) and catalog checks to avoid
--     NOTICE spam (no DO blocks, no “already exists” chatter).
--   - Only creates objects/policies when missing.
--   - Exits early with actionable guidance if required dependencies are absent.
--
-- Prerequisites (scripts to run before this one)
--   00_roles_database.sql   – ensures DB and roles exist
--   01_extensions.sql       – installs extensions and prints a summary
--
-- Required runtime environment
--   - Run with psql.
--   - PostgreSQL 14+ (tested on PG 17).
--   - TimescaleDB installed in the app DB AND present in shared_preload_libraries.
--   - PostGIS installed in the app DB (for geography(Point,4326)).
--   - pgvector installed in the app DB (for vector(384)), unless you toggle it off.
--
-- Variables consumed (psql -v or \set)
--   - IS_INIT_DB        : 0 during dev to auto-fill APP_DB/DBA_USER defaults.
--   - APP_DB            : target application database (must match \connect).
--   - DBA_USER          : used only for logging lines here.
--   - SREQUIRE_POSTGIS  : 1=require PostGIS, 0=optional   (default 1)
--   - SREQUIRE_TIMESCALE: 1=require TimescaleDB, 0=optional (default 1)
--   - SREQUIRE_PGVECTOR : 1=require pgvector, 0=optional   (default 1)
--   - SREQUIRE_PARTMAN  : 1=require pg_partman, 0=optional (default 0)
--
-- Exit behavior
--   - On missing required deps (PostGIS/TimescaleDB/pgvector/pg_partman as toggled)
--     the script prints guidance and terminates with \quit.
--   - No explicit COMMITs are needed (psql autocommit). If you run inside an
--     explicit transaction and error, you must ROLLBACK before retrying.
--
-- Example invocation
--   psql \
--     -v ON_ERROR_STOP=1 \
--     -v IS_INIT_DB=0 \
--     -v APP_DB='app_db' \
--     -v DBA_USER='dba_user' \
--     -f 02_schema_timeseries.sql
--
-- Notes
--   - If you change retention/compression windows, adjust both policies and any
--     downstream queries/rollups that assume those horizons.
--   - pg_partman registration is version-sensitive; a minimal stub is left here.
--     Add the version-aware registration block when you finalize your partman path.
--
-- Change log
--   - 2025-10-05: Initial quiet/idempotent version with dependency gate & policies.
-- 
-- Author: Linggawasistha Djohari
-- Date:   2025-10-05
-- =============================================================================
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
\echo :ts '=== 02 Schema Timeseries init starting ==='
\echo :ts 'Values'
\echo '         IS_INIT_DB =' :IS_INIT_DB
\echo '         APP_DB     =' :"APP_DB"
\echo '         DBA_USER   =' :"DBA_USER"
\echo '         RW_USER    =' :"RW_USER"
\echo '         RO_USER    =' :"RO_USER"

-- ===== Dependency gate (hard fail with guidance) ============================
-- needed for geography(Point,4326)
\set SREQUIRE_POSTGIS   1
-- needed for hypertable/policies     
\set SREQUIRE_TIMESCALE 1     
-- set 0 if vector embedding is optional
\set SREQUIRE_PGVECTOR  1     
-- set 1 if metrics_part + partman is mandatory
\set SREQUIRE_PARTMAN   0     

SELECT (:SREQUIRE_POSTGIS::int <> 0) AS require_postgis \gset
SELECT (:SREQUIRE_TIMESCALE::int <> 0) AS require_timescale \gset
SELECT (:SREQUIRE_PGVECTOR::int <> 0) AS require_pgvector \gset
SELECT (:SREQUIRE_PARTMAN::int <> 0) AS require_partman \gset

\echo :ts 'Extension Dependencies'
\echo '         REQUIRE_POSTGIS         =' :SREQUIRE_POSTGIS
\echo '         REQUIRE_TIMESCALEDB     =' :SREQUIRE_TIMESCALE
\echo '         REQUIRE_PGVECTOR        =' :SREQUIRE_PGVECTOR
\echo '         REQUIRE_PARTMAN         =' :SREQUIRE_PARTMAN

\connect :"APP_DB"

SELECT current_setting('shared_preload_libraries', true) AS spl \gset
SELECT (POSITION('timescaledb' IN COALESCE(:'spl','')) > 0) AS tsdb_preloaded \gset

SET ROLE :"DBA_USER";

-- show where we really are
SELECT current_database() AS cur_db,
       current_setting('search_path') AS cur_search_path
\gset
-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset
\echo :ts 'DB::INFO DB=':"cur_db"' search_path=':cur_search_path


-- detect availability/installed/preload
SELECT EXISTS (SELECT 1 FROM pg_available_extensions 
  WHERE name='postgis')      
  AS postgis_available \gset

SELECT EXISTS (
  SELECT 1 FROM pg_extension 
  WHERE extname = 'postgis'
) AS postgis_installed \gset

SELECT EXISTS (SELECT 1 FROM pg_available_extensions 
  WHERE name='timescaledb')  
  AS tsdb_available    \gset

SELECT EXISTS (SELECT 1 FROM pg_extension            
  WHERE extname='timescaledb') 
  AS tsdb_installed   \gset



SELECT EXISTS (SELECT 1 FROM pg_available_extensions 
  WHERE name='vector')       
  AS vec_available     \gset

SELECT EXISTS (SELECT 1 FROM pg_extension            
  WHERE extname='vector')    
  AS vec_installed      \gset

SELECT EXISTS (SELECT 1 FROM pg_available_extensions 
  WHERE name='pg_partman')   
  AS partman_available \gset

SELECT EXISTS (SELECT 1 FROM pg_extension            
  WHERE extname='pg_partman') 
  AS partman_installed \gset

-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

-- POSTGIS
\if :require_postgis
  \if :postgis_available
    \if :postgis_installed
      \echo :ts 'DEP::OK postgis installed'
    \else
      \echo :ts 'FATAL: Required extension postgis is NOT installed in database ' :"APP_DB"
      \echo '       Fix: \connect ' :APP_DB ' ; CREATE EXTENSION postgis;'
      \echo '       If CREATE EXTENSION fails, install OS package for PostGIS matching your PG version.'
      \quit
    \endif
  \else
    \echo :ts 'FATAL: Required extension postgis is NOT available on this server.'
    \echo '       Fix: install PostGIS packages (e.g., postgis / postgis3) that match your PostgreSQL version.'
    \quit
  \endif
\endif

-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

-- TIMESCALEDB
\if :require_timescale
  \if :tsdb_available
    \if :tsdb_preloaded
      \if :tsdb_installed
        \echo :ts 'DEP::OK timescaledb installed & preloaded'
      \else
        \echo :ts 'FATAL: timescaledb is available and preloaded, but NOT installed in ' :"APP_DB"
        \echo '         Fix: \connect ' :APP_DB ' ; CREATE EXTENSION timescaledb;'
        \quit
      \endif
    \else
      \echo :ts 'FATAL: timescaledb requires shared_preload_libraries but is NOT preloaded.'
      \echo '         Fix: ALTER SYSTEM SET shared_preload_libraries = ''timescaledb,pg_stat_statements,...'' ; restart PostgreSQL.'
      \quit
    \endif
  \else
    \echo :ts 'FATAL: timescaledb is NOT available on this server.'
    \echo '         Fix: install the TimescaleDB package for your PostgreSQL version and restart.'
    \quit 
  \endif
\endif

-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

-- PGVECTOR
\if :require_pgvector
  \if :vec_available
    \if :vec_installed
      \echo :ts 'DEP::OK pgvector installed'
    \else
      \echo :ts 'FATAL: pgvector is available but NOT installed in ' :"APP_DB"
      \echo '         Fix: \connect ' :APP_DB ' ; CREATE EXTENSION vector;'
      \quit
    \endif
  \else
    \echo :ts 'FATAL: pgvector extension is NOT available on this server.'
    \echo '         Fix: install pgvector for your PostgreSQL version (package or from source), then CREATE EXTENSION vector;'
    \quit 
  \endif
\else
  -- optional mode: only warn in logs, continue
  \if :vec_available
    \if :vec_installed
      \echo :ts 'DEP::OK pgvector installed (optional)'
    \else
      \echo :ts 'DEP::WARN pgvector available but not installed (optional)'
    \endif
  \else
    \echo :ts 'DEP::WARN pgvector not available (optional)'
  \endif
\endif

-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

-- PARTMAN (optional by default)
\if :require_partman
  \if :partman_available
    \if :partman_installed
      \echo :ts 'DEP::OK pg_partman installed'
    \else
      \echo :ts 'FATAL: pg_partman is available but NOT installed in ' :"APP_DB"
      \echo '       Fix: \connect ' :APP_DB ' ; CREATE EXTENSION pg_partman;'
      \quit 
    \endif
  \else
    \echo :ts 'FATAL: pg_partman is NOT available on this server.'
    \echo '         Fix: install pg_partman package/source for your PG version, then CREATE EXTENSION pg_partman;'
    \quit 
  \endif
\else
  \if :partman_installed
    \echo :ts 'DEP::OK pg_partman installed (optional)'
  \endif
\endif
-- ===== End dependency gate ==================================================

-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

-- ===== Timescale hypertable (quiet & safe) =====

-- Create metrics_ts only if absent (avoid NOTICE)
SELECT EXISTS (
  SELECT 1
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relname = 'metrics_ts' AND c.relkind = 'r'
) AS has_metrics_ts \gset

\if :has_metrics_ts
  \echo :ts 'TABLE::metrics_ts already exists'
\else
  -- pgvector is required by your gate, so embed the column directly
  CREATE TABLE public.metrics_ts
  (
    ts          timestamptz   NOT NULL,
    device_id   bigint        NOT NULL,
    speed_kph   real,
    heading_deg real,
    loc         geography(Point,4326),
    embedding   vector(384),
    PRIMARY KEY (ts, device_id)
  );
  \echo :ts 'TABLE::metrics_ts created'
\endif


-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

-- Make hypertable & policies only if timescaledb is installed
\if :tsdb_installed

  -- Already a hypertable?
  SELECT EXISTS (
    SELECT 1
    FROM timescaledb_information.hypertables
    WHERE hypertable_schema='public' AND hypertable_name='metrics_ts'
  ) AS metrics_ts_is_ht \gset

  \if :metrics_ts_is_ht
    \echo :ts 'TSDB::HT metrics_ts already hypertable'
  \else
    SELECT create_hypertable(
      'metrics_ts','ts',
      chunk_time_interval => interval '7 days',
      if_not_exists => TRUE
    );
    \echo :ts 'TSDB::HT created (7d chunks)'
  \endif

  -- refresh [ts]
  SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

  -- Enable compression BEFORE adding compression policy
  SELECT COALESCE((
    SELECT compression_enabled
    FROM   timescaledb_information.hypertables
    WHERE  hypertable_schema='public' AND hypertable_name='metrics_ts'
  ), false) AS metrics_ts_compression_on \gset

  \if :metrics_ts_compression_on
    \echo :ts 'TSDB::HT compression already enabled'
  \else
    ALTER TABLE public.metrics_ts
      SET (timescaledb.compress = true,
           timescaledb.compress_segmentby = 'device_id');
    \echo :ts 'TSDB::HT compression enabled (segmentby=device_id)'
  \endif

  -- refresh [ts]
  SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

  -- Retention policy (180d): add only if missing
  SELECT EXISTS (
    SELECT 1
    FROM timescaledb_information.jobs
    WHERE hypertable_schema = 'public'
      AND hypertable_name   = 'metrics_ts'
      AND proc_schema       = 'timescaledb'
      AND proc_name         = 'policy_retention'
  ) AS metrics_ts_has_retention \gset

  \if :metrics_ts_has_retention
    \echo :ts 'TSDB::POLICY retention already present (metrics_ts)'
  \else
    SELECT add_retention_policy('metrics_ts', INTERVAL '180 days', if_not_exists => TRUE);
    \echo :ts 'TSDB::POLICY retention 180d added'
  \endif

  -- -- Fallback (optional): check retention via config tables
  -- SELECT EXISTS (
  --   SELECT 1
  --   FROM _timescaledb_config.bgw_policy_retention pr
  --   JOIN _timescaledb_catalog.hypertable ht ON ht.id = pr.hypertable_id
  --   JOIN _timescaledb_catalog.schema_name s ON s.id = ht.schema_name AND s.name = 'public'
  --   JOIN _timescaledb_catalog.hypertable_name htn ON htn.id = ht.table_name AND htn.name = 'metrics_ts'
  -- ) AS metrics_ts_has_retention_cfg \gset

  -- refresh [ts]
  SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

  -- Compression policy (30d): add only if missing (now safe: compression is ON)
  SELECT EXISTS (
  SELECT 1
  FROM timescaledb_information.jobs
  WHERE hypertable_schema = 'public'
    AND hypertable_name   = 'metrics_ts'
    AND proc_schema       = 'timescaledb'
    AND proc_name         = 'policy_compression'
) AS metrics_ts_has_comp_policy \gset

  \if :metrics_ts_has_comp_policy
    \echo :ts 'TSDB::POLICY compression already present (metrics_ts)'
  \else
    SELECT add_compression_policy('metrics_ts', INTERVAL '30 days', if_not_exists => TRUE);
    \echo :ts 'TSDB::POLICY compression 30d added'
  \endif

\else
  \echo :ts 'TSDB::SKIP timescaledb not installed (gate should catch this)'
\endif

-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset

-- Supporting indexes (IF NOT EXISTS is quiet for indexes)
CREATE INDEX IF NOT EXISTS metrics_ts_device_ts_btree ON public.metrics_ts (device_id, ts DESC);
CREATE INDEX IF NOT EXISTS metrics_ts_ts_brin         ON public.metrics_ts USING brin (ts);
CREATE INDEX IF NOT EXISTS metrics_ts_loc_gist        ON public.metrics_ts USING gist (loc);

-- ===== pg_partman native partition registration (quiet & version-aware) =====
\if :partman_installed
  \echo :ts 'EXT::PARTMAN partman not yet implemented for this example'
\endif



-- refresh [ts]
SELECT '[' || to_char(clock_timestamp(),'YY.MM.DD HH24:MI:SS.MS TZ') || ']' AS ts \gset
\echo :ts '=== 02 Schema Timeseries init finished ==='