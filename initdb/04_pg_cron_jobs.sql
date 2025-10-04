\connect :"APP_DB"

CREATE SCHEMA IF NOT EXISTS admin;

-- Nightly ANALYZE
SELECT cron.schedule('analyze-nightly', '5 3 * * *',
$$
  DO $$
  DECLARE r RECORD;
  BEGIN
    FOR r IN
      SELECT c.oid::regclass AS tbl
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relkind='r' AND n.nspname IN ('public','partman')
    LOOP
      EXECUTE format('ANALYZE VERBOSE %s;', r.tbl);
    END LOOP;
  END$$;
$$);

-- Weekly bloat snapshot using pgstattuple_approx
CREATE TABLE IF NOT EXISTS admin.tbl_bloat_report
(
  run_at timestamptz NOT NULL DEFAULT now(),
  rel regclass NOT NULL,
  table_len bigint, tuple_count bigint, tuple_len bigint,
  tuple_percent numeric, dead_tuple_count bigint, dead_tuple_len bigint, dead_tuple_percent numeric,
  free_space bigint, free_percent numeric
);

SELECT cron.schedule('bloat-weekly', '10 3 * * 0',
$$
  INSERT INTO admin.tbl_bloat_report(rel,table_len,tuple_count,tuple_len,tuple_percent,
                                     dead_tuple_count,dead_tuple_len,dead_tuple_percent,
                                     free_space,free_percent)
  SELECT c.oid::regclass,
         (pgstattuple_approx(c.oid)).*
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE c.relkind='r' AND n.nspname IN ('public','partman');
$$);

-- Hourly pg_partman maintenance
SELECT cron.schedule('partman-maint', '0 * * * *', $$ SELECT partman.run_maintenance(); $$);
