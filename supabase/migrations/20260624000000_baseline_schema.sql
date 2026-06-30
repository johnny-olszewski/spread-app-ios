--
-- Baseline schema snapshot.
--
-- Pre-release: deployments are personal/dev only, so this baseline is squashed in place
-- rather than carrying forward incremental history (same approach as SPRD-239's original
-- squash). This snapshot folds in SPRD-246's entries/assignments/entry_tags unification —
-- tasks/notes/task_assignments/note_assignments/task_tags/note_tags never existed in this
-- baseline; entries/assignments/entry_tags are created directly.
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Functions
--

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

CREATE FUNCTION public.cleanup_tombstones() RETURNS void
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

CREATE FUNCTION public.collections_trigger_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.revision := next_revision();
    NEW.updated_at := now();

    IF TG_OP = 'INSERT' THEN
        NEW.title_updated_at := COALESCE(NEW.title_updated_at, now());
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.title IS DISTINCT FROM OLD.title THEN
            NEW.title_updated_at := now();
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.merge_entry(p_id uuid, p_user_id uuid, p_device_id uuid, p_type text, p_title text, p_content text, p_date date, p_period text, p_status text, p_body text, p_priority text, p_due_date date, p_list_id uuid, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone, p_content_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_status_updated_at timestamp with time zone, p_body_updated_at timestamp with time zone, p_priority_updated_at timestamp with time zone, p_due_date_updated_at timestamp with time zone, p_list_updated_at timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_existing RECORD;
    v_result RECORD;
BEGIN
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    SELECT * INTO v_existing FROM entries WHERE id = p_id AND user_id = p_user_id;

    IF NOT FOUND THEN
        INSERT INTO entries (
            id, user_id, device_id, type, title, content, date, period, status, body, priority, due_date, list_id,
            created_at, deleted_at,
            title_updated_at, content_updated_at, date_updated_at, period_updated_at, status_updated_at,
            body_updated_at, priority_updated_at, due_date_updated_at, list_updated_at
        ) VALUES (
            p_id, p_user_id, p_device_id, p_type, p_title, p_content, p_date, p_period, p_status, p_body, p_priority, p_due_date, p_list_id,
            p_created_at, p_deleted_at,
            p_title_updated_at, p_content_updated_at, p_date_updated_at, p_period_updated_at, p_status_updated_at,
            p_body_updated_at, p_priority_updated_at, p_due_date_updated_at, p_list_updated_at
        )
        RETURNING * INTO v_result;
    ELSE
        IF p_deleted_at IS NOT NULL AND (v_existing.deleted_at IS NULL OR p_deleted_at > v_existing.deleted_at) THEN
            UPDATE entries SET deleted_at = p_deleted_at, device_id = p_device_id
            WHERE id = p_id RETURNING * INTO v_result;
        ELSE
            UPDATE entries SET
                device_id           = p_device_id,
                title                = CASE WHEN p_title_updated_at      > v_existing.title_updated_at      THEN p_title      ELSE v_existing.title      END,
                title_updated_at     = GREATEST(p_title_updated_at,      v_existing.title_updated_at),
                content              = CASE WHEN p_content_updated_at    > v_existing.content_updated_at    THEN p_content    ELSE v_existing.content    END,
                content_updated_at   = GREATEST(p_content_updated_at,    v_existing.content_updated_at),
                date                 = CASE WHEN p_date_updated_at       > v_existing.date_updated_at       THEN p_date       ELSE v_existing.date       END,
                date_updated_at      = GREATEST(p_date_updated_at,       v_existing.date_updated_at),
                period               = CASE WHEN p_period_updated_at     > v_existing.period_updated_at     THEN p_period     ELSE v_existing.period     END,
                period_updated_at    = GREATEST(p_period_updated_at,     v_existing.period_updated_at),
                status               = CASE WHEN p_status_updated_at     > v_existing.status_updated_at     THEN p_status     ELSE v_existing.status     END,
                status_updated_at    = GREATEST(p_status_updated_at,     v_existing.status_updated_at),
                body                 = CASE WHEN p_body_updated_at       > v_existing.body_updated_at       THEN p_body       ELSE v_existing.body       END,
                body_updated_at      = GREATEST(p_body_updated_at,       v_existing.body_updated_at),
                priority             = CASE WHEN p_priority_updated_at   > v_existing.priority_updated_at   THEN p_priority   ELSE v_existing.priority   END,
                priority_updated_at  = GREATEST(p_priority_updated_at,   v_existing.priority_updated_at),
                due_date             = CASE WHEN p_due_date_updated_at   > v_existing.due_date_updated_at   THEN p_due_date   ELSE v_existing.due_date   END,
                due_date_updated_at  = GREATEST(p_due_date_updated_at,   v_existing.due_date_updated_at),
                list_id              = CASE WHEN p_list_updated_at       > v_existing.list_updated_at       THEN p_list_id    ELSE v_existing.list_id    END,
                list_updated_at      = GREATEST(p_list_updated_at,       v_existing.list_updated_at)
            WHERE id = p_id RETURNING * INTO v_result;
        END IF;
    END IF;

    RETURN to_jsonb(v_result);
END;
$$;

CREATE FUNCTION public.merge_assignment(p_id uuid, p_user_id uuid, p_device_id uuid, p_entry_id uuid, p_entry_type text, p_period text, p_date date, p_spread_id uuid, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_status_updated_at timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_existing RECORD;
    v_result RECORD;
BEGIN
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    SELECT * INTO v_existing FROM assignments WHERE id = p_id AND user_id = p_user_id;

    IF NOT FOUND THEN
        SELECT * INTO v_existing
        FROM assignments
        WHERE user_id = p_user_id
          AND entry_id = p_entry_id
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
            INSERT INTO assignments (
                id, user_id, device_id, entry_id, entry_type, period, date, spread_id, status,
                created_at, deleted_at, status_updated_at
            ) VALUES (
                p_id, p_user_id, p_device_id, p_entry_id, p_entry_type, p_period, p_date, p_spread_id, p_status,
                p_created_at, p_deleted_at, p_status_updated_at
            )
            RETURNING * INTO v_result;
        EXCEPTION
            WHEN unique_violation THEN
                SELECT * INTO v_existing
                FROM assignments
                WHERE user_id = p_user_id
                  AND entry_id = p_entry_id
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
            UPDATE assignments SET deleted_at = p_deleted_at, device_id = p_device_id
            WHERE id = v_existing.id RETURNING * INTO v_result;
        ELSE
            UPDATE assignments SET
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

CREATE FUNCTION public.merge_entry_tag(p_entry_id uuid, p_tag_id uuid, p_user_id uuid, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO public.entry_tags (entry_id, tag_id, user_id, created_at, deleted_at)
    VALUES (p_entry_id, p_tag_id, p_user_id, p_created_at, p_deleted_at)
    ON CONFLICT (entry_id, tag_id) DO UPDATE SET
        deleted_at = EXCLUDED.deleted_at,
        revision   = entry_tags.revision + 1;
END;
$$;

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

CREATE FUNCTION public.merge_collection(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_existing RECORD;
    v_result RECORD;
BEGIN
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    SELECT * INTO v_existing FROM collections WHERE id = p_id AND user_id = p_user_id;

    IF NOT FOUND THEN
        INSERT INTO collections (
            id, user_id, device_id, title, created_at, deleted_at, title_updated_at
        ) VALUES (
            p_id, p_user_id, p_device_id, p_title, p_created_at, p_deleted_at, p_title_updated_at
        )
        RETURNING * INTO v_result;
    ELSE
        IF p_deleted_at IS NOT NULL AND (v_existing.deleted_at IS NULL OR p_deleted_at > v_existing.deleted_at) THEN
            UPDATE collections SET deleted_at = p_deleted_at, device_id = p_device_id
            WHERE id = p_id RETURNING * INTO v_result;
        ELSE
            UPDATE collections SET
                device_id = p_device_id,
                title = CASE WHEN p_title_updated_at > v_existing.title_updated_at THEN p_title ELSE v_existing.title END,
                title_updated_at = GREATEST(p_title_updated_at, v_existing.title_updated_at)
            WHERE id = p_id RETURNING * INTO v_result;
        END IF;
    END IF;

    RETURN to_jsonb(v_result);
END;
$$;

CREATE FUNCTION public.merge_list(p_id uuid, p_user_id uuid, p_device_id uuid, p_name text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_name_updated_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
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

CREATE FUNCTION public.merge_settings(p_id uuid, p_user_id uuid, p_device_id uuid, p_bujo_mode text, p_first_weekday integer, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_bujo_mode_updated_at timestamp with time zone, p_first_weekday_updated_at timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_existing RECORD;
    v_result RECORD;
BEGIN
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    SELECT * INTO v_existing FROM settings WHERE id = p_id AND user_id = p_user_id;

    IF NOT FOUND THEN
        INSERT INTO settings (
            id, user_id, device_id, bujo_mode, first_weekday,
            created_at, deleted_at, bujo_mode_updated_at, first_weekday_updated_at
        ) VALUES (
            p_id, p_user_id, p_device_id, p_bujo_mode, p_first_weekday,
            p_created_at, p_deleted_at, p_bujo_mode_updated_at, p_first_weekday_updated_at
        )
        RETURNING * INTO v_result;
    ELSE
        IF p_deleted_at IS NOT NULL AND (v_existing.deleted_at IS NULL OR p_deleted_at > v_existing.deleted_at) THEN
            UPDATE settings SET deleted_at = p_deleted_at, device_id = p_device_id
            WHERE id = p_id RETURNING * INTO v_result;
        ELSE
            UPDATE settings SET
                device_id = p_device_id,
                bujo_mode = CASE WHEN p_bujo_mode_updated_at > v_existing.bujo_mode_updated_at THEN p_bujo_mode ELSE v_existing.bujo_mode END,
                bujo_mode_updated_at = GREATEST(p_bujo_mode_updated_at, v_existing.bujo_mode_updated_at),
                first_weekday = CASE WHEN p_first_weekday_updated_at > v_existing.first_weekday_updated_at THEN p_first_weekday ELSE v_existing.first_weekday END,
                first_weekday_updated_at = GREATEST(p_first_weekday_updated_at, v_existing.first_weekday_updated_at)
            WHERE id = p_id RETURNING * INTO v_result;
        END IF;
    END IF;

    RETURN to_jsonb(v_result);
END;
$$;

CREATE FUNCTION public.merge_spread(p_id uuid, p_user_id uuid, p_device_id uuid, p_period text, p_date date, p_start_date date, p_end_date date, p_is_favorite boolean, p_custom_name text, p_uses_dynamic_name boolean, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_start_date_updated_at timestamp with time zone, p_end_date_updated_at timestamp with time zone, p_is_favorite_updated_at timestamp with time zone, p_custom_name_updated_at timestamp with time zone, p_uses_dynamic_name_updated_at timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_existing RECORD;
    v_result RECORD;
BEGIN
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    -- Primary lookup: by id
    SELECT * INTO v_existing FROM spreads WHERE id = p_id AND user_id = p_user_id;

    -- Fallback lookup: by (user_id, period, date) to handle duplicate-UUID conflicts
    IF NOT FOUND THEN
        SELECT * INTO v_existing FROM spreads
        WHERE user_id = p_user_id AND period = p_period AND date = p_date;
    END IF;

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
            WHERE id = v_existing.id RETURNING * INTO v_result;
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
            WHERE id = v_existing.id RETURNING * INTO v_result;
        END IF;
    END IF;

    RETURN to_jsonb(v_result);
END;
$$;

CREATE FUNCTION public.merge_tag(p_id uuid, p_user_id uuid, p_device_id uuid, p_name text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_name_updated_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
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

CREATE FUNCTION public.merge_entry_batch(p_rows jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_row jsonb;
    v_result jsonb;
    v_results jsonb := '[]'::jsonb;
BEGIN
    FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows)
    LOOP
        BEGIN
            v_result := public.merge_entry(
                (v_row->>'p_id')::uuid, (v_row->>'p_user_id')::uuid, (v_row->>'p_device_id')::uuid,
                v_row->>'p_type', v_row->>'p_title', v_row->>'p_content',
                (v_row->>'p_date')::date, v_row->>'p_period', v_row->>'p_status',
                v_row->>'p_body', v_row->>'p_priority', (v_row->>'p_due_date')::date,
                (v_row->>'p_list_id')::uuid,
                (v_row->>'p_created_at')::timestamptz, (v_row->>'p_deleted_at')::timestamptz,
                (v_row->>'p_title_updated_at')::timestamptz, (v_row->>'p_content_updated_at')::timestamptz,
                (v_row->>'p_date_updated_at')::timestamptz, (v_row->>'p_period_updated_at')::timestamptz,
                (v_row->>'p_status_updated_at')::timestamptz, (v_row->>'p_body_updated_at')::timestamptz,
                (v_row->>'p_priority_updated_at')::timestamptz, (v_row->>'p_due_date_updated_at')::timestamptz,
                (v_row->>'p_list_updated_at')::timestamptz
            );
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_row->>'p_id', 'success', true, 'row', v_result));
        EXCEPTION WHEN OTHERS THEN
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_row->>'p_id', 'success', false, 'error', SQLERRM));
        END;
    END LOOP;

    RETURN v_results;
END;
$$;

CREATE FUNCTION public.merge_assignment_batch(p_rows jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_row jsonb;
    v_result jsonb;
    v_results jsonb := '[]'::jsonb;
BEGIN
    FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows)
    LOOP
        BEGIN
            v_result := public.merge_assignment(
                (v_row->>'p_id')::uuid, (v_row->>'p_user_id')::uuid, (v_row->>'p_device_id')::uuid,
                (v_row->>'p_entry_id')::uuid, v_row->>'p_entry_type', v_row->>'p_period',
                (v_row->>'p_date')::date, (v_row->>'p_spread_id')::uuid, v_row->>'p_status',
                (v_row->>'p_created_at')::timestamptz, (v_row->>'p_deleted_at')::timestamptz,
                (v_row->>'p_status_updated_at')::timestamptz
            );
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_row->>'p_id', 'success', true, 'row', v_result));
        EXCEPTION WHEN OTHERS THEN
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_row->>'p_id', 'success', false, 'error', SQLERRM));
        END;
    END LOOP;

    RETURN v_results;
END;
$$;

CREATE FUNCTION public.merge_entry_tag_batch(p_rows jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_row jsonb;
    v_id text;
    v_results jsonb := '[]'::jsonb;
BEGIN
    FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows)
    LOOP
        v_id := (v_row->>'p_entry_id') || ':' || (v_row->>'p_tag_id');
        BEGIN
            PERFORM public.merge_entry_tag(
                (v_row->>'p_entry_id')::uuid, (v_row->>'p_tag_id')::uuid, (v_row->>'p_user_id')::uuid,
                (v_row->>'p_created_at')::timestamptz, (v_row->>'p_deleted_at')::timestamptz
            );
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_id, 'success', true, 'row', NULL));
        EXCEPTION WHEN OTHERS THEN
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_id, 'success', false, 'error', SQLERRM));
        END;
    END LOOP;

    RETURN v_results;
END;
$$;

CREATE FUNCTION public.merge_collection_batch(p_rows jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_row jsonb;
    v_result jsonb;
    v_results jsonb := '[]'::jsonb;
BEGIN
    FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows)
    LOOP
        BEGIN
            v_result := public.merge_collection(
                (v_row->>'p_id')::uuid, (v_row->>'p_user_id')::uuid, (v_row->>'p_device_id')::uuid,
                v_row->>'p_title',
                (v_row->>'p_created_at')::timestamptz, (v_row->>'p_deleted_at')::timestamptz,
                (v_row->>'p_title_updated_at')::timestamptz
            );
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_row->>'p_id', 'success', true, 'row', v_result));
        EXCEPTION WHEN OTHERS THEN
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_row->>'p_id', 'success', false, 'error', SQLERRM));
        END;
    END LOOP;

    RETURN v_results;
END;
$$;

CREATE FUNCTION public.merge_list_batch(p_rows jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_row jsonb;
    v_results jsonb := '[]'::jsonb;
BEGIN
    FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows)
    LOOP
        BEGIN
            PERFORM public.merge_list(
                (v_row->>'p_id')::uuid, (v_row->>'p_user_id')::uuid, (v_row->>'p_device_id')::uuid,
                v_row->>'p_name',
                (v_row->>'p_created_at')::timestamptz, (v_row->>'p_deleted_at')::timestamptz,
                (v_row->>'p_name_updated_at')::timestamptz
            );
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_row->>'p_id', 'success', true, 'row', NULL));
        EXCEPTION WHEN OTHERS THEN
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_row->>'p_id', 'success', false, 'error', SQLERRM));
        END;
    END LOOP;

    RETURN v_results;
END;
$$;

CREATE FUNCTION public.merge_settings_batch(p_rows jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_row jsonb;
    v_result jsonb;
    v_results jsonb := '[]'::jsonb;
BEGIN
    FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows)
    LOOP
        BEGIN
            v_result := public.merge_settings(
                (v_row->>'p_id')::uuid, (v_row->>'p_user_id')::uuid, (v_row->>'p_device_id')::uuid,
                v_row->>'p_bujo_mode', (v_row->>'p_first_weekday')::integer,
                (v_row->>'p_created_at')::timestamptz, (v_row->>'p_deleted_at')::timestamptz,
                (v_row->>'p_bujo_mode_updated_at')::timestamptz, (v_row->>'p_first_weekday_updated_at')::timestamptz
            );
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_row->>'p_id', 'success', true, 'row', v_result));
        EXCEPTION WHEN OTHERS THEN
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_row->>'p_id', 'success', false, 'error', SQLERRM));
        END;
    END LOOP;

    RETURN v_results;
END;
$$;

CREATE FUNCTION public.merge_spread_batch(p_rows jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_row jsonb;
    v_result jsonb;
    v_results jsonb := '[]'::jsonb;
BEGIN
    FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows)
    LOOP
        BEGIN
            v_result := public.merge_spread(
                (v_row->>'p_id')::uuid, (v_row->>'p_user_id')::uuid, (v_row->>'p_device_id')::uuid,
                v_row->>'p_period', (v_row->>'p_date')::date,
                (v_row->>'p_start_date')::date, (v_row->>'p_end_date')::date,
                (v_row->>'p_is_favorite')::boolean, v_row->>'p_custom_name', (v_row->>'p_uses_dynamic_name')::boolean,
                (v_row->>'p_created_at')::timestamptz, (v_row->>'p_deleted_at')::timestamptz,
                (v_row->>'p_period_updated_at')::timestamptz, (v_row->>'p_date_updated_at')::timestamptz,
                (v_row->>'p_start_date_updated_at')::timestamptz, (v_row->>'p_end_date_updated_at')::timestamptz,
                (v_row->>'p_is_favorite_updated_at')::timestamptz, (v_row->>'p_custom_name_updated_at')::timestamptz,
                (v_row->>'p_uses_dynamic_name_updated_at')::timestamptz
            );
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_row->>'p_id', 'success', true, 'row', v_result));
        EXCEPTION WHEN OTHERS THEN
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_row->>'p_id', 'success', false, 'error', SQLERRM));
        END;
    END LOOP;

    RETURN v_results;
END;
$$;

CREATE FUNCTION public.merge_tag_batch(p_rows jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_row jsonb;
    v_results jsonb := '[]'::jsonb;
BEGIN
    FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows)
    LOOP
        BEGIN
            PERFORM public.merge_tag(
                (v_row->>'p_id')::uuid, (v_row->>'p_user_id')::uuid, (v_row->>'p_device_id')::uuid,
                v_row->>'p_name',
                (v_row->>'p_created_at')::timestamptz, (v_row->>'p_deleted_at')::timestamptz,
                (v_row->>'p_name_updated_at')::timestamptz
            );
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_row->>'p_id', 'success', true, 'row', NULL));
        EXCEPTION WHEN OTHERS THEN
            v_results := v_results || jsonb_build_array(jsonb_build_object('id', v_row->>'p_id', 'success', false, 'error', SQLERRM));
        END;
    END LOOP;

    RETURN v_results;
END;
$$;

CREATE FUNCTION public.next_revision() RETURNS bigint
    LANGUAGE sql
    AS $$
    SELECT nextval('sync_revision_seq');
$$;

CREATE FUNCTION public.settings_trigger_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.revision := next_revision();
    NEW.updated_at := now();

    IF TG_OP = 'INSERT' THEN
        NEW.bujo_mode_updated_at := COALESCE(NEW.bujo_mode_updated_at, now());
        NEW.first_weekday_updated_at := COALESCE(NEW.first_weekday_updated_at, now());
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.bujo_mode IS DISTINCT FROM OLD.bujo_mode THEN
            NEW.bujo_mode_updated_at := now();
        END IF;
        IF NEW.first_weekday IS DISTINCT FROM OLD.first_weekday THEN
            NEW.first_weekday_updated_at := now();
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE FUNCTION public.spreads_trigger_fn() RETURNS trigger
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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Tables
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
    )
);

CREATE TABLE public.collections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_id uuid NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    title_updated_at timestamp with time zone DEFAULT now() NOT NULL
);

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
    )
);

CREATE TABLE public.entry_tags (
    entry_id uuid NOT NULL,
    tag_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    CONSTRAINT entry_tags_pkey PRIMARY KEY (entry_id, tag_id)
);

CREATE TABLE public.lists (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    device_id uuid,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    name_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT lists_name_check CHECK ((char_length(TRIM(BOTH FROM name)) > 0))
);

CREATE TABLE public.settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_id uuid NOT NULL,
    bujo_mode text DEFAULT 'conventional'::text NOT NULL,
    first_weekday integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    bujo_mode_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    first_weekday_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT settings_bujo_mode_check CHECK ((bujo_mode = ANY (ARRAY['conventional'::text, 'traditional'::text]))),
    CONSTRAINT settings_first_weekday_check CHECK (((first_weekday >= 1) AND (first_weekday <= 7)))
);

CREATE TABLE public.spreads (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_id uuid NOT NULL,
    period text NOT NULL,
    date date NOT NULL,
    start_date date,
    end_date date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    period_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    date_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    start_date_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    end_date_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_favorite boolean DEFAULT false NOT NULL,
    custom_name text,
    uses_dynamic_name boolean DEFAULT false NOT NULL,
    is_favorite_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    custom_name_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    uses_dynamic_name_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT spreads_multiday_dates_check CHECK ((((period = 'multiday'::text) AND (start_date IS NOT NULL) AND (end_date IS NOT NULL)) OR ((period <> 'multiday'::text) AND (start_date IS NULL) AND (end_date IS NULL)))),
    CONSTRAINT spreads_period_check CHECK ((period = ANY (ARRAY['year'::text, 'month'::text, 'day'::text, 'multiday'::text])))
);

CREATE SEQUENCE public.sync_revision_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE public.tags (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    device_id uuid,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    name_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT tags_name_check CHECK ((char_length(TRIM(BOTH FROM name)) > 0))
);

--
-- Primary key constraints
--

ALTER TABLE ONLY public.collections
    ADD CONSTRAINT collections_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.lists
    ADD CONSTRAINT lists_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_user_id_key UNIQUE (user_id);

ALTER TABLE ONLY public.spreads
    ADD CONSTRAINT spreads_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);

--
-- Indices
--

CREATE INDEX collections_user_deleted_idx ON public.collections USING btree (user_id, deleted_at);
CREATE INDEX collections_user_revision_idx ON public.collections USING btree (user_id, revision);

CREATE INDEX lists_revision_idx ON public.lists USING btree (revision);
CREATE INDEX lists_user_id_idx ON public.lists USING btree (user_id);

CREATE INDEX settings_user_deleted_idx ON public.settings USING btree (user_id, deleted_at);
CREATE INDEX settings_user_revision_idx ON public.settings USING btree (user_id, revision);

CREATE INDEX spreads_user_deleted_idx ON public.spreads USING btree (user_id, deleted_at);
CREATE UNIQUE INDEX spreads_user_multiday_range_unique ON public.spreads USING btree (user_id, start_date, end_date) WHERE ((period = 'multiday'::text) AND (deleted_at IS NULL));
CREATE UNIQUE INDEX spreads_user_period_date_unique ON public.spreads USING btree (user_id, period, date) WHERE ((period <> 'multiday'::text) AND (deleted_at IS NULL));
CREATE INDEX spreads_user_revision_idx ON public.spreads USING btree (user_id, revision);

CREATE INDEX tags_revision_idx ON public.tags USING btree (revision);
CREATE INDEX tags_user_id_idx ON public.tags USING btree (user_id);

CREATE INDEX entries_user_deleted_idx ON public.entries USING btree (user_id, deleted_at);
CREATE INDEX entries_user_revision_idx ON public.entries USING btree (user_id, revision);
CREATE INDEX entries_user_type_deleted_idx ON public.entries USING btree (user_id, type, deleted_at);

CREATE INDEX assignments_entry_id_idx ON public.assignments USING btree (entry_id);
CREATE INDEX assignments_spread_id_idx ON public.assignments USING btree (spread_id);
CREATE INDEX assignments_user_deleted_idx ON public.assignments USING btree (user_id, deleted_at);
CREATE INDEX assignments_user_revision_idx ON public.assignments USING btree (user_id, revision);
CREATE UNIQUE INDEX assignments_user_entry_multiday_spread_unique ON public.assignments USING btree (user_id, entry_id, spread_id) WHERE ((deleted_at IS NULL) AND (spread_id IS NOT NULL));
CREATE UNIQUE INDEX assignments_user_entry_period_date_unique ON public.assignments USING btree (user_id, entry_id, period, date) WHERE ((deleted_at IS NULL) AND (spread_id IS NULL));

CREATE INDEX entry_tags_entry_id_idx ON public.entry_tags USING btree (entry_id);
CREATE INDEX entry_tags_tag_id_idx ON public.entry_tags USING btree (tag_id);
CREATE INDEX entry_tags_revision_idx ON public.entry_tags USING btree (revision);

--
-- Triggers
--

CREATE TRIGGER collections_before_upsert BEFORE INSERT OR UPDATE ON public.collections FOR EACH ROW EXECUTE FUNCTION public.collections_trigger_fn();
CREATE TRIGGER settings_before_upsert BEFORE INSERT OR UPDATE ON public.settings FOR EACH ROW EXECUTE FUNCTION public.settings_trigger_fn();
CREATE TRIGGER spreads_before_upsert BEFORE INSERT OR UPDATE ON public.spreads FOR EACH ROW EXECUTE FUNCTION public.spreads_trigger_fn();
CREATE TRIGGER entries_before_upsert BEFORE INSERT OR UPDATE ON public.entries FOR EACH ROW EXECUTE FUNCTION public.entries_trigger_fn();
CREATE TRIGGER assignments_before_upsert BEFORE INSERT OR UPDATE ON public.assignments FOR EACH ROW EXECUTE FUNCTION public.assignments_trigger_fn();

--
-- Foreign key constraints
--

ALTER TABLE ONLY public.lists
    ADD CONSTRAINT lists_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT entries_list_id_fkey FOREIGN KEY (list_id) REFERENCES public.lists(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT assignments_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT assignments_spread_id_fkey FOREIGN KEY (spread_id) REFERENCES public.spreads(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.entry_tags
    ADD CONSTRAINT entry_tags_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.entry_tags
    ADD CONSTRAINT entry_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.entry_tags
    ADD CONSTRAINT entry_tags_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

--
-- Row level security policies
--

CREATE POLICY "Users can delete their own collections" ON public.collections FOR DELETE USING ((auth.uid() = user_id));
CREATE POLICY "Users can insert their own collections" ON public.collections FOR INSERT WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Users can select their own collections" ON public.collections FOR SELECT USING ((auth.uid() = user_id));
CREATE POLICY "Users can update their own collections" ON public.collections FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));

CREATE POLICY "Users can delete their own settings" ON public.settings FOR DELETE USING ((auth.uid() = user_id));
CREATE POLICY "Users can insert their own settings" ON public.settings FOR INSERT WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Users can select their own settings" ON public.settings FOR SELECT USING ((auth.uid() = user_id));
CREATE POLICY "Users can update their own settings" ON public.settings FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));

CREATE POLICY "Users can delete their own spreads" ON public.spreads FOR DELETE USING ((auth.uid() = user_id));
CREATE POLICY "Users can insert their own spreads" ON public.spreads FOR INSERT WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Users can select their own spreads" ON public.spreads FOR SELECT USING ((auth.uid() = user_id));
CREATE POLICY "Users can update their own spreads" ON public.spreads FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));

CREATE POLICY "Users can manage their own lists" ON public.lists USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Users can manage their own tags" ON public.tags USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));

CREATE POLICY "Users can select their own entries" ON public.entries FOR SELECT USING ((auth.uid() = user_id));
CREATE POLICY "Users can insert their own entries" ON public.entries FOR INSERT WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Users can update their own entries" ON public.entries FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Users can delete their own entries" ON public.entries FOR DELETE USING ((auth.uid() = user_id));

CREATE POLICY "Users can select their own assignments" ON public.assignments FOR SELECT USING ((auth.uid() = user_id));
CREATE POLICY "Users can insert their own assignments" ON public.assignments FOR INSERT WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Users can update their own assignments" ON public.assignments FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "Users can delete their own assignments" ON public.assignments FOR DELETE USING ((auth.uid() = user_id));

CREATE POLICY "Users can manage their own entry_tags" ON public.entry_tags USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));

ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spreads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entry_tags ENABLE ROW LEVEL SECURITY;

--
-- Grants
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;

GRANT ALL ON FUNCTION public.assignments_trigger_fn() TO anon;
GRANT ALL ON FUNCTION public.assignments_trigger_fn() TO authenticated;
GRANT ALL ON FUNCTION public.assignments_trigger_fn() TO service_role;

GRANT ALL ON FUNCTION public.cleanup_tombstones() TO anon;
GRANT ALL ON FUNCTION public.cleanup_tombstones() TO authenticated;
GRANT ALL ON FUNCTION public.cleanup_tombstones() TO service_role;

GRANT ALL ON FUNCTION public.collections_trigger_fn() TO anon;
GRANT ALL ON FUNCTION public.collections_trigger_fn() TO authenticated;
GRANT ALL ON FUNCTION public.collections_trigger_fn() TO service_role;

GRANT ALL ON FUNCTION public.entries_trigger_fn() TO anon;
GRANT ALL ON FUNCTION public.entries_trigger_fn() TO authenticated;
GRANT ALL ON FUNCTION public.entries_trigger_fn() TO service_role;

GRANT ALL ON FUNCTION public.merge_entry(p_id uuid, p_user_id uuid, p_device_id uuid, p_type text, p_title text, p_content text, p_date date, p_period text, p_status text, p_body text, p_priority text, p_due_date date, p_list_id uuid, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone, p_content_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_status_updated_at timestamp with time zone, p_body_updated_at timestamp with time zone, p_priority_updated_at timestamp with time zone, p_due_date_updated_at timestamp with time zone, p_list_updated_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_entry(p_id uuid, p_user_id uuid, p_device_id uuid, p_type text, p_title text, p_content text, p_date date, p_period text, p_status text, p_body text, p_priority text, p_due_date date, p_list_id uuid, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone, p_content_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_status_updated_at timestamp with time zone, p_body_updated_at timestamp with time zone, p_priority_updated_at timestamp with time zone, p_due_date_updated_at timestamp with time zone, p_list_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_entry(p_id uuid, p_user_id uuid, p_device_id uuid, p_type text, p_title text, p_content text, p_date date, p_period text, p_status text, p_body text, p_priority text, p_due_date date, p_list_id uuid, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone, p_content_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_status_updated_at timestamp with time zone, p_body_updated_at timestamp with time zone, p_priority_updated_at timestamp with time zone, p_due_date_updated_at timestamp with time zone, p_list_updated_at timestamp with time zone) TO service_role;

GRANT ALL ON FUNCTION public.merge_assignment(p_id uuid, p_user_id uuid, p_device_id uuid, p_entry_id uuid, p_entry_type text, p_period text, p_date date, p_spread_id uuid, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_assignment(p_id uuid, p_user_id uuid, p_device_id uuid, p_entry_id uuid, p_entry_type text, p_period text, p_date date, p_spread_id uuid, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_assignment(p_id uuid, p_user_id uuid, p_device_id uuid, p_entry_id uuid, p_entry_type text, p_period text, p_date date, p_spread_id uuid, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO service_role;

GRANT ALL ON FUNCTION public.merge_entry_tag(p_entry_id uuid, p_tag_id uuid, p_user_id uuid, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_entry_tag(p_entry_id uuid, p_tag_id uuid, p_user_id uuid, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_entry_tag(p_entry_id uuid, p_tag_id uuid, p_user_id uuid, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone) TO service_role;

GRANT ALL ON FUNCTION public.merge_collection(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_collection(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_collection(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone) TO service_role;

GRANT ALL ON FUNCTION public.merge_list(p_id uuid, p_user_id uuid, p_device_id uuid, p_name text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_name_updated_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_list(p_id uuid, p_user_id uuid, p_device_id uuid, p_name text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_name_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_list(p_id uuid, p_user_id uuid, p_device_id uuid, p_name text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_name_updated_at timestamp with time zone) TO service_role;

GRANT ALL ON FUNCTION public.merge_settings(p_id uuid, p_user_id uuid, p_device_id uuid, p_bujo_mode text, p_first_weekday integer, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_bujo_mode_updated_at timestamp with time zone, p_first_weekday_updated_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_settings(p_id uuid, p_user_id uuid, p_device_id uuid, p_bujo_mode text, p_first_weekday integer, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_bujo_mode_updated_at timestamp with time zone, p_first_weekday_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_settings(p_id uuid, p_user_id uuid, p_device_id uuid, p_bujo_mode text, p_first_weekday integer, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_bujo_mode_updated_at timestamp with time zone, p_first_weekday_updated_at timestamp with time zone) TO service_role;

GRANT ALL ON FUNCTION public.merge_spread(p_id uuid, p_user_id uuid, p_device_id uuid, p_period text, p_date date, p_start_date date, p_end_date date, p_is_favorite boolean, p_custom_name text, p_uses_dynamic_name boolean, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_start_date_updated_at timestamp with time zone, p_end_date_updated_at timestamp with time zone, p_is_favorite_updated_at timestamp with time zone, p_custom_name_updated_at timestamp with time zone, p_uses_dynamic_name_updated_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_spread(p_id uuid, p_user_id uuid, p_device_id uuid, p_period text, p_date date, p_start_date date, p_end_date date, p_is_favorite boolean, p_custom_name text, p_uses_dynamic_name boolean, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_start_date_updated_at timestamp with time zone, p_end_date_updated_at timestamp with time zone, p_is_favorite_updated_at timestamp with time zone, p_custom_name_updated_at timestamp with time zone, p_uses_dynamic_name_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_spread(p_id uuid, p_user_id uuid, p_device_id uuid, p_period text, p_date date, p_start_date date, p_end_date date, p_is_favorite boolean, p_custom_name text, p_uses_dynamic_name boolean, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_start_date_updated_at timestamp with time zone, p_end_date_updated_at timestamp with time zone, p_is_favorite_updated_at timestamp with time zone, p_custom_name_updated_at timestamp with time zone, p_uses_dynamic_name_updated_at timestamp with time zone) TO service_role;

GRANT ALL ON FUNCTION public.merge_tag(p_id uuid, p_user_id uuid, p_device_id uuid, p_name text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_name_updated_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_tag(p_id uuid, p_user_id uuid, p_device_id uuid, p_name text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_name_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_tag(p_id uuid, p_user_id uuid, p_device_id uuid, p_name text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_name_updated_at timestamp with time zone) TO service_role;

GRANT ALL ON FUNCTION public.merge_entry_batch(p_rows jsonb) TO anon;
GRANT ALL ON FUNCTION public.merge_entry_batch(p_rows jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.merge_entry_batch(p_rows jsonb) TO service_role;

GRANT ALL ON FUNCTION public.merge_assignment_batch(p_rows jsonb) TO anon;
GRANT ALL ON FUNCTION public.merge_assignment_batch(p_rows jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.merge_assignment_batch(p_rows jsonb) TO service_role;

GRANT ALL ON FUNCTION public.merge_entry_tag_batch(p_rows jsonb) TO anon;
GRANT ALL ON FUNCTION public.merge_entry_tag_batch(p_rows jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.merge_entry_tag_batch(p_rows jsonb) TO service_role;

GRANT ALL ON FUNCTION public.merge_collection_batch(p_rows jsonb) TO anon;
GRANT ALL ON FUNCTION public.merge_collection_batch(p_rows jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.merge_collection_batch(p_rows jsonb) TO service_role;

GRANT ALL ON FUNCTION public.merge_list_batch(p_rows jsonb) TO anon;
GRANT ALL ON FUNCTION public.merge_list_batch(p_rows jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.merge_list_batch(p_rows jsonb) TO service_role;

GRANT ALL ON FUNCTION public.merge_settings_batch(p_rows jsonb) TO anon;
GRANT ALL ON FUNCTION public.merge_settings_batch(p_rows jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.merge_settings_batch(p_rows jsonb) TO service_role;

GRANT ALL ON FUNCTION public.merge_spread_batch(p_rows jsonb) TO anon;
GRANT ALL ON FUNCTION public.merge_spread_batch(p_rows jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.merge_spread_batch(p_rows jsonb) TO service_role;

GRANT ALL ON FUNCTION public.merge_tag_batch(p_rows jsonb) TO anon;
GRANT ALL ON FUNCTION public.merge_tag_batch(p_rows jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.merge_tag_batch(p_rows jsonb) TO service_role;

GRANT ALL ON FUNCTION public.next_revision() TO anon;
GRANT ALL ON FUNCTION public.next_revision() TO authenticated;
GRANT ALL ON FUNCTION public.next_revision() TO service_role;

GRANT ALL ON FUNCTION public.settings_trigger_fn() TO anon;
GRANT ALL ON FUNCTION public.settings_trigger_fn() TO authenticated;
GRANT ALL ON FUNCTION public.settings_trigger_fn() TO service_role;

GRANT ALL ON FUNCTION public.spreads_trigger_fn() TO anon;
GRANT ALL ON FUNCTION public.spreads_trigger_fn() TO authenticated;
GRANT ALL ON FUNCTION public.spreads_trigger_fn() TO service_role;

GRANT ALL ON TABLE public.collections TO anon;
GRANT ALL ON TABLE public.collections TO authenticated;
GRANT ALL ON TABLE public.collections TO service_role;

GRANT ALL ON TABLE public.lists TO anon;
GRANT ALL ON TABLE public.lists TO authenticated;
GRANT ALL ON TABLE public.lists TO service_role;

GRANT ALL ON TABLE public.settings TO anon;
GRANT ALL ON TABLE public.settings TO authenticated;
GRANT ALL ON TABLE public.settings TO service_role;

GRANT ALL ON TABLE public.spreads TO anon;
GRANT ALL ON TABLE public.spreads TO authenticated;
GRANT ALL ON TABLE public.spreads TO service_role;

GRANT ALL ON SEQUENCE public.sync_revision_seq TO anon;
GRANT ALL ON SEQUENCE public.sync_revision_seq TO authenticated;
GRANT ALL ON SEQUENCE public.sync_revision_seq TO service_role;

GRANT ALL ON TABLE public.tags TO anon;
GRANT ALL ON TABLE public.tags TO authenticated;
GRANT ALL ON TABLE public.tags TO service_role;

GRANT ALL ON TABLE public.entries TO anon;
GRANT ALL ON TABLE public.entries TO authenticated;
GRANT ALL ON TABLE public.entries TO service_role;

GRANT ALL ON TABLE public.assignments TO anon;
GRANT ALL ON TABLE public.assignments TO authenticated;
GRANT ALL ON TABLE public.assignments TO service_role;

GRANT ALL ON TABLE public.entry_tags TO anon;
GRANT ALL ON TABLE public.entry_tags TO authenticated;
GRANT ALL ON TABLE public.entry_tags TO service_role;
