-- ============================================================================
-- Atomic Queue Token Allocation & Secure Joining Migration
-- Date: 2026-08-21
-- Purpose:
--   1. Enforce atomic, race-condition-free token generation per salon using row-level locking.
--   2. Validate active salon, open queue, authenticated customer, and matching auth.uid().
--   3. Allow salon owner to generate walk-in queue tickets.
--   4. Prevent duplicate active tickets (WAITING/IN_CHAIR) for same customer at same salon.
--   5. Maintain compatibility with existing public.queue_tickets schema and realtime events.
-- ============================================================================

-- 1. Create unique partial index to guarantee single active ticket per customer per salon
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_ticket_per_customer 
ON public.queue_tickets(salon_id, customer_id) 
WHERE status IN ('WAITING', 'IN_CHAIR') AND customer_id IS NOT NULL;

-- 2. Create RPC Function for atomic token generation and ticket insertion
CREATE OR REPLACE FUNCTION public.join_queue_atomic(
    p_salon_id UUID,
    p_customer_id UUID DEFAULT NULL,
    p_customer_name TEXT DEFAULT 'Valued Customer',
    p_customer_phone TEXT DEFAULT NULL,
    p_service_names TEXT[] DEFAULT '{}',
    p_total_price NUMERIC DEFAULT 0.00,
    p_total_duration_minutes INT DEFAULT 20,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_salon record;
    v_calling_user_id UUID;
    v_is_salon_owner BOOLEAN := false;
    v_next_token INT;
    v_new_ticket public.queue_tickets;
    v_active_ticket_count INT;
    v_target_customer_id UUID;
BEGIN
    -- 1. Identify caller (must be authenticated)
    v_calling_user_id := auth.uid();
    IF v_calling_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to join queue.' USING ERRCODE = '42501';
    END IF;

    -- 2. Lock salon row with FOR UPDATE to eliminate concurrent token race conditions
    SELECT id, owner_id, is_active, is_queue_open, is_published
    INTO v_salon
    FROM public.salons
    WHERE id = p_salon_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Salon not found.' USING ERRCODE = 'P0002';
    END IF;

    -- 3. Check salon status & queue open
    IF NOT COALESCE(v_salon.is_active, true) THEN
        RAISE EXCEPTION 'Salon is currently inactive.' USING ERRCODE = '22023';
    END IF;

    IF NOT COALESCE(v_salon.is_queue_open, true) THEN
        RAISE EXCEPTION 'Queue is currently closed for this salon.' USING ERRCODE = '22023';
    END IF;

    -- 4. Check whether caller is the salon owner (e.g. creating a walk-in ticket) or customer
    IF v_salon.owner_id = v_calling_user_id THEN
        v_is_salon_owner := true;
    END IF;

    -- 5. Customer authorization check
    IF v_is_salon_owner THEN
        v_target_customer_id := p_customer_id;
    ELSE
        -- Customer joining: customer_id must match authenticated user
        IF p_customer_id IS NOT NULL AND p_customer_id <> v_calling_user_id THEN
            RAISE EXCEPTION 'Customer ID must match authenticated user.' USING ERRCODE = '42501';
        END IF;
        v_target_customer_id := v_calling_user_id;
    END IF;

    -- 6. Prevent duplicate active tickets (WAITING / IN_CHAIR) for the same customer at this salon
    IF v_target_customer_id IS NOT NULL THEN
        SELECT COUNT(*)
        INTO v_active_ticket_count
        FROM public.queue_tickets
        WHERE salon_id = p_salon_id
          AND customer_id = v_target_customer_id
          AND status IN ('WAITING', 'IN_CHAIR');

        IF v_active_ticket_count > 0 THEN
            RAISE EXCEPTION 'Customer already has an active ticket at this salon.' USING ERRCODE = '23505';
        END IF;
    END IF;

    -- 7. Atomically calculate next token number for this salon (scoped to today)
    SELECT COALESCE(MAX(token_number), 0) + 1
    INTO v_next_token
    FROM public.queue_tickets
    WHERE salon_id = p_salon_id
      AND created_at >= date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata');

    IF v_next_token IS NULL OR v_next_token < 1 THEN
        v_next_token := 1;
    END IF;

    -- 8. Insert the queue ticket
    INSERT INTO public.queue_tickets (
        salon_id,
        customer_id,
        customer_name,
        customer_phone,
        service_names,
        total_price,
        total_duration_minutes,
        token_number,
        status,
        notes,
        created_at
    ) VALUES (
        p_salon_id,
        v_target_customer_id,
        COALESCE(NULLIF(TRIM(p_customer_name), ''), 'Valued Customer'),
        p_customer_phone,
        COALESCE(p_service_names, '{}'),
        COALESCE(p_total_price, 0.00),
        COALESCE(NULLIF(p_total_duration_minutes, 0), 20),
        v_next_token,
        'WAITING',
        p_notes,
        now()
    )
    RETURNING * INTO v_new_ticket;

    RETURN to_jsonb(v_new_ticket);
END;
$$;

-- 3. Grant execute permission on the atomic function
GRANT EXECUTE ON FUNCTION public.join_queue_atomic(
    UUID, UUID, TEXT, TEXT, TEXT[], NUMERIC, INT, TEXT
) TO authenticated, service_role;

-- 4. Defensive Trigger: If a direct INSERT is performed, ensure token_number is never null or zero
CREATE OR REPLACE FUNCTION public.trg_assign_queue_token()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NEW.token_number IS NULL OR NEW.token_number <= 0 THEN
        SELECT COALESCE(MAX(token_number), 0) + 1
        INTO NEW.token_number
        FROM public.queue_tickets
        WHERE salon_id = NEW.salon_id
          AND created_at >= date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata');
        
        IF NEW.token_number IS NULL OR NEW.token_number < 1 THEN
            NEW.token_number := 1;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_queue_tickets_assign_token ON public.queue_tickets;
CREATE TRIGGER trg_queue_tickets_assign_token
    BEFORE INSERT ON public.queue_tickets
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_assign_queue_token();

-- 5. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
