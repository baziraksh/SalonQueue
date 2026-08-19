-- ============================================================================
-- CANONICAL SERVICES & QUEUE REALTIME FLOW MIGRATION
-- Project: SalonQueue (https://ktabfbscrehhdstggjzp.supabase.co)
-- Date: 2026-08-19
-- ============================================================================

-- 1. Ensure public.services table exists with full schema
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID NOT NULL REFERENCES public.salons(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Hair',
    price DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    duration_minutes INT NOT NULL DEFAULT 20,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Ensure all columns exist on public.services
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Hair';
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS price DOUBLE PRECISION DEFAULT 0.0;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS duration_minutes INT DEFAULT 20;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 3. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_services_salon_id ON public.services(salon_id);
CREATE INDEX IF NOT EXISTS idx_services_is_active ON public.services(salon_id, is_active);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queue_tickets ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for public.services
DROP POLICY IF EXISTS "Services viewable by everyone" ON public.services;
CREATE POLICY "Services viewable by everyone" 
    ON public.services FOR SELECT USING (true);

DROP POLICY IF EXISTS "Owners can insert their salon services" ON public.services;
CREATE POLICY "Owners can insert their salon services" 
    ON public.services FOR INSERT 
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.salons 
            WHERE salons.id = services.salon_id 
            AND salons.owner_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Owners can update their salon services" ON public.services;
CREATE POLICY "Owners can update their salon services" 
    ON public.services FOR UPDATE 
    USING (
        EXISTS (
            SELECT 1 FROM public.salons 
            WHERE salons.id = services.salon_id 
            AND salons.owner_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.salons 
            WHERE salons.id = services.salon_id 
            AND salons.owner_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Owners can delete their salon services" ON public.services;
CREATE POLICY "Owners can delete their salon services" 
    ON public.services FOR DELETE 
    USING (
        EXISTS (
            SELECT 1 FROM public.salons 
            WHERE salons.id = services.salon_id 
            AND salons.owner_id = auth.uid()
        )
    );

-- 6. RLS Policies for public.queue_tickets
DROP POLICY IF EXISTS "Queue tickets viewable by everyone" ON public.queue_tickets;
CREATE POLICY "Queue tickets viewable by everyone" 
    ON public.queue_tickets FOR SELECT USING (true);

DROP POLICY IF EXISTS "Customers and owners can insert queue tickets" ON public.queue_tickets;
CREATE POLICY "Customers and owners can insert queue tickets" 
    ON public.queue_tickets FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Owners and ticket holders can update queue tickets" ON public.queue_tickets;
CREATE POLICY "Owners and ticket holders can update queue tickets" 
    ON public.queue_tickets FOR UPDATE USING (
        auth.uid() = customer_id 
        OR EXISTS (
            SELECT 1 FROM public.salons 
            WHERE salons.id = queue_tickets.salon_id 
            AND salons.owner_id = auth.uid()
        )
        OR customer_id IS NULL
    );

-- 7. Grant Permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.services TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.queue_tickets TO anon, authenticated, service_role;

-- 8. Add tables to Supabase Realtime publication
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
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
            AND tablename = 'notifications'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
        END IF;
    END IF;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

-- 9. Reload PostgREST Schema Cache
NOTIFY pgrst, 'reload schema';
