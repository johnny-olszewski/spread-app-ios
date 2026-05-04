-- Migration: sprd193_multiday_assignment_spread_id
-- Description: Preserve explicit multiday assignment ownership via spread_id.

ALTER TABLE public.task_assignments
    ADD COLUMN IF NOT EXISTS spread_id uuid;

ALTER TABLE public.note_assignments
    ADD COLUMN IF NOT EXISTS spread_id uuid;

ALTER TABLE public.task_assignments
    DROP CONSTRAINT IF EXISTS task_assignments_spread_id_fkey,
    ADD CONSTRAINT task_assignments_spread_id_fkey
        FOREIGN KEY (spread_id) REFERENCES public.spreads(id) ON DELETE SET NULL;

ALTER TABLE public.note_assignments
    DROP CONSTRAINT IF EXISTS note_assignments_spread_id_fkey,
    ADD CONSTRAINT note_assignments_spread_id_fkey
        FOREIGN KEY (spread_id) REFERENCES public.spreads(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS task_assignments_spread_id_idx
    ON public.task_assignments USING btree (spread_id);

CREATE INDEX IF NOT EXISTS note_assignments_spread_id_idx
    ON public.note_assignments USING btree (spread_id);

DROP INDEX IF EXISTS public.task_assignments_user_task_period_date_unique;
DROP INDEX IF EXISTS public.note_assignments_user_note_period_date_unique;

CREATE UNIQUE INDEX IF NOT EXISTS task_assignments_user_task_period_date_unique
    ON public.task_assignments USING btree (user_id, task_id, period, date)
    WHERE ((deleted_at IS NULL) AND (spread_id IS NULL));

CREATE UNIQUE INDEX IF NOT EXISTS task_assignments_user_task_multiday_spread_unique
    ON public.task_assignments USING btree (user_id, task_id, spread_id)
    WHERE ((deleted_at IS NULL) AND (spread_id IS NOT NULL));

CREATE UNIQUE INDEX IF NOT EXISTS note_assignments_user_note_period_date_unique
    ON public.note_assignments USING btree (user_id, note_id, period, date)
    WHERE ((deleted_at IS NULL) AND (spread_id IS NULL));

CREATE UNIQUE INDEX IF NOT EXISTS note_assignments_user_note_multiday_spread_unique
    ON public.note_assignments USING btree (user_id, note_id, spread_id)
    WHERE ((deleted_at IS NULL) AND (spread_id IS NOT NULL));

DROP FUNCTION IF EXISTS public.merge_task_assignment(
    uuid, uuid, uuid, uuid, text, date, text,
    timestamp with time zone, timestamp with time zone, timestamp with time zone
);

DROP FUNCTION IF EXISTS public.merge_note_assignment(
    uuid, uuid, uuid, uuid, text, date, text,
    timestamp with time zone, timestamp with time zone, timestamp with time zone
);

CREATE OR REPLACE FUNCTION public.merge_task_assignment(
    p_id uuid,
    p_user_id uuid,
    p_device_id uuid,
    p_task_id uuid,
    p_period text,
    p_date date,
    p_spread_id uuid,
    p_status text,
    p_created_at timestamp with time zone,
    p_deleted_at timestamp with time zone,
    p_status_updated_at timestamp with time zone
) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_existing RECORD;
    v_result RECORD;
BEGIN
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    SELECT * INTO v_existing FROM task_assignments WHERE id = p_id AND user_id = p_user_id;

    IF NOT FOUND THEN
        SELECT * INTO v_existing
        FROM task_assignments
        WHERE user_id = p_user_id
          AND task_id = p_task_id
          AND (
              (p_spread_id IS NOT NULL AND spread_id = p_spread_id)
              OR (
                  p_spread_id IS NULL
                  AND spread_id IS NULL
                  AND period = p_period
                  AND date = p_date
              )
          )
        ORDER BY CASE WHEN deleted_at IS NULL THEN 0 ELSE 1 END, created_at
        LIMIT 1;
    END IF;

    IF NOT FOUND THEN
        BEGIN
            INSERT INTO task_assignments (
                id, user_id, device_id, task_id, period, date, spread_id, status,
                created_at, deleted_at, status_updated_at
            ) VALUES (
                p_id, p_user_id, p_device_id, p_task_id, p_period, p_date, p_spread_id, p_status,
                p_created_at, p_deleted_at, p_status_updated_at
            )
            RETURNING * INTO v_result;
        EXCEPTION
            WHEN unique_violation THEN
                SELECT * INTO v_existing
                FROM task_assignments
                WHERE user_id = p_user_id
                  AND task_id = p_task_id
                  AND (
                      (p_spread_id IS NOT NULL AND spread_id = p_spread_id)
                      OR (
                          p_spread_id IS NULL
                          AND spread_id IS NULL
                          AND period = p_period
                          AND date = p_date
                      )
                  )
                ORDER BY CASE WHEN deleted_at IS NULL THEN 0 ELSE 1 END, created_at
                LIMIT 1;

                IF NOT FOUND THEN
                    RAISE;
                END IF;
        END;

        IF v_result IS NOT NULL THEN
            RETURN to_jsonb(v_result);
        END IF;
    ELSE
        IF p_deleted_at IS NOT NULL AND (v_existing.deleted_at IS NULL OR p_deleted_at > v_existing.deleted_at) THEN
            UPDATE task_assignments SET deleted_at = p_deleted_at, device_id = p_device_id
            WHERE id = v_existing.id RETURNING * INTO v_result;
        ELSE
            UPDATE task_assignments SET
                device_id = p_device_id,
                spread_id = COALESCE(v_existing.spread_id, p_spread_id),
                status = CASE WHEN p_status_updated_at > v_existing.status_updated_at THEN p_status ELSE v_existing.status END,
                status_updated_at = GREATEST(p_status_updated_at, v_existing.status_updated_at)
            WHERE id = v_existing.id RETURNING * INTO v_result;
        END IF;
    END IF;

    RETURN to_jsonb(v_result);
END;
$$;

CREATE OR REPLACE FUNCTION public.merge_note_assignment(
    p_id uuid,
    p_user_id uuid,
    p_device_id uuid,
    p_note_id uuid,
    p_period text,
    p_date date,
    p_spread_id uuid,
    p_status text,
    p_created_at timestamp with time zone,
    p_deleted_at timestamp with time zone,
    p_status_updated_at timestamp with time zone
) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_existing RECORD;
    v_result RECORD;
BEGIN
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    SELECT * INTO v_existing FROM note_assignments WHERE id = p_id AND user_id = p_user_id;

    IF NOT FOUND THEN
        SELECT * INTO v_existing
        FROM note_assignments
        WHERE user_id = p_user_id
          AND note_id = p_note_id
          AND (
              (p_spread_id IS NOT NULL AND spread_id = p_spread_id)
              OR (
                  p_spread_id IS NULL
                  AND spread_id IS NULL
                  AND period = p_period
                  AND date = p_date
              )
          )
        ORDER BY CASE WHEN deleted_at IS NULL THEN 0 ELSE 1 END, created_at
        LIMIT 1;
    END IF;

    IF NOT FOUND THEN
        BEGIN
            INSERT INTO note_assignments (
                id, user_id, device_id, note_id, period, date, spread_id, status,
                created_at, deleted_at, status_updated_at
            ) VALUES (
                p_id, p_user_id, p_device_id, p_note_id, p_period, p_date, p_spread_id, p_status,
                p_created_at, p_deleted_at, p_status_updated_at
            )
            RETURNING * INTO v_result;
        EXCEPTION
            WHEN unique_violation THEN
                SELECT * INTO v_existing
                FROM note_assignments
                WHERE user_id = p_user_id
                  AND note_id = p_note_id
                  AND (
                      (p_spread_id IS NOT NULL AND spread_id = p_spread_id)
                      OR (
                          p_spread_id IS NULL
                          AND spread_id IS NULL
                          AND period = p_period
                          AND date = p_date
                      )
                  )
                ORDER BY CASE WHEN deleted_at IS NULL THEN 0 ELSE 1 END, created_at
                LIMIT 1;

                IF NOT FOUND THEN
                    RAISE;
                END IF;
        END;

        IF v_result IS NOT NULL THEN
            RETURN to_jsonb(v_result);
        END IF;
    ELSE
        IF p_deleted_at IS NOT NULL AND (v_existing.deleted_at IS NULL OR p_deleted_at > v_existing.deleted_at) THEN
            UPDATE note_assignments SET deleted_at = p_deleted_at, device_id = p_device_id
            WHERE id = v_existing.id RETURNING * INTO v_result;
        ELSE
            UPDATE note_assignments SET
                device_id = p_device_id,
                spread_id = COALESCE(v_existing.spread_id, p_spread_id),
                status = CASE WHEN p_status_updated_at > v_existing.status_updated_at THEN p_status ELSE v_existing.status END,
                status_updated_at = GREATEST(p_status_updated_at, v_existing.status_updated_at)
            WHERE id = v_existing.id RETURNING * INTO v_result;
        END IF;
    END IF;

    RETURN to_jsonb(v_result);
END;
$$;

NOTIFY pgrst, 'reload schema';
