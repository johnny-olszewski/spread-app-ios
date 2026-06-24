--
-- SPRD-246: Unify tasks/notes -> entries, task_assignments/note_assignments -> assignments,
-- task_tags/note_tags -> entry_tags.
--
-- Direct-cutover migration (no phased dual-write): create the three new tables, migrate
-- existing rows, drop the six old tables, and update RLS/indices/triggers accordingly.
-- entries.date/.period are nullable from the start, covering Task's existing nullability and
-- Note's future requirement (SPRD-247).
--

--
-- New table: entries
--

CREATE TABLE public.entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_id uuid NOT NULL,
    type text NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    content text,
    date date,
    period text,
    status text NOT NULL,
    body text,
    priority text,
    due_date date,
    list_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    title_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    content_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    date_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    period_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    status_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    body_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    priority_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    due_date_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    list_updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT entries_pkey PRIMARY KEY (id),
    CONSTRAINT entries_type_check CHECK ((type = ANY (ARRAY['task'::text, 'note'::text]))),
    CONSTRAINT entries_period_check CHECK ((period IS NULL) OR (period = ANY (ARRAY['year'::text, 'month'::text, 'day'::text, 'multiday'::text]))),
    CONSTRAINT entries_priority_check CHECK ((priority IS NULL) OR (priority = ANY (ARRAY['none'::text, 'low'::text, 'medium'::text, 'high'::text]))),
    CONSTRAINT entries_status_check CHECK (
        ((type = 'task'::text) AND (status = ANY (ARRAY['open'::text, 'complete'::text, 'migrated'::text, 'cancelled'::text])))
        OR ((type = 'note'::text) AND (status = ANY (ARRAY['active'::text, 'migrated'::text])))
    ),
    CONSTRAINT entries_list_id_fkey FOREIGN KEY (list_id) REFERENCES public.lists(id) ON DELETE SET NULL
);

CREATE INDEX entries_user_deleted_idx ON public.entries USING btree (user_id, deleted_at);
CREATE INDEX entries_user_revision_idx ON public.entries USING btree (user_id, revision);
CREATE INDEX entries_user_type_deleted_idx ON public.entries USING btree (user_id, type, deleted_at);

CREATE FUNCTION public.entries_trigger_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.revision := next_revision();
    NEW.updated_at := now();

    IF TG_OP = 'INSERT' THEN
        NEW.title_updated_at := COALESCE(NEW.title_updated_at, now());
        NEW.content_updated_at := COALESCE(NEW.content_updated_at, now());
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
        IF NEW.content IS DISTINCT FROM OLD.content THEN
            NEW.content_updated_at := now();
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
        IF NEW.list_id IS DISTINCT FROM OLD.list_id THEN
            NEW.list_updated_at := now();
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER entries_before_upsert BEFORE INSERT OR UPDATE ON public.entries
    FOR EACH ROW EXECUTE FUNCTION public.entries_trigger_fn();

ALTER TABLE public.entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select their own entries" ON public.entries FOR SELECT USING ((auth.uid() = user_id));
CREATE POLICY "Users can insert their own entries" ON public.entries FOR INSERT WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Users can update their own entries" ON public.entries FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Users can delete their own entries" ON public.entries FOR DELETE USING ((auth.uid() = user_id));

GRANT ALL ON TABLE public.entries TO anon;
GRANT ALL ON TABLE public.entries TO authenticated;
GRANT ALL ON TABLE public.entries TO service_role;

GRANT ALL ON FUNCTION public.entries_trigger_fn() TO anon;
GRANT ALL ON FUNCTION public.entries_trigger_fn() TO authenticated;
GRANT ALL ON FUNCTION public.entries_trigger_fn() TO service_role;

--
-- New table: assignments
--

CREATE TABLE public.assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_id uuid NOT NULL,
    entry_id uuid NOT NULL,
    entry_type text NOT NULL,
    period text NOT NULL,
    date date NOT NULL,
    status text NOT NULL,
    spread_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    status_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT assignments_pkey PRIMARY KEY (id),
    CONSTRAINT assignments_entry_type_check CHECK ((entry_type = ANY (ARRAY['task'::text, 'note'::text]))),
    CONSTRAINT assignments_period_check CHECK ((period = ANY (ARRAY['year'::text, 'month'::text, 'day'::text, 'multiday'::text]))),
    CONSTRAINT assignments_status_check CHECK (
        ((entry_type = 'task'::text) AND (status = ANY (ARRAY['open'::text, 'complete'::text, 'migrated'::text, 'cancelled'::text])))
        OR ((entry_type = 'note'::text) AND (status = ANY (ARRAY['active'::text, 'migrated'::text])))
    ),
    CONSTRAINT assignments_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id) ON DELETE CASCADE,
    CONSTRAINT assignments_spread_id_fkey FOREIGN KEY (spread_id) REFERENCES public.spreads(id) ON DELETE SET NULL
);

CREATE INDEX assignments_entry_id_idx ON public.assignments USING btree (entry_id);
CREATE INDEX assignments_spread_id_idx ON public.assignments USING btree (spread_id);
CREATE INDEX assignments_user_deleted_idx ON public.assignments USING btree (user_id, deleted_at);
CREATE INDEX assignments_user_revision_idx ON public.assignments USING btree (user_id, revision);
CREATE UNIQUE INDEX assignments_user_entry_multiday_spread_unique ON public.assignments USING btree (user_id, entry_id, spread_id) WHERE ((deleted_at IS NULL) AND (spread_id IS NOT NULL));
CREATE UNIQUE INDEX assignments_user_entry_period_date_unique ON public.assignments USING btree (user_id, entry_id, period, date) WHERE ((deleted_at IS NULL) AND (spread_id IS NULL));

CREATE FUNCTION public.assignments_trigger_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.revision := next_revision();
    NEW.updated_at := now();

    IF TG_OP = 'INSERT' THEN
        NEW.status_updated_at := COALESCE(NEW.status_updated_at, now());
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.status IS DISTINCT FROM OLD.status THEN
            NEW.status_updated_at := now();
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER assignments_before_upsert BEFORE INSERT OR UPDATE ON public.assignments
    FOR EACH ROW EXECUTE FUNCTION public.assignments_trigger_fn();

ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select their own assignments" ON public.assignments FOR SELECT USING ((auth.uid() = user_id));
CREATE POLICY "Users can insert their own assignments" ON public.assignments FOR INSERT WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Users can update their own assignments" ON public.assignments FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Users can delete their own assignments" ON public.assignments FOR DELETE USING ((auth.uid() = user_id));

GRANT ALL ON TABLE public.assignments TO anon;
GRANT ALL ON TABLE public.assignments TO authenticated;
GRANT ALL ON TABLE public.assignments TO service_role;

GRANT ALL ON FUNCTION public.assignments_trigger_fn() TO anon;
GRANT ALL ON FUNCTION public.assignments_trigger_fn() TO authenticated;
GRANT ALL ON FUNCTION public.assignments_trigger_fn() TO service_role;

--
-- New table: entry_tags
--

CREATE TABLE public.entry_tags (
    entry_id uuid NOT NULL,
    tag_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    CONSTRAINT entry_tags_pkey PRIMARY KEY (entry_id, tag_id),
    CONSTRAINT entry_tags_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id) ON DELETE CASCADE,
    CONSTRAINT entry_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE,
    CONSTRAINT entry_tags_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE INDEX entry_tags_entry_id_idx ON public.entry_tags USING btree (entry_id);
CREATE INDEX entry_tags_tag_id_idx ON public.entry_tags USING btree (tag_id);
CREATE INDEX entry_tags_revision_idx ON public.entry_tags USING btree (revision);

ALTER TABLE public.entry_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own entry_tags" ON public.entry_tags USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));

GRANT ALL ON TABLE public.entry_tags TO anon;
GRANT ALL ON TABLE public.entry_tags TO authenticated;
GRANT ALL ON TABLE public.entry_tags TO service_role;

--
-- Migrate existing rows
--

INSERT INTO public.entries (
    id, user_id, device_id, type, title, content, date, period, status, body, priority, due_date, list_id,
    created_at, updated_at, deleted_at, revision,
    title_updated_at, content_updated_at, date_updated_at, period_updated_at, status_updated_at,
    body_updated_at, priority_updated_at, due_date_updated_at, list_updated_at
)
SELECT
    id, user_id, device_id, 'task', title, NULL, date, period, status, body, priority, due_date, list_id,
    created_at, updated_at, deleted_at, revision,
    title_updated_at, now(), date_updated_at, period_updated_at, status_updated_at,
    body_updated_at, priority_updated_at, due_date_updated_at, list_updated_at
FROM public.tasks;

INSERT INTO public.entries (
    id, user_id, device_id, type, title, content, date, period, status, body, priority, due_date, list_id,
    created_at, updated_at, deleted_at, revision,
    title_updated_at, content_updated_at, date_updated_at, period_updated_at, status_updated_at,
    body_updated_at, priority_updated_at, due_date_updated_at, list_updated_at
)
SELECT
    id, user_id, device_id, 'note', title, content, date, period, status, NULL, NULL, NULL, list_id,
    created_at, updated_at, deleted_at, revision,
    title_updated_at, content_updated_at, date_updated_at, period_updated_at, status_updated_at,
    now(), now(), now(), list_updated_at
FROM public.notes;

INSERT INTO public.assignments (
    id, user_id, device_id, entry_id, entry_type, period, date, status, spread_id,
    created_at, updated_at, deleted_at, revision, status_updated_at
)
SELECT
    id, user_id, device_id, task_id, 'task', period, date, status, spread_id,
    created_at, updated_at, deleted_at, revision, status_updated_at
FROM public.task_assignments;

INSERT INTO public.assignments (
    id, user_id, device_id, entry_id, entry_type, period, date, status, spread_id,
    created_at, updated_at, deleted_at, revision, status_updated_at
)
SELECT
    id, user_id, device_id, note_id, 'note', period, date, status, spread_id,
    created_at, updated_at, deleted_at, revision, status_updated_at
FROM public.note_assignments;

INSERT INTO public.entry_tags (entry_id, tag_id, user_id, created_at, deleted_at, revision)
SELECT task_id, tag_id, user_id, created_at, deleted_at, revision FROM public.task_tags;

INSERT INTO public.entry_tags (entry_id, tag_id, user_id, created_at, deleted_at, revision)
SELECT note_id, tag_id, user_id, created_at, deleted_at, revision FROM public.note_tags;

--
-- Drop obsolete sync RPCs and trigger functions tied to the six old tables.
-- SPRD-247 rewires SyncSerializer against the new entries/assignments/entry_tags schema
-- and will add the merge_entry/merge_assignment/merge_entry_tag replacements.
--

DROP FUNCTION public.merge_task(uuid, uuid, uuid, text, text, text, date, uuid, date, text, text, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone);
DROP FUNCTION public.merge_note(uuid, uuid, uuid, text, text, date, text, text, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone);
DROP FUNCTION public.merge_task_assignment(uuid, uuid, uuid, uuid, text, date, uuid, text, timestamp with time zone, timestamp with time zone, timestamp with time zone);
DROP FUNCTION public.merge_note_assignment(uuid, uuid, uuid, uuid, text, date, uuid, text, timestamp with time zone, timestamp with time zone, timestamp with time zone);
DROP FUNCTION public.merge_task_tag(uuid, uuid, uuid, timestamp with time zone, timestamp with time zone);
DROP FUNCTION public.merge_note_tag(uuid, uuid, uuid, timestamp with time zone, timestamp with time zone);

--
-- Drop the six old tables (also drops their triggers, policies, and indices).
--

DROP TABLE public.task_tags;
DROP TABLE public.note_tags;
DROP TABLE public.task_assignments;
DROP TABLE public.note_assignments;
DROP TABLE public.tasks;
DROP TABLE public.notes;

DROP FUNCTION public.tasks_trigger_fn();
DROP FUNCTION public.notes_trigger_fn();
DROP FUNCTION public.task_assignments_trigger_fn();
DROP FUNCTION public.note_assignments_trigger_fn();

--
-- Repoint cleanup_tombstones() at the new tables.
--

CREATE OR REPLACE FUNCTION public.cleanup_tombstones() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    cutoff timestamptz := now() - interval '90 days';
BEGIN
    DELETE FROM assignments WHERE deleted_at IS NOT NULL AND deleted_at < cutoff;
    DELETE FROM entries WHERE deleted_at IS NOT NULL AND deleted_at < cutoff;
    DELETE FROM spreads WHERE deleted_at IS NOT NULL AND deleted_at < cutoff;
    DELETE FROM collections WHERE deleted_at IS NOT NULL AND deleted_at < cutoff;
    DELETE FROM settings WHERE deleted_at IS NOT NULL AND deleted_at < cutoff;
END;
$$;
