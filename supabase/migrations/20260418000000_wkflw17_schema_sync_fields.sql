-- Migration: wkflw17_schema_sync_fields
-- Description: Add spread personalization and richer task metadata sync fields.

ALTER TABLE public.spreads
    ADD COLUMN IF NOT EXISTS is_favorite boolean DEFAULT false NOT NULL,
    ADD COLUMN IF NOT EXISTS custom_name text,
    ADD COLUMN IF NOT EXISTS uses_dynamic_name boolean DEFAULT false NOT NULL,
    ADD COLUMN IF NOT EXISTS is_favorite_updated_at timestamp with time zone,
    ADD COLUMN IF NOT EXISTS custom_name_updated_at timestamp with time zone,
    ADD COLUMN IF NOT EXISTS uses_dynamic_name_updated_at timestamp with time zone;

UPDATE public.spreads
SET
    is_favorite_updated_at = COALESCE(is_favorite_updated_at, updated_at, created_at),
    custom_name_updated_at = COALESCE(custom_name_updated_at, updated_at, created_at),
    uses_dynamic_name_updated_at = COALESCE(uses_dynamic_name_updated_at, updated_at, created_at);

ALTER TABLE public.spreads
    ALTER COLUMN is_favorite_updated_at SET DEFAULT now(),
    ALTER COLUMN is_favorite_updated_at SET NOT NULL,
    ALTER COLUMN custom_name_updated_at SET DEFAULT now(),
    ALTER COLUMN custom_name_updated_at SET NOT NULL,
    ALTER COLUMN uses_dynamic_name_updated_at SET DEFAULT now(),
    ALTER COLUMN uses_dynamic_name_updated_at SET NOT NULL;

ALTER TABLE public.tasks
    ADD COLUMN IF NOT EXISTS body text,
    ADD COLUMN IF NOT EXISTS priority text DEFAULT 'none' NOT NULL,
    ADD COLUMN IF NOT EXISTS due_date date,
    ADD COLUMN IF NOT EXISTS body_updated_at timestamp with time zone,
    ADD COLUMN IF NOT EXISTS priority_updated_at timestamp with time zone,
    ADD COLUMN IF NOT EXISTS due_date_updated_at timestamp with time zone;

UPDATE public.tasks
SET
    body_updated_at = COALESCE(body_updated_at, updated_at, created_at),
    priority_updated_at = COALESCE(priority_updated_at, updated_at, created_at),
    due_date_updated_at = COALESCE(due_date_updated_at, updated_at, created_at);

ALTER TABLE public.tasks
    ALTER COLUMN date DROP NOT NULL,
    ALTER COLUMN period DROP NOT NULL,
    ALTER COLUMN body_updated_at SET DEFAULT now(),
    ALTER COLUMN body_updated_at SET NOT NULL,
    ALTER COLUMN priority_updated_at SET DEFAULT now(),
    ALTER COLUMN priority_updated_at SET NOT NULL,
    ALTER COLUMN due_date_updated_at SET DEFAULT now(),
    ALTER COLUMN due_date_updated_at SET NOT NULL,
    DROP CONSTRAINT IF EXISTS tasks_period_check,
    ADD CONSTRAINT tasks_period_check CHECK (
        period IS NULL OR period = ANY (ARRAY['year'::text, 'month'::text, 'day'::text, 'multiday'::text])
    ),
    DROP CONSTRAINT IF EXISTS tasks_priority_check,
    ADD CONSTRAINT tasks_priority_check CHECK (
        priority = ANY (ARRAY['none'::text, 'low'::text, 'medium'::text, 'high'::text])
    );

DROP FUNCTION IF EXISTS public.merge_spread(
    uuid, uuid, uuid, text, date, date, date,
    timestamp with time zone, timestamp with time zone,
    timestamp with time zone, timestamp with time zone,
    timestamp with time zone, timestamp with time zone
);

DROP FUNCTION IF EXISTS public.merge_task(
    uuid, uuid, uuid, text, date, text, text,
    timestamp with time zone, timestamp with time zone,
    timestamp with time zone, timestamp with time zone,
    timestamp with time zone, timestamp with time zone
);

CREATE OR REPLACE FUNCTION public.spreads_trigger_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.revision := next_revision();
    NEW.updated_at := now();

    IF TG_OP = 'INSERT' THEN
        NEW.period_updated_at := COALESCE(NEW.period_updated_at, now());
        NEW.date_updated_at := COALESCE(NEW.date_updated_at, now());
        NEW.start_date_updated_at := COALESCE(NEW.start_date_updated_at, now());
        NEW.end_date_updated_at := COALESCE(NEW.end_date_updated_at, now());
        NEW.is_favorite_updated_at := COALESCE(NEW.is_favorite_updated_at, now());
        NEW.custom_name_updated_at := COALESCE(NEW.custom_name_updated_at, now());
        NEW.uses_dynamic_name_updated_at := COALESCE(NEW.uses_dynamic_name_updated_at, now());
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.period IS DISTINCT FROM OLD.period THEN
            NEW.period_updated_at := now();
        END IF;
        IF NEW.date IS DISTINCT FROM OLD.date THEN
            NEW.date_updated_at := now();
        END IF;
        IF NEW.start_date IS DISTINCT FROM OLD.start_date THEN
            NEW.start_date_updated_at := now();
        END IF;
        IF NEW.end_date IS DISTINCT FROM OLD.end_date THEN
            NEW.end_date_updated_at := now();
        END IF;
        IF NEW.is_favorite IS DISTINCT FROM OLD.is_favorite THEN
            NEW.is_favorite_updated_at := now();
        END IF;
        IF NEW.custom_name IS DISTINCT FROM OLD.custom_name THEN
            NEW.custom_name_updated_at := now();
        END IF;
        IF NEW.uses_dynamic_name IS DISTINCT FROM OLD.uses_dynamic_name THEN
            NEW.uses_dynamic_name_updated_at := now();
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.tasks_trigger_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.revision := next_revision();
    NEW.updated_at := now();

    IF TG_OP = 'INSERT' THEN
        NEW.title_updated_at := COALESCE(NEW.title_updated_at, now());
        NEW.date_updated_at := COALESCE(NEW.date_updated_at, now());
        NEW.period_updated_at := COALESCE(NEW.period_updated_at, now());
        NEW.status_updated_at := COALESCE(NEW.status_updated_at, now());
        NEW.body_updated_at := COALESCE(NEW.body_updated_at, now());
        NEW.priority_updated_at := COALESCE(NEW.priority_updated_at, now());
        NEW.due_date_updated_at := COALESCE(NEW.due_date_updated_at, now());
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.title IS DISTINCT FROM OLD.title THEN
            NEW.title_updated_at := now();
        END IF;
        IF NEW.date IS DISTINCT FROM OLD.date THEN
            NEW.date_updated_at := now();
        END IF;
        IF NEW.period IS DISTINCT FROM OLD.period THEN
            NEW.period_updated_at := now();
        END IF;
        IF NEW.status IS DISTINCT FROM OLD.status THEN
            NEW.status_updated_at := now();
        END IF;
        IF NEW.body IS DISTINCT FROM OLD.body THEN
            NEW.body_updated_at := now();
        END IF;
        IF NEW.priority IS DISTINCT FROM OLD.priority THEN
            NEW.priority_updated_at := now();
        END IF;
        IF NEW.due_date IS DISTINCT FROM OLD.due_date THEN
            NEW.due_date_updated_at := now();
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.merge_spread(
    p_id uuid,
    p_user_id uuid,
    p_device_id uuid,
    p_period text,
    p_date date,
    p_start_date date,
    p_end_date date,
    p_is_favorite boolean,
    p_custom_name text,
    p_uses_dynamic_name boolean,
    p_created_at timestamp with time zone,
    p_deleted_at timestamp with time zone,
    p_period_updated_at timestamp with time zone,
    p_date_updated_at timestamp with time zone,
    p_start_date_updated_at timestamp with time zone,
    p_end_date_updated_at timestamp with time zone,
    p_is_favorite_updated_at timestamp with time zone,
    p_custom_name_updated_at timestamp with time zone,
    p_uses_dynamic_name_updated_at timestamp with time zone
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

    SELECT * INTO v_existing FROM spreads WHERE id = p_id AND user_id = p_user_id;

    IF NOT FOUND THEN
        INSERT INTO spreads (
            id, user_id, device_id, period, date, start_date, end_date,
            is_favorite, custom_name, uses_dynamic_name,
            created_at, deleted_at,
            period_updated_at, date_updated_at, start_date_updated_at, end_date_updated_at,
            is_favorite_updated_at, custom_name_updated_at, uses_dynamic_name_updated_at
        ) VALUES (
            p_id, p_user_id, p_device_id, p_period, p_date, p_start_date, p_end_date,
            p_is_favorite, p_custom_name, p_uses_dynamic_name,
            p_created_at, p_deleted_at,
            p_period_updated_at, p_date_updated_at, p_start_date_updated_at, p_end_date_updated_at,
            p_is_favorite_updated_at, p_custom_name_updated_at, p_uses_dynamic_name_updated_at
        )
        RETURNING * INTO v_result;
    ELSE
        IF p_deleted_at IS NOT NULL AND (v_existing.deleted_at IS NULL OR p_deleted_at > v_existing.deleted_at) THEN
            UPDATE spreads SET deleted_at = p_deleted_at, device_id = p_device_id
            WHERE id = p_id RETURNING * INTO v_result;
        ELSE
            UPDATE spreads SET
                device_id = p_device_id,
                period = CASE WHEN p_period_updated_at > v_existing.period_updated_at THEN p_period ELSE v_existing.period END,
                period_updated_at = GREATEST(p_period_updated_at, v_existing.period_updated_at),
                date = CASE WHEN p_date_updated_at > v_existing.date_updated_at THEN p_date ELSE v_existing.date END,
                date_updated_at = GREATEST(p_date_updated_at, v_existing.date_updated_at),
                start_date = CASE WHEN p_start_date_updated_at > v_existing.start_date_updated_at THEN p_start_date ELSE v_existing.start_date END,
                start_date_updated_at = GREATEST(p_start_date_updated_at, v_existing.start_date_updated_at),
                end_date = CASE WHEN p_end_date_updated_at > v_existing.end_date_updated_at THEN p_end_date ELSE v_existing.end_date END,
                end_date_updated_at = GREATEST(p_end_date_updated_at, v_existing.end_date_updated_at),
                is_favorite = CASE WHEN p_is_favorite_updated_at > v_existing.is_favorite_updated_at THEN p_is_favorite ELSE v_existing.is_favorite END,
                is_favorite_updated_at = GREATEST(p_is_favorite_updated_at, v_existing.is_favorite_updated_at),
                custom_name = CASE WHEN p_custom_name_updated_at > v_existing.custom_name_updated_at THEN p_custom_name ELSE v_existing.custom_name END,
                custom_name_updated_at = GREATEST(p_custom_name_updated_at, v_existing.custom_name_updated_at),
                uses_dynamic_name = CASE WHEN p_uses_dynamic_name_updated_at > v_existing.uses_dynamic_name_updated_at THEN p_uses_dynamic_name ELSE v_existing.uses_dynamic_name END,
                uses_dynamic_name_updated_at = GREATEST(p_uses_dynamic_name_updated_at, v_existing.uses_dynamic_name_updated_at)
            WHERE id = p_id RETURNING * INTO v_result;
        END IF;
    END IF;

    RETURN to_jsonb(v_result);
END;
$$;

CREATE OR REPLACE FUNCTION public.merge_task(
    p_id uuid,
    p_user_id uuid,
    p_device_id uuid,
    p_title text,
    p_body text,
    p_priority text,
    p_due_date date,
    p_date date,
    p_period text,
    p_status text,
    p_created_at timestamp with time zone,
    p_deleted_at timestamp with time zone,
    p_title_updated_at timestamp with time zone,
    p_date_updated_at timestamp with time zone,
    p_period_updated_at timestamp with time zone,
    p_status_updated_at timestamp with time zone,
    p_body_updated_at timestamp with time zone,
    p_priority_updated_at timestamp with time zone,
    p_due_date_updated_at timestamp with time zone
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

    SELECT * INTO v_existing FROM tasks WHERE id = p_id AND user_id = p_user_id;

    IF NOT FOUND THEN
        INSERT INTO tasks (
            id, user_id, device_id, title, body, priority, due_date, date, period, status,
            created_at, deleted_at,
            title_updated_at, date_updated_at, period_updated_at, status_updated_at,
            body_updated_at, priority_updated_at, due_date_updated_at
        ) VALUES (
            p_id, p_user_id, p_device_id, p_title, p_body, p_priority, p_due_date, p_date, p_period, p_status,
            p_created_at, p_deleted_at,
            p_title_updated_at, p_date_updated_at, p_period_updated_at, p_status_updated_at,
            p_body_updated_at, p_priority_updated_at, p_due_date_updated_at
        )
        RETURNING * INTO v_result;
    ELSE
        IF p_deleted_at IS NOT NULL AND (v_existing.deleted_at IS NULL OR p_deleted_at > v_existing.deleted_at) THEN
            UPDATE tasks SET deleted_at = p_deleted_at, device_id = p_device_id
            WHERE id = p_id RETURNING * INTO v_result;
        ELSE
            UPDATE tasks SET
                device_id = p_device_id,
                title = CASE WHEN p_title_updated_at > v_existing.title_updated_at THEN p_title ELSE v_existing.title END,
                title_updated_at = GREATEST(p_title_updated_at, v_existing.title_updated_at),
                date = CASE WHEN p_date_updated_at > v_existing.date_updated_at THEN p_date ELSE v_existing.date END,
                date_updated_at = GREATEST(p_date_updated_at, v_existing.date_updated_at),
                period = CASE WHEN p_period_updated_at > v_existing.period_updated_at THEN p_period ELSE v_existing.period END,
                period_updated_at = GREATEST(p_period_updated_at, v_existing.period_updated_at),
                status = CASE WHEN p_status_updated_at > v_existing.status_updated_at THEN p_status ELSE v_existing.status END,
                status_updated_at = GREATEST(p_status_updated_at, v_existing.status_updated_at),
                body = CASE WHEN p_body_updated_at > v_existing.body_updated_at THEN p_body ELSE v_existing.body END,
                body_updated_at = GREATEST(p_body_updated_at, v_existing.body_updated_at),
                priority = CASE WHEN p_priority_updated_at > v_existing.priority_updated_at THEN p_priority ELSE v_existing.priority END,
                priority_updated_at = GREATEST(p_priority_updated_at, v_existing.priority_updated_at),
                due_date = CASE WHEN p_due_date_updated_at > v_existing.due_date_updated_at THEN p_due_date ELSE v_existing.due_date END,
                due_date_updated_at = GREATEST(p_due_date_updated_at, v_existing.due_date_updated_at)
            WHERE id = p_id RETURNING * INTO v_result;
        END IF;
    END IF;

    RETURN to_jsonb(v_result);
END;
$$;
