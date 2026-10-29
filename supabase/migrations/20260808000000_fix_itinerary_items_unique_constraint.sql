-- Fix itinerary_items' uniqueness constraint: it's still keyed on
-- (user_id, event_id), a leftover from before subactivity_id existed, when
-- one itinerary_items row represented one whole event. Rows now represent
-- individual activities within an event (via subactivity_id), so the old
-- constraint incorrectly blocks adding a second activity from the same
-- event to My Schedule — confirmed live via "+ Add to Itinerary" failing
-- with: duplicate key value violates unique constraint
-- "itinerary_items_user_id_event_id_key" (23505).
--
-- subactivity_id is nullable (see the Batch A migration:
-- `subactivity_id integer REFERENCES public.sub_activity(subactivity_id)
-- ON DELETE SET NULL` — no NOT NULL, and ON DELETE SET NULL requires
-- nullability anyway). Postgres treats multiple NULLs as distinct under a
-- UNIQUE constraint by default, so rows with no linked sub_activity (the
-- legacy/unresolvable rows the mapper already skips per the previous fix)
-- won't collide with each other or block anything.

-- ============================================================================
-- 1. Drop the incorrect (user_id, event_id) constraint
-- ============================================================================

ALTER TABLE public.itinerary_items
  DROP CONSTRAINT IF EXISTS itinerary_items_user_id_event_id_key;

-- ============================================================================
-- 2. Add the correct (user_id, subactivity_id) constraint
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'itinerary_items_user_id_subactivity_id_key'
  ) THEN
    ALTER TABLE public.itinerary_items
      ADD CONSTRAINT itinerary_items_user_id_subactivity_id_key
      UNIQUE (user_id, subactivity_id);
  END IF;
END $$;

-- ============================================================================
-- 3. isScheduled(activityId) in SupabaseItineraryRepository — no code change
--    needed. It already queries by (user_id, subactivity_id):
--
--      .eq('user_id', userId).eq('subactivity_id', subactivityId)
--
--    which matches this new constraint's shape exactly — it was written
--    assuming per-activity uniqueness even though the database itself
--    still had the old per-event constraint until this migration runs.
-- ============================================================================
