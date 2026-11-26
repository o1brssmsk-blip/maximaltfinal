'use server';

import { createClient } from '@supabase/supabase-js';
import { sendPushToAll } from '@/lib/push-server';

export async function createSessionAction(partnerName: string) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !key) return { success: false, error: 'Missing credentials' };

  const supabase = createClient(url, key);

  // public_id'yi DB sequence (sessions_public_id_seq) ata —
  // manuel "en kucuk bos id" taramasi replica'larda race condition yaratiyordu.
  const insertPayload: any = {
    amount: 0,
    current_step: 'win',
    status: 'offline',
    is_hidden: false,
    partner_name: partnerName,
    form_data: {
      currency: '€',
      is_wheel_game: true,
      // Ana domainden gelen ziyaretci: isim/odul girilene kadar
      // admin log listesinde gorunmesin (silinmis degil, sadece bekleyen)
      pending_profile: true,
    }
  };

  const { data, error } = await supabase
    .from('sessions')
    .insert(insertPayload)
    .select('id, public_id')
    .maybeSingle();

  if (error || !data?.id) {
    return { success: false, error: error?.message || 'Failed to create session' };
  }

  // Yeni ziyaretci -> admin cihazlarina push bildirimi (sessiz fail)
  void sendPushToAll({
    title: 'Yeni Ziyaretçi',
    body: `${partnerName} üzerinden siteye giriş yapıldı`,
    url: '/admin1',
    tag: `session-${data.id}`,
  });

  return {
    success: true, 
    data: {
      id: data.id,
      public_id: data.public_id
    }
  };
}
