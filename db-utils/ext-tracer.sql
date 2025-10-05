-- Reset any aborted transaction first
ROLLBACK;

BEGIN;

CREATE TEMP TABLE ext_probe_result (
  name            text PRIMARY KEY,
  installed       boolean,
  loadable_now    boolean,
  needs_preload   boolean,
  message         text
);

DO $$
DECLARE
  r   record;
  msg text;
BEGIN
  -- Choose which extensions to check: (use WHERE name IN (...) to limit)
  FOR r IN
    SELECT name
    FROM pg_available_extensions
    -- WHERE name IN ('postgis','pg_stat_statements','pg_cron','timescaledb','pg_uuidv7',
    --                'pgvector','pg_partman','pg_repack','pg_buffercache','hypopg',
    --                'pg_trgm','unaccent','pgcrypto','hstore','pg_stat_kcache')
  LOOP
    -- Already installed?
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = r.name) THEN
      INSERT INTO ext_probe_result(name, installed, loadable_now, needs_preload, message)
      VALUES (r.name, true, NULL, NULL, 'already installed');
      CONTINUE;
    END IF;

    -- Try to create; if it works, drop it again (we're in a tx)
    BEGIN
      EXECUTE format('CREATE EXTENSION %I', r.name);
      EXECUTE format('DROP EXTENSION %I', r.name);

      INSERT INTO ext_probe_result(name, installed, loadable_now, needs_preload, message)
      VALUES (r.name, false, true, false, 'can create now');

    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS msg = MESSAGE_TEXT;

      INSERT INTO ext_probe_result(name, installed, loadable_now, needs_preload, message)
      VALUES (
        r.name, false, false,
        position('shared_preload_libraries' IN msg) > 0,
        msg
      );
      -- Exception block automatically rolls back its own subtransaction; loop continues.
    END;
  END LOOP;
END $$;

-- Results
SELECT
  name,
  installed,
  COALESCE(loadable_now,false)  AS can_create_now,
  COALESCE(needs_preload,false) AS requires_preload,
  message
FROM ext_probe_result
ORDER BY name;

-- Throw away any temp install attempts
ROLLBACK;
