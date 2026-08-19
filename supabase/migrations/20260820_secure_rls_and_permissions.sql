-- ============================================================
-- SALON QUEUE - RLS REPAIR
-- Fixes schema mismatch errors only
-- Target: ktabfbscrehhdstggjzp.supabase.co
-- Date: 2026-08-20
-- ============================================================

BEGIN;

-- ============================================================
-- 1. SERVICE SESSIONS
-- Actual schema:
-- service_sessions.queue_entry_id
-- service_sessions.salon_id
-- service_sessions.staff_id
-- There is NO customer_id column.
-- ============================================================

ALTER TABLE public.service_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Sessions viewable by salon owners and clients"
ON public.service_sessions;

DROP POLICY IF EXISTS "Sessions manageable by salon owners"
ON public.service_sessions;

DROP POLICY IF EXISTS service_sessions_select
ON public.service_sessions;

DROP POLICY IF EXISTS service_sessions_insert_owner_staff
ON public.service_sessions;

DROP POLICY IF EXISTS service_sessions_update_owner_staff
ON public.service_sessions;

DROP POLICY IF EXISTS service_sessions_insert_owner
ON public.service_sessions;

DROP POLICY IF EXISTS service_sessions_update_owner
ON public.service_sessions;

DROP POLICY IF EXISTS service_sessions_delete_owner
ON public.service_sessions;


-- Customer can see the service session belonging to their own queue entry.
-- Owner can see sessions belonging to their salon.

CREATE POLICY service_sessions_select
ON public.service_sessions
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.queue_entries qe
        WHERE qe.id = service_sessions.queue_entry_id
        AND qe.customer_id = auth.uid()
    )
    OR
    EXISTS (
        SELECT 1
        FROM public.salons s
        WHERE s.id = service_sessions.salon_id
        AND s.owner_id = auth.uid()
    )
);


-- Owner can create service sessions for their own salon.

CREATE POLICY service_sessions_insert_owner
ON public.service_sessions
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.salons s
        WHERE s.id = service_sessions.salon_id
        AND s.owner_id = auth.uid()
    )
);


-- Owner can update service sessions for their own salon.

CREATE POLICY service_sessions_update_owner
ON public.service_sessions
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.salons s
        WHERE s.id = service_sessions.salon_id
        AND s.owner_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.salons s
        WHERE s.id = service_sessions.salon_id
        AND s.owner_id = auth.uid()
    )
);


-- Owner can delete service sessions for their own salon.

CREATE POLICY service_sessions_delete_owner
ON public.service_sessions
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.salons s
        WHERE s.id = service_sessions.salon_id
        AND s.owner_id = auth.uid()
    )
);


-- ============================================================
-- 2. NOTIFICATIONS
-- Actual schema uses recipient_id UUID.
-- Do NOT use owner_id/user_id here.
-- ============================================================

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notifications"
ON public.notifications;

DROP POLICY IF EXISTS "Authenticated users can create notifications"
ON public.notifications;

DROP POLICY IF EXISTS "Users can update own notifications"
ON public.notifications;

DROP POLICY IF EXISTS "Users can delete own notifications"
ON public.notifications;

DROP POLICY IF EXISTS notifications_select_own
ON public.notifications;

DROP POLICY IF EXISTS notifications_insert_auth
ON public.notifications;

DROP POLICY IF EXISTS notifications_update_own
ON public.notifications;

DROP POLICY IF EXISTS notifications_delete_own
ON public.notifications;


CREATE POLICY notifications_select_own
ON public.notifications
FOR SELECT
TO authenticated
USING (
    recipient_id = auth.uid()
);


CREATE POLICY notifications_insert_auth
ON public.notifications
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() IS NOT NULL
);


CREATE POLICY notifications_update_own
ON public.notifications
FOR UPDATE
TO authenticated
USING (
    recipient_id = auth.uid()
)
WITH CHECK (
    recipient_id = auth.uid()
);


CREATE POLICY notifications_delete_own
ON public.notifications
FOR DELETE
TO authenticated
USING (
    recipient_id = auth.uid()
);


-- ============================================================
-- 3. QUEUE ENTRIES
-- Customer sees own queue.
-- Owner sees queue of own salon.
-- ============================================================

ALTER TABLE public.queue_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Queue entries viewable by relevant users"
ON public.queue_entries;

DROP POLICY IF EXISTS "Queue entries insertable by users"
ON public.queue_entries;

DROP POLICY IF EXISTS "Queue entries updateable by owners and customers"
ON public.queue_entries;

DROP POLICY IF EXISTS queue_entries_select
ON public.queue_entries;

DROP POLICY IF EXISTS queue_entries_insert
ON public.queue_entries;

DROP POLICY IF EXISTS queue_entries_update
ON public.queue_entries;


CREATE POLICY queue_entries_select
ON public.queue_entries
FOR SELECT
TO authenticated
USING (
    customer_id = auth.uid()
    OR
    EXISTS (
        SELECT 1
        FROM public.salons s
        WHERE s.id = queue_entries.salon_id
        AND s.owner_id = auth.uid()
    )
);

CREATE POLICY queue_entries_insert
ON public.queue_entries
FOR INSERT
TO authenticated
WITH CHECK (
    customer_id = auth.uid()
    OR
    EXISTS (
        SELECT 1
        FROM public.salons s
        WHERE s.id = queue_entries.salon_id
        AND s.owner_id = auth.uid()
    )
);

CREATE POLICY queue_entries_update
ON public.queue_entries
FOR UPDATE
TO authenticated
USING (
    customer_id = auth.uid()
    OR
    EXISTS (
        SELECT 1
        FROM public.salons s
        WHERE s.id = queue_entries.salon_id
        AND s.owner_id = auth.uid()
    )
);


-- ============================================================
-- 4. SALONS
-- No location column is referenced here.
-- ============================================================

ALTER TABLE public.salons ENABLE ROW LEVEL SECURITY;

DROP INDEX IF EXISTS public.idx_salons_location;


DROP POLICY IF EXISTS "Active published salons viewable by everyone"
ON public.salons;

DROP POLICY IF EXISTS "Owners can insert their own salon"
ON public.salons;

DROP POLICY IF EXISTS "Owners can update their own salon"
ON public.salons;

DROP POLICY IF EXISTS "Owners can delete their own salon"
ON public.salons;

DROP POLICY IF EXISTS salons_select_public
ON public.salons;

DROP POLICY IF EXISTS salons_insert_owner
ON public.salons;

DROP POLICY IF EXISTS salons_update_owner
ON public.salons;

DROP POLICY IF EXISTS salons_delete_owner
ON public.salons;


CREATE POLICY salons_select_public
ON public.salons
FOR SELECT
USING (
    (
        is_active = true
        AND
        (
            is_published = true
            OR is_published IS NULL
        )
    )
    OR
    owner_id = auth.uid()
);


CREATE POLICY salons_insert_owner
ON public.salons
FOR INSERT
TO authenticated
WITH CHECK (
    owner_id = auth.uid()
);


CREATE POLICY salons_update_owner
ON public.salons
FOR UPDATE
TO authenticated
USING (
    owner_id = auth.uid()
)
WITH CHECK (
    owner_id = auth.uid()
);


CREATE POLICY salons_delete_owner
ON public.salons
FOR DELETE
TO authenticated
USING (
    owner_id = auth.uid()
);


-- ============================================================
-- 5. SERVICES
-- Public can see active services.
-- Owner can manage own salon services.
-- ============================================================

ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Active services viewable by everyone"
ON public.services;

DROP POLICY IF EXISTS "Owners can insert services"
ON public.services;

DROP POLICY IF EXISTS "Owners can update services"
ON public.services;

DROP POLICY IF EXISTS "Owners can delete services"
ON public.services;

DROP POLICY IF EXISTS services_select_public
ON public.services;

DROP POLICY IF EXISTS services_insert_owner
ON public.services;

DROP POLICY IF EXISTS services_update_owner
ON public.services;

DROP POLICY IF EXISTS services_delete_owner
ON public.services;


CREATE POLICY services_select_public
ON public.services
FOR SELECT
USING (
    is_active = true
    OR
    EXISTS (
        SELECT 1
        FROM public.salons s
        WHERE s.id = services.salon_id
        AND s.owner_id = auth.uid()
    )
);


CREATE POLICY services_insert_owner
ON public.services
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.salons s
        WHERE s.id = services.salon_id
        AND s.owner_id = auth.uid()
    )
);


CREATE POLICY services_update_owner
ON public.services
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.salons s
        WHERE s.id = services.salon_id
        AND s.owner_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.salons s
        WHERE s.id = services.salon_id
        AND s.owner_id = auth.uid()
    )
);


CREATE POLICY services_delete_owner
ON public.services
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.salons s
        WHERE s.id = services.salon_id
        AND s.owner_id = auth.uid()
    )
);


COMMIT;

NOTIFY pgrst, 'reload schema';
