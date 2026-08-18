-- ============================================================================
-- Migration: Ensure Single Canonical Salon Per Owner, Storage & Full Persistence Fix
-- Date: 2026-08-18
-- Purpose:
--   1. De-duplicate any multiple salon rows per owner_id keeping the latest updated.
--   2. Enforce UNIQUE(owner_id) constraint on public.salons table.
--   3. Ensure RLS policies allow owner CRUD and public read on salons, profiles, services.
--   4. Ensure storage buckets ('avatars', 'salon_images') exist with unrestricted public access.
--   5. Ensure indexes on owner_id, state, city, and district.
-- ============================================================================

-- 1. De-duplicate any existing multiple salon rows per owner_id (keep newest updated_at)
DELETE FROM public.salons a
USING public.salons b
WHERE a.owner_id = b.owner_id
  AND a.owner_id IS NOT NULL
  AND a.updated_at < b.updated_at;

-- 2. Add Unique constraint on owner_id so an owner always maps to 1 canonical salon
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'salons_owner_id_unique'
    ) THEN
        ALTER TABLE public.salons ADD CONSTRAINT salons_owner_id_unique UNIQUE (owner_id);
    END IF;
END $$;

-- 3. Ensure all columns exist on public.salons
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS name TEXT NOT NULL DEFAULT 'My Salon & Spa';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS description TEXT DEFAULT 'Welcome to our premium salon.';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS address TEXT NOT NULL DEFAULT 'Main Market Road';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS city TEXT NOT NULL DEFAULT 'Angul';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS district TEXT NOT NULL DEFAULT 'Angul';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS state TEXT NOT NULL DEFAULT 'Odisha';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS pincode TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS active_chairs INT NOT NULL DEFAULT 3;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS is_queue_open BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS is_published BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS opening_time TEXT NOT NULL DEFAULT '09:00 AM';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS closing_time TEXT NOT NULL DEFAULT '09:00 PM';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS cover_image_url TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS banner_url TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS owner_name TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS owner_avatar_url TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS gallery_images JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- 4. Enable RLS
ALTER TABLE public.salons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queue_tickets ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for Profiles
DROP POLICY IF EXISTS "Profiles viewable by everyone" ON public.profiles;
CREATE POLICY "Profiles viewable by everyone" 
    ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" 
    ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" 
    ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 6. RLS Policies for Salons
DROP POLICY IF EXISTS "Salons viewable by everyone" ON public.salons;
CREATE POLICY "Salons viewable by everyone" 
    ON public.salons FOR SELECT USING (true);

DROP POLICY IF EXISTS "Owners can insert their own salon" ON public.salons;
CREATE POLICY "Owners can insert their own salon" 
    ON public.salons FOR INSERT WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can update their own salon" ON public.salons;
CREATE POLICY "Owners can update their own salon" 
    ON public.salons FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can delete their own salon" ON public.salons;
CREATE POLICY "Owners can delete their own salon" 
    ON public.salons FOR DELETE USING (auth.uid() = owner_id);

-- 7. Grant Permissions
GRANT ALL ON TABLE public.salons TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.services TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.profiles TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.queue_tickets TO anon, authenticated, service_role;

-- 8. Storage Buckets & Policies
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('avatars', 'avatars', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('salon_images', 'salon_images', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO UPDATE SET public = true;

GRANT ALL ON SCHEMA storage TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "Storage select policy" ON storage.objects;
CREATE POLICY "Storage select policy" 
  ON storage.objects FOR SELECT 
  USING (bucket_id IN ('avatars', 'salon_images'));

DROP POLICY IF EXISTS "Storage insert policy" ON storage.objects;
CREATE POLICY "Storage insert policy" 
  ON storage.objects FOR INSERT 
  WITH CHECK (bucket_id IN ('avatars', 'salon_images'));

DROP POLICY IF EXISTS "Storage update policy" ON storage.objects;
CREATE POLICY "Storage update policy" 
  ON storage.objects FOR UPDATE 
  USING (bucket_id IN ('avatars', 'salon_images'));

DROP POLICY IF EXISTS "Storage delete policy" ON storage.objects;
CREATE POLICY "Storage delete policy" 
  ON storage.objects FOR DELETE 
  USING (bucket_id IN ('avatars', 'salon_images'));

-- 9. Indexes for High Performance Discovery
CREATE INDEX IF NOT EXISTS idx_salons_owner_id ON public.salons(owner_id);
CREATE INDEX IF NOT EXISTS idx_salons_state ON public.salons(state);
CREATE INDEX IF NOT EXISTS idx_salons_city ON public.salons(city);
CREATE INDEX IF NOT EXISTS idx_salons_district ON public.salons(district);
CREATE INDEX IF NOT EXISTS idx_salons_updated_at ON public.salons(updated_at DESC);
