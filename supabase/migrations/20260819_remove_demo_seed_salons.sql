-- ============================================================================
-- Migration: Remove All Demo/Sample Seed Salons and Neutralize Default Values
-- Target: ktabfbscrehhdstggjzp.supabase.co
-- Date: 2026-08-19
-- ============================================================================

-- 1. Remove services linked to known demo seed salons or un-owned dummy salons
DELETE FROM public.services 
WHERE salon_id IN (
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid,
    '44444444-4444-4444-4444-444444444444'::uuid,
    '55555555-5555-5555-5555-555555555555'::uuid
) OR salon_id IN (
    SELECT id FROM public.salons 
    WHERE owner_id IS NULL OR owner_id NOT IN (SELECT id FROM auth.users)
);

-- 2. Remove demo tickets linked to known demo seed salons or un-owned dummy salons
DELETE FROM public.queue_tickets 
WHERE salon_id IN (
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid,
    '44444444-4444-4444-4444-444444444444'::uuid,
    '55555555-5555-5555-5555-555555555555'::uuid
) OR salon_id IN (
    SELECT id FROM public.salons 
    WHERE owner_id IS NULL OR owner_id NOT IN (SELECT id FROM auth.users)
);

-- 3. Delete the known demo seed salons and any un-owned dummy salons
DELETE FROM public.salons 
WHERE id IN (
    '11111111-1111-1111-1111-111111111111'::uuid,
    '22222222-2222-2222-2222-222222222222'::uuid,
    '33333333-3333-3333-3333-333333333333'::uuid,
    '44444444-4444-4444-4444-444444444444'::uuid,
    '55555555-5555-5555-5555-555555555555'::uuid
) OR owner_id IS NULL OR owner_id NOT IN (SELECT id FROM auth.users);

-- 4. Neutralize column default values so missing fields never manufacture fake ratings
ALTER TABLE public.salons ALTER COLUMN rating SET DEFAULT 0.0;
ALTER TABLE public.salons ALTER COLUMN review_count SET DEFAULT 0;
ALTER TABLE public.salons ALTER COLUMN active_chairs SET DEFAULT 1;

-- 5. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
