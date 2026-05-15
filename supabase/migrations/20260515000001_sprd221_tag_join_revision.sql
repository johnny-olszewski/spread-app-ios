-- Migration: sprd221_tag_join_revision
-- Description: Add revision column to task_tags and note_tags for incremental pull support.
--              Updates merge_task_tag and merge_note_tag RPCs to increment revision on upsert.

-- ============================================================
-- Add revision to task_tags
-- ============================================================

ALTER TABLE public.task_tags
    ADD COLUMN IF NOT EXISTS revision bigint NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS task_tags_revision_idx ON public.task_tags (revision);

-- ============================================================
-- Add revision to note_tags
-- ============================================================

ALTER TABLE public.note_tags
    ADD COLUMN IF NOT EXISTS revision bigint NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS note_tags_revision_idx ON public.note_tags (revision);

-- ============================================================
-- merge_task_tag — updated to increment revision on upsert
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
        deleted_at = EXCLUDED.deleted_at,
        revision   = task_tags.revision + 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.merge_task_tag TO authenticated;

-- ============================================================
-- merge_note_tag — updated to increment revision on upsert
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
        deleted_at = EXCLUDED.deleted_at,
        revision   = note_tags.revision + 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.merge_note_tag TO authenticated;
