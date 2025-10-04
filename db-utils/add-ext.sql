\connect :"DB_NAME"

DO $$
DECLARE
  raw_list  text := :'EXTENSIONS';
  item      text;
  ext_name  text;
  ext_schem text;
  parts     text[];
  preload text := current_setting('shared_preload_libraries', true);
  requires_preload CONSTANT text[] := ARRAY['timescaledb','pg_cron','pg_stat_statements','pg_partman_bgw'];
  require_preload boolean := (:'REQUIRE_PRELOAD' = 'true');
BEGIN
  IF raw_list IS NULL OR length(btrim(raw_list))=0 THEN
    RAISE NOTICE 'No extensions specified.'; RETURN;
  END IF;

  FOREACH item IN ARRAY regexp_split_to_array(raw_list, '\s*,\s*') LOOP
    IF item IS NULL OR length(item)=0 THEN CONTINUE; END IF;

    parts    := regexp_split_to_array(item, ':');
    ext_name := parts[1];
    ext_schem:= COALESCE(parts[2], NULL);

    IF NOT EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = ext_name) THEN
      RAISE NOTICE 'Skipping %, not available', ext_name; CONTINUE;
    END IF;

    IF ext_name = ANY(requires_preload) THEN
      IF preload IS NULL OR position(ext_name in preload) = 0 THEN
        IF require_preload THEN
          RAISE EXCEPTION 'Preload % missing in shared_preload_libraries (current=%)', ext_name, preload;
        ELSE
          RAISE WARNING 'Preload % missing (current=%). Will require config+restart.', ext_name, preload;
        END IF;
      END IF;
    END IF;

    IF ext_schem IS NOT NULL THEN
      EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I;', ext_schem);
      EXECUTE format('CREATE EXTENSION IF NOT EXISTS %I SCHEMA %I;', ext_name, ext_schem);
    ELSE
      EXECUTE format('CREATE EXTENSION IF NOT EXISTS %I;', ext_name);
    END IF;
    RAISE NOTICE 'Ensured extension % (schema=%)', ext_name, COALESCE(ext_schem,'default');
  END LOOP;
END$$;
