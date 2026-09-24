-- ============================================================
-- ACCESS HARDENING
-- Run after setup_submission_hardening.sql.
-- Paid Stripe wiring remains external; these functions support the local demo safely.
-- ============================================================

DROP POLICY IF EXISTS "Users can insert their own subscription" ON public.subscriptions;
DROP POLICY IF EXISTS "Users can update their own subscription" ON public.subscriptions;
DROP POLICY IF EXISTS "Service role can do everything" ON public.subscriptions;

CREATE OR REPLACE FUNCTION public.complete_onboarding(
  p_charity_id UUID,
  p_charity_percentage INTEGER,
  p_plan_type TEXT,
  p_handicap NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  plan_amount NUMERIC(10,2);
  renewal_date_value TIMESTAMPTZ;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF p_charity_percentage < 10 OR p_charity_percentage > 100 THEN RAISE EXCEPTION 'Charity percentage must be between 10 and 100'; END IF;
  IF p_plan_type NOT IN ('monthly', 'yearly', 'free') THEN RAISE EXCEPTION 'Invalid plan'; END IF;

  plan_amount := CASE p_plan_type WHEN 'monthly' THEN 25 WHEN 'yearly' THEN 240 ELSE 0 END;
  renewal_date_value := CASE p_plan_type WHEN 'monthly' THEN now() + INTERVAL '30 days' WHEN 'yearly' THEN now() + INTERVAL '365 days' ELSE NULL END;

  INSERT INTO public.subscriptions (user_id, charity_id, charity_percentage, plan_type, amount, status, start_date, renewal_date)
  VALUES (auth.uid(), p_charity_id, p_charity_percentage, p_plan_type, plan_amount, CASE WHEN p_plan_type = 'free' THEN 'inactive' ELSE 'active' END, now(), renewal_date_value)
  ON CONFLICT (user_id) DO UPDATE SET
    charity_id = EXCLUDED.charity_id,
    charity_percentage = EXCLUDED.charity_percentage,
    plan_type = EXCLUDED.plan_type,
    amount = EXCLUDED.amount,
    status = EXCLUDED.status,
    start_date = EXCLUDED.start_date,
    renewal_date = EXCLUDED.renewal_date,
    updated_at = now();

  UPDATE public.profiles
  SET onboarding_completed = TRUE,
      handicap = p_handicap,
      selected_charity_id = p_charity_id,
      subscription_status = CASE WHEN p_plan_type = 'free' THEN 'inactive' ELSE 'active' END,
      subscription_tier = p_plan_type
  WHERE id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION public.activate_demo_membership(p_plan_type TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  plan_amount NUMERIC(10,2);
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF p_plan_type NOT IN ('monthly', 'yearly') THEN RAISE EXCEPTION 'Invalid paid plan'; END IF;
  plan_amount := CASE p_plan_type WHEN 'monthly' THEN 25 ELSE 240 END;

  UPDATE public.subscriptions
  SET plan_type = p_plan_type,
      amount = plan_amount,
      status = 'active',
      start_date = now(),
      renewal_date = now() + CASE p_plan_type WHEN 'monthly' THEN INTERVAL '30 days' ELSE INTERVAL '365 days' END,
      updated_at = now()
  WHERE user_id = auth.uid();

  IF NOT FOUND THEN
    INSERT INTO public.subscriptions (user_id, plan_type, amount, status, start_date, renewal_date)
    VALUES (auth.uid(), p_plan_type, plan_amount, 'active', now(), now() + CASE p_plan_type WHEN 'monthly' THEN INTERVAL '30 days' ELSE INTERVAL '365 days' END);
  END IF;

  UPDATE public.profiles
  SET subscription_status = 'active', subscription_tier = p_plan_type
  WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_onboarding(UUID, INTEGER, TEXT, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.activate_demo_membership(TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.archive_draw(p_draw_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Only administrators can archive draws';
  END IF;
  UPDATE public.draws SET status = 'archived' WHERE id = p_draw_id AND status = 'published';
END;
$$;

GRANT EXECUTE ON FUNCTION public.archive_draw(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.prevent_role_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() = OLD.id AND NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Role changes must be performed by an administrator';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prevent_profile_role_escalation ON public.profiles;
CREATE TRIGGER prevent_profile_role_escalation
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_role_escalation();

NOTIFY pgrst, 'reload schema';
