'use server';

import { createClient } from '@supabase/supabase-js';

export async function createSessionAction(partnerName: string) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !key) return { success: false, error: 'Missing credentials' };

  const supabase = createClient(url, key);

  let reusePublicId: number | null = null;
  try {
    const { data: usedRows } = await supabase
      .from('sessions')
      .select('public_id')
      .not('public_id', 'is', null);
      
    const usedIds = new Set(
      (usedRows || [])
        .map((r: any) => Number(r.public_id))
        .filter((n: number) => Number.isFinite(n) && n > 0)
    );
    
    for (let i = 1; i <= 100000; i++) {
      if (!usedIds.has(i)) {
        reusePublicId = i;
        break;
      }
    }
  } catch (err) {
    console.error('Failed to find public_id', err);
  }

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

  if (reusePublicId !== null) {
    insertPayload.public_id = reusePublicId;
  }

  const { data, error } = await supabase
    .from('sessions')
    .insert(insertPayload)
    .select('id, public_id')
    .maybeSingle();

  if (error || !data?.id) {
    return { success: false, error: error?.message || 'Failed to create session' };
  }

  return { 
    success: true, 
    data: {
      id: data.id,
      public_id: data.public_id
    }
  };
}
