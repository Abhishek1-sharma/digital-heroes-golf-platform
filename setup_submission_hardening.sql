-- ============================================================
-- SUBMISSION HARDENING
-- Run after all existing migrations in Supabase SQL Editor.
-- This removes public raw score/profile access and centralizes payout accounting.
-- ============================================================

ALTER TABLE public.draw_entries
  ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;

ALTER TABLE public.winner_proofs
  ADD COLUMN IF NOT EXISTS review_note TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS file_path TEXT;

-- Do not expose raw profiles or scores to anonymous visitors.
DROP POLICY IF EXISTS "Public profiles are visible for leaderboard" ON public.profiles;
DROP POLICY IF EXISTS "Public scores are visible for leaderboard" ON public.scores;

-- Safe public leaderboard projection: names, impact, and aggregate scores only.
CREATE OR REPLACE VIEW public.leaderboard AS
SELECT
  p.id,
  COALESCE(NULLIF(p.full_name, ''), 'Anonymous Player') AS full_name,
  COALESCE(p.total_impact, 0) AS total_impact,
  COUNT(s.id)::INTEGER AS rounds_count,
  ROUND(AVG(s.stableford_points)::NUMERIC, 1) AS average_points
FROM public.profiles p
JOIN public.scores s ON s.user_id = p.id
GROUP BY p.id, p.full_name, p.total_impact;

GRANT SELECT ON public.leaderboard TO anon, authenticated;

-- Users may submit/view their own proof, but only admins can review it.
DROP POLICY IF EXISTS "Users can update their own proofs" ON public.winner_proofs;
DROP POLICY IF EXISTS "Users can view their own proofs" ON public.winner_proofs;
DROP POLICY IF EXISTS "Users can insert their own proofs" ON public.winner_proofs;
DROP POLICY IF EXISTS "Admins can manage proofs" ON public.winner_proofs;
CREATE POLICY "Users can view their own proofs" ON public.winner_proofs
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own proofs" ON public.winner_proofs
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can manage proofs" ON public.winner_proofs
  FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- Users can read their entries, but winner status and payouts are admin-owned.
DROP POLICY IF EXISTS "Users can update their entry status" ON public.draw_entries;

CREATE OR REPLACE FUNCTION public.mark_winner_paid(p_user_id UUID, p_draw_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  payout NUMERIC(10,2);
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Only administrators can mark payouts as paid';
  END IF;

  SELECT prize_amount INTO payout
  FROM public.draw_entries
  WHERE user_id = p_user_id AND draw_id = p_draw_id;

  UPDATE public.draw_entries
  SET winner_status = 'paid', paid_at = now()
  WHERE user_id = p_user_id AND draw_id = p_draw_id;

  UPDATE public.profiles
  SET lifetime_winnings = COALESCE(lifetime_winnings, 0) + COALESCE(payout, 0)
  WHERE id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_winner_paid(UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_winner_proof(p_draw_id UUID, p_file_path TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;

  INSERT INTO public.winner_proofs (user_id, draw_id, file_path, file_url, status)
  VALUES (auth.uid(), p_draw_id, p_file_path, p_file_path, 'pending')
  ON CONFLICT (user_id, draw_id) DO UPDATE SET
    file_path = EXCLUDED.file_path,
    file_url = EXCLUDED.file_url,
    status = 'pending',
    review_note = NULL,
    reviewed_at = NULL;

  UPDATE public.draw_entries
  SET winner_status = 'pending_verification'
  WHERE user_id = auth.uid()
    AND draw_id = p_draw_id
    AND winner_status IN ('pending', 'rejected');
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_winner_proof(UUID, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
