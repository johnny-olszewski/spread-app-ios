-- Migration: sprd221_lists_tags
-- Description: Add List and Tag as first-class organizational models for tasks and notes.
--              Adds lists, tags, task_tags, and note_tags tables.
--              Adds list_id foreign key to tasks and notes. [SPRD-221]

-- ============================================================
-- lists table
-- ============================================================

CREATE TABLE IF NOT EXISTS public.lists (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    device_id uuid,
    name text NOT NULL CHECK (char_length(trim(name)) > 0),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    deleted_at timestamp with time zone,
    revision bigint NOT NULL DEFAULT 0,
    name_updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.lists ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own lists"
    ON public.lists
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS lists_user_id_idx ON public.lists (user_id);
CREATE INDEX IF NOT EXISTS lists_revision_idx ON public.lists (revision);

-- ============================================================
-- tags table
-- ============================================================

CREATE TABLE IF NOT EXISTS public.tags (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    device_id uuid,
    name text NOT NULL CHECK (char_length(trim(name)) > 0),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    deleted_at timestamp with time zone,
    revision bigint NOT NULL DEFAULT 0,
    name_updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own tags"
    ON public.tags
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS tags_user_id_idx ON public.tags (user_id);
CREATE INDEX IF NOT EXISTS tags_revision_idx ON public.tags (revision);

-- ============================================================
-- Add list_id to tasks (nullable FK; tasks may belong to one list)
-- ============================================================

ALTER TABLE public.tasks
    ADD COLUMN IF NOT EXISTS list_id uuid REFERENCES public.lists (id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS list_updated_at timestamp with time zone;

UPDATE public.tasks
SET list_updated_at = COALESCE(list_updated_at, updated_at, created_at)
WHERE list_updated_at IS NULL;

ALTER TABLE public.tasks
    ALTER COLUMN list_updated_at SET DEFAULT now();

-- ============================================================
-- Add list_id to notes (nullable FK; notes may belong to one list)
-- ============================================================

ALTER TABLE public.notes
    ADD COLUMN IF NOT EXISTS list_id uuid REFERENCES public.lists (id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS list_updated_at timestamp with time zone;

UPDATE public.notes
SET list_updated_at = COALESCE(list_updated_at, updated_at, created_at)
WHERE list_updated_at IS NULL;

ALTER TABLE public.notes
    ALTER COLUMN list_updated_at SET DEFAULT now();

-- ============================================================
-- task_tags join table (many-to-many: tasks ↔ tags)
-- Compound PK on (task_id, tag_id); soft-delete via deleted_at.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.task_tags (
    task_id uuid NOT NULL REFERENCES public.tasks (id) ON DELETE CASCADE,
    tag_id  uuid NOT NULL REFERENCES public.tags  (id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users   (id) ON DELETE CASCADE,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    deleted_at timestamp with time zone,
    PRIMARY KEY (task_id, tag_id)
);

ALTER TABLE public.task_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own task_tags"
    ON public.task_tags
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS task_tags_task_id_idx ON public.task_tags (task_id);
CREATE INDEX IF NOT EXISTS task_tags_tag_id_idx  ON public.task_tags (tag_id);

-- ============================================================
-- note_tags join table (many-to-many: notes ↔ tags)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.note_tags (
    note_id uuid NOT NULL REFERENCES public.notes (id) ON DELETE CASCADE,
    tag_id  uuid NOT NULL REFERENCES public.tags  (id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users   (id) ON DELETE CASCADE,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    deleted_at timestamp with time zone,
    PRIMARY KEY (note_id, tag_id)
);

ALTER TABLE public.note_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own note_tags"
    ON public.note_tags
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS note_tags_note_id_idx ON public.note_tags (note_id);
CREATE INDEX IF NOT EXISTS note_tags_tag_id_idx  ON public.note_tags (tag_id);

-- ============================================================
-- merge_list RPC (LWW upsert for List entities)
-- ============================================================

CREATE OR REPLACE FUNCTION public.merge_list(
    p_id              uuid,
    p_user_id         uuid,
    p_device_id       uuid,
    p_name            text,
    p_created_at      timestamp with time zone,
    p_deleted_at      timestamp with time zone,
    p_name_updated_at timestamp with time zone
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.lists (
        id, user_id, device_id, name,
        created_at, deleted_at, name_updated_at
    ) VALUES (
        p_id, p_user_id, p_device_id, p_name,
        p_created_at, p_deleted_at, p_name_updated_at
    )
    ON CONFLICT (id) DO UPDATE SET
        device_id       = EXCLUDED.device_id,
        name            = CASE WHEN EXCLUDED.name_updated_at > lists.name_updated_at
                               THEN EXCLUDED.name ELSE lists.name END,
        deleted_at      = COALESCE(EXCLUDED.deleted_at, lists.deleted_at),
        name_updated_at = GREATEST(EXCLUDED.name_updated_at, lists.name_updated_at),
        revision        = lists.revision + 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.merge_list TO authenticated;

-- ============================================================
-- merge_tag RPC (LWW upsert for Tag entities)
-- ============================================================

CREATE OR REPLACE FUNCTION public.merge_tag(
    p_id              uuid,
    p_user_id         uuid,
    p_device_id       uuid,
    p_name            text,
    p_created_at      timestamp with time zone,
    p_deleted_at      timestamp with time zone,
    p_name_updated_at timestamp with time zone
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.tags (
        id, user_id, device_id, name,
        created_at, deleted_at, name_updated_at
    ) VALUES (
        p_id, p_user_id, p_device_id, p_name,
        p_created_at, p_deleted_at, p_name_updated_at
    )
    ON CONFLICT (id) DO UPDATE SET
        device_id       = EXCLUDED.device_id,
        name            = CASE WHEN EXCLUDED.name_updated_at > tags.name_updated_at
                               THEN EXCLUDED.name ELSE tags.name END,
        deleted_at      = COALESCE(EXCLUDED.deleted_at, tags.deleted_at),
        name_updated_at = GREATEST(EXCLUDED.name_updated_at, tags.name_updated_at),
        revision        = tags.revision + 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.merge_tag TO authenticated;

-- ============================================================
-- merge_task_tag RPC (upsert/soft-delete for task-tag join rows)
-- Server identifies rows by (task_id, tag_id) compound PK.
-- ============================================================

CREATE OR REPLACE FUNCTION public.merge_task_tag(
    p_task_id    uuid,
    p_tag_id     uuid,
    p_user_id    uuid,
    p_created_at timestamp with time zone,
    p_deleted_at timestamp with time zone
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.task_tags (task_id, tag_id, user_id, created_at, deleted_at)
    VALUES (p_task_id, p_tag_id, p_user_id, p_created_at, p_deleted_at)
    ON CONFLICT (task_id, tag_id) DO UPDATE SET
        deleted_at = EXCLUDED.deleted_at;
END;
$$;

GRANT EXECUTE ON FUNCTION public.merge_task_tag TO authenticated;

-- ============================================================
-- merge_note_tag RPC (upsert/soft-delete for note-tag join rows)
-- ============================================================

CREATE OR REPLACE FUNCTION public.merge_note_tag(
    p_note_id    uuid,
    p_tag_id     uuid,
    p_user_id    uuid,
    p_created_at timestamp with time zone,
    p_deleted_at timestamp with time zone
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.note_tags (note_id, tag_id, user_id, created_at, deleted_at)
    VALUES (p_note_id, p_tag_id, p_user_id, p_created_at, p_deleted_at)
    ON CONFLICT (note_id, tag_id) DO UPDATE SET
        deleted_at = EXCLUDED.deleted_at;
END;
$$;

GRANT EXECUTE ON FUNCTION public.merge_note_tag TO authenticated;

-- ============================================================
-- merge_task RPC — updated to include p_list_id / p_list_updated_at
-- (DROP required because parameter list changed)
-- ============================================================

DROP FUNCTION IF EXISTS public.merge_task(
    uuid, uuid, uuid, text, text, text, date, date, text, text,
    timestamp with time zone, timestamp with time zone,
    timestamp with time zone, timestamp with time zone, timestamp with time zone,
    timestamp with time zone, timestamp with time zone, timestamp with time zone,
    timestamp with time zone
);

CREATE OR REPLACE FUNCTION public.merge_task(
    p_id                  uuid,
    p_user_id             uuid,
    p_device_id           uuid,
    p_title               text,
    p_body                text,
    p_priority            text,
    p_due_date            date,
    p_list_id             uuid,
    p_date                date,
    p_period              text,
    p_status              text,
    p_created_at          timestamp with time zone,
    p_deleted_at          timestamp with time zone,
    p_title_updated_at    timestamp with time zone,
    p_date_updated_at     timestamp with time zone,
    p_period_updated_at   timestamp with time zone,
    p_status_updated_at   timestamp with time zone,
    p_body_updated_at     timestamp with time zone,
    p_priority_updated_at timestamp with time zone,
    p_due_date_updated_at timestamp with time zone,
    p_list_updated_at     timestamp with time zone
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_existing RECORD;
    v_result   RECORD;
BEGIN
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    SELECT * INTO v_existing FROM tasks WHERE id = p_id AND user_id = p_user_id;

    IF NOT FOUND THEN
        INSERT INTO tasks (
            id, user_id, device_id, title, body, priority, due_date, list_id, date, period, status,
            created_at, deleted_at,
            title_updated_at, date_updated_at, period_updated_at, status_updated_at,
            body_updated_at, priority_updated_at, due_date_updated_at, list_updated_at
        ) VALUES (
            p_id, p_user_id, p_device_id, p_title, p_body, p_priority, p_due_date, p_list_id, p_date, p_period, p_status,
            p_created_at, p_deleted_at,
            p_title_updated_at, p_date_updated_at, p_period_updated_at, p_status_updated_at,
            p_body_updated_at, p_priority_updated_at, p_due_date_updated_at, p_list_updated_at
        )
        RETURNING * INTO v_result;
    ELSE
        IF p_deleted_at IS NOT NULL AND (v_existing.deleted_at IS NULL OR p_deleted_at > v_existing.deleted_at) THEN
            UPDATE tasks SET deleted_at = p_deleted_at, device_id = p_device_id
            WHERE id = p_id RETURNING * INTO v_result;
        ELSE
            UPDATE tasks SET
                device_id           = p_device_id,
                title               = CASE WHEN p_title_updated_at    > v_existing.title_updated_at    THEN p_title    ELSE v_existing.title    END,
                title_updated_at    = GREATEST(p_title_updated_at,    v_existing.title_updated_at),
                date                = CASE WHEN p_date_updated_at     > v_existing.date_updated_at     THEN p_date     ELSE v_existing.date     END,
                date_updated_at     = GREATEST(p_date_updated_at,     v_existing.date_updated_at),
                period              = CASE WHEN p_period_updated_at   > v_existing.period_updated_at   THEN p_period   ELSE v_existing.period   END,
                period_updated_at   = GREATEST(p_period_updated_at,   v_existing.period_updated_at),
                status              = CASE WHEN p_status_updated_at   > v_existing.status_updated_at   THEN p_status   ELSE v_existing.status   END,
                status_updated_at   = GREATEST(p_status_updated_at,   v_existing.status_updated_at),
                body                = CASE WHEN p_body_updated_at     > v_existing.body_updated_at     THEN p_body     ELSE v_existing.body     END,
                body_updated_at     = GREATEST(p_body_updated_at,     v_existing.body_updated_at),
                priority            = CASE WHEN p_priority_updated_at > v_existing.priority_updated_at THEN p_priority ELSE v_existing.priority END,
                priority_updated_at = GREATEST(p_priority_updated_at, v_existing.priority_updated_at),
                due_date            = CASE WHEN p_due_date_updated_at > v_existing.due_date_updated_at THEN p_due_date ELSE v_existing.due_date END,
                due_date_updated_at = GREATEST(p_due_date_updated_at, v_existing.due_date_updated_at),
                list_id             = CASE WHEN p_list_updated_at     > v_existing.list_updated_at     THEN p_list_id  ELSE v_existing.list_id  END,
                list_updated_at     = GREATEST(p_list_updated_at,     v_existing.list_updated_at)
            WHERE id = p_id RETURNING * INTO v_result;
        END IF;
    END IF;

    RETURN to_jsonb(v_result);
END;
$$;

GRANT EXECUTE ON FUNCTION public.merge_task TO authenticated;
