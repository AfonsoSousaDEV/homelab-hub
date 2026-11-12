-- Apply once after 001, including on databases with existing execution history.
-- Adds a guard only; no execution records are modified or removed.
BEGIN;

CREATE FUNCTION metrics.protect_completed_run() RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    IF OLD.status <> 'running' AND NEW IS DISTINCT FROM OLD THEN
        RAISE EXCEPTION 'Completed workflow runs cannot be changed'
            USING ERRCODE = '23514', CONSTRAINT = 'completed_run_immutable';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER protect_completed_run
BEFORE UPDATE ON metrics.workflow_runs
FOR EACH ROW EXECUTE FUNCTION metrics.protect_completed_run();

COMMIT;
