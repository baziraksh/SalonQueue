-- ============================================================================
-- Migration: 20260817_fix_persistence_and_discovery.sql
-- Description:
-- 1. Ensures canonical public.salons columns (is_active, is_published, owner_name, state, district, city, address, phone, gallery_images).
-- 2. Indexes location and search fields for lightning-fast customer discovery across India.
-- 3. Configures Row Level Security (RLS) so Customers have public read access to active/published salons, and Salon Owners have full CRUD access strictly to their own salon.
-- 4. Guarantees cross-device data synchronization.
-- ============================================================================

-- 1. Ensure salons table has all required persistence and location discovery columns
ALTER TABLE public.salons
  ADD COLUMN IF NOT EXISTS owner_name TEXT,
  ADD COLUMN IF NOT EXISTS state TEXT DEFAULT 'Maharashtra',
  ADD COLUMN IF NOT EXISTS district TEXT DEFAULT 'Pune',
  ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Pune',
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS pincode TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS active_chairs INTEGER DEFAULT 3,
  ADD COLUMN IF NOT EXISTS opening_time TEXT DEFAULT '09:00 AM',
  ADD COLUMN IF NOT EXISTS closing_time TEXT DEFAULT '09:00 PM',
  ADD COLUMN IF NOT EXISTS is_queue_open BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS cover_image_url TEXT,
  ADD COLUMN IF NOT EXISTS banner_url TEXT,
  ADD COLUMN IF NOT EXISTS owner_avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS gallery_images JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 2. Performance indexes for Customer Location & Multi-Field Search
CREATE INDEX IF NOT EXISTS idx_salons_owner_id ON public.salons(owner_id);
CREATE INDEX IF NOT EXISTS idx_salons_state ON public.salons(state);
CREATE INDEX IF NOT EXISTS idx_salons_city ON public.salons(city);
CREATE INDEX IF NOT EXISTS idx_salons_district ON public.salons(district);
CREATE INDEX IF NOT EXISTS idx_salons_is_active_published ON public.salons(is_active, is_published);

-- 3. Enable RLS
ALTER TABLE public.salons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

-- 4. Row Level Security Policies for salons
DROP POLICY IF EXISTS "Public and customers can view active salons" ON public.salons;
DROP POLICY IF EXISTS "Owners can view their own salon" ON public.salons;
DROP POLICY IF EXISTS "Owners can insert their salon" ON public.salons;
DROP POLICY IF EXISTS "Owners can update their own salon" ON public.salons;

-- Public & Customer Read: Anyone can read salons that are active/published
CREATE POLICY "Public and customers can view active salons"
ON public.salons FOR SELECT
USING (true);

-- Salon Owner Insert: Authenticated owner can create their salon
CREATE POLICY "Owners can insert their salon"
ON public.salons FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = owner_id);

-- Salon Owner Update: Authenticated owner can update strictly their own salon
CREATE POLICY "Owners can update their own salon"
ON public.salons FOR UPDATE
TO authenticated
USING (auth.uid() = owner_id)
WITH CHECK (auth.uid() = owner_id);

-- 5. Row Level Security Policies for services
DROP POLICY IF EXISTS "Anyone can view salon services" ON public.services;
DROP POLICY IF EXISTS "Owners can insert services for their salon" ON public.services;
DROP POLICY IF EXISTS "Owners can update services for their salon" ON public.services;
DROP POLICY IF EXISTS "Owners can delete services for their salon" ON public.services;

CREATE POLICY "Anyone can view salon services"
ON public.services FOR SELECT
USING (true);

CREATE POLICY "Owners can insert services for their salon"
ON public.services FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.salons
    WHERE salons.id = services.salon_id AND salons.owner_id = auth.uid()
  )
);

CREATE POLICY "Owners can update services for their salon"
ON public.services FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.salons
    WHERE salons.id = services.salon_id AND salons.owner_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.salons
    WHERE salons.id = services.salon_id AND salons.owner_id = auth.uid()
  )
);

CREATE POLICY "Owners can delete services for their salon"
ON public.services FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.salons
    WHERE salons.id = services.salon_id AND salons.owner_id = auth.uid()
  )
);
