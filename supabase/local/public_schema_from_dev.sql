--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.3

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
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--



--
-- Name: cleanup_tombstones(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_tombstones() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: collections_trigger_fn(); Type: FUNCTION; Schema: public; Owner: -
--

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


--
-- Name: merge_collection(uuid, uuid, uuid, text, timestamp with time zone, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

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


--
-- Name: merge_note(uuid, uuid, uuid, text, text, date, text, text, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.merge_note(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_content text, p_date date, p_period text, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone, p_content_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_status_updated_at timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_existing RECORD;
    v_result RECORD;
BEGIN
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    SELECT * INTO v_existing FROM notes WHERE id = p_id AND user_id = p_user_id;
    
    IF NOT FOUND THEN
        INSERT INTO notes (
            id, user_id, device_id, title, content, date, period, status,
            created_at, deleted_at,
            title_updated_at, content_updated_at, date_updated_at, period_updated_at, status_updated_at
        ) VALUES (
            p_id, p_user_id, p_device_id, p_title, p_content, p_date, p_period, p_status,
            p_created_at, p_deleted_at,
            p_title_updated_at, p_content_updated_at, p_date_updated_at, p_period_updated_at, p_status_updated_at
        )
        RETURNING * INTO v_result;
    ELSE
        IF p_deleted_at IS NOT NULL AND (v_existing.deleted_at IS NULL OR p_deleted_at > v_existing.deleted_at) THEN
            UPDATE notes SET deleted_at = p_deleted_at, device_id = p_device_id
            WHERE id = p_id RETURNING * INTO v_result;
        ELSE
            UPDATE notes SET
                device_id = p_device_id,
                title = CASE WHEN p_title_updated_at > v_existing.title_updated_at THEN p_title ELSE v_existing.title END,
                title_updated_at = GREATEST(p_title_updated_at, v_existing.title_updated_at),
                content = CASE WHEN p_content_updated_at > v_existing.content_updated_at THEN p_content ELSE v_existing.content END,
                content_updated_at = GREATEST(p_content_updated_at, v_existing.content_updated_at),
                date = CASE WHEN p_date_updated_at > v_existing.date_updated_at THEN p_date ELSE v_existing.date END,
                date_updated_at = GREATEST(p_date_updated_at, v_existing.date_updated_at),
                period = CASE WHEN p_period_updated_at > v_existing.period_updated_at THEN p_period ELSE v_existing.period END,
                period_updated_at = GREATEST(p_period_updated_at, v_existing.period_updated_at),
                status = CASE WHEN p_status_updated_at > v_existing.status_updated_at THEN p_status ELSE v_existing.status END,
                status_updated_at = GREATEST(p_status_updated_at, v_existing.status_updated_at)
            WHERE id = p_id RETURNING * INTO v_result;
        END IF;
    END IF;
    
    RETURN to_jsonb(v_result);
END;
$$;


--
-- Name: merge_note_assignment(uuid, uuid, uuid, uuid, text, date, text, timestamp with time zone, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.merge_note_assignment(p_id uuid, p_user_id uuid, p_device_id uuid, p_note_id uuid, p_period text, p_date date, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_status_updated_at timestamp with time zone) RETURNS jsonb
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
        INSERT INTO note_assignments (
            id, user_id, device_id, note_id, period, date, status,
            created_at, deleted_at, status_updated_at
        ) VALUES (
            p_id, p_user_id, p_device_id, p_note_id, p_period, p_date, p_status,
            p_created_at, p_deleted_at, p_status_updated_at
        )
        RETURNING * INTO v_result;
    ELSE
        IF p_deleted_at IS NOT NULL AND (v_existing.deleted_at IS NULL OR p_deleted_at > v_existing.deleted_at) THEN
            UPDATE note_assignments SET deleted_at = p_deleted_at, device_id = p_device_id
            WHERE id = p_id RETURNING * INTO v_result;
        ELSE
            UPDATE note_assignments SET
                device_id = p_device_id,
                status = CASE WHEN p_status_updated_at > v_existing.status_updated_at THEN p_status ELSE v_existing.status END,
                status_updated_at = GREATEST(p_status_updated_at, v_existing.status_updated_at)
            WHERE id = p_id RETURNING * INTO v_result;
        END IF;
    END IF;
    
    RETURN to_jsonb(v_result);
END;
$$;


--
-- Name: merge_settings(uuid, uuid, uuid, text, integer, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

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


--
-- Name: merge_spread(uuid, uuid, uuid, text, date, date, date, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.merge_spread(p_id uuid, p_user_id uuid, p_device_id uuid, p_period text, p_date date, p_start_date date, p_end_date date, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_start_date_updated_at timestamp with time zone, p_end_date_updated_at timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_existing RECORD;
    v_result RECORD;
BEGIN
    -- Check ownership
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;

    -- Get existing record
    SELECT * INTO v_existing FROM spreads WHERE id = p_id AND user_id = p_user_id;
    
    IF NOT FOUND THEN
        -- Insert new record
        INSERT INTO spreads (
            id, user_id, device_id, period, date, start_date, end_date,
            created_at, deleted_at,
            period_updated_at, date_updated_at, start_date_updated_at, end_date_updated_at
        ) VALUES (
            p_id, p_user_id, p_device_id, p_period, p_date, p_start_date, p_end_date,
            p_created_at, p_deleted_at,
            p_period_updated_at, p_date_updated_at, p_start_date_updated_at, p_end_date_updated_at
        )
        RETURNING * INTO v_result;
    ELSE
        -- Delete-wins: if incoming deleted_at is newer, apply it
        IF p_deleted_at IS NOT NULL AND (v_existing.deleted_at IS NULL OR p_deleted_at > v_existing.deleted_at) THEN
            UPDATE spreads SET
                deleted_at = p_deleted_at,
                device_id = p_device_id
            WHERE id = p_id
            RETURNING * INTO v_result;
        ELSE
            -- Field-level LWW merge
            UPDATE spreads SET
                device_id = p_device_id,
                period = CASE WHEN p_period_updated_at > v_existing.period_updated_at THEN p_period ELSE v_existing.period END,
                period_updated_at = GREATEST(p_period_updated_at, v_existing.period_updated_at),
                date = CASE WHEN p_date_updated_at > v_existing.date_updated_at THEN p_date ELSE v_existing.date END,
                date_updated_at = GREATEST(p_date_updated_at, v_existing.date_updated_at),
                start_date = CASE WHEN p_start_date_updated_at > v_existing.start_date_updated_at THEN p_start_date ELSE v_existing.start_date END,
                start_date_updated_at = GREATEST(p_start_date_updated_at, v_existing.start_date_updated_at),
                end_date = CASE WHEN p_end_date_updated_at > v_existing.end_date_updated_at THEN p_end_date ELSE v_existing.end_date END,
                end_date_updated_at = GREATEST(p_end_date_updated_at, v_existing.end_date_updated_at)
            WHERE id = p_id
            RETURNING * INTO v_result;
        END IF;
    END IF;
    
    RETURN to_jsonb(v_result);
END;
$$;


--
-- Name: merge_task(uuid, uuid, uuid, text, date, text, text, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.merge_task(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_date date, p_period text, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_status_updated_at timestamp with time zone) RETURNS jsonb
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
            id, user_id, device_id, title, date, period, status,
            created_at, deleted_at,
            title_updated_at, date_updated_at, period_updated_at, status_updated_at
        ) VALUES (
            p_id, p_user_id, p_device_id, p_title, p_date, p_period, p_status,
            p_created_at, p_deleted_at,
            p_title_updated_at, p_date_updated_at, p_period_updated_at, p_status_updated_at
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
                status_updated_at = GREATEST(p_status_updated_at, v_existing.status_updated_at)
            WHERE id = p_id RETURNING * INTO v_result;
        END IF;
    END IF;
    
    RETURN to_jsonb(v_result);
END;
$$;


--
-- Name: merge_task_assignment(uuid, uuid, uuid, uuid, text, date, text, timestamp with time zone, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.merge_task_assignment(p_id uuid, p_user_id uuid, p_device_id uuid, p_task_id uuid, p_period text, p_date date, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_status_updated_at timestamp with time zone) RETURNS jsonb
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
        INSERT INTO task_assignments (
            id, user_id, device_id, task_id, period, date, status,
            created_at, deleted_at, status_updated_at
        ) VALUES (
            p_id, p_user_id, p_device_id, p_task_id, p_period, p_date, p_status,
            p_created_at, p_deleted_at, p_status_updated_at
        )
        RETURNING * INTO v_result;
    ELSE
        IF p_deleted_at IS NOT NULL AND (v_existing.deleted_at IS NULL OR p_deleted_at > v_existing.deleted_at) THEN
            UPDATE task_assignments SET deleted_at = p_deleted_at, device_id = p_device_id
            WHERE id = p_id RETURNING * INTO v_result;
        ELSE
            UPDATE task_assignments SET
                device_id = p_device_id,
                status = CASE WHEN p_status_updated_at > v_existing.status_updated_at THEN p_status ELSE v_existing.status END,
                status_updated_at = GREATEST(p_status_updated_at, v_existing.status_updated_at)
            WHERE id = p_id RETURNING * INTO v_result;
        END IF;
    END IF;
    
    RETURN to_jsonb(v_result);
END;
$$;


--
-- Name: next_revision(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.next_revision() RETURNS bigint
    LANGUAGE sql
    AS $$
    SELECT nextval('sync_revision_seq');
$$;


--
-- Name: note_assignments_trigger_fn(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.note_assignments_trigger_fn() RETURNS trigger
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


--
-- Name: notes_trigger_fn(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notes_trigger_fn() RETURNS trigger
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
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: settings_trigger_fn(); Type: FUNCTION; Schema: public; Owner: -
--

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


--
-- Name: spreads_trigger_fn(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.spreads_trigger_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Always update revision and updated_at
    NEW.revision := next_revision();
    NEW.updated_at := now();
    
    IF TG_OP = 'INSERT' THEN
        -- On insert, set all field timestamps
        NEW.period_updated_at := COALESCE(NEW.period_updated_at, now());
        NEW.date_updated_at := COALESCE(NEW.date_updated_at, now());
        NEW.start_date_updated_at := COALESCE(NEW.start_date_updated_at, now());
        NEW.end_date_updated_at := COALESCE(NEW.end_date_updated_at, now());
    ELSIF TG_OP = 'UPDATE' THEN
        -- On update, only update timestamps for changed fields
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
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: task_assignments_trigger_fn(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.task_assignments_trigger_fn() RETURNS trigger
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


--
-- Name: tasks_trigger_fn(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tasks_trigger_fn() RETURNS trigger
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
    END IF;
    
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: collections; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: note_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.note_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_id uuid NOT NULL,
    note_id uuid NOT NULL,
    period text NOT NULL,
    date date NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    status_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT note_assignments_period_check CHECK ((period = ANY (ARRAY['year'::text, 'month'::text, 'day'::text, 'multiday'::text]))),
    CONSTRAINT note_assignments_status_check CHECK ((status = ANY (ARRAY['active'::text, 'migrated'::text])))
);


--
-- Name: notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_id uuid NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    content text DEFAULT ''::text NOT NULL,
    date date NOT NULL,
    period text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    title_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    content_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    date_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    period_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    status_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT notes_period_check CHECK ((period = ANY (ARRAY['year'::text, 'month'::text, 'day'::text, 'multiday'::text]))),
    CONSTRAINT notes_status_check CHECK ((status = ANY (ARRAY['active'::text, 'migrated'::text])))
);


--
-- Name: settings; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: spreads; Type: TABLE; Schema: public; Owner: -
--

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
    CONSTRAINT spreads_multiday_dates_check CHECK ((((period = 'multiday'::text) AND (start_date IS NOT NULL) AND (end_date IS NOT NULL)) OR ((period <> 'multiday'::text) AND (start_date IS NULL) AND (end_date IS NULL)))),
    CONSTRAINT spreads_period_check CHECK ((period = ANY (ARRAY['year'::text, 'month'::text, 'day'::text, 'multiday'::text])))
);


--
-- Name: sync_revision_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sync_revision_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_id uuid NOT NULL,
    task_id uuid NOT NULL,
    period text NOT NULL,
    date date NOT NULL,
    status text DEFAULT 'open'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    status_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT task_assignments_period_check CHECK ((period = ANY (ARRAY['year'::text, 'month'::text, 'day'::text, 'multiday'::text]))),
    CONSTRAINT task_assignments_status_check CHECK ((status = ANY (ARRAY['open'::text, 'complete'::text, 'migrated'::text, 'cancelled'::text])))
);


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_id uuid NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    date date NOT NULL,
    period text NOT NULL,
    status text DEFAULT 'open'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    revision bigint DEFAULT 0 NOT NULL,
    title_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    date_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    period_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    status_updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT tasks_period_check CHECK ((period = ANY (ARRAY['year'::text, 'month'::text, 'day'::text, 'multiday'::text]))),
    CONSTRAINT tasks_status_check CHECK ((status = ANY (ARRAY['open'::text, 'complete'::text, 'migrated'::text, 'cancelled'::text])))
);


--
-- Name: collections collections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collections
    ADD CONSTRAINT collections_pkey PRIMARY KEY (id);


--
-- Name: note_assignments note_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_assignments
    ADD CONSTRAINT note_assignments_pkey PRIMARY KEY (id);


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: settings settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_pkey PRIMARY KEY (id);


--
-- Name: settings settings_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_user_id_key UNIQUE (user_id);


--
-- Name: spreads spreads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spreads
    ADD CONSTRAINT spreads_pkey PRIMARY KEY (id);


--
-- Name: task_assignments task_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: collections_user_deleted_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX collections_user_deleted_idx ON public.collections USING btree (user_id, deleted_at);


--
-- Name: collections_user_revision_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX collections_user_revision_idx ON public.collections USING btree (user_id, revision);


--
-- Name: note_assignments_note_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX note_assignments_note_id_idx ON public.note_assignments USING btree (note_id);


--
-- Name: note_assignments_user_deleted_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX note_assignments_user_deleted_idx ON public.note_assignments USING btree (user_id, deleted_at);


--
-- Name: note_assignments_user_note_period_date_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX note_assignments_user_note_period_date_unique ON public.note_assignments USING btree (user_id, note_id, period, date) WHERE (deleted_at IS NULL);


--
-- Name: note_assignments_user_revision_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX note_assignments_user_revision_idx ON public.note_assignments USING btree (user_id, revision);


--
-- Name: notes_user_deleted_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notes_user_deleted_idx ON public.notes USING btree (user_id, deleted_at);


--
-- Name: notes_user_revision_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notes_user_revision_idx ON public.notes USING btree (user_id, revision);


--
-- Name: settings_user_deleted_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX settings_user_deleted_idx ON public.settings USING btree (user_id, deleted_at);


--
-- Name: settings_user_revision_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX settings_user_revision_idx ON public.settings USING btree (user_id, revision);


--
-- Name: spreads_user_deleted_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX spreads_user_deleted_idx ON public.spreads USING btree (user_id, deleted_at);


--
-- Name: spreads_user_multiday_range_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX spreads_user_multiday_range_unique ON public.spreads USING btree (user_id, start_date, end_date) WHERE ((period = 'multiday'::text) AND (deleted_at IS NULL));


--
-- Name: spreads_user_period_date_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX spreads_user_period_date_unique ON public.spreads USING btree (user_id, period, date) WHERE ((period <> 'multiday'::text) AND (deleted_at IS NULL));


--
-- Name: spreads_user_revision_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX spreads_user_revision_idx ON public.spreads USING btree (user_id, revision);


--
-- Name: task_assignments_task_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_assignments_task_id_idx ON public.task_assignments USING btree (task_id);


--
-- Name: task_assignments_user_deleted_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_assignments_user_deleted_idx ON public.task_assignments USING btree (user_id, deleted_at);


--
-- Name: task_assignments_user_revision_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_assignments_user_revision_idx ON public.task_assignments USING btree (user_id, revision);


--
-- Name: task_assignments_user_task_period_date_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX task_assignments_user_task_period_date_unique ON public.task_assignments USING btree (user_id, task_id, period, date) WHERE (deleted_at IS NULL);


--
-- Name: tasks_user_deleted_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_user_deleted_idx ON public.tasks USING btree (user_id, deleted_at);


--
-- Name: tasks_user_revision_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tasks_user_revision_idx ON public.tasks USING btree (user_id, revision);


--
-- Name: collections collections_before_upsert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER collections_before_upsert BEFORE INSERT OR UPDATE ON public.collections FOR EACH ROW EXECUTE FUNCTION public.collections_trigger_fn();


--
-- Name: note_assignments note_assignments_before_upsert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER note_assignments_before_upsert BEFORE INSERT OR UPDATE ON public.note_assignments FOR EACH ROW EXECUTE FUNCTION public.note_assignments_trigger_fn();


--
-- Name: notes notes_before_upsert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notes_before_upsert BEFORE INSERT OR UPDATE ON public.notes FOR EACH ROW EXECUTE FUNCTION public.notes_trigger_fn();


--
-- Name: settings settings_before_upsert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER settings_before_upsert BEFORE INSERT OR UPDATE ON public.settings FOR EACH ROW EXECUTE FUNCTION public.settings_trigger_fn();


--
-- Name: spreads spreads_before_upsert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER spreads_before_upsert BEFORE INSERT OR UPDATE ON public.spreads FOR EACH ROW EXECUTE FUNCTION public.spreads_trigger_fn();


--
-- Name: task_assignments task_assignments_before_upsert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER task_assignments_before_upsert BEFORE INSERT OR UPDATE ON public.task_assignments FOR EACH ROW EXECUTE FUNCTION public.task_assignments_trigger_fn();


--
-- Name: tasks tasks_before_upsert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tasks_before_upsert BEFORE INSERT OR UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.tasks_trigger_fn();


--
-- Name: note_assignments note_assignments_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_assignments
    ADD CONSTRAINT note_assignments_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(id) ON DELETE CASCADE;


--
-- Name: task_assignments task_assignments_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: collections Users can delete their own collections; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete their own collections" ON public.collections FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: note_assignments Users can delete their own note_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete their own note_assignments" ON public.note_assignments FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: notes Users can delete their own notes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete their own notes" ON public.notes FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: settings Users can delete their own settings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete their own settings" ON public.settings FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: spreads Users can delete their own spreads; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete their own spreads" ON public.spreads FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: task_assignments Users can delete their own task_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete their own task_assignments" ON public.task_assignments FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: tasks Users can delete their own tasks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete their own tasks" ON public.tasks FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: collections Users can insert their own collections; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert their own collections" ON public.collections FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: note_assignments Users can insert their own note_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert their own note_assignments" ON public.note_assignments FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: notes Users can insert their own notes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert their own notes" ON public.notes FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: settings Users can insert their own settings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert their own settings" ON public.settings FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: spreads Users can insert their own spreads; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert their own spreads" ON public.spreads FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: task_assignments Users can insert their own task_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert their own task_assignments" ON public.task_assignments FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: tasks Users can insert their own tasks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert their own tasks" ON public.tasks FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: collections Users can select their own collections; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can select their own collections" ON public.collections FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: note_assignments Users can select their own note_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can select their own note_assignments" ON public.note_assignments FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: notes Users can select their own notes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can select their own notes" ON public.notes FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: settings Users can select their own settings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can select their own settings" ON public.settings FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: spreads Users can select their own spreads; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can select their own spreads" ON public.spreads FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: task_assignments Users can select their own task_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can select their own task_assignments" ON public.task_assignments FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: tasks Users can select their own tasks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can select their own tasks" ON public.tasks FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: collections Users can update their own collections; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update their own collections" ON public.collections FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: note_assignments Users can update their own note_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update their own note_assignments" ON public.note_assignments FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: notes Users can update their own notes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update their own notes" ON public.notes FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: settings Users can update their own settings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update their own settings" ON public.settings FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: spreads Users can update their own spreads; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update their own spreads" ON public.spreads FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: task_assignments Users can update their own task_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update their own task_assignments" ON public.task_assignments FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: tasks Users can update their own tasks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update their own tasks" ON public.tasks FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: collections; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;

--
-- Name: note_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.note_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: notes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

--
-- Name: settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

--
-- Name: spreads; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.spreads ENABLE ROW LEVEL SECURITY;

--
-- Name: task_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.task_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: tasks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION cleanup_tombstones(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.cleanup_tombstones() FROM PUBLIC;
GRANT ALL ON FUNCTION public.cleanup_tombstones() TO anon;
GRANT ALL ON FUNCTION public.cleanup_tombstones() TO authenticated;
GRANT ALL ON FUNCTION public.cleanup_tombstones() TO service_role;


--
-- Name: FUNCTION collections_trigger_fn(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.collections_trigger_fn() TO anon;
GRANT ALL ON FUNCTION public.collections_trigger_fn() TO authenticated;
GRANT ALL ON FUNCTION public.collections_trigger_fn() TO service_role;


--
-- Name: FUNCTION merge_collection(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.merge_collection(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_collection(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_collection(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone) TO service_role;


--
-- Name: FUNCTION merge_note(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_content text, p_date date, p_period text, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone, p_content_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_status_updated_at timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.merge_note(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_content text, p_date date, p_period text, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone, p_content_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_note(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_content text, p_date date, p_period text, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone, p_content_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_note(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_content text, p_date date, p_period text, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone, p_content_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO service_role;


--
-- Name: FUNCTION merge_note_assignment(p_id uuid, p_user_id uuid, p_device_id uuid, p_note_id uuid, p_period text, p_date date, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_status_updated_at timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.merge_note_assignment(p_id uuid, p_user_id uuid, p_device_id uuid, p_note_id uuid, p_period text, p_date date, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_note_assignment(p_id uuid, p_user_id uuid, p_device_id uuid, p_note_id uuid, p_period text, p_date date, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_note_assignment(p_id uuid, p_user_id uuid, p_device_id uuid, p_note_id uuid, p_period text, p_date date, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO service_role;


--
-- Name: FUNCTION merge_settings(p_id uuid, p_user_id uuid, p_device_id uuid, p_bujo_mode text, p_first_weekday integer, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_bujo_mode_updated_at timestamp with time zone, p_first_weekday_updated_at timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.merge_settings(p_id uuid, p_user_id uuid, p_device_id uuid, p_bujo_mode text, p_first_weekday integer, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_bujo_mode_updated_at timestamp with time zone, p_first_weekday_updated_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_settings(p_id uuid, p_user_id uuid, p_device_id uuid, p_bujo_mode text, p_first_weekday integer, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_bujo_mode_updated_at timestamp with time zone, p_first_weekday_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_settings(p_id uuid, p_user_id uuid, p_device_id uuid, p_bujo_mode text, p_first_weekday integer, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_bujo_mode_updated_at timestamp with time zone, p_first_weekday_updated_at timestamp with time zone) TO service_role;


--
-- Name: FUNCTION merge_spread(p_id uuid, p_user_id uuid, p_device_id uuid, p_period text, p_date date, p_start_date date, p_end_date date, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_start_date_updated_at timestamp with time zone, p_end_date_updated_at timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.merge_spread(p_id uuid, p_user_id uuid, p_device_id uuid, p_period text, p_date date, p_start_date date, p_end_date date, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_start_date_updated_at timestamp with time zone, p_end_date_updated_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_spread(p_id uuid, p_user_id uuid, p_device_id uuid, p_period text, p_date date, p_start_date date, p_end_date date, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_start_date_updated_at timestamp with time zone, p_end_date_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_spread(p_id uuid, p_user_id uuid, p_device_id uuid, p_period text, p_date date, p_start_date date, p_end_date date, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_start_date_updated_at timestamp with time zone, p_end_date_updated_at timestamp with time zone) TO service_role;


--
-- Name: FUNCTION merge_task(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_date date, p_period text, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_status_updated_at timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.merge_task(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_date date, p_period text, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_task(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_date date, p_period text, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_task(p_id uuid, p_user_id uuid, p_device_id uuid, p_title text, p_date date, p_period text, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_title_updated_at timestamp with time zone, p_date_updated_at timestamp with time zone, p_period_updated_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO service_role;


--
-- Name: FUNCTION merge_task_assignment(p_id uuid, p_user_id uuid, p_device_id uuid, p_task_id uuid, p_period text, p_date date, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_status_updated_at timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.merge_task_assignment(p_id uuid, p_user_id uuid, p_device_id uuid, p_task_id uuid, p_period text, p_date date, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.merge_task_assignment(p_id uuid, p_user_id uuid, p_device_id uuid, p_task_id uuid, p_period text, p_date date, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.merge_task_assignment(p_id uuid, p_user_id uuid, p_device_id uuid, p_task_id uuid, p_period text, p_date date, p_status text, p_created_at timestamp with time zone, p_deleted_at timestamp with time zone, p_status_updated_at timestamp with time zone) TO service_role;


--
-- Name: FUNCTION next_revision(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.next_revision() TO anon;
GRANT ALL ON FUNCTION public.next_revision() TO authenticated;
GRANT ALL ON FUNCTION public.next_revision() TO service_role;


--
-- Name: FUNCTION note_assignments_trigger_fn(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.note_assignments_trigger_fn() TO anon;
GRANT ALL ON FUNCTION public.note_assignments_trigger_fn() TO authenticated;
GRANT ALL ON FUNCTION public.note_assignments_trigger_fn() TO service_role;


--
-- Name: FUNCTION notes_trigger_fn(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.notes_trigger_fn() TO anon;
GRANT ALL ON FUNCTION public.notes_trigger_fn() TO authenticated;
GRANT ALL ON FUNCTION public.notes_trigger_fn() TO service_role;


--
-- Name: FUNCTION settings_trigger_fn(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.settings_trigger_fn() TO anon;
GRANT ALL ON FUNCTION public.settings_trigger_fn() TO authenticated;
GRANT ALL ON FUNCTION public.settings_trigger_fn() TO service_role;


--
-- Name: FUNCTION spreads_trigger_fn(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.spreads_trigger_fn() TO anon;
GRANT ALL ON FUNCTION public.spreads_trigger_fn() TO authenticated;
GRANT ALL ON FUNCTION public.spreads_trigger_fn() TO service_role;


--
-- Name: FUNCTION task_assignments_trigger_fn(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.task_assignments_trigger_fn() TO anon;
GRANT ALL ON FUNCTION public.task_assignments_trigger_fn() TO authenticated;
GRANT ALL ON FUNCTION public.task_assignments_trigger_fn() TO service_role;


--
-- Name: FUNCTION tasks_trigger_fn(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.tasks_trigger_fn() TO anon;
GRANT ALL ON FUNCTION public.tasks_trigger_fn() TO authenticated;
GRANT ALL ON FUNCTION public.tasks_trigger_fn() TO service_role;


--
-- Name: TABLE collections; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.collections TO anon;
GRANT ALL ON TABLE public.collections TO authenticated;
GRANT ALL ON TABLE public.collections TO service_role;


--
-- Name: TABLE note_assignments; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.note_assignments TO anon;
GRANT ALL ON TABLE public.note_assignments TO authenticated;
GRANT ALL ON TABLE public.note_assignments TO service_role;


--
-- Name: TABLE notes; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.notes TO anon;
GRANT ALL ON TABLE public.notes TO authenticated;
GRANT ALL ON TABLE public.notes TO service_role;


--
-- Name: TABLE settings; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.settings TO anon;
GRANT ALL ON TABLE public.settings TO authenticated;
GRANT ALL ON TABLE public.settings TO service_role;


--
-- Name: TABLE spreads; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.spreads TO anon;
GRANT ALL ON TABLE public.spreads TO authenticated;
GRANT ALL ON TABLE public.spreads TO service_role;


--
-- Name: SEQUENCE sync_revision_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.sync_revision_seq TO anon;
GRANT ALL ON SEQUENCE public.sync_revision_seq TO authenticated;
GRANT ALL ON SEQUENCE public.sync_revision_seq TO service_role;


--
-- Name: TABLE task_assignments; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.task_assignments TO anon;
GRANT ALL ON TABLE public.task_assignments TO authenticated;
GRANT ALL ON TABLE public.task_assignments TO service_role;


--
-- Name: TABLE tasks; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.tasks TO anon;
GRANT ALL ON TABLE public.tasks TO authenticated;
GRANT ALL ON TABLE public.tasks TO service_role;


--
-- PostgreSQL database dump complete
--


