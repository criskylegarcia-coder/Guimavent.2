-- Fix: legacy int-typed user-reference columns (registered_by_user_id,
-- created_by_user_id) reference the old pre-Auth `users` table, not
-- auth.users — there's no valid uuid-to-int mapping the app can supply for
-- them. Both were flagged as an assumption to verify back in Batch 1/2
-- (see admin_event_repository.dart / admin_venue_repository.dart), and
-- venue creation has now confirmed the failure live:
--
--   PostgrestException: null value in column "registered_by_user_id"
--   violates not-null constraint (code 23502)
--
-- event.created_by_user_id could not be confirmed the same way — no schema
-- introspection access via the anon key (information_schema isn't exposed
-- through PostgREST) and no staff account to test a real insert with.
-- Included anyway: DROP NOT NULL is a safe no-op on a column that's
-- already nullable, so there's no risk in covering it defensively rather
-- than waiting for event creation to fail the same way live.
--
-- sub_activity was checked directly (a live row was fetched in full) and
-- has no equivalent legacy user-reference column at all — nothing to fix
-- there for Batch 3.
--
-- Only the NOT NULL constraint is dropped — the columns, their FKs to the
-- legacy `users` table, and any existing historical values are untouched,
-- per instructions.

ALTER TABLE public.venue
  ALTER COLUMN registered_by_user_id DROP NOT NULL;

ALTER TABLE public.event
  ALTER COLUMN created_by_user_id DROP NOT NULL;
