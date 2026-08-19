-- ============================================================================
-- Migration: Secure Supabase Row Level Security (RLS) & Access Control
-- Target: ktabfbscrehhdstggjzp.supabase.co
-- Date: 2026-08-20
-- Description:
--   1. Revokes broad public table/sequence/routine grants from anon and authenticated.
--   2. Grants minimum required privileges to anon and authenticated client roles.
--   3. Secures queue_tickets with strict customer vs owner read, insert, and update RLS.
--   4. Hardens profiles table against unauthorized private data leakage.
--   5. Secures salons and services with strict owner isolation and public active discovery.
--   6. Standardizes notifications with canonical user_id ownership.
--   7. Secures support_tickets per user.
--   8. Hardens storage.objects with folder-level ownership for avatars and salon_images.
--   9. Adds constraints and composite indexes for high-throughput queue and discovery queries.
--  10. Registers all interactive tables in supabase_realtime publication and reloads schema.
-- ============================================================================

-- ── 1. REVOKE BROAD PRIVILEGES & RESET DEFAULT PERMISSIONS ──────────────────
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL ROUTINES IN SCHEMA public FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON ROUTINES FROM anon, authenticated;

-- ── 2. GRANT MINIMUM NECESSARY PRIVILEGES ────────────────────────────────────
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- Anonymous: read-only access for discovering active published salons and services
GRANT SELECT ON TABLE public.salons TO anon;
GRANT SELECT ON TABLE public.services TO anon;

-- Authenticated: explicit CRUD on application tables governed strictly by RLS
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.salons TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.services TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.queue_tickets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.support_tickets TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Service Role: full administrative access
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO service_role;

-- ── 3. CANONICAL COLUMNS & SCHEMA INTEGRITY ──────────────────────────────────
-- Ensure canonical columns exist with proper types and foreign key relationships
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'CUSTOMER';

ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT true;
ALTER TABLE public.salons ADD COLUMN IF NOT EXISTS is_queue_open BOOLEAN DEFAULT true;
ALTER TABLE public.salons ALTER COLUMN rating SET DEFAULT 0.0;
ALTER TABLE public.salons ALTER COLUMN review_count SET DEFAULT 0;
ALTER TABLE public.salons ALTER COLUMN active_chairs SET DEFAULT 1;

ALTER TABLE public.services ADD COLUMN IF NOT EXISTS salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

ALTER TABLE public.queue_tickets ADD COLUMN IF NOT EXISTS salon_id UUID REFERENCES public.salons(id) ON DELETE CASCADE;
ALTER TABLE public.queue_tickets ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.queue_tickets ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'WAITING';

ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS owner_id TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false;

ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Backfill user_id in notifications from owner_id if missing
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'notifications' 
        AND column_name = 'owner_id'
    ) THEN
        UPDATE public.notifications 
        SET user_id = owner_id::uuid 
        WHERE user_id IS NULL AND owner_id ~ '^[0-9a-fA-F-]{36}$';
    END IF;
END $$;

-- ── 4. SAFE DATABASE CONSTRAINTS ─────────────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_profile_role'
    ) THEN
        ALTER TABLE public.profiles 
        ADD CONSTRAINT check_profile_role 
        CHECK (role IN ('customer', 'salonOwner', 'salon_owner', 'CUSTOMER', 'SALON_OWNER'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_queue_status'
    ) THEN
        ALTER TABLE public.queue_tickets 
        ADD CONSTRAINT check_queue_status 
        CHECK (status IN ('WAITING', 'IN_CHAIR', 'COMPLETED', 'CANCELLED', 'SKIPPED'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_salon_chairs'
    ) THEN
        ALTER TABLE public.salons 
        ADD CONSTRAINT check_salon_chairs 
        CHECK (active_chairs >= 1);
    END IF;
END $$;

-- ── 5. PERFORMANCE & SECURITY COMPOSITE INDEXES ─────────────────────────────
CREATE INDEX IF NOT EXISTS idx_salons_owner_id ON public.salons(owner_id);
CREATE INDEX IF NOT EXISTS idx_salons_active_published ON public.salons(is_active, is_published);
CREATE INDEX IF NOT EXISTS idx_salons_location ON public.salons(state, district, city);

CREATE INDEX IF NOT EXISTS idx_services_salon_active ON public.services(salon_id, is_active);

CREATE INDEX IF NOT EXISTS idx_queue_tickets_customer_id ON public.queue_tickets(customer_id);
CREATE INDEX IF NOT EXISTS idx_queue_tickets_salon_status ON public.queue_tickets(salon_id, status, token_number);
CREATE INDEX IF NOT EXISTS idx_queue_tickets_customer_status ON public.queue_tickets(customer_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_user_id ON public.support_tickets(user_id);

-- ── 6. ROW LEVEL SECURITY (RLS) POLICIES ─────────────────────────────────────

-- ── A. PROFILES TABLE ────────────────────────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Profiles viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Public can view salon owner public profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON public.profiles;

-- 1. Users can read their own complete profile
CREATE POLICY "Users can view own profile" 
    ON public.profiles FOR SELECT 
    USING (auth.uid() = id);

-- 2. Public / Customers can view public profile info of verified salon owners
CREATE POLICY "Public can view salon owner public profiles" 
    ON public.profiles FOR SELECT 
    USING (
        id IN (SELECT owner_id FROM public.salons WHERE is_active = true AND is_published = true)
    );

-- 3. Users can create their own initial profile during signup
CREATE POLICY "Users can insert their own profile" 
    ON public.profiles FOR INSERT 
    WITH CHECK (auth.uid() = id);

-- 4. Users can only update their own profile
CREATE POLICY "Users can update their own profile" 
    ON public.profiles FOR UPDATE 
    USING (auth.uid() = id) 
    WITH CHECK (auth.uid() = id);

-- 5. Users can delete their own profile
CREATE POLICY "Users can delete own profile" 
    ON public.profiles FOR DELETE 
    USING (auth.uid() = id);


-- ── B. SALONS TABLE ──────────────────────────────────────────────────────────
ALTER TABLE public.salons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Salons viewable by everyone" ON public.salons;
DROP POLICY IF EXISTS "Active published salons viewable by everyone" ON public.salons;
DROP POLICY IF EXISTS "Owners can view own salon" ON public.salons;
DROP POLICY IF EXISTS "Owners can insert their own salon" ON public.salons;
DROP POLICY IF EXISTS "Owners can update their own salon" ON public.salons;
DROP POLICY IF EXISTS "Owners can delete their own salon" ON public.salons;

-- 1. Customers can discover active published salons; Owners can view their own salon
CREATE POLICY "Active published salons viewable by everyone" 
    ON public.salons FOR SELECT 
    USING (
        (is_active = true AND is_published = true) 
        OR 
        (auth.uid() IS NOT NULL AND auth.uid() = owner_id)
    );

-- 2. Authenticated owners can create their own salon
CREATE POLICY "Owners can insert their own salon" 
    ON public.salons FOR INSERT 
    WITH CHECK (auth.uid() IS NOT NULL AND auth.uid() = owner_id);

-- 3. Owners can update only their own salon
CREATE POLICY "Owners can update their own salon" 
    ON public.salons FOR UPDATE 
    USING (auth.uid() IS NOT NULL AND auth.uid() = owner_id) 
    WITH CHECK (auth.uid() IS NOT NULL AND auth.uid() = owner_id);

-- 4. Owners can delete only their own salon
CREATE POLICY "Owners can delete their own salon" 
    ON public.salons FOR DELETE 
    USING (auth.uid() IS NOT NULL AND auth.uid() = owner_id);


-- ── C. SERVICES TABLE ────────────────────────────────────────────────────────
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Services viewable by everyone" ON public.services;
DROP POLICY IF EXISTS "Active services viewable by everyone" ON public.services;
DROP POLICY IF EXISTS "Owners can manage services of their salon" ON public.services;
DROP POLICY IF EXISTS "Owners can insert services" ON public.services;
DROP POLICY IF EXISTS "Owners can update services" ON public.services;
DROP POLICY IF EXISTS "Owners can delete services" ON public.services;

-- 1. Customers can read active services; Owners can read all services of their salon
CREATE POLICY "Active services viewable by everyone" 
    ON public.services FOR SELECT 
    USING (
        is_active = true 
        OR 
        salon_id IN (SELECT id FROM public.salons WHERE owner_id = auth.uid())
    );

-- 2. Owners can insert services only for their own salon
CREATE POLICY "Owners can insert services" 
    ON public.services FOR INSERT 
    WITH CHECK (
        auth.uid() IS NOT NULL 
        AND 
        salon_id IN (SELECT id FROM public.salons WHERE owner_id = auth.uid())
    );

-- 3. Owners can update services only for their own salon
CREATE POLICY "Owners can update services" 
    ON public.services FOR UPDATE 
    USING (
        auth.uid() IS NOT NULL 
        AND 
        salon_id IN (SELECT id FROM public.salons WHERE owner_id = auth.uid())
    ) 
    WITH CHECK (
        auth.uid() IS NOT NULL 
        AND 
        salon_id IN (SELECT id FROM public.salons WHERE owner_id = auth.uid())
    );

-- 4. Owners can delete services only for their own salon
CREATE POLICY "Owners can delete services" 
    ON public.services FOR DELETE 
    USING (
        auth.uid() IS NOT NULL 
        AND 
        salon_id IN (SELECT id FROM public.salons WHERE owner_id = auth.uid())
    );


-- ── D. QUEUE TICKETS TABLE ───────────────────────────────────────────────────
ALTER TABLE public.queue_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Queue tickets viewable by everyone" ON public.queue_tickets;
DROP POLICY IF EXISTS "Users can view relevant queue tickets" ON public.queue_tickets;
DROP POLICY IF EXISTS "Users can insert tickets" ON public.queue_tickets;
DROP POLICY IF EXISTS "Customers and Owners can insert tickets" ON public.queue_tickets;
DROP POLICY IF EXISTS "Users can update tickets" ON public.queue_tickets;
DROP POLICY IF EXISTS "Customers can cancel own tickets" ON public.queue_tickets;
DROP POLICY IF EXISTS "Owners can update tickets for own salon" ON public.queue_tickets;
DROP POLICY IF EXISTS "Owners can delete tickets for own salon" ON public.queue_tickets;

-- 1. SELECT PRIVACY:
-- Customers can ONLY view their own tickets.
-- Owners can view all tickets belonging to their own salon.
-- Customer A cannot read Customer B's tickets.
CREATE POLICY "Users can view relevant queue tickets" 
    ON public.queue_tickets FOR SELECT 
    USING (
        (auth.uid() IS NOT NULL AND customer_id = auth.uid())
        OR
        (salon_id IN (SELECT id FROM public.salons WHERE owner_id = auth.uid()))
    );

-- 2. INSERT AUTHORIZATION:
-- Authenticated customer joining queue: must set customer_id = auth.uid(), salon must have open queue, status must be WAITING.
-- Salon owner adding walk-in ticket: salon must belong to auth.uid().
CREATE POLICY "Customers and Owners can insert tickets" 
    ON public.queue_tickets FOR INSERT 
    WITH CHECK (
        (
            auth.uid() IS NOT NULL 
            AND 
            customer_id = auth.uid()
            AND 
            EXISTS (
                SELECT 1 FROM public.salons s 
                WHERE s.id = salon_id AND s.is_queue_open = true AND s.is_active = true
            )
            AND 
            status = 'WAITING'
        )
        OR
        (
            auth.uid() IS NOT NULL 
            AND 
            salon_id IN (SELECT id FROM public.salons WHERE owner_id = auth.uid())
        )
    );

-- 3. CUSTOMER UPDATE AUTHORIZATION:
-- Customer can only cancel their own ticket. Cannot transition to IN_CHAIR or COMPLETED.
CREATE POLICY "Customers can cancel own tickets" 
    ON public.queue_tickets FOR UPDATE 
    USING (
        auth.uid() IS NOT NULL AND customer_id = auth.uid()
    ) 
    WITH CHECK (
        auth.uid() IS NOT NULL 
        AND 
        customer_id = auth.uid() 
        AND 
        status = 'CANCELLED'
    );

-- 4. OWNER UPDATE AUTHORIZATION:
-- Owner can manage and update tickets belonging to their own salon.
CREATE POLICY "Owners can update tickets for own salon" 
    ON public.queue_tickets FOR UPDATE 
    USING (
        auth.uid() IS NOT NULL 
        AND 
        salon_id IN (SELECT id FROM public.salons WHERE owner_id = auth.uid())
    ) 
    WITH CHECK (
        auth.uid() IS NOT NULL 
        AND 
        salon_id IN (SELECT id FROM public.salons WHERE owner_id = auth.uid())
    );

-- 5. OWNER DELETE AUTHORIZATION:
-- Owner can remove tickets for their own salon.
CREATE POLICY "Owners can delete tickets for own salon" 
    ON public.queue_tickets FOR DELETE 
    USING (
        auth.uid() IS NOT NULL 
        AND 
        salon_id IN (SELECT id FROM public.salons WHERE owner_id = auth.uid())
    );


-- ── E. NOTIFICATIONS TABLE ───────────────────────────────────────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Notifications viewable by everyone" ON public.notifications;
DROP POLICY IF EXISTS "Notifications insertable by authenticated" ON public.notifications;
DROP POLICY IF EXISTS "Notifications updateable by owner" ON public.notifications;
DROP POLICY IF EXISTS "Notifications viewable by owner" ON public.notifications;
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Authenticated users can create notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;

-- 1. Users can ONLY read notifications targeted to their user_id
CREATE POLICY "Users can view own notifications" 
    ON public.notifications FOR SELECT 
    USING (
        auth.uid() IS NOT NULL 
        AND 
        (user_id = auth.uid() OR owner_id = auth.uid()::text)
    );

-- 2. Authenticated users and queue actions can create notifications
CREATE POLICY "Authenticated users can create notifications" 
    ON public.notifications FOR INSERT 
    WITH CHECK (auth.uid() IS NOT NULL);

-- 3. Users can only update their own notifications (e.g. mark as read)
CREATE POLICY "Users can update own notifications" 
    ON public.notifications FOR UPDATE 
    USING (
        auth.uid() IS NOT NULL 
        AND 
        (user_id = auth.uid() OR owner_id = auth.uid()::text)
    ) 
    WITH CHECK (
        auth.uid() IS NOT NULL 
        AND 
        (user_id = auth.uid() OR owner_id = auth.uid()::text)
    );

-- 4. Users can only delete their own notifications
CREATE POLICY "Users can delete own notifications" 
    ON public.notifications FOR DELETE 
    USING (
        auth.uid() IS NOT NULL 
        AND 
        (user_id = auth.uid() OR owner_id = auth.uid()::text)
    );


-- ── F. SUPPORT TICKETS TABLE ─────────────────────────────────────────────────
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Support tickets viewable by owner or admin" ON public.support_tickets;
DROP POLICY IF EXISTS "Support tickets insertable by everyone" ON public.support_tickets;
DROP POLICY IF EXISTS "Users can view own support tickets" ON public.support_tickets;
DROP POLICY IF EXISTS "Users can create own support tickets" ON public.support_tickets;
DROP POLICY IF EXISTS "Users can update own support tickets" ON public.support_tickets;

-- 1. Users can only view their own support tickets
CREATE POLICY "Users can view own support tickets" 
    ON public.support_tickets FOR SELECT 
    USING (auth.uid() IS NOT NULL AND user_id = auth.uid());

-- 2. Users can create support tickets for their own account
CREATE POLICY "Users can create own support tickets" 
    ON public.support_tickets FOR INSERT 
    WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());

-- 3. Users can update their own support tickets
CREATE POLICY "Users can update own support tickets" 
    ON public.support_tickets FOR UPDATE 
    USING (auth.uid() IS NOT NULL AND user_id = auth.uid()) 
    WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());


-- ── 7. STORAGE BUCKET ISOLATION & POLICIES ───────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('avatars', 'avatars', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']),
  ('salon_images', 'salon_images', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO UPDATE SET public = true;

GRANT ALL ON SCHEMA storage TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "Storage select policy" ON storage.objects;
DROP POLICY IF EXISTS "Public storage read policy" ON storage.objects;
DROP POLICY IF EXISTS "Storage insert policy" ON storage.objects;
DROP POLICY IF EXISTS "User Storage Insert Policy" ON storage.objects;
DROP POLICY IF EXISTS "Storage update policy" ON storage.objects;
DROP POLICY IF EXISTS "User Storage Update Policy" ON storage.objects;
DROP POLICY IF EXISTS "Storage delete policy" ON storage.objects;
DROP POLICY IF EXISTS "User Storage Delete Policy" ON storage.objects;

-- 1. Public read for avatars and salon images
CREATE POLICY "Public storage read policy" 
    ON storage.objects FOR SELECT 
    USING (bucket_id IN ('avatars', 'salon_images'));

-- 2. Authenticated users can upload only to their own folder path
-- Supports: 'owners/<userId>/...', '<userId>/...', or '<userId>.<ext>'
CREATE POLICY "User Storage Insert Policy" 
    ON storage.objects FOR INSERT 
    WITH CHECK (
        bucket_id IN ('avatars', 'salon_images')
        AND 
        auth.uid() IS NOT NULL 
        AND 
        (
            ((storage.foldername(name))[1] = 'owners' AND (storage.foldername(name))[2] = auth.uid()::text)
            OR
            ((storage.foldername(name))[1] = auth.uid()::text)
            OR
            (name LIKE (auth.uid()::text || '%'))
        )
    );

-- 3. Authenticated users can update only their own files
CREATE POLICY "User Storage Update Policy" 
    ON storage.objects FOR UPDATE 
    USING (
        bucket_id IN ('avatars', 'salon_images')
        AND 
        auth.uid() IS NOT NULL 
        AND 
        (
            ((storage.foldername(name))[1] = 'owners' AND (storage.foldername(name))[2] = auth.uid()::text)
            OR
            ((storage.foldername(name))[1] = auth.uid()::text)
            OR
            (name LIKE (auth.uid()::text || '%'))
        )
    );

-- 4. Authenticated users can delete only their own files
CREATE POLICY "User Storage Delete Policy" 
    ON storage.objects FOR DELETE 
    USING (
        bucket_id IN ('avatars', 'salon_images')
        AND 
        auth.uid() IS NOT NULL 
        AND 
        (
            ((storage.foldername(name))[1] = 'owners' AND (storage.foldername(name))[2] = auth.uid()::text)
            OR
            ((storage.foldername(name))[1] = auth.uid()::text)
            OR
            (name LIKE (auth.uid()::text || '%'))
        )
    );


-- ── 8. ENSURE SUPABASE REALTIME PUBLICATION ──────────────────────────────────
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
        AND tablename = 'services'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.services;
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
        AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
END $$;

-- ── 9. RELOAD SCHEMA CACHE ───────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
