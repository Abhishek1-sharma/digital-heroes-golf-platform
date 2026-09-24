-- ============================================================
-- DIGITAL HEROES CONTRACT FIXES
-- Safe to run after the existing setup scripts.
-- ============================================================

ALTER TABLE public.charities
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- The app uses featured as the canonical public flag.
UPDATE public.charities
SET is_active = TRUE
WHERE is_active IS NULL;

ALTER TABLE public.winner_proofs
  ADD COLUMN IF NOT EXISTS file_path TEXT;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS handicap NUMERIC(4,1);

ALTER TABLE public.draws
  DROP CONSTRAINT IF EXISTS draws_status_check;

ALTER TABLE public.draws
  ADD CONSTRAINT draws_status_check
  CHECK (status IN ('pending', 'published', 'archived'));

-- Winner proofs must not be publicly readable.
UPDATE storage.buckets
SET public = FALSE
WHERE id = 'winner-proofs';

DROP POLICY IF EXISTS "Public can view proofs" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own proofs" ON storage.objects;
DROP POLICY IF EXISTS "Admins can view proofs" ON storage.objects;

CREATE POLICY "Users can view their own proofs"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'winner-proofs'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Admins can view proofs"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'winner-proofs'
  AND EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

NOTIFY pgrst, 'reload schema';
