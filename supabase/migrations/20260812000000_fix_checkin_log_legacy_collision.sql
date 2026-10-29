-- Fix: Batch 3's migration used `CREATE TABLE IF NOT EXISTS public.
-- checkin_log`, not knowing a table of that exact name already existed as
-- a pre-existing legacy table (confirmed empty, 0 rows — safe to leave
-- untouched). IF NOT EXISTS silently skipped table creation, but the rest
-- of that migration (ENABLE ROW LEVEL SECURITY, CREATE POLICY) still ran
-- against the legacy table, since it matched the name. This undoes that,
-- and creates the originally-intended table under a new name that can't
-- collide with anything.

-- ============================================================================
-- 1. Undo the mistaken RLS changes on the legacy checkin_log table
-- ============================================================================
-- Only the two policies Batch 3 actually added are dropped. RLS
-- enablement itself is left exactly as it was — there's no way to
-- determine what its pre-Batch-3 state was, and leaving it alone is the
-- safer default when unsure, per instructions. (The staff-read policy
-- added to arrival_cards in the same migration was correct and unrelated
-- to this table-name collision — not touched here.)

DROP POLICY IF EXISTS "Staff can view checkin log" ON public.checkin_log;
DROP POLICY IF EXISTS "Staff can insert checkin log" ON public.checkin_log;

-- ============================================================================
-- 2. Create the originally-intended table under a collision-free name
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.admin_checkin_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  arrival_card_id uuid NOT NULL REFERENCES public.arrival_cards(id),
  checked_in_by uuid NOT NULL REFERENCES auth.users(id),
  port_id integer REFERENCES public.arrival_port(port_id),
  checked_in_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_checkin_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff can view checkin log" ON public.admin_checkin_log;
CREATE POLICY "Staff can view checkin log" ON public.admin_checkin_log
  FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  );

DROP POLICY IF EXISTS "Staff can insert checkin log" ON public.admin_checkin_log;
CREATE POLICY "Staff can insert checkin log" ON public.admin_checkin_log
  FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  );
