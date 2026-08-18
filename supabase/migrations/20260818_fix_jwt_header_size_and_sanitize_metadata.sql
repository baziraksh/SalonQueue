-- ============================================================================
-- Migration: Fix JWT Header Size, Clean Bloated User Metadata & Pre-Auth RPC
-- Date: 2026-08-18
-- Purpose:
--   1. Strip historical large base64 avatar images or metadata fields > 500 chars
--      from auth.users.raw_user_meta_data so GoTrue JWTs remain small (<1KB),
--      preventing HTTP 431 Request Header Fields Too Large on Kong/PostgREST.
--   2. Provide public SECURITY DEFINER RPC function to sanitize metadata on login.
-- ============================================================================

-- 1. Strip oversized base64 avatar_url from auth.users raw_user_meta_data
UPDATE auth.users
SET raw_user_meta_data = raw_user_meta_data - 'avatar_url'
WHERE (raw_user_meta_data->>'avatar_url') LIKE 'data:image%'
   OR length(raw_user_meta_data->>'avatar_url') > 500;

-- 2. Create helper RPC for pre-auth metadata cleanup
CREATE OR REPLACE FUNCTION public.clean_user_metadata_for_login(user_email text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE auth.users
    SET raw_user_meta_data = raw_user_meta_data - 'avatar_url'
    WHERE lower(email) = lower(trim(user_email))
      AND (
        (raw_user_meta_data->>'avatar_url') LIKE 'data:image%'
        OR length(raw_user_meta_data->>'avatar_url') > 500
      );
    RETURN true;
EXCEPTION WHEN OTHERS THEN
    RETURN false;
END;
$$;

GRANT EXECUTE ON FUNCTION public.clean_user_metadata_for_login(text) TO anon, authenticated, service_role;
