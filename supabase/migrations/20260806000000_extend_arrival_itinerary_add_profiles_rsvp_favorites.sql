-- Batch A: Supabase schema migration for GuimaVent
--
-- Scope:
--   1. Extend arrival_cards with the remaining Pre-Arrival Registration
--      fields (it's currently much thinner than the app's Registration model).
--   2. Extend itinerary_items with a nullable link to sub_activity, so
--      "My Schedule" entries can point at a specific activity, not just an
--      event.
--   3. Create profiles, properly linked to auth.users (tourist_profile is
--      NOT this — it's linked to a separate legacy public.users table and is
--      left untouched, per instructions).
--   4. Create rsvp (event RSVPs) and favorites (generalized event/activity
--      favorites) — neither existed before.
--
-- Explicitly NOT touched: event, sub_activity, venue, municipality,
-- arrival_port (existing public-SELECT reference tables), and the deprecated
-- leftovers (tourist_profile, public.users, arrival_card, arrival_card_interest,
-- checkin_log, entry_port, interest, itinerary, users).
--
-- Assumption worth double-checking before applying: event.event_id and
-- sub_activity.subactivity_id are assumed to be `integer` — inferred from
-- live sample rows returning small plain-integer values (e.g. event_id: 10,
-- subactivity_id: 14), not uuid-shaped values. If the Table Editor shows
-- these as bigint instead, swap `integer` for `bigint` below before running.

-- ============================================================================
-- 1. Extend arrival_cards (Pre-Arrival Registration)
-- ============================================================================
-- Existing columns are left exactly as-is: id, user_id, full_name, age, sex,
-- duration, municipality, created_at.

ALTER TABLE public.arrival_cards
  ADD COLUMN IF NOT EXISTS nationality varchar,
  ADD COLUMN IF NOT EXISTS date_of_birth date,
  ADD COLUMN IF NOT EXISTS email varchar,
  ADD COLUMN IF NOT EXISTS mobile_number varchar,
  ADD COLUMN IF NOT EXISTS date_of_arrival date,
  ADD COLUMN IF NOT EXISTS port_of_entry varchar,
  ADD COLUMN IF NOT EXISTS date_of_departure date,
  ADD COLUMN IF NOT EXISTS traveling_with varchar,
  ADD COLUMN IF NOT EXISTS purpose_of_visit varchar,
  ADD COLUMN IF NOT EXISTS municipalities_to_visit text[],
  ADD COLUMN IF NOT EXISTS pass_code varchar,
  ADD COLUMN IF NOT EXISTS valid_from date,
  ADD COLUMN IF NOT EXISTS valid_to date;

-- Unique constraint on pass_code (multiple NULLs are fine in Postgres, so
-- this doesn't block rows that haven't generated a pass yet). Wrapped in a
-- existence check since Postgres has no ADD CONSTRAINT IF NOT EXISTS.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'arrival_cards_pass_code_key'
  ) THEN
    ALTER TABLE public.arrival_cards
      ADD CONSTRAINT arrival_cards_pass_code_key UNIQUE (pass_code);
  END IF;
END $$;

-- No RLS changes needed here — the existing "authenticated, own rows only"
-- policies on arrival_cards apply at the row level and automatically cover
-- the new columns.

-- ============================================================================
-- 2. Extend itinerary_items (My Schedule)
-- ============================================================================
-- Existing columns are left exactly as-is: id, user_id, event_id, title,
-- venue, event_date, created_at.

ALTER TABLE public.itinerary_items
  ADD COLUMN IF NOT EXISTS subactivity_id integer
    REFERENCES public.sub_activity(subactivity_id) ON DELETE SET NULL;

-- No RLS changes needed here either, for the same reason as above.

-- ============================================================================
-- 3. profiles — a real profile table linked to auth.users
-- ============================================================================
-- Deliberately separate from the deprecated tourist_profile table (which is
-- keyed to a legacy public.users table, not Supabase Auth).

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name varchar,
  email varchar,
  mobile_number varchar,
  avatar_url varchar,
  is_verified boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Auto-create a profiles row whenever a new auth.users row is created
-- (i.e. on sign-up). Pulls full_name from signup metadata if the client
-- passed it (e.g. via `data: {'full_name': ...}` on signUp()); falls back
-- to an empty string otherwise, since register_screen.dart doesn't
-- currently send that metadata.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.email, '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- 4. rsvp — events the user has RSVP'd to
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.rsvp (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_id integer NOT NULL REFERENCES public.event(event_id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, event_id)
);

ALTER TABLE public.rsvp ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own rsvps" ON public.rsvp;
CREATE POLICY "Users can view own rsvps" ON public.rsvp
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own rsvps" ON public.rsvp;
CREATE POLICY "Users can insert own rsvps" ON public.rsvp
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own rsvps" ON public.rsvp;
CREATE POLICY "Users can delete own rsvps" ON public.rsvp
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- 5. favorites — generalized favorites for both events and activities
-- ============================================================================
-- target_id is stored as text (not a real FK) since it needs to point at
-- either event.event_id or sub_activity.subactivity_id, which can't both be
-- foreign-keyed from one column. Cast target_id on query as needed.

CREATE TABLE IF NOT EXISTS public.favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_type varchar NOT NULL CHECK (target_type IN ('event', 'activity')),
  target_id varchar NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, target_type, target_id)
);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own favorites" ON public.favorites;
CREATE POLICY "Users can view own favorites" ON public.favorites
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own favorites" ON public.favorites;
CREATE POLICY "Users can insert own favorites" ON public.favorites
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own favorites" ON public.favorites;
CREATE POLICY "Users can delete own favorites" ON public.favorites
  FOR DELETE
  USING (auth.uid() = user_id);
