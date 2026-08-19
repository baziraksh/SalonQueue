-- ============================================================================
-- Complete Schema Harmonization & Schema Cache Reload
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/ktabfbscrehhdstggjzp/sql
-- ============================================================================

-- 1. Ensure all columns exist on public.salons
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS district TEXT DEFAULT 'Angul';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Angul';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS state TEXT DEFAULT 'Odisha';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS pincode TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS active_chairs INT DEFAULT 3;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS is_queue_open BOOLEAN DEFAULT true;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT true;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT true;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS opening_time TEXT DEFAULT '09:00 AM';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS closing_time TEXT DEFAULT '09:00 PM';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS cover_image_url TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS banner_url TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS owner_name TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS owner_avatar_url TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS gallery_images JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS rating DOUBLE PRECISION DEFAULT 4.8;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS review_count INT DEFAULT 50;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 2. Ensure UNIQUE(owner_id) constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'salons_owner_id_unique'
    ) THEN
        ALTER TABLE public.salons ADD CONSTRAINT salons_owner_id_unique UNIQUE (owner_id);
    END IF;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

-- 3. Ensure notifications table has user_id
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false;

-- 4. Enable RLS and public policies
ALTER TABLE public.salons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Salons viewable by everyone" ON public.salons;
CREATE POLICY "Salons viewable by everyone" ON public.salons FOR SELECT USING (true);

DROP POLICY IF EXISTS "Owners can insert their own salon" ON public.salons;
CREATE POLICY "Owners can insert their own salon" ON public.salons FOR INSERT WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can update their own salon" ON public.salons;
CREATE POLICY "Owners can update their own salon" ON public.salons FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Notifications viewable by owner" ON public.notifications;
CREATE POLICY "Notifications viewable by owner" ON public.notifications FOR ALL USING (auth.uid() = user_id OR user_id IS NULL);

-- 5. Grant Permissions
GRANT ALL ON TABLE public.salons TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.notifications TO anon, authenticated, service_role;

-- 6. Reload PostgREST Schema Cache
NOTIFY pgrst, 'reload schema';
