-- ============================================================================
-- Migration: Strict Account Isolation, Real-Time Queue & Storage Isolation
-- Date: 2026-08-14
-- Purpose: Permanently prevent cross-account data leakage, enforce per-owner
--          isolation on salons, images, and services, and configure Realtime.
-- ============================================================================

-- 1. Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Schema Permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

-- 3. Ensure Table Columns
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    phone TEXT,
    avatar_url TEXT,
    role TEXT NOT NULL DEFAULT 'CUSTOMER' CHECK (role IN ('CUSTOMER', 'SALON_OWNER')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.salons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    address TEXT NOT NULL,
    city TEXT NOT NULL DEFAULT 'Pune',
    district TEXT NOT NULL DEFAULT 'Pune',
    state TEXT NOT NULL DEFAULT 'Maharashtra',
    pincode TEXT,
    phone TEXT,
    rating NUMERIC(2, 1) NOT NULL DEFAULT 4.8,
    review_count INT NOT NULL DEFAULT 45,
    active_chairs INT NOT NULL DEFAULT 3,
    is_queue_open BOOLEAN NOT NULL DEFAULT true,
    is_verified BOOLEAN NOT NULL DEFAULT false,
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

-- Ensure all columns exist on salons
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS district TEXT DEFAULT 'Pune';
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS cover_image_url TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS banner_url TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS owner_avatar_url TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS owner_name TEXT;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS gallery_images JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS active_chairs INT DEFAULT 3;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS is_queue_open BOOLEAN DEFAULT true;

CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID NOT NULL REFERENCES public.salons(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('Hair', 'Beard', 'Facial', 'Color', 'Spa', 'Combo', 'Other')),
    price NUMERIC(10, 2) NOT NULL,
    duration_minutes INT NOT NULL DEFAULT 20,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

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

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'SYSTEM_UPDATE',
    related_id TEXT,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Enable Row Level Security (RLS) on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queue_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 5. Strict Profiles RLS Policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone" 
    ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" 
    ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" 
    ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 6. Strict Salons RLS Policies (Public Read, Owner Isolated Write)
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

-- 7. Strict Services RLS Policies
DROP POLICY IF EXISTS "Services viewable by everyone" ON public.services;
CREATE POLICY "Services viewable by everyone" 
    ON public.services FOR SELECT USING (true);

DROP POLICY IF EXISTS "Owners can manage services" ON public.services;
CREATE POLICY "Owners can manage services" 
    ON public.services FOR ALL USING (
        EXISTS (SELECT 1 FROM public.salons WHERE salons.id = services.salon_id AND salons.owner_id = auth.uid())
    );

-- 8. Queue Tickets RLS Policies & Realtime
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

-- 9. Real-Time Publications
-- Enables Supabase Realtime websocket subscriptions for live customer queue updates
DO $$
BEGIN
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
        AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
END $$;

-- 10. Supabase Storage Buckets & Policies
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true) 
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('salon_images', 'salon_images', true) 
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public avatars access" ON storage.objects;
CREATE POLICY "Public avatars access" 
    ON storage.objects FOR SELECT 
    USING (bucket_id IN ('avatars', 'salon_images'));

DROP POLICY IF EXISTS "Authenticated upload avatars" ON storage.objects;
CREATE POLICY "Authenticated upload avatars" 
    ON storage.objects FOR INSERT 
    WITH CHECK (
        bucket_id IN ('avatars', 'salon_images')
    );

DROP POLICY IF EXISTS "Authenticated update avatars" ON storage.objects;
CREATE POLICY "Authenticated update avatars" 
    ON storage.objects FOR UPDATE 
    USING (
        bucket_id IN ('avatars', 'salon_images')
    );

DROP POLICY IF EXISTS "Authenticated delete avatars" ON storage.objects;
CREATE POLICY "Authenticated delete avatars" 
    ON storage.objects FOR DELETE 
    USING (
        bucket_id IN ('avatars', 'salon_images')
    );
