\set ON_ERROR_STOP 1

-- Create DB (only if APP_DB is provided; psql-level conditional)
\if :{?APP_DB}
\if '' <> :'APP_DB'
  -- If you need idempotency and PG >= 15 supports IF NOT EXISTS for DBs in your build, you can use it.
  -- Otherwise rely on first-boot creation (recommended).
  CREATE DATABASE :"APP_DB";
\endif
\endif

-- Create roles if missing (idempotent)
DO $$
BEGIN
  IF :'DBA_USER' IS NOT NULL AND :'DBA_USER' <> '' AND
     NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'DBA_USER') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L CREATEDB CREATEROLE;', :'DBA_USER', :'DBA_PASSWORD');
  END IF;

  IF :'RW_USER' IS NOT NULL AND :'RW_USER' <> '' AND
     NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'RW_USER') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L;', :'RW_USER', :'RW_PASSWORD');
  END IF;

  IF :'RO_USER' IS NOT NULL AND :'RO_USER' <> '' AND
     NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'RO_USER') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L;', :'RO_USER', :'RO_PASSWORD');
  END IF;
END$$;

-- Make DBA owner of the DB (only if both provided)
\if :{?APP_DB}
\if :{?DBA_USER}
\if '' <> :'APP_DB'
\if '' <> :'DBA_USER'
  ALTER DATABASE :"APP_DB" OWNER TO :"DBA_USER";
\endif
\endif
\endif
\endif

-- Connect to the APP_DB if provided
\if :{?APP_DB}
\if '' <> :'APP_DB'
\connect :"APP_DB"
\endif
\endif

-- Ensure partman schema and grants
\if :{?DBA_USER}
CREATE SCHEMA IF NOT EXISTS partman AUTHORIZATION :"DBA_USER";
\endif

-- Direct schema grants (current DB)
\if :{?DBA_USER}
GRANT ALL ON SCHEMA public TO :"DBA_USER";
\endif
\if :{?RW_USER}
\if :{?RO_USER}
GRANT USAGE ON SCHEMA public TO :"RW_USER", :"RO_USER";
GRANT USAGE ON SCHEMA partman TO :"RW_USER", :"RO_USER";
\else
\if :{?RW_USER}
GRANT USAGE ON SCHEMA public TO :"RW_USER";
GRANT USAGE ON SCHEMA partman TO :"RW_USER";
\endif
\if :{?RO_USER}
GRANT USAGE ON SCHEMA public TO :"RO_USER";
GRANT USAGE ON SCHEMA partman TO :"RO_USER";
\endif
\endif
\endif

-- Default privileges:
-- IMPORTANT: Default privileges apply to objects CREATED BY the specified role.
-- Typically you want defaults for objects created by the *DBA_USER* in this DB.
\if :{?DBA_USER}

-- For future TABLES in schema public created by DBA_USER:
\if :{?RW_USER}
ALTER DEFAULT PRIVILEGES FOR ROLE :"DBA_USER" IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"RW_USER";
\endif
\if :{?RO_USER}
ALTER DEFAULT PRIVILEGES FOR ROLE :"DBA_USER" IN SCHEMA public
  GRANT SELECT ON TABLES TO :"RO_USER";
\endif

-- For future SCHEMAS created by DBA_USER (note: NO "IN SCHEMA" here):
-- Granting USAGE, CREATE on new schemas to DBA_USER is usually redundant (they own them),
-- but keep it if you intended it. Otherwise, grant to RW/RO as needed.
ALTER DEFAULT PRIVILEGES FOR ROLE :"DBA_USER"
  GRANT USAGE, CREATE ON SCHEMAS TO :"DBA_USER";

\endif
