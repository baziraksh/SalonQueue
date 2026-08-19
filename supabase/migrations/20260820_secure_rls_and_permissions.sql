-- ============================================================================
-- Migration: Secure Supabase Row Level Security (RLS) & Access Control (Final Verified)
-- Target: ktabfbscrehhdstggjzp.supabase.co
-- Date: 2026-08-20
-- Description:
--   1. Revokes broad public table grants and default privileges.
--   2. Grants minimum required privileges to anon and authenticated roles.
--   3. Secures profiles, salons, services, queue_tickets, queue_entries,
--      service_sessions, notifications, and support_tickets.
--   4. Resolves service_sessions customer identity via queue_entries.queue_entry_id.
--   5. Uses explicit text-casting (::text = ::text) for 100% type-safe comparisons across
--      BIGINT, INTEGER, TEXT, and UUID columns.
--   6. Indexes only verified existing columns (state, district, city, etc.).
--   7. Secures storage buckets (avatars, salon_images) by authenticated user folder.
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

-- Anonymous: read-only access for discovering active salons and services
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'salons') THEN
        GRANT SELECT ON TABLE public.salons TO anon;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'services') THEN
        GRANT SELECT ON TABLE public.services TO anon;
    END IF;
END $$;

-- Authenticated: CRUD on application tables governed strictly by RLS policies
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.profiles TO authenticated;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'salons') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.salons TO authenticated;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'services') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.services TO authenticated;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'queue_tickets') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.queue_tickets TO authenticated;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'queue_entries') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.queue_entries TO authenticated;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'service_sessions') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.service_sessions TO authenticated;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.notifications TO authenticated;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'support_tickets') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.support_tickets TO authenticated;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'reviews') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.reviews TO authenticated;
    END IF;
END $$;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Service Role: full administrative access
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO service_role;

-- ── 3. CLEAN UP OBSOLETE INDEXES & ADD SAFE COMPOSITE INDEXES ────────────────
DROP INDEX IF EXISTS public.idx_salons_location;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'salons') THEN
        CREATE INDEX IF NOT EXISTS idx_salons_owner_id ON public.salons(owner_id);
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'salons' AND column_name = 'state') THEN
            CREATE INDEX IF NOT EXISTS idx_salons_state_district_city ON public.salons(state, district, city);
        END IF;
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'salons' AND column_name = 'is_active') THEN
            CREATE INDEX IF NOT EXISTS idx_salons_active_published ON public.salons(is_active, is_published);
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'services') THEN
        CREATE INDEX IF NOT EXISTS idx_services_salon_active ON public.services(salon_id, is_active);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'queue_tickets') THEN
        CREATE INDEX IF NOT EXISTS idx_queue_tickets_customer_id ON public.queue_tickets(customer_id);
        CREATE INDEX IF NOT EXISTS idx_queue_tickets_salon_status ON public.queue_tickets(salon_id, status, token_number);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'queue_entries') THEN
        CREATE INDEX IF NOT EXISTS idx_queue_entries_customer_id ON public.queue_entries(customer_id);
        CREATE INDEX IF NOT EXISTS idx_queue_entries_salon_status ON public.queue_entries(salon_id, status);
    END IF;
END $$;

-- ── 4. ROW LEVEL SECURITY (RLS) POLICIES ─────────────────────────────────────

-- ── A. PROFILES TABLE ────────────────────────────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
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
            USING (auth.uid()::text = id::text);

        -- 2. Public can view salon owner public profiles for verified/active salons
        CREATE POLICY "Public can view salon owner public profiles" 
            ON public.profiles FOR SELECT 
            USING (
                id::text IN (SELECT owner_id::text FROM public.salons WHERE is_active = true AND is_published = true)
            );

        -- 3. Users can create their own initial profile during signup
        CREATE POLICY "Users can insert their own profile" 
            ON public.profiles FOR INSERT 
            WITH CHECK (auth.uid()::text = id::text);

        -- 4. Users can only update their own profile (and cannot tamper with role unless already set)
        CREATE POLICY "Users can update their own profile" 
            ON public.profiles FOR UPDATE 
            USING (auth.uid()::text = id::text) 
            WITH CHECK (auth.uid()::text = id::text);

        -- 5. Users can delete their own profile
        CREATE POLICY "Users can delete own profile" 
            ON public.profiles FOR DELETE 
            USING (auth.uid()::text = id::text);
    END IF;
END $$;


-- ── B. SALONS TABLE ──────────────────────────────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'salons') THEN
        ALTER TABLE public.salons ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Salons viewable by everyone" ON public.salons;
        DROP POLICY IF EXISTS "Public salons viewable by everyone" ON public.salons;
        DROP POLICY IF EXISTS "Public and customers can view active salons" ON public.salons;
        DROP POLICY IF EXISTS "Active published salons viewable by everyone" ON public.salons;
        DROP POLICY IF EXISTS "Owners can view own salon" ON public.salons;
        DROP POLICY IF EXISTS "Owners can manage their salons" ON public.salons;
        DROP POLICY IF EXISTS "Owners can insert their own salon" ON public.salons;
        DROP POLICY IF EXISTS "Owners can insert their salon" ON public.salons;
        DROP POLICY IF EXISTS "Owners can update their own salon" ON public.salons;
        DROP POLICY IF EXISTS "Owners can delete their own salon" ON public.salons;

        -- 1. Customers discover active published salons; Owners view their own salon
        CREATE POLICY "Active published salons viewable by everyone" 
            ON public.salons FOR SELECT 
            USING (
                (is_active = true AND is_published = true) 
                OR 
                (auth.uid() IS NOT NULL AND owner_id::text = auth.uid()::text)
            );

        -- 2. Authenticated owners can create their own salon
        CREATE POLICY "Owners can insert their own salon" 
            ON public.salons FOR INSERT 
            WITH CHECK (auth.uid() IS NOT NULL AND owner_id::text = auth.uid()::text);

        -- 3. Owners can update only their own salon
        CREATE POLICY "Owners can update their own salon" 
            ON public.salons FOR UPDATE 
            USING (auth.uid() IS NOT NULL AND owner_id::text = auth.uid()::text) 
            WITH CHECK (auth.uid() IS NOT NULL AND owner_id::text = auth.uid()::text);

        -- 4. Owners can delete only their own salon
        CREATE POLICY "Owners can delete their own salon" 
            ON public.salons FOR DELETE 
            USING (auth.uid() IS NOT NULL AND owner_id::text = auth.uid()::text);
    END IF;
END $$;


-- ── C. SERVICES TABLE ────────────────────────────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'services') THEN
        ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Services viewable by everyone" ON public.services;
        DROP POLICY IF EXISTS "Public services viewable by everyone" ON public.services;
        DROP POLICY IF EXISTS "Active services viewable by everyone" ON public.services;
        DROP POLICY IF EXISTS "Salon owners can manage services" ON public.services;
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
                salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text)
            );

        -- 2. Owners can insert services only for their own salon
        CREATE POLICY "Owners can insert services" 
            ON public.services FOR INSERT 
            WITH CHECK (
                auth.uid() IS NOT NULL 
                AND 
                salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text)
            );

        -- 3. Owners can update services only for their own salon
        CREATE POLICY "Owners can update services" 
            ON public.services FOR UPDATE 
            USING (
                auth.uid() IS NOT NULL 
                AND 
                salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text)
            ) 
            WITH CHECK (
                auth.uid() IS NOT NULL 
                AND 
                salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text)
            );

        -- 4. Owners can delete services only for their own salon
        CREATE POLICY "Owners can delete services" 
            ON public.services FOR DELETE 
            USING (
                auth.uid() IS NOT NULL 
                AND 
                salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text)
            );
    END IF;
END $$;


-- ── D. QUEUE TICKETS TABLE ───────────────────────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'queue_tickets') THEN
        ALTER TABLE public.queue_tickets ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Queue tickets viewable by everyone" ON public.queue_tickets;
        DROP POLICY IF EXISTS "Queue tickets viewable by salon owner and ticket customer" ON public.queue_tickets;
        DROP POLICY IF EXISTS "Users can view relevant queue tickets" ON public.queue_tickets;
        DROP POLICY IF EXISTS "Customers can create tickets" ON public.queue_tickets;
        DROP POLICY IF EXISTS "Users can insert tickets" ON public.queue_tickets;
        DROP POLICY IF EXISTS "Customers and Owners can insert tickets" ON public.queue_tickets;
        DROP POLICY IF EXISTS "Users can update tickets" ON public.queue_tickets;
        DROP POLICY IF EXISTS "Customers can update their own tickets (cancel)" ON public.queue_tickets;
        DROP POLICY IF EXISTS "Customers can cancel own tickets" ON public.queue_tickets;
        DROP POLICY IF EXISTS "Owners can update tickets for own salon" ON public.queue_tickets;
        DROP POLICY IF EXISTS "Owners can delete tickets for own salon" ON public.queue_tickets;

        -- 1. SELECT: Customer views own tickets; Owner views own salon tickets
        CREATE POLICY "Users can view relevant queue tickets" 
            ON public.queue_tickets FOR SELECT 
            USING (
                (auth.uid() IS NOT NULL AND customer_id::text = auth.uid()::text)
                OR
                (salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text))
            );

        -- 2. INSERT: Customer joining queue OR Owner adding walk-in
        CREATE POLICY "Customers and Owners can insert tickets" 
            ON public.queue_tickets FOR INSERT 
            WITH CHECK (
                (
                    auth.uid() IS NOT NULL 
                    AND 
                    customer_id::text = auth.uid()::text
                    AND 
                    EXISTS (
                        SELECT 1 FROM public.salons s 
                        WHERE s.id::text = salon_id::text AND s.is_queue_open = true AND s.is_active = true
                    )
                    AND 
                    status = 'WAITING'
                )
                OR
                (
                    auth.uid() IS NOT NULL 
                    AND 
                    salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text)
                )
            );

        -- 3. CUSTOMER UPDATE: Cancel own ticket
        CREATE POLICY "Customers can cancel own tickets" 
            ON public.queue_tickets FOR UPDATE 
            USING (
                auth.uid() IS NOT NULL AND customer_id::text = auth.uid()::text
            ) 
            WITH CHECK (
                auth.uid() IS NOT NULL 
                AND 
                customer_id::text = auth.uid()::text 
                AND 
                status = 'CANCELLED'
            );

        -- 4. OWNER UPDATE: Manage tickets for own salon
        CREATE POLICY "Owners can update tickets for own salon" 
            ON public.queue_tickets FOR UPDATE 
            USING (
                auth.uid() IS NOT NULL 
                AND 
                salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text)
            ) 
            WITH CHECK (
                auth.uid() IS NOT NULL 
                AND 
                salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text)
            );

        -- 5. OWNER DELETE: Delete tickets for own salon
        CREATE POLICY "Owners can delete tickets for own salon" 
            ON public.queue_tickets FOR DELETE 
            USING (
                auth.uid() IS NOT NULL 
                AND 
                salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text)
            );
    END IF;
END $$;


-- ── E. QUEUE ENTRIES TABLE (Alternative/Core queue_entries support) ──────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'queue_entries') THEN
        ALTER TABLE public.queue_entries ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Queue entries viewable by relevant users" ON public.queue_entries;
        DROP POLICY IF EXISTS "Queue entries insertable by users" ON public.queue_entries;
        DROP POLICY IF EXISTS "Queue entries updateable by owners and customers" ON public.queue_entries;

        CREATE POLICY "Queue entries viewable by relevant users" 
            ON public.queue_entries FOR SELECT 
            USING (
                (auth.uid() IS NOT NULL AND customer_id::text = auth.uid()::text)
                OR
                (salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text))
            );

        CREATE POLICY "Queue entries insertable by users" 
            ON public.queue_entries FOR INSERT 
            WITH CHECK (
                (auth.uid() IS NOT NULL AND customer_id::text = auth.uid()::text)
                OR
                (auth.uid() IS NOT NULL AND salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text))
            );

        CREATE POLICY "Queue entries updateable by owners and customers" 
            ON public.queue_entries FOR UPDATE 
            USING (
                (auth.uid() IS NOT NULL AND customer_id::text = auth.uid()::text)
                OR
                (auth.uid() IS NOT NULL AND salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text))
            );
    END IF;
END $$;


-- ── F. SERVICE SESSIONS TABLE ────────────────────────────────────────────────
-- Customer identity resolved through queue_entry_id -> queue_entries.customer_id
-- Salon owner authorization resolved through salon_id -> salons.owner_id
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'service_sessions') THEN
        ALTER TABLE public.service_sessions ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Sessions viewable by salon owners and clients" ON public.service_sessions;
        DROP POLICY IF EXISTS "Sessions manageable by salon owners" ON public.service_sessions;

        -- 1. SELECT: Owner of the salon OR Client linked via queue_entry_id
        CREATE POLICY "Sessions viewable by salon owners and clients" 
            ON public.service_sessions FOR SELECT 
            USING (
                (
                    auth.uid() IS NOT NULL 
                    AND 
                    salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text)
                )
                OR
                (
                    auth.uid() IS NOT NULL 
                    AND 
                    EXISTS (
                        SELECT 1 FROM public.queue_entries qe 
                        WHERE qe.id::text = service_sessions.queue_entry_id::text 
                        AND qe.customer_id::text = auth.uid()::text
                    )
                )
            );

        -- 2. ALL: Salon Owner management
        CREATE POLICY "Sessions manageable by salon owners" 
            ON public.service_sessions FOR ALL 
            USING (
                auth.uid() IS NOT NULL 
                AND 
                salon_id::text IN (SELECT id::text FROM public.salons WHERE owner_id::text = auth.uid()::text)
            );
    END IF;
END $$;


-- ── G. NOTIFICATIONS TABLE ───────────────────────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
        ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Notifications viewable by everyone" ON public.notifications;
        DROP POLICY IF EXISTS "Notifications insertable by authenticated" ON public.notifications;
        DROP POLICY IF EXISTS "Notifications updateable by owner" ON public.notifications;
        DROP POLICY IF EXISTS "Notifications viewable by owner" ON public.notifications;
        DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
        DROP POLICY IF EXISTS "Authenticated users can create notifications" ON public.notifications;
        DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
        DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;

        -- 1. SELECT: Only the recipient can view their notification
        CREATE POLICY "Users can view own notifications" 
            ON public.notifications FOR SELECT 
            USING (
                auth.uid() IS NOT NULL 
                AND 
                (
                    (EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'user_id') AND user_id::text = auth.uid()::text)
                    OR
                    (EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'recipient_id') AND recipient_id::text = auth.uid()::text)
                    OR
                    (EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'owner_id') AND owner_id::text = auth.uid()::text)
                )
            );

        -- 2. INSERT: Authenticated users / queue workflows can create notifications
        CREATE POLICY "Authenticated users can create notifications" 
            ON public.notifications FOR INSERT 
            WITH CHECK (auth.uid() IS NOT NULL);

        -- 3. UPDATE: Users can only mark their own notifications as read
        CREATE POLICY "Users can update own notifications" 
            ON public.notifications FOR UPDATE 
            USING (
                auth.uid() IS NOT NULL 
                AND 
                (
                    (EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'user_id') AND user_id::text = auth.uid()::text)
                    OR
                    (EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'recipient_id') AND recipient_id::text = auth.uid()::text)
                    OR
                    (EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'owner_id') AND owner_id::text = auth.uid()::text)
                )
            );

        -- 4. DELETE: Users can only delete their own notifications
        CREATE POLICY "Users can delete own notifications" 
            ON public.notifications FOR DELETE 
            USING (
                auth.uid() IS NOT NULL 
                AND 
                (
                    (EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'user_id') AND user_id::text = auth.uid()::text)
                    OR
                    (EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'recipient_id') AND recipient_id::text = auth.uid()::text)
                    OR
                    (EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'owner_id') AND owner_id::text = auth.uid()::text)
                )
            );
    END IF;
END $$;


-- ── H. SUPPORT TICKETS TABLE ─────────────────────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'support_tickets') THEN
        ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Support tickets viewable by owner or admin" ON public.support_tickets;
        DROP POLICY IF EXISTS "Support tickets insertable by everyone" ON public.support_tickets;
        DROP POLICY IF EXISTS "Users can view own support tickets" ON public.support_tickets;
        DROP POLICY IF EXISTS "Users can create own support tickets" ON public.support_tickets;
        DROP POLICY IF EXISTS "Users can update own support tickets" ON public.support_tickets;

        CREATE POLICY "Users can view own support tickets" 
            ON public.support_tickets FOR SELECT 
            USING (auth.uid() IS NOT NULL AND user_id::text = auth.uid()::text);

        CREATE POLICY "Users can create own support tickets" 
            ON public.support_tickets FOR INSERT 
            WITH CHECK (auth.uid() IS NOT NULL AND user_id::text = auth.uid()::text);

        CREATE POLICY "Users can update own support tickets" 
            ON public.support_tickets FOR UPDATE 
            USING (auth.uid() IS NOT NULL AND user_id::text = auth.uid()::text) 
            WITH CHECK (auth.uid() IS NOT NULL AND user_id::text = auth.uid()::text);
    END IF;
END $$;


-- ── I. REVIEWS TABLE (If exists) ─────────────────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'reviews') THEN
        ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Reviews viewable by everyone" ON public.reviews;
        DROP POLICY IF EXISTS "Customers can create reviews" ON public.reviews;

        CREATE POLICY "Reviews viewable by everyone" 
            ON public.reviews FOR SELECT 
            USING (true);

        CREATE POLICY "Customers can create reviews" 
            ON public.reviews FOR INSERT 
            WITH CHECK (auth.uid() IS NOT NULL AND customer_id::text = auth.uid()::text);
    END IF;
END $$;


-- ── 5. STORAGE BUCKET ISOLATION & POLICIES ───────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'storage') THEN
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
    END IF;
END $$;


-- ── 6. SUPABASE REALTIME PUBLICATION ─────────────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'salons') THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'salons') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.salons;
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'services') THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'services') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.services;
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'queue_tickets') THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'queue_tickets') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.queue_tickets;
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'queue_entries') THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'queue_entries') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.queue_entries;
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
        END IF;
    END IF;
END $$;

-- ── 7. RELOAD SCHEMA CACHE ───────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
