\connect :"APP_DB"

-- FTS demo
CREATE TABLE IF NOT EXISTS doc_search
(
  id    bigserial PRIMARY KEY,
  title text NOT NULL,
  body  text NOT NULL,
  tsv   tsvector
);

CREATE OR REPLACE FUNCTION doc_search_tsv_update() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.tsv := to_tsvector('simple_unaccent', coalesce(NEW.title,'') || ' ' || coalesce(NEW.body,''));
  RETURN NEW;
END$$;

DROP TRIGGER IF EXISTS trg_doc_search_tsv ON doc_search;
CREATE TRIGGER trg_doc_search_tsv
BEFORE INSERT OR UPDATE ON doc_search
FOR EACH ROW EXECUTE FUNCTION doc_search_tsv_update();

CREATE INDEX IF NOT EXISTS doc_search_tsv_gin   ON doc_search USING gin(tsv);
CREATE INDEX IF NOT EXISTS doc_search_title_trg ON doc_search USING gin (title gin_trgm_ops);

-- GIS sanity (distance Jakarta ↔ Singapore, meters)
WITH a AS (
  SELECT ST_GeogFromText('POINT(106.8451 -6.2146)') AS jakarta,
         ST_GeogFromText('POINT(103.8198  1.3521)') AS singapore
)
SELECT ST_Distance(jakarta, singapore) AS meters FROM a;
