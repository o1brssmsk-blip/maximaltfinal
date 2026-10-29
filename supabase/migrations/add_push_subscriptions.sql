-- Push notification abonelikleri (admin cihazlari)
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  endpoint text PRIMARY KEY,
  keys jsonb NOT NULL,
  user_agent text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

-- Yazma/silme sadece service_role (API route uzerinden); anon okuyamaz
DROP POLICY IF EXISTS push_subscriptions_service_all ON public.push_subscriptions;
CREATE POLICY push_subscriptions_service_all ON public.push_subscriptions
  FOR ALL TO service_role USING (true) WITH CHECK (true);
