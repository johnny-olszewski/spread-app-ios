-- Migration: tombstone_cleanup_job
-- Task: SPRD-89
-- Description: Scheduled job to hard-delete soft-deleted rows older than 90 days.
-- Uses pg_cron to run daily at 03:00 UTC.
-- Executes with service role privileges, bypassing RLS.

-- 0. Ensure pg_cron extension is enabled
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
GRANT USAGE ON SCHEMA cron TO postgres;

-- 1. Create the cleanup function
CREATE OR REPLACE FUNCTION cleanup_tombstones()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    cutoff timestamptz := now() - interval '90 days';
BEGIN
    -- Delete child assignments first (FK CASCADE would handle this,
    -- but explicit ordering avoids reliance on cascade timing).
    DELETE FROM task_assignments WHERE deleted_at IS NOT NULL AND deleted_at < cutoff;
    DELETE FROM note_assignments WHERE deleted_at IS NOT NULL AND deleted_at < cutoff;

    -- Delete parent entries
    DELETE FROM tasks WHERE deleted_at IS NOT NULL AND deleted_at < cutoff;
    DELETE FROM notes WHERE deleted_at IS NOT NULL AND deleted_at < cutoff;

    -- Delete other entities
    DELETE FROM spreads WHERE deleted_at IS NOT NULL AND deleted_at < cutoff;
    DELETE FROM collections WHERE deleted_at IS NOT NULL AND deleted_at < cutoff;
    DELETE FROM settings WHERE deleted_at IS NOT NULL AND deleted_at < cutoff;
END;
$$;

-- Restrict execution to service role only
REVOKE ALL ON FUNCTION cleanup_tombstones() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION cleanup_tombstones() TO service_role;

-- 2. Schedule the cron job: daily at 03:00 UTC
SELECT cron.schedule(
    'cleanup-tombstones',          -- job name
    '0 3 * * *',                   -- cron expression: daily at 03:00 UTC
    $$SELECT cleanup_tombstones()$$
);
