-- Fix merge_spread to handle duplicate (user_id, period, date) gracefully.
--
-- Previously, if a spread already existed in Supabase for a given (user_id, period, date)
-- with a different UUID, the INSERT would fail with a unique constraint violation.
-- This can happen when the same spread period is created on two devices before sync,
-- or when a local spread is recreated after a data reset.
--
-- The fix: after finding no row by id, check for an existing row by (user_id, period, date).
-- If found, merge into that row using LWW rules and return it (keeping the server's UUID).

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
