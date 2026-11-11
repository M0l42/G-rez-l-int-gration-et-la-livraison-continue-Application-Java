-- The seed dump assigns ownership to "postgres", which does not exist when
-- POSTGRES_USER is something else. Create it (idempotently) before the dump runs.
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'postgres') THEN
    CREATE ROLE postgres;
  END IF;
END $$;
