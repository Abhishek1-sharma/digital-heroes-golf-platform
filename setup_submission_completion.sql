-- FINAL SUBMISSION HARDENING
-- Run this AFTER the existing setup_*.sql scripts. It centralises score writes
-- and draw execution in trusted Postgres functions.

CREATE TABLE IF NOT EXISTS public.platform_settings (
  id BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id),
  prize_pool_percentage NUMERIC(5,2) NOT NULL DEFAULT 50 CHECK (prize_pool_percentage BETWEEN 0 AND 100),
  five_match_percentage NUMERIC(5,2) NOT NULL DEFAULT 40 CHECK (five_match_percentage BETWEEN 0 AND 100),
  four_match_percentage NUMERIC(5,2) NOT NULL DEFAULT 35 CHECK (four_match_percentage BETWEEN 0 AND 100),
  three_match_percentage NUMERIC(5,2) NOT NULL DEFAULT 25 CHECK (three_match_percentage BETWEEN 0 AND 100),
  CONSTRAINT prize_tiers_total CHECK (five_match_percentage + four_match_percentage + three_match_percentage = 100)
);
INSERT INTO public.platform_settings (id) VALUES (TRUE) ON CONFLICT (id) DO NOTHING;
ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users can read platform settings" ON public.platform_settings;
CREATE POLICY "Authenticated users can read platform settings" ON public.platform_settings
  FOR SELECT TO authenticated USING (TRUE);
DROP POLICY IF EXISTS "Admins can update platform settings" ON public.platform_settings;
CREATE POLICY "Admins can update platform settings" ON public.platform_settings
  FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

UPDATE public.subscriptions SET status = 'inactive', renewal_date = NULL WHERE plan_type = 'free';
UPDATE public.profiles SET subscription_status = 'inactive' WHERE subscription_tier = 'free';

-- Scores are written only through these functions so a user cannot bypass the
-- active-subscription, unique-date, or rolling-five rules with a raw API call.
DROP POLICY IF EXISTS "Users can insert their own scores" ON public.scores;
DROP POLICY IF EXISTS "Users can update their own scores" ON public.scores;
DROP POLICY IF EXISTS "Users can delete their own scores" ON public.scores;

CREATE OR REPLACE FUNCTION public.save_my_score(
  p_course_name TEXT, p_date DATE, p_stableford_points INTEGER, p_score_id UUID DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE saved_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF p_course_name IS NULL OR length(trim(p_course_name)) < 2 THEN RAISE EXCEPTION 'Course name must contain at least two characters'; END IF;
  IF p_date IS NULL OR p_stableford_points NOT BETWEEN 1 AND 45 THEN RAISE EXCEPTION 'Invalid score data'; END IF;
  IF NOT EXISTS (SELECT 1 FROM subscriptions WHERE user_id = auth.uid() AND status = 'active' AND plan_type IN ('monthly','yearly')) THEN
    RAISE EXCEPTION 'An active subscription is required to save scores';
  END IF;
  IF p_score_id IS NOT NULL THEN
    UPDATE scores SET course_name = trim(p_course_name), date = p_date, stableford_points = p_stableford_points
    WHERE id = p_score_id AND user_id = auth.uid() RETURNING id INTO saved_id;
    IF saved_id IS NULL THEN RAISE EXCEPTION 'Score not found'; END IF;
    RETURN saved_id;
  END IF;
  DELETE FROM scores WHERE id IN (
    SELECT id FROM scores WHERE user_id = auth.uid() ORDER BY date ASC, created_at ASC OFFSET 4
  );
  INSERT INTO scores (user_id, course_name, date, stableford_points)
  VALUES (auth.uid(), trim(p_course_name), p_date, p_stableford_points) RETURNING id INTO saved_id;
  RETURN saved_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.save_my_score(TEXT, DATE, INTEGER, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.delete_my_score(p_score_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  DELETE FROM scores WHERE id = p_score_id AND user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Score not found'; END IF;
END; $$;
GRANT EXECUTE ON FUNCTION public.delete_my_score(UUID) TO authenticated;

-- Draws are calculated and saved in a single server transaction. The client
-- receives a preview from simulate_draw but cannot submit prize amounts or entries.
CREATE OR REPLACE FUNCTION public.run_draw(
  p_mode TEXT, p_winning_numbers INTEGER[] DEFAULT NULL, p_publish BOOLEAN DEFAULT FALSE
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_numbers INTEGER[]; v_pool NUMERIC(10,2); v_rollover NUMERIC(10,2); v_total NUMERIC(10,2);
  v_five NUMERIC; v_four NUMERIC; v_three NUMERIC; v_new_rollover NUMERIC(10,2); v_draw_id UUID;
  v_entries JSONB; v_winners JSONB; v_month TEXT := to_char(now(), 'YYYY-MM'); v_settings platform_settings%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Only administrators can run draws'; END IF;
  IF p_mode NOT IN ('random','algorithmic') THEN RAISE EXCEPTION 'Invalid draw mode'; END IF;
  SELECT * INTO v_settings FROM platform_settings WHERE id = TRUE;
  IF p_winning_numbers IS NOT NULL THEN
    IF cardinality(p_winning_numbers) <> 5 OR (SELECT count(DISTINCT n) FROM unnest(p_winning_numbers) n) <> 5
       OR EXISTS (SELECT 1 FROM unnest(p_winning_numbers) n WHERE n NOT BETWEEN 1 AND 45) THEN RAISE EXCEPTION 'Five unique numbers between 1 and 45 are required'; END IF;
    v_numbers := p_winning_numbers;
  ELSIF p_mode = 'random' THEN
    SELECT array_agg(n) INTO v_numbers FROM (SELECT n FROM generate_series(1,45) n ORDER BY random() LIMIT 5) x;
  ELSE
    SELECT array_agg(stableford_points) INTO v_numbers FROM (
      SELECT stableford_points FROM scores GROUP BY stableford_points ORDER BY count(*) DESC, stableford_points DESC LIMIT 5
    ) x;
    IF cardinality(v_numbers) < 5 THEN SELECT array_agg(n) INTO v_numbers FROM (SELECT n FROM generate_series(1,45) n ORDER BY random() LIMIT 5) x; END IF;
  END IF;
  SELECT COALESCE(sum(CASE WHEN plan_type = 'yearly' THEN amount / 12 ELSE amount END), 0) * v_settings.prize_pool_percentage / 100 INTO v_pool
  FROM subscriptions WHERE status = 'active' AND plan_type IN ('monthly','yearly');
  SELECT COALESCE(jackpot_rollover_amount, 0) INTO v_rollover FROM draws WHERE status = 'published' ORDER BY published_at DESC NULLS LAST, created_at DESC LIMIT 1;
  v_total := round(v_pool + v_rollover, 2); v_five := v_total * v_settings.five_match_percentage / 100; v_four := v_total * v_settings.four_match_percentage / 100; v_three := v_total * v_settings.three_match_percentage / 100;
  WITH eligible AS (
    SELECT s.user_id, array_agg(s.stableford_points ORDER BY s.date DESC, s.created_at DESC) AS nums
    FROM scores s JOIN subscriptions sub ON sub.user_id = s.user_id AND sub.status = 'active' AND sub.plan_type IN ('monthly','yearly') GROUP BY s.user_id HAVING count(*) = 5
  ), prepared AS (
    SELECT user_id, nums, (SELECT count(DISTINCT n) FROM unnest(nums) n WHERE n = ANY(v_numbers)) AS matches FROM eligible
  ) SELECT COALESCE(jsonb_agg(jsonb_build_object('user_id',user_id,'entry_numbers',nums,'match_count',matches)), '[]'::jsonb) INTO v_entries FROM prepared;
  WITH data AS (SELECT * FROM jsonb_to_recordset(v_entries) AS x(user_id UUID, entry_numbers INTEGER[], match_count INTEGER)), counts AS (SELECT match_count, count(*) count FROM data WHERE match_count IN (3,4,5) GROUP BY match_count)
  SELECT COALESCE(jsonb_agg(jsonb_build_object('user_id',d.user_id,'prize_amount',round(CASE d.match_count WHEN 5 THEN v_five / c.count WHEN 4 THEN v_four / c.count ELSE v_three / c.count END,2),'match_count',d.match_count)), '[]'::jsonb)
  INTO v_winners FROM data d JOIN counts c USING (match_count) WHERE d.match_count IN (3,4,5);
  v_new_rollover := CASE WHEN NOT EXISTS (SELECT 1 FROM jsonb_to_recordset(v_entries) AS x(match_count INTEGER) WHERE match_count = 5) THEN v_five ELSE 0 END;
  IF p_publish THEN
    IF EXISTS (SELECT 1 FROM draws WHERE draw_month = v_month AND status = 'published') THEN RAISE EXCEPTION 'A draw has already been published for this month'; END IF;
    INSERT INTO draws (draw_month, draw_year, draw_mode, winning_numbers, prize_pool, jackpot_rollover_amount, status, winners, published_at)
    VALUES (v_month, to_char(now(),'YYYY'), p_mode, v_numbers, v_total, v_new_rollover, 'published', v_winners, now()) RETURNING id INTO v_draw_id;
    INSERT INTO draw_entries (draw_id,user_id,entry_numbers,match_count,prize_amount,winner_status)
    SELECT v_draw_id, e.user_id, e.entry_numbers, e.match_count, COALESCE((w->>'prize_amount')::NUMERIC,0), CASE WHEN e.match_count IN (3,4,5) THEN 'pending' ELSE 'none' END
    FROM jsonb_to_recordset(v_entries) AS e(user_id UUID,entry_numbers INTEGER[],match_count INTEGER)
    LEFT JOIN LATERAL (SELECT w FROM jsonb_array_elements(v_winners) w WHERE (w->>'user_id')::UUID = e.user_id) winner ON TRUE;
  END IF;
  RETURN jsonb_build_object('draw_id',v_draw_id,'winningNumbers',v_numbers,'currentPool',v_pool,'rollover',v_rollover,'totalPool',v_total,'newRollover',v_new_rollover,'participantsCount',jsonb_array_length(v_entries),'eligibleCount',jsonb_array_length(v_entries),'winners',v_winners,'allEntries',v_entries);
END; $$;
GRANT EXECUTE ON FUNCTION public.run_draw(TEXT, INTEGER[], BOOLEAN) TO authenticated;

-- Subscription contribution ledger. Call this from the Stripe webhook after a
-- successful payment; the unique period key prevents duplicate accounting.
ALTER TABLE public.donations ADD COLUMN IF NOT EXISTS source_period TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS donations_subscription_period_unique ON public.donations(subscription_id, source_period) WHERE donation_type = 'subscription_share';

CREATE OR REPLACE FUNCTION public.record_subscription_contribution()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE contribution NUMERIC(10,2); period_key TEXT;
BEGIN
  IF NEW.status <> 'active' OR NEW.plan_type NOT IN ('monthly', 'yearly') OR NEW.charity_id IS NULL THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = 'active' AND OLD.renewal_date IS NOT DISTINCT FROM NEW.renewal_date THEN RETURN NEW; END IF;
  contribution := round(COALESCE(NEW.amount, 0) * COALESCE(NEW.charity_percentage, 10) / 100, 2);
  IF contribution <= 0 THEN RETURN NEW; END IF;
  period_key := to_char(COALESCE(NEW.start_date, now()), 'YYYY-MM') || ':' || COALESCE(NEW.stripe_subscription_id, NEW.id::TEXT);
  INSERT INTO donations (user_id, charity_id, subscription_id, amount, donation_type, status, source_period)
  VALUES (NEW.user_id, NEW.charity_id, NEW.id, contribution, 'subscription_share', 'completed', period_key)
  ON CONFLICT (subscription_id, source_period) WHERE donation_type = 'subscription_share' DO NOTHING;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS record_subscription_contribution ON public.subscriptions;
CREATE TRIGGER record_subscription_contribution AFTER INSERT OR UPDATE OF status, renewal_date ON public.subscriptions
FOR EACH ROW EXECUTE FUNCTION public.record_subscription_contribution();
NOTIFY pgrst, 'reload schema';
