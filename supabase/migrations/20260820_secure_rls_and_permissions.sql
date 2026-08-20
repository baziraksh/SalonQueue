-- ============================================================================
-- Migration: Secure Supabase Row Level Security (RLS) & Access Control
-- Target Supabase Project: ktabfbscrehhdstggjzp.supabase.co
-- Date: 2026-08-20
-- Architecture:
--   - Single canonical queue system: public.queue_tickets
--   - Notifications use canonical recipient_id UUID
--   - Service sessions link to public.queue_tickets (or salon_id for owners)
--   - Hardened RLS for profiles, salons, services, queue_tickets, notifications, support_tickets
--   - Storage isolation for avatars and salon_images
-- ============================================================================

BEGIN;

-- ── 1. REVOKE BROAD PRIVILEGES & RESET DEFAULT PRIVILEGES ───────────────────
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL ROUTINES IN SCHEMA public FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON ROUTINES FROM anon, authenticated;

-- ── 2. GRANT MINIMUM NECESSARY PRIVILEGES ────────────────────────────────────
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- Anonymous: read-only access for discovering active salons and services
GRANT SELECT ON TABLE public.salons TO anon;
GRANT SELECT ON TABLE public.services TO anon;

-- Authenticated: explicit CRUD governed strictly by RLS policies
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.salons TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.services TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.queue_tickets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.notifications TO authenticated;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'support_tickets') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.support_tickets TO authenticated;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'service_sessions') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.service_sessions TO authenticated;
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

-- ── 3. CLEAN UP OBSOLETE INDEXES & ENSURE PERFORMANCE INDEXES ───────────────
DROP INDEX IF EXISTS public.idx_salons_location;

CREATE INDEX IF NOT EXISTS idx_salons_owner_id ON public.salons(owner_id);
CREATE INDEX IF NOT EXISTS idx_salons_state_district_city ON public.salons(state, district, city);
CREATE INDEX IF NOT EXISTS idx_salons_active_published ON public.salons(is_active, is_published);

CREATE INDEX IF NOT EXISTS idx_services_salon_active ON public.services(salon_id, is_active);

CREATE INDEX IF NOT EXISTS idx_queue_tickets_customer_id ON public.queue_tickets(customer_id);
CREATE INDEX IF NOT EXISTS idx_queue_tickets_salon_status ON public.queue_tickets(salon_id, status, token_number);
CREATE INDEX IF NOT EXISTS idx_queue_tickets_created ON public.queue_tickets(salon_id, created_at DESC);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'recipient_id') THEN
            CREATE INDEX IF NOT EXISTS idx_notifications_recipient_id ON public.notifications(recipient_id);
        END IF;
    END IF;
END $$;


-- ── 4. ROW LEVEL SECURITY (RLS) POLICIES ─────────────────────────────────────

-- ── A. PROFILES TABLE ────────────────────────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Profiles viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Public can view salon owner public profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON public.profiles;
DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
DROP POLICY IF EXISTS profiles_select_owner_public ON public.profiles;
DROP POLICY IF EXISTS profiles_insert_own ON public.profiles;
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
DROP POLICY IF EXISTS profiles_delete_own ON public.profiles;

-- 1. Users can read their own profile
CREATE POLICY profiles_select_own 
    ON public.profiles FOR SELECT 
    USING (auth.uid() = id);

-- 2. Public can view public profile details of active/published salon owners
CREATE POLICY profiles_select_owner_public 
    ON public.profiles FOR SELECT 
    USING (
        id IN (SELECT owner_id FROM public.salons WHERE is_active = true AND (is_published = true OR is_published IS NULL))
    );

-- 3. Users can create their own profile upon signup
CREATE POLICY profiles_insert_own 
    ON public.profiles FOR INSERT 
    WITH CHECK (auth.uid() = id);

-- 4. Users can only update their own profile
CREATE POLICY profiles_update_own 
    ON public.profiles FOR UPDATE 
    USING (auth.uid() = id) 
    WITH CHECK (auth.uid() = id);

-- 5. Users can delete their own profile
CREATE POLICY profiles_delete_own 
    ON public.profiles FOR DELETE 
    USING (auth.uid() = id);


-- ── B. SALONS TABLE ──────────────────────────────────────────────────────────
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
DROP POLICY IF EXISTS salons_select_public ON public.salons;
DROP POLICY IF EXISTS salons_insert_owner ON public.salons;
DROP POLICY IF EXISTS salons_update_owner ON public.salons;
DROP POLICY IF EXISTS salons_delete_owner ON public.salons;

-- 1. Public can discover active/published salons; Owners can always view their own salon
CREATE POLICY salons_select_public 
    ON public.salons FOR SELECT 
    USING (
        (is_active = true AND (is_published = true OR is_published IS NULL))
        OR 
        (auth.uid() IS NOT NULL AND owner_id = auth.uid())
    );

-- 2. Authenticated owners can insert their own salon
CREATE POLICY salons_insert_owner 
    ON public.salons FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL AND owner_id = auth.uid());

-- 3. Owners can update only their own salon
CREATE POLICY salons_update_owner 
    ON public.salons FOR UPDATE 
    TO authenticated
    USING (auth.uid() IS NOT NULL AND owner_id = auth.uid()) 
    WITH CHECK (auth.uid() IS NOT NULL AND owner_id = auth.uid());

-- 4. Owners can delete only their own salon
CREATE POLICY salons_delete_owner 
    ON public.salons FOR DELETE 
    TO authenticated
    USING (auth.uid() IS NOT NULL AND owner_id = auth.uid());


-- ── C. SERVICES TABLE ────────────────────────────────────────────────────────
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Services viewable by everyone" ON public.services;
DROP POLICY IF EXISTS "Public services viewable by everyone" ON public.services;
DROP POLICY IF EXISTS "Active services viewable by everyone" ON public.services;
DROP POLICY IF EXISTS "Salon owners can manage services" ON public.services;
DROP POLICY IF EXISTS "Owners can manage services of their salon" ON public.services;
DROP POLICY IF EXISTS "Owners can insert services" ON public.services;
DROP POLICY IF EXISTS "Owners can update services" ON public.services;
DROP POLICY IF EXISTS "Owners can delete services" ON public.services;
DROP POLICY IF EXISTS services_select_public ON public.services;
DROP POLICY IF EXISTS services_insert_owner ON public.services;
DROP POLICY IF EXISTS services_update_owner ON public.services;
DROP POLICY IF EXISTS services_delete_owner ON public.services;

-- 1. Public can read active services; Owners can read all services of their salon
CREATE POLICY services_select_public 
    ON public.services FOR SELECT 
    USING (
        is_active = true 
        OR 
        EXISTS (
            SELECT 1 FROM public.salons s 
            WHERE s.id = services.salon_id AND s.owner_id = auth.uid()
        )
    );

-- 2. Owners can insert services only for their own salon
CREATE POLICY services_insert_owner 
    ON public.services FOR INSERT 
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.salons s 
            WHERE s.id = services.salon_id AND s.owner_id = auth.uid()
        )
    );

-- 3. Owners can update services only for their own salon
CREATE POLICY services_update_owner 
    ON public.services FOR UPDATE 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.salons s 
            WHERE s.id = services.salon_id AND s.owner_id = auth.uid()
        )
    ) 
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.salons s 
            WHERE s.id = services.salon_id AND s.owner_id = auth.uid()
        )
    );

-- 4. Owners can delete services only for their own salon
CREATE POLICY services_delete_owner 
    ON public.services FOR DELETE 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.salons s 
            WHERE s.id = services.salon_id AND s.owner_id = auth.uid()
        )
    );


-- ── D. QUEUE TICKETS TABLE (THE ONLY QUEUE SYSTEM) ───────────────────────────
ALTER TABLE public.queue_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Queue tickets viewable by everyone" ON public.queue_tickets;
DROP POLICY IF EXISTS "Queue tickets viewable by salon owner and ticket customer" ON public.queue_tickets;
DROP POLICY IF EXISTS "Users can view relevant queue tickets" ON public.queue_tickets;
DROP POLICY IF EXISTS "Customers can create tickets" ON public.queue_tickets;
DROP POLICY IF EXISTS "Users can insert tickets" ON public.queue_tickets;
DROP POLICY IF EXISTS "Customers and Owners can insert tickets" ON public.queue_tickets;
DROP POLICY IF EXISTS "Customers and owners can create tickets" ON public.queue_tickets;
DROP POLICY IF EXISTS "Customers and owners can insert queue tickets" ON public.queue_tickets;
DROP POLICY IF EXISTS "Users can update tickets" ON public.queue_tickets;
DROP POLICY IF EXISTS "Ticket update policy" ON public.queue_tickets;
DROP POLICY IF EXISTS "Customers can update their own tickets (cancel)" ON public.queue_tickets;
DROP POLICY IF EXISTS "Owners and ticket holders can update queue tickets" ON public.queue_tickets;
DROP POLICY IF EXISTS "Customers can cancel own tickets" ON public.queue_tickets;
DROP POLICY IF EXISTS "Owners can update tickets for own salon" ON public.queue_tickets;
DROP POLICY IF EXISTS "Owners can delete tickets for own salon" ON public.queue_tickets;
DROP POLICY IF EXISTS queue_tickets_select ON public.queue_tickets;
DROP POLICY IF EXISTS queue_tickets_insert ON public.queue_tickets;
DROP POLICY IF EXISTS queue_tickets_customer_cancel ON public.queue_tickets;
DROP POLICY IF EXISTS queue_tickets_owner_update ON public.queue_tickets;
DROP POLICY IF EXISTS queue_tickets_owner_delete ON public.queue_tickets;

-- 1. SELECT: Customer reads own tickets; Owner reads all tickets for their salon
CREATE POLICY queue_tickets_select 
    ON public.queue_tickets FOR SELECT 
    TO authenticated
    USING (
        customer_id = auth.uid()
        OR
        EXISTS (
            SELECT 1 FROM public.salons s 
            WHERE s.id = queue_tickets.salon_id AND s.owner_id = auth.uid()
        )
    );

-- 2. INSERT: Customer joining queue OR Owner adding walk-in ticket
CREATE POLICY queue_tickets_insert 
    ON public.queue_tickets FOR INSERT 
    TO authenticated
    WITH CHECK (
        (
            customer_id = auth.uid()
            AND 
            EXISTS (
                SELECT 1 FROM public.salons s 
                WHERE s.id = queue_tickets.salon_id AND s.is_queue_open = true AND s.is_active = true
            )
            AND 
            status = 'WAITING'
        )
        OR
        EXISTS (
            SELECT 1 FROM public.salons s 
            WHERE s.id = queue_tickets.salon_id AND s.owner_id = auth.uid()
        )
    );

-- 3. CUSTOMER UPDATE: Customer can only cancel their own active ticket
CREATE POLICY queue_tickets_customer_cancel 
    ON public.queue_tickets FOR UPDATE 
    TO authenticated
    USING (
        customer_id = auth.uid()
    ) 
    WITH CHECK (
        customer_id = auth.uid() 
        AND 
        status = 'CANCELLED'
    );

-- 4. OWNER UPDATE: Salon owner manages queue status, chairs, and times for own salon
CREATE POLICY queue_tickets_owner_update 
    ON public.queue_tickets FOR UPDATE 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.salons s 
            WHERE s.id = queue_tickets.salon_id AND s.owner_id = auth.uid()
        )
    ) 
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.salons s 
            WHERE s.id = queue_tickets.salon_id AND s.owner_id = auth.uid()
        )
    );

-- 5. OWNER DELETE: Salon owner can remove tickets for own salon
CREATE POLICY queue_tickets_owner_delete 
    ON public.queue_tickets FOR DELETE 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.salons s 
            WHERE s.id = queue_tickets.salon_id AND s.owner_id = auth.uid()
        )
    );


-- ── E. NOTIFICATIONS TABLE (USES RECIPIENT_ID) ───────────────────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Notifications viewable by everyone" ON public.notifications;
DROP POLICY IF EXISTS "Notifications insertable by authenticated" ON public.notifications;
DROP POLICY IF EXISTS "Notifications updateable by owner" ON public.notifications;
DROP POLICY IF EXISTS "Notifications viewable by owner" ON public.notifications;
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Authenticated users can create notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
DROP POLICY IF EXISTS notifications_insert_auth ON public.notifications;
DROP POLICY IF EXISTS notifications_update_own ON public.notifications;
DROP POLICY IF EXISTS notifications_delete_own ON public.notifications;

-- 1. SELECT: Users can only read notifications addressed to their recipient_id
CREATE POLICY notifications_select_own 
    ON public.notifications FOR SELECT 
    TO authenticated
    USING (recipient_id = auth.uid());

-- 2. INSERT: Authenticated users / queue actions can create notifications
CREATE POLICY notifications_insert_auth 
    ON public.notifications FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

-- 3. UPDATE: Users can only update their own notifications (e.g. mark as read)
CREATE POLICY notifications_update_own 
    ON public.notifications FOR UPDATE 
    TO authenticated
    USING (recipient_id = auth.uid()) 
    WITH CHECK (recipient_id = auth.uid());

-- 4. DELETE: Users can only delete their own notifications
CREATE POLICY notifications_delete_own 
    ON public.notifications FOR DELETE 
    TO authenticated
    USING (recipient_id = auth.uid());


-- ── F. SERVICE SESSIONS TABLE (OPTIONAL / BACKEND TABLE) ──────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'service_sessions') THEN
        ALTER TABLE public.service_sessions ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Sessions viewable by salon owners and clients" ON public.service_sessions;
        DROP POLICY IF EXISTS "Sessions manageable by salon owners" ON public.service_sessions;
        DROP POLICY IF EXISTS service_sessions_select ON public.service_sessions;
        DROP POLICY IF EXISTS service_sessions_insert_owner ON public.service_sessions;
        DROP POLICY IF EXISTS service_sessions_update_owner ON public.service_sessions;
        DROP POLICY IF EXISTS service_sessions_delete_owner ON public.service_sessions;

        -- Check if ticket_id column exists
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'service_sessions' AND column_name = 'ticket_id') THEN
            EXECUTE '
            CREATE POLICY service_sessions_select 
                ON public.service_sessions FOR SELECT 
                TO authenticated
                USING (
                    EXISTS (
                        SELECT 1 FROM public.queue_tickets qt 
                        WHERE qt.id = service_sessions.ticket_id AND qt.customer_id = auth.uid()
                    )
                    OR
                    EXISTS (
                        SELECT 1 FROM public.salons s 
                        WHERE s.id = service_sessions.salon_id AND s.owner_id = auth.uid()
                    )
                )';
        ELSE
            EXECUTE '
            CREATE POLICY service_sessions_select 
                ON public.service_sessions FOR SELECT 
                TO authenticated
                USING (
                    EXISTS (
                        SELECT 1 FROM public.salons s 
                        WHERE s.id = service_sessions.salon_id AND s.owner_id = auth.uid()
                    )
                )';
        END IF;

        CREATE POLICY service_sessions_insert_owner 
            ON public.service_sessions FOR INSERT 
            TO authenticated
            WITH CHECK (
                EXISTS (
                    SELECT 1 FROM public.salons s 
                    WHERE s.id = service_sessions.salon_id AND s.owner_id = auth.uid()
                )
            );

        CREATE POLICY service_sessions_update_owner 
            ON public.service_sessions FOR UPDATE 
            TO authenticated
            USING (
                EXISTS (
                    SELECT 1 FROM public.salons s 
                    WHERE s.id = service_sessions.salon_id AND s.owner_id = auth.uid()
                )
            ) 
            WITH CHECK (
                EXISTS (
                    SELECT 1 FROM public.salons s 
                    WHERE s.id = service_sessions.salon_id AND s.owner_id = auth.uid()
                )
            );

        CREATE POLICY service_sessions_delete_owner 
            ON public.service_sessions FOR DELETE 
            TO authenticated
            USING (
                EXISTS (
                    SELECT 1 FROM public.salons s 
                    WHERE s.id = service_sessions.salon_id AND s.owner_id = auth.uid()
                )
            );
    END IF;
END $$;


-- ── G. SUPPORT TICKETS TABLE (IF EXISTS) ─────────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'support_tickets') THEN
        ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Support tickets viewable by owner or admin" ON public.support_tickets;
        DROP POLICY IF EXISTS "Support tickets insertable by everyone" ON public.support_tickets;
        DROP POLICY IF EXISTS "Users can view own support tickets" ON public.support_tickets;
        DROP POLICY IF EXISTS "Users can create own support tickets" ON public.support_tickets;
        DROP POLICY IF EXISTS "Users can update own support tickets" ON public.support_tickets;
        DROP POLICY IF EXISTS support_tickets_select_own ON public.support_tickets;
        DROP POLICY IF EXISTS support_tickets_insert_own ON public.support_tickets;
        DROP POLICY IF EXISTS support_tickets_update_own ON public.support_tickets;

        CREATE POLICY support_tickets_select_own 
            ON public.support_tickets FOR SELECT 
            TO authenticated
            USING (user_id = auth.uid());

        CREATE POLICY support_tickets_insert_own 
            ON public.support_tickets FOR INSERT 
            TO authenticated
            WITH CHECK (user_id = auth.uid());

        CREATE POLICY support_tickets_update_own 
            ON public.support_tickets FOR UPDATE 
            TO authenticated
            USING (user_id = auth.uid()) 
            WITH CHECK (user_id = auth.uid());
    END IF;
END $$;


-- ── H. REVIEWS TABLE (IF EXISTS) ─────────────────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'reviews') THEN
        ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS "Reviews viewable by everyone" ON public.reviews;
        DROP POLICY IF EXISTS "Customers can create reviews" ON public.reviews;
        DROP POLICY IF EXISTS reviews_select_public ON public.reviews;
        DROP POLICY IF EXISTS reviews_insert_customer ON public.reviews;

        CREATE POLICY reviews_select_public 
            ON public.reviews FOR SELECT 
            USING (true);

        CREATE POLICY reviews_insert_customer 
            ON public.reviews FOR INSERT 
            TO authenticated
            WITH CHECK (customer_id = auth.uid());
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
        DROP POLICY IF EXISTS storage_public_read ON storage.objects;
        DROP POLICY IF EXISTS storage_user_insert ON storage.objects;
        DROP POLICY IF EXISTS storage_user_update ON storage.objects;
        DROP POLICY IF EXISTS storage_user_delete ON storage.objects;

        -- 1. Public read for avatars and salon images
        CREATE POLICY storage_public_read 
            ON storage.objects FOR SELECT 
            USING (bucket_id IN ('avatars', 'salon_images'));

        -- 2. Authenticated users can upload only to their own folder path
        CREATE POLICY storage_user_insert 
            ON storage.objects FOR INSERT 
            TO authenticated
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
        CREATE POLICY storage_user_update 
            ON storage.objects FOR UPDATE 
            TO authenticated
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
        CREATE POLICY storage_user_delete 
            ON storage.objects FOR DELETE 
            TO authenticated
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

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
        IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications') THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
        END IF;
    END IF;
END $$;

COMMIT;

-- ── 7. RELOAD SCHEMA CACHE ───────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
