-- ============================================================
-- CHARITIES TABLE: Ensure RLS allows public read access
-- ============================================================

CREATE TABLE IF NOT EXISTS public.charities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    logo_url TEXT,
    website_url TEXT,
    category TEXT DEFAULT 'General',
    total_raised NUMERIC(12, 2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Enable RLS
ALTER TABLE public.charities ENABLE ROW LEVEL SECURITY;

-- Drop conflicting policies
DROP POLICY IF EXISTS "Public read access for charities" ON public.charities;
DROP POLICY IF EXISTS "Admins can manage charities" ON public.charities;
DROP POLICY IF EXISTS "Authenticated users can view charities" ON public.charities;

-- ============================================================
-- PUBLIC READ ACCESS
-- ============================================================

CREATE POLICY "Public read access for charities"
ON public.charities
FOR SELECT
USING (true);

-- ============================================================
-- ADMIN ACCESS
-- ============================================================

CREATE POLICY "Admins can manage charities"
ON public.charities
FOR ALL
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = auth.uid()
        AND role = 'admin'
    )
);

-- ============================================================
-- INSERT SAMPLE CHARITIES
-- Only inserts if the table is completely empty
-- ============================================================

INSERT INTO public.charities (
    name,
    description,
    category,
    logo_url,
    website_url,
    total_raised
)
SELECT *
FROM (
    VALUES
    (
        'Macmillan Cancer Support',
        'We provide physical, financial, and emotional support to help people live life as fully as they can when affected by cancer.',
        'Health',
        '/images/charity-fallback.svg',
        'https://www.macmillan.org.uk',
        12450.00
    ),
    (
        'British Heart Foundation',
        'The UK''s largest independent funder of cardiovascular research. Fighting heart and circulatory diseases.',
        'Health',
        '/images/charity-fallback.svg',
        'https://www.bhf.org.uk',
        9870.00
    ),
    (
        'Oxfam GB',
        'Fighting poverty and injustice around the world. Providing emergency relief and long-term development support.',
        'Humanitarian',
        '/images/charity-fallback.svg',
        'https://www.oxfam.org.uk',
        7320.00
    ),
    (
        'WWF UK',
        'Working to conserve nature and reduce the most pressing threats to the diversity of life on Earth.',
        'Environment',
        '/images/charity-fallback.svg',
        'https://www.wwf.org.uk',
        5940.00
    ),
    (
        'RNLI',
        'The Royal National Lifeboat Institution saves lives at sea. Operating 24/7 around the UK and Irish coastline.',
        'Emergency Services',
        '/images/charity-fallback.svg',
        'https://rnli.org',
        6120.00
    ),
    (
        'Age UK',
        'Supporting older people to live fulfilling lives. Providing information, friendship, advice and care locally and nationally.',
        'Community',
        '/images/charity-fallback.svg',
        'https://www.ageuk.org.uk',
        4350.00
    )
) AS new_charities(
    name,
    description,
    category,
    logo_url,
    website_url,
    total_raised
)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.charities
    LIMIT 1
);

-- ============================================================
-- IMPORTANT:
-- Update existing charity records to use local fallback image
-- ============================================================

UPDATE public.charities
SET logo_url = '/images/charity-fallback.svg'
WHERE name IN (
    'Macmillan Cancer Support',
    'British Heart Foundation',
    'Oxfam GB',
    'WWF UK',
    'RNLI',
    'Age UK'
);


SELECT
    id,
    name,
    logo_url,
    website_url,
    category,
    total_raised
FROM public.charities
ORDER BY name;