-- ============================================================================
-- CRITICAL FIX: Grant Table Privileges to anon and authenticated roles in Supabase
-- Target Supabase Project: ktabfbscrehhdstggjzp.supabase.co
-- ============================================================================

-- 1. Grant Schema Usage
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- 2. Grant table permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

-- 3. Ensure future tables also inherit these permissions
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;

-- 4. Explicit Grants for Core Application Tables
GRANT ALL ON TABLE public.salons TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.profiles TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.queue_tickets TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.services TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.notifications TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.support_tickets TO anon, authenticated, service_role;

-- 5. RLS Policies
ALTER TABLE public.salons ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Salons viewable by everyone" ON public.salons;
CREATE POLICY "Salons viewable by everyone" ON public.salons FOR SELECT USING (true);

DROP POLICY IF EXISTS "Owners can insert their own salon" ON public.salons;
CREATE POLICY "Owners can insert their own salon" ON public.salons FOR INSERT WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owners can update their own salon" ON public.salons;
CREATE POLICY "Owners can update their own salon" ON public.salons FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

ALTER TABLE public.queue_tickets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Queue tickets viewable by everyone" ON public.queue_tickets;
CREATE POLICY "Queue tickets viewable by everyone" ON public.queue_tickets FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert tickets" ON public.queue_tickets;
CREATE POLICY "Users can insert tickets" ON public.queue_tickets FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update tickets" ON public.queue_tickets;
CREATE POLICY "Users can update tickets" ON public.queue_tickets FOR UPDATE USING (true);
