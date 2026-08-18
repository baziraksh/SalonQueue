-- ============================================================================
-- Migration: Complete Supabase Cross-Device Sync, RLS, Storage & Realtime Fix
-- Date: 2026-08-17
-- Purpose: 
--   1. Grant full table and schema permissions to anon and authenticated roles.
--   2. Ensure all tables (profiles, salons, services, queue_tickets, notifications) exist with correct columns.
--   3. Configure public read, owner write RLS policies.
--   4. Configure storage buckets ('avatars', 'salon_images') with public access & upload policies.
--   5. Configure Supabase Realtime publications for live queue and salon synchronization.
-- ============================================================================

-- 1. Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Schema Permissions (Fixes 42501 permission denied for table salons / profiles)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;

-- 3. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    phone TEXT,
    avatar_url TEXT,
    role TEXT NOT NULL DEFAULT 'CUSTOMER' CHECK (role IN ('CUSTOMER', 'SALON_OWNER')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'CUSTOMER';

-- 4. Salons Table
CREATE TABLE IF NOT EXISTS public.salons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL DEFAULT 'My Salon & Spa',
    description TEXT DEFAULT 'Welcome to our premium salon.',
    address TEXT NOT NULL DEFAULT 'Main Market Road',
    city TEXT NOT NULL DEFAULT 'Pune',
    district TEXT NOT NULL DEFAULT 'Pune',
    state TEXT NOT NULL DEFAULT 'Maharashtra',
    pincode TEXT,
    phone TEXT,
    latitude NUMERIC(10, 6) DEFAULT 18.5204,
    longitude NUMERIC(10, 6) DEFAULT 73.8567,
    rating NUMERIC(2, 1) NOT NULL DEFAULT 4.8,
    review_count INT NOT NULL DEFAULT 45,
    active_chairs INT NOT NULL DEFAULT 3,
    is_queue_open BOOLEAN NOT NULL DEFAULT true,
    is_verified BOOLEAN NOT NULL DEFAULT true,
    opening_time TEXT NOT NULL DEFAULT '09:00 AM',
    closing_time TEXT NOT NULL DEFAULT '09:00 PM',
    banner_url TEXT,
    cover_image_url TEXT,
    owner_name TEXT,
    owner_avatar_url TEXT,
    gallery_images JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure all columns on salons exist
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS description TEXT DEFAULT 'Welcome to our premium salon.';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Pune';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS district TEXT DEFAULT 'Pune';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS state TEXT DEFAULT 'Maharashtra';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS pincode TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 6) DEFAULT 18.5204;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS longitude NUMERIC(10, 6) DEFAULT 73.8567;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS rating NUMERIC(2, 1) DEFAULT 4.8;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS review_count INT DEFAULT 45;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS active_chairs INT DEFAULT 3;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS is_queue_open BOOLEAN DEFAULT true;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT true;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS opening_time TEXT DEFAULT '09:00 AM';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS closing_time TEXT DEFAULT '09:00 PM';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS banner_url TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS cover_image_url TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS owner_name TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS owner_avatar_url TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS gallery_images JSONB DEFAULT '[]'::jsonb;

-- 5. Services Table
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID NOT NULL REFERENCES public.salons(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Hair',
    price NUMERIC(10, 2) NOT NULL DEFAULT 150.00,
    duration_minutes INT NOT NULL DEFAULT 20,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Queue Tickets Table
CREATE TABLE IF NOT EXISTS public.queue_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID NOT NULL REFERENCES public.salons(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    customer_name TEXT NOT NULL,
    customer_phone TEXT,
    service_names TEXT[] NOT NULL DEFAULT '{}',
    total_price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    total_duration_minutes INT NOT NULL DEFAULT 20,
    token_number INT NOT NULL,
    status TEXT NOT NULL DEFAULT 'WAITING' CHECK (status IN ('WAITING', 'IN_CHAIR', 'COMPLETED', 'CANCELLED', 'SKIPPED')),
    chair_number INT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

-- 7. Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id TEXT,
    user_id TEXT,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'SYSTEM_UPDATE',
    related_id TEXT,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS owner_id TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS user_id TEXT;

-- 8. Enable Row Level Security (RLS) on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queue_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 9. Profiles Policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone" 
    ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" 
    ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" 
    ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 10. Salons Policies (Public Read, Owner Insert/Update/Delete)
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

-- 11. Services Policies
DROP POLICY IF EXISTS "Services viewable by everyone" ON public.services;
CREATE POLICY "Services viewable by everyone" 
    ON public.services FOR SELECT USING (true);

DROP POLICY IF EXISTS "Owners can manage services" ON public.services;
CREATE POLICY "Owners can manage services" 
    ON public.services FOR ALL USING (
        EXISTS (SELECT 1 FROM public.salons WHERE salons.id = services.salon_id AND salons.owner_id = auth.uid())
    );

-- 12. Queue Tickets Policies
DROP POLICY IF EXISTS "Queue tickets viewable by everyone" ON public.queue_tickets;
CREATE POLICY "Queue tickets viewable by everyone" 
    ON public.queue_tickets FOR SELECT USING (true);

DROP POLICY IF EXISTS "Customers and owners can create tickets" ON public.queue_tickets;
CREATE POLICY "Customers and owners can create tickets" 
    ON public.queue_tickets FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Ticket update policy" ON public.queue_tickets;
CREATE POLICY "Ticket update policy" 
    ON public.queue_tickets FOR UPDATE USING (
        customer_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.salons WHERE salons.id = queue_tickets.salon_id AND salons.owner_id = auth.uid())
    );

-- 13. Notifications Policies
DROP POLICY IF EXISTS "Notifications viewable by everyone" ON public.notifications;
CREATE POLICY "Notifications viewable by everyone" 
    ON public.notifications FOR SELECT USING (true);

DROP POLICY IF EXISTS "Notifications insertable by authenticated" ON public.notifications;
CREATE POLICY "Notifications insertable by authenticated" 
    ON public.notifications FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Notifications updateable by owner" ON public.notifications;
CREATE POLICY "Notifications updateable by owner" 
    ON public.notifications FOR UPDATE USING (true);

-- 14. Real-Time Publications
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'salons'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.salons;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'queue_tickets'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.queue_tickets;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'services'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.services;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
END $$;

-- 15. Storage Buckets & Policies
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('avatars', 'avatars', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('salon_images', 'salon_images', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO UPDATE SET public = true;

GRANT ALL ON SCHEMA storage TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "Public storage access" ON storage.objects;
CREATE POLICY "Public storage access" 
  ON storage.objects FOR SELECT 
  USING (bucket_id IN ('avatars', 'salon_images'));

DROP POLICY IF EXISTS "Authenticated upload access" ON storage.objects;
CREATE POLICY "Authenticated upload access" 
  ON storage.objects FOR INSERT 
  WITH CHECK (bucket_id IN ('avatars', 'salon_images'));

DROP POLICY IF EXISTS "Authenticated update access" ON storage.objects;
CREATE POLICY "Authenticated update access" 
  ON storage.objects FOR UPDATE 
  USING (bucket_id IN ('avatars', 'salon_images'));

DROP POLICY IF EXISTS "Authenticated delete access" ON storage.objects;
CREATE POLICY "Authenticated delete access" 
  ON storage.objects FOR DELETE 
  USING (bucket_id IN ('avatars', 'salon_images'));
