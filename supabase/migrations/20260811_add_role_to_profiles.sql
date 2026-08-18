-- ============================================================================
-- Phase 2B: Role-based authorization
-- Adds an explicit `role` column to `profiles` so the app can enforce which
-- dashboard a user is authorized to access. The role is set at signup and
-- is immutable afterward.
-- ============================================================================

-- 1) Add role column (idempotent)
-- Drop the trigger first so the backfill UPDATE below isn't blocked.
DROP TRIGGER IF EXISTS profiles_prevent_role_change ON profiles;
DROP FUNCTION IF EXISTS prevent_role_change();

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'CUSTOMER'
  CHECK (role IN ('CUSTOMER', 'SALON_OWNER'));

-- 2) Backfill existing salon owners
-- Anyone who owns a salon is promoted to SALON_OWNER.
UPDATE profiles p
SET role = 'SALON_OWNER'
WHERE p.id IN (SELECT owner_id FROM salons);

-- 3) Prevent clients from updating the role column
-- An authenticated user can only INSERT a profile (at signup); after that
-- the role must never change.
REVOKE UPDATE (role) ON profiles FROM anon, authenticated;

-- 4) Server-side guard: role is immutable once set
CREATE OR REPLACE FUNCTION prevent_role_change()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Role cannot be changed.';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER profiles_prevent_role_change
BEFORE UPDATE ON profiles
FOR EACH ROW EXECUTE FUNCTION prevent_role_change();
