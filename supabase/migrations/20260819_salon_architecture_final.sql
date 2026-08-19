-- ============================================================================
-- Migration: Clean Single-Source-of-Truth Salon Architecture & RLS Policies
-- Target: ktabfbscrehhdstggjzp.supabase.co
-- Date: 2026-08-19
-- ============================================================================

-- 1. Ensure public.salons table exists with all required columns
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

-- 2. Enforce UNIQUE(owner_id) constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'salons_owner_id_unique'
    ) THEN
        ALTER TABLE public.salons ADD CONSTRAINT salons_owner_id_unique UNIQUE (owner_id);
    END IF;
END $$;

-- 3. Create Performance Indexes for discovery
CREATE INDEX IF NOT EXISTS idx_salons_owner_id ON public.salons(owner_id);
CREATE INDEX IF NOT EXISTS idx_salons_state ON public.salons(state);
CREATE INDEX IF NOT EXISTS idx_salons_district ON public.salons(district);
CREATE INDEX IF NOT EXISTS idx_salons_city ON public.salons(city);
CREATE INDEX IF NOT EXISTS idx_salons_is_active ON public.salons(is_active, is_published);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.salons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queue_tickets ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for public.salons
-- Public / Customer: View all active published salons
DROP POLICY IF EXISTS "Salons viewable by everyone" ON public.salons;
CREATE POLICY "Salons viewable by everyone" 
    ON public.salons FOR SELECT USING (true);

-- Salon Owner: Insert own salon
DROP POLICY IF EXISTS "Owners can insert their own salon" ON public.salons;
CREATE POLICY "Owners can insert their own salon" 
    ON public.salons FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- Salon Owner: Update own salon
DROP POLICY IF EXISTS "Owners can update their own salon" ON public.salons;
CREATE POLICY "Owners can update their own salon" 
    ON public.salons FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

-- Salon Owner: Delete own salon
DROP POLICY IF EXISTS "Owners can delete their own salon" ON public.salons;
CREATE POLICY "Owners can delete their own salon" 
    ON public.salons FOR DELETE USING (auth.uid() = owner_id);

-- 6. Grant Permissions to anon, authenticated, and service_role
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.salons TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.services TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.profiles TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.queue_tickets TO anon, authenticated, service_role;
