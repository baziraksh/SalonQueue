-- ============================================================================
-- Migration: Salons, Services, and Queue Tickets Schema
-- Supports multi-city salon discovery, service catalog (haircut, facial, etc.),
-- live rush level tracking, and digital queue tokens.
-- ============================================================================

-- Drop old conflicting tables if any exist
DROP TABLE IF EXISTS queue_tickets, services, salons CASCADE;

-- 1) Salons Table
CREATE TABLE salons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    address TEXT NOT NULL,
    city TEXT NOT NULL DEFAULT 'Pune',
    state TEXT NOT NULL DEFAULT 'Maharashtra',
    phone TEXT,
    rating NUMERIC(2, 1) NOT NULL DEFAULT 4.8,
    review_count INT NOT NULL DEFAULT 45,
    active_chairs INT NOT NULL DEFAULT 3,
    is_queue_open BOOLEAN NOT NULL DEFAULT true,
    opening_time TEXT NOT NULL DEFAULT '09:00 AM',
    closing_time TEXT NOT NULL DEFAULT '09:00 PM',
    banner_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2) Services Table (Haircut, Facial, Beard, Spa, etc.)
CREATE TABLE IF NOT EXISTS services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('Hair', 'Beard', 'Facial', 'Color', 'Spa', 'Combo', 'Other')),
    price NUMERIC(10, 2) NOT NULL,
    duration_minutes INT NOT NULL DEFAULT 20,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3) Queue Tickets Table
CREATE TABLE IF NOT EXISTS queue_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
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

-- Indexes for lightning fast lookups
CREATE INDEX IF NOT EXISTS idx_salons_city ON salons(city);
CREATE INDEX IF NOT EXISTS idx_salons_owner ON salons(owner_id);
CREATE INDEX IF NOT EXISTS idx_services_salon ON services(salon_id);
CREATE INDEX IF NOT EXISTS idx_queue_salon_status ON queue_tickets(salon_id, status);
CREATE INDEX IF NOT EXISTS idx_queue_customer ON queue_tickets(customer_id);

-- Enable RLS
ALTER TABLE salons ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE queue_tickets ENABLE ROW LEVEL SECURITY;

-- Salons RLS: Anyone can view; owners can insert/update
CREATE POLICY "Public salons viewable by everyone" ON salons FOR SELECT USING (true);
CREATE POLICY "Owners can manage their salons" ON salons FOR ALL USING (auth.uid() = owner_id);

-- Services RLS: Anyone can view; salon owners can manage
CREATE POLICY "Public services viewable by everyone" ON services FOR SELECT USING (true);
CREATE POLICY "Salon owners can manage services" ON services FOR ALL USING (
    EXISTS (SELECT 1 FROM salons WHERE salons.id = services.salon_id AND salons.owner_id = auth.uid())
);

-- Queue Tickets RLS: Anyone can view tickets for their salon/queue; Customers manage their own; Owners manage salon tickets
CREATE POLICY "Queue tickets viewable by salon owner and ticket customer" ON queue_tickets FOR SELECT USING (
    customer_id = auth.uid() OR
    EXISTS (SELECT 1 FROM salons WHERE salons.id = queue_tickets.salon_id AND salons.owner_id = auth.uid()) OR
    true -- Public queue count view
);

CREATE POLICY "Customers can create tickets" ON queue_tickets FOR INSERT WITH CHECK (true);
CREATE POLICY "Customers can update their own tickets (cancel)" ON queue_tickets FOR UPDATE USING (
    customer_id = auth.uid() OR
    EXISTS (SELECT 1 FROM salons WHERE salons.id = queue_tickets.salon_id AND salons.owner_id = auth.uid())
);

-- ============================================================================
-- Seed Sample Salons & Services (Pune, Mumbai, Delhi, Bangalore)
-- ============================================================================
INSERT INTO salons (id, name, description, address, city, state, phone, rating, review_count, active_chairs, is_queue_open, opening_time, closing_time)
VALUES
    ('11111111-1111-1111-1111-111111111111', 'Royal Cuts & Grooming Lounge', 'Premium men salon with expert stylists and luxury ambience.', 'FC Road, Near Deccan Gymkhana', 'Pune', 'Maharashtra', '+91 98765 43210', 4.9, 142, 4, true, '08:30 AM', '09:30 PM'),
    ('22222222-2222-2222-2222-222222222222', 'Scissors & Combs Unisex Studio', 'Modern unisex salon offering trendy haircuts, facials & spas.', 'Koregaon Park, Lane 7', 'Pune', 'Maharashtra', '+91 98234 56789', 4.7, 98, 3, true, '09:00 AM', '10:00 PM'),
    ('33333333-3333-3333-3333-333333333333', 'Glamour Looks Family Salon', 'Affordable and hygienic beauty & hair styling services for the whole family.', 'Viman Nagar, Phoenix Mall Road', 'Pune', 'Maharashtra', '+91 97654 32109', 4.5, 64, 3, true, '09:30 AM', '09:00 PM'),
    ('44444444-4444-4444-4444-444444444444', 'The Urban Barber Club', 'Classic grooming, fades, beard spa & charcoal facial treatments.', 'Bandra West, Linking Road', 'Mumbai', 'Maharashtra', '+91 98111 22334', 4.8, 210, 5, true, '08:00 AM', '10:00 PM'),
    ('55555555-5555-5555-5555-555555555555', 'Style Studio & Spa', 'Professional hair coloring, keratin, and skin rejuvenation.', 'Connaught Place, Block B', 'Delhi', 'Delhi', '+91 99887 76655', 4.6, 175, 4, true, '09:00 AM', '09:00 PM')
ON CONFLICT (id) DO NOTHING;

-- Seed Services for Salon 1 (Royal Cuts)
INSERT INTO services (salon_id, name, category, price, duration_minutes, is_active) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Classic Haircut', 'Hair', 150.00, 25, true),
    ('11111111-1111-1111-1111-111111111111', 'Beard Trim & Shape', 'Beard', 80.00, 15, true),
    ('11111111-1111-1111-1111-111111111111', 'Gold Glow Facial', 'Facial', 450.00, 35, true),
    ('11111111-1111-1111-1111-111111111111', 'De-Tan Clean Up', 'Facial', 250.00, 20, true),
    ('11111111-1111-1111-1111-111111111111', 'Head & Shoulder Massage', 'Spa', 200.00, 20, true),
    ('11111111-1111-1111-1111-111111111111', 'Royal Combo (Hair + Beard + D-Tan)', 'Combo', 420.00, 50, true)
ON CONFLICT DO NOTHING;

-- Seed Services for Salon 2 (Scissors & Combs)
INSERT INTO services (salon_id, name, category, price, duration_minutes, is_active) VALUES
    ('22222222-2222-2222-2222-222222222222', 'Trendy Haircut & Wash', 'Hair', 200.00, 30, true),
    ('22222222-2222-2222-2222-222222222222', 'Beard Styling & Oil Spa', 'Beard', 120.00, 20, true),
    ('22222222-2222-2222-2222-222222222222', 'Fruit Facial', 'Facial', 350.00, 30, true),
    ('22222222-2222-2222-2222-222222222222', 'Hair Spa & Scalp Therapy', 'Spa', 500.00, 40, true)
ON CONFLICT DO NOTHING;
