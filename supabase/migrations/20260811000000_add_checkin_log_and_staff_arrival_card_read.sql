-- Admin Web Portal — Batch 3: QR Scanner check-in log.
--
-- Investigated first (read-only):
--   - What the tourist app's QR actually encodes: registration_success_
--     screen.dart does `QrImageView(data: passCode, ...)` — the raw
--     pass_code string only (e.g. "GV-2025-123456"), no JSON wrapper.
--     (A separate, orphaned legacy file, lib/screens/qr/qr_screen.dart,
--     encodes a completely different multi-line text block — confirmed via
--     grep that nothing imports it, so it's dead code, irrelevant here.)
--   - arrival_cards.id's type: not derivable from any accessible schema
--     introspection (information_schema isn't exposed via PostgREST), so
--     confirmed empirically instead — a type-mismatched filter
--     (?id=eq.1) returned "invalid input syntax for type uuid: \"1\"",
--     while a uuid-shaped filter passed type validation cleanly. Confirmed:
--     arrival_cards.id is uuid.
--   - arrival_port.port_id: confirmed integer directly from live sample
--     rows (port_id: 1, 2 — Jordan Wharf, Buenavista Port).
--   - arrival_cards RLS: currently "own rows only" (confirmed in the
--     Batch A migration's own comments, and empirically — the anon key
--     gets an empty result set even with no filter). This blocks staff
--     from looking up ANY tourist's arrival card by pass_code, since
--     staff aren't the row's owner — not something the task explicitly
--     asked for, but required for the scanner to function at all, so
--     it's added here too (an additional SELECT policy — Postgres ORs
--     multiple policies together, so the tourist's own-row access is
--     untouched).

-- ============================================================================
-- 1. checkin_log
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.checkin_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  arrival_card_id uuid NOT NULL REFERENCES public.arrival_cards(id),
  checked_in_by uuid NOT NULL REFERENCES auth.users(id),
  port_id integer REFERENCES public.arrival_port(port_id),
  checked_in_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.checkin_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff can view checkin log" ON public.checkin_log;
CREATE POLICY "Staff can view checkin log" ON public.checkin_log
  FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  );

DROP POLICY IF EXISTS "Staff can insert checkin log" ON public.checkin_log;
CREATE POLICY "Staff can insert checkin log" ON public.checkin_log
  FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  );

-- ============================================================================
-- 2. Staff read access on arrival_cards (see note above — required for the
--    scanner to look up a tourist's card by pass_code at all)
-- ============================================================================

DROP POLICY IF EXISTS "Staff can view all arrival cards" ON public.arrival_cards;
CREATE POLICY "Staff can view all arrival cards" ON public.arrival_cards
  FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND staff = true)
  );
