-- Local Supabase seed entrypoint.
--
-- Spread currently provisions deterministic local auth users via
-- ./scripts/local-supabase.sh provision-users because auth.users lives outside
-- the normal app schema/reset flow.
--
-- Keep this file present so `supabase db reset` has a stable seed target even
-- when we intentionally skip seed loading during scripted resets.

SELECT 1;
