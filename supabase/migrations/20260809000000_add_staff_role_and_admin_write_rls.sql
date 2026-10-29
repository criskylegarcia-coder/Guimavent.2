-- Admin Web Portal — Batch 1: staff role + write RLS for event/sub_activity/venue.
--
-- Investigated first (read-only, via curl with the anon key, no auth):
-- POSTed an empty {} body to event, sub_activity, and venue. All three
-- returned 401 with code 42501 "new row violates row-level security policy
-- for table ...". This confirms RLS is already ENABLED on all three tables
-- with NO existing INSERT policy for anyone (not even authenticated
-- non-staff users) — they've been public-SELECT-only this whole time, as
-- expected. This migration adds the first write policies these tables have
-- ever had, scoped to staff accounts only.
--
-- Staff marking: a boolean column on the existing `profiles` table, not a
-- separate `staff_members` table. Chosen because every authenticated user
-- already gets a profiles row for free (see handle_new_user() in the Batch A
-- migration), so "is this user staff" is a single boolean check with no
-- extra join — simpler than a separate table for a binary flag with no
-- other attributes needed yet. If staff ever need role-specific data
-- (assigned municipality, permission levels, etc.), that's a reason to
-- promote this to a real table later — not needed for Batch 1.

-- ============================================================================
-- 1. profiles.staff
-- ============================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS staff boolean NOT NULL DEFAULT false;

-- Manual only for Batch 1, per instructions — no signup flow sets this.
-- To make an existing account staff:
--   UPDATE public.profiles SET staff = true WHERE id = '<their auth.users.id>';

-- ============================================================================
-- 2. Staff-only write policies on event, sub_activity, venue
-- ============================================================================
-- Existing public SELECT access on these three tables is untouched — this
-- only adds INSERT/UPDATE/DELETE, which didn't exist for anyone before.

DROP POLICY IF EXISTS "Staff can insert events" ON public.event;
CREATE POLICY "Staff can insert events" ON public.event
  FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  );

DROP POLICY IF EXISTS "Staff can update events" ON public.event;
CREATE POLICY "Staff can update events" ON public.event
  FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  );

DROP POLICY IF EXISTS "Staff can delete events" ON public.event;
CREATE POLICY "Staff can delete events" ON public.event
  FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  );

DROP POLICY IF EXISTS "Staff can insert sub_activities" ON public.sub_activity;
CREATE POLICY "Staff can insert sub_activities" ON public.sub_activity
  FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  );

DROP POLICY IF EXISTS "Staff can update sub_activities" ON public.sub_activity;
CREATE POLICY "Staff can update sub_activities" ON public.sub_activity
  FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  );

DROP POLICY IF EXISTS "Staff can delete sub_activities" ON public.sub_activity;
CREATE POLICY "Staff can delete sub_activities" ON public.sub_activity
  FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  );

DROP POLICY IF EXISTS "Staff can insert venues" ON public.venue;
CREATE POLICY "Staff can insert venues" ON public.venue
  FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  );

DROP POLICY IF EXISTS "Staff can update venues" ON public.venue;
CREATE POLICY "Staff can update venues" ON public.venue
  FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  );

DROP POLICY IF EXISTS "Staff can delete venues" ON public.venue;
CREATE POLICY "Staff can delete venues" ON public.venue
  FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  );
