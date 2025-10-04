DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'DB_NAME') THEN
    EXECUTE format(
      'CREATE DATABASE %I WITH TEMPLATE template0 ENCODING ''UTF8'' LC_COLLATE ''C'' LC_CTYPE ''C'';',
      :'DB_NAME'
    );
  END IF;
END$$;
