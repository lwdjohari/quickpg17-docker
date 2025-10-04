\connect :"DB_NAME"

DO $$
DECLARE
  raw_list text := :'EXTENSIONS';
  item     text;
  parts    text[];
  ext_name text;
  cascade  boolean := (:'DROP_CASCADE' = 'true');
  dangerous_ok boolean := (:'DANGEROUS_OK' = 'true');
  dangerous CONSTANT text[] := ARRAY['timescaledb','postgis','postgis_topology','postgis_raster'];
BEGIN
  IF raw_list IS NULL OR length(btrim(raw_list))=0 THEN
    RAISE NOTICE 'No extensions specified.'; RETURN;
  END IF;

  FOREACH item IN ARRAY regexp_split_to_array(raw_list, '\s*,\s*') LOOP
    IF item IS NULL OR length(item)=0 THEN CONTINUE; END IF;

    parts := regexp_split_to_array(item, ':');
    ext_name := parts[1];

    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = ext_name) THEN
      RAISE NOTICE 'Extension % not installed; skipping.', ext_name; CONTINUE;
    END IF;

    IF ext_name = ANY(dangerous) AND NOT dangerous_ok THEN
      RAISE EXCEPTION 'Refusing to drop % without DANGEROUS_OK=true.', ext_name;
    END IF;

    IF cascade THEN
      EXECUTE format('DROP EXTENSION IF EXISTS %I CASCADE;', ext_name);
    ELSE
      EXECUTE format('DROP EXTENSION IF EXISTS %I;', ext_name);
    END IF;
    RAISE NOTICE 'Dropped extension % (cascade=%)', ext_name, cascade;
  END LOOP;
END$$;
