-- ============================================================================
-- CANONICAL SALONS SCHEMA & POSTGREST SCHEMA CACHE RELOAD MIGRATION
-- Project: SalonQueue (https://ktabfbscrehhdstggjzp.supabase.co)
-- Date: 2026-08-19
-- ============================================================================

-- 1. Create public.salons if it does not exist
CREATE TABLE IF NOT EXISTS public.salons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL DEFAULT 'My Salon & Spa',
    description TEXT DEFAULT 'Welcome to our premium salon.',
    phone TEXT,
    address TEXT NOT NULL DEFAULT 'Main Market Road',
    city TEXT NOT NULL DEFAULT 'Angul',
    district TEXT NOT NULL DEFAULT 'Angul',
    state TEXT NOT NULL DEFAULT 'Odisha',
    pincode TEXT,
    active_chairs INT NOT NULL DEFAULT 3,
    is_queue_open BOOLEAN NOT NULL DEFAULT true,
    is_verified BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_published BOOLEAN NOT NULL DEFAULT true,
    opening_time TEXT NOT NULL DEFAULT '09:00 AM',
    closing_time TEXT NOT NULL DEFAULT '09:00 PM',
    cover_image_url TEXT,
    banner_url TEXT,
    owner_name TEXT,
    owner_avatar_url TEXT,
    gallery_images JSONB NOT NULL DEFAULT '[]'::jsonb,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    rating DOUBLE PRECISION NOT NULL DEFAULT 4.8,
    review_count INT NOT NULL DEFAULT 50,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Ensure every required column exists on existing tables (Non-destructive)
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS district TEXT DEFAULT 'Angul';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Angul';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS state TEXT DEFAULT 'Odisha';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS address TEXT DEFAULT 'Main Market Road';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS pincode TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS name TEXT DEFAULT 'My Salon & Spa';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS description TEXT DEFAULT 'Welcome to our premium salon.';
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
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 3. Ensure UNIQUE(owner_id) constraint
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

-- 4. Create Performance Indexes for discovery
CREATE INDEX IF NOT EXISTS idx_salons_owner_id ON public.salons(owner_id);
CREATE INDEX IF NOT EXISTS idx_salons_state ON public.salons(state);
CREATE INDEX IF NOT EXISTS idx_salons_district ON public.salons(district);
CREATE INDEX IF NOT EXISTS idx_salons_city ON public.salons(city);
CREATE INDEX IF NOT EXISTS idx_salons_is_active ON public.salons(is_active, is_published);

-- 5. Notifications table support
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

-- 6. Enable Row Level Security (RLS)
ALTER TABLE public.salons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queue_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 7. RLS Policies for public.salons
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

DROP POLICY IF EXISTS "Notifications viewable by owner" ON public.notifications;
CREATE POLICY "Notifications viewable by owner" 
    ON public.notifications FOR ALL USING (auth.uid() = user_id OR user_id IS NULL);

-- 8. Grant Permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.salons TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.services TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.profiles TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.queue_tickets TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.notifications TO anon, authenticated, service_role;

-- 9. Reload PostgREST Schema Cache (Fixes PGRST204)
NOTIFY pgrst, 'reload schema';
