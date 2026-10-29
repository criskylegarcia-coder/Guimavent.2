-- Spatial Location Database upgrade — Part 1: PostGIS on venue + nearby_activities RPC
--
-- Scope:
--   1. Enable the postgis extension.
--   2. Add venue.location (geography Point, 4326) alongside the existing
--      latitude/longitude columns — those are NOT removed, both stay in sync.
--   3. Backfill location for existing rows from latitude/longitude.
--   4. Trigger: keep location in sync automatically whenever latitude/
--      longitude change on INSERT/UPDATE, so the app keeps writing plain
--      lat/lng and never needs to know PostGIS exists.
--   5. GIST spatial index on venue.location.
--   6. nearby_activities(p_activity_id, p_radius_meters, p_max_results) RPC:
--      given a sub_activity, returns other sub_activity rows (joined to
--      venue + event for display) within radius, nearest first.
--
-- Assumption worth double-checking before applying: sub_activity.start_time
-- and end_time are assumed to be `timestamp without time zone` — inferred
-- from live sample rows returning offset-less ISO strings like
-- "2026-05-16T08:00:00". If the Table Editor shows a different type
-- (e.g. timestamptz), adjust the RETURNS TABLE types in nearby_activities
-- below to match before running.
--
-- Explicitly NOT touched: every other table/column on venue, sub_activity,
-- event stays as-is; no RLS policy changes on those tables (see note in
-- section 6 on why none are needed).

-- ============================================================================
-- 1. Enable PostGIS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================================
-- 2. venue.location — geography column alongside latitude/longitude
-- ============================================================================

ALTER TABLE public.venue
  ADD COLUMN IF NOT EXISTS location geography(Point, 4326);

-- ============================================================================
-- 3. Backfill location from existing latitude/longitude
-- ============================================================================

UPDATE public.venue
SET location = ST_SetSRID(
  ST_MakePoint(longitude::double precision, latitude::double precision),
  4326
)::geography
WHERE latitude IS NOT NULL
  AND longitude IS NOT NULL
  AND location IS NULL;

-- ============================================================================
-- 4. Trigger — keep location in sync with latitude/longitude going forward
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sync_venue_location()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.location := ST_SetSRID(
      ST_MakePoint(NEW.longitude::double precision, NEW.latitude::double precision),
      4326
    )::geography;
  ELSE
    NEW.location := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS venue_sync_location ON public.venue;
CREATE TRIGGER venue_sync_location
  BEFORE INSERT OR UPDATE OF latitude, longitude ON public.venue
  FOR EACH ROW EXECUTE FUNCTION public.sync_venue_location();

-- ============================================================================
-- 5. Spatial index
-- ============================================================================

CREATE INDEX IF NOT EXISTS venue_location_gist_idx
  ON public.venue USING GIST (location);

-- ============================================================================
-- 6. nearby_activities RPC
-- ============================================================================
-- SECURITY INVOKER (the default — no SECURITY DEFINER clause below) is
-- deliberate, not an oversight: venue, sub_activity, and event are already
-- readable by the anon/authenticated roles directly (confirmed live — the
-- app's existing repositories query them straight over PostgREST with the
-- anon key, no auth required). Since the calling role can already read
-- every row this function touches, running as SECURITY DEFINER would only
-- add an unnecessary privilege escalation with no functional benefit, so
-- it's deliberately left out.

CREATE OR REPLACE FUNCTION public.nearby_activities(
  p_activity_id integer,
  p_radius_meters double precision DEFAULT 1000,
  p_max_results integer DEFAULT 10
)
RETURNS TABLE (
  subactivity_id integer,
  activity_name varchar,
  description text,
  start_time timestamp,
  end_time timestamp,
  event_id integer,
  event_name varchar,
  venue_id integer,
  venue_name varchar,
  distance_meters double precision
)
LANGUAGE sql
STABLE
AS $$
  WITH origin AS (
    SELECT v.location
    FROM public.sub_activity sa
    JOIN public.venue v ON v.venue_id = sa.venue_id
    WHERE sa.subactivity_id = p_activity_id
  )
  SELECT
    sa.subactivity_id,
    sa.activity_name,
    sa.description,
    sa.start_time,
    sa.end_time,
    e.event_id,
    e.event_name,
    v.venue_id,
    v.venue_name,
    ST_Distance(v.location, origin.location) AS distance_meters
  FROM public.sub_activity sa
  JOIN public.venue v ON v.venue_id = sa.venue_id
  JOIN public.event e ON e.event_id = sa.event_id
  CROSS JOIN origin
  WHERE sa.subactivity_id <> p_activity_id
    AND v.location IS NOT NULL
    AND ST_DWithin(v.location, origin.location, p_radius_meters)
  ORDER BY distance_meters ASC
  LIMIT p_max_results;
$$;

-- Explicit grants (Postgres grants EXECUTE on new functions to PUBLIC by
-- default, so this is likely redundant — but stated explicitly so intent
-- doesn't silently depend on that default).
GRANT EXECUTE ON FUNCTION public.nearby_activities(integer, double precision, integer)
  TO anon, authenticated;
