-- ============================================================
-- ADMIN SCORE MANAGEMENT
-- Run this in your Supabase SQL Editor
-- ============================================================

-- Elevate permissions on the `public.scores` table for Admins

-- Create the table if setup_scores.sql has not been run yet.
CREATE TABLE IF NOT EXISTS public.scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stableford_points INTEGER NOT NULL CHECK (stableford_points BETWEEN 1 AND 45),
  course_name TEXT NOT NULL,
  date DATE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  CONSTRAINT scores_user_date_key UNIQUE (user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_scores_user_date
ON public.scores(user_id, date DESC);

ALTER TABLE public.scores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own scores" ON public.scores;
CREATE POLICY "Users can view their own scores" ON public.scores
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own scores" ON public.scores;
CREATE POLICY "Users can insert their own scores" ON public.scores
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own scores" ON public.scores;
CREATE POLICY "Users can update their own scores" ON public.scores
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own scores" ON public.scores;
CREATE POLICY "Users can delete their own scores" ON public.scores
  FOR DELETE USING (auth.uid() = user_id);

-- Drop existing admin policies if they exist (to prevent duplicates)
DROP POLICY IF EXISTS "Admins can update scores" ON public.scores;
DROP POLICY IF EXISTS "Admins can delete scores" ON public.scores;
DROP POLICY IF EXISTS "Admins can view all scores" ON public.scores;

-- Create policy allowing Admins to read all scores
CREATE POLICY "Admins can view all scores" ON public.scores
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Create policy allowing Admins to update user scores
CREATE POLICY "Admins can update scores" ON public.scores
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Create policy allowing Admins to delete user scores
CREATE POLICY "Admins can delete scores" ON public.scores
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Reload Schema Cache
NOTIFY pgrst, 'reload schema';
