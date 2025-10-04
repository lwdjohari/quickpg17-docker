\connect :"APP_DB"

-- Timescale hypertable
CREATE TABLE IF NOT EXISTS metrics_ts
(
  ts          timestamptz   NOT NULL,
  device_id   bigint        NOT NULL,
  speed_kph   real,
  heading_deg real,
  loc         geography(Point,4326),
  embedding   vector(384),
  PRIMARY KEY (ts, device_id)
);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname='timescaledb') THEN
    PERFORM create_hypertable('metrics_ts','ts', chunk_time_interval => interval '7 days', if_not_exists => TRUE);
    PERFORM add_retention_policy('metrics_ts', INTERVAL '180 days', if_not_exists => TRUE);
    PERFORM add_compression_policy('metrics_ts', INTERVAL '30 days',  if_not_exists => TRUE);
    ALTER TABLE metrics_ts SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_id');
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS metrics_ts_device_ts_btree ON metrics_ts (device_id, ts DESC);
CREATE INDEX IF NOT EXISTS metrics_ts_ts_brin         ON metrics_ts USING brin (ts);
CREATE INDEX IF NOT EXISTS metrics_ts_loc_gist        ON metrics_ts USING gist (loc);

-- pg_partman native partition example
CREATE TABLE IF NOT EXISTS metrics_part
(
  ts          timestamptz   NOT NULL,
  device_id   bigint        NOT NULL,
  speed_kph   real,
  heading_deg real,
  loc         geography(Point,4326),
  embedding   vector(384)
) PARTITION BY RANGE (ts);

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname='pg_partman') THEN
    PERFORM partman.create_parent(
      p_parent_table := 'public.metrics_part',
      p_control      := 'ts',
      p_type         := 'native',
      p_interval     := 'daily',
      p_infinite_time_partitions := FALSE,
      p_template_table := NULL,
      p_use_run_maintenance := TRUE
    );
  END IF;
END $$;
