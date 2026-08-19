-- ============================================================================
-- SQL: Strip Any Bloated Metadata from Supabase Auth Users
-- Target: ktabfbscrehhdstggjzp.supabase.co
-- Purpose: Permanently prevent Cloudflare "400 Request Header Or Cookie Too Large"
-- ============================================================================

UPDATE auth.users
SET raw_user_meta_data = jsonb_build_object(
    'role', raw_user_meta_data->>'role',
    'full_name', raw_user_meta_data->>'full_name',
    'phone', raw_user_meta_data->>'phone'
)
WHERE raw_user_meta_data IS NOT NULL;
