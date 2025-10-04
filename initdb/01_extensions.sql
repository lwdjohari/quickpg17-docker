\connect :"APP_DB"

-- PostGIS stack
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name='postgis') THEN
    EXECUTE 'CREATE EXTENSION IF NOT EXISTS postgis;';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name='postgis_topology') THEN
    EXECUTE 'CREATE EXTENSION IF NOT EXISTS postgis_topology;';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name='postgis_raster') THEN
    EXECUTE 'CREATE EXTENSION IF NOT EXISTS postgis_raster;';
  END IF;
END$$;

-- Generic set (auto-if-available)
DO $$
DECLARE ext TEXT;
BEGIN
  FOR ext IN SELECT unnest(ARRAY[
    'pgcrypto','hstore','pg_trgm','unaccent','pg_stat_statements',
    'pgstattuple','pgvector','pg_partman','pg_cron','pg_repack',
    'pg_stat_kcache','pg_buffercache','hypopg'
  ]) LOOP
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = ext) THEN
      EXECUTE format('CREATE EXTENSION IF NOT EXISTS %I;', ext);
    END IF;
  END LOOP;
END$$;

-- TimescaleDB
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name='timescaledb') THEN
    EXECUTE 'CREATE EXTENSION IF NOT EXISTS timescaledb;';
  END IF;
END $$;

-- Text search config (unaccent chain)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname = 'simple_unaccent') THEN
    CREATE TEXT SEARCH CONFIGURATION simple_unaccent ( COPY = simple );
    ALTER TEXT SEARCH CONFIGURATION simple_unaccent
      ALTER MAPPING FOR hword, hword_part, word
      WITH unaccent, simple;
  END IF;
END $$;

-- pg_partman bgw
SELECT set_config('pg_partman_bgw.interval','3600',false);
SELECT set_config('pg_partman_bgw.role',:'DBA_USER',false);
