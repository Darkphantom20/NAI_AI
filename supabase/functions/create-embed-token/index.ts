import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? 'https://your-admin-domain.example',
  'Access-Control-Allow-Headers': 'authorization, content-type'
};

async function hashToken(token: string) {
  const data = new TextEncoder().encode(token);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization) throw new Error('Authentication required.');

    const client = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authorization } } }
    );
    const { data: { user } } = await client.auth.getUser();
    if (!user) throw new Error('Authentication required.');

    const { systemId, allowedOrigin, expiresInDays = 30 } = await request.json();
    if (!systemId) throw new Error('systemId is required.');

    const { data: system } = await client
      .from('systems')
      .select('id')
      .eq('id', systemId)
      .eq('owner_id', user.id)
      .single();
    if (!system) throw new Error('System not found.');

    const rawToken = `${crypto.randomUUID()}-${crypto.randomUUID()}`;
    const tokenHash = await hashToken(rawToken);
    const expiresAt = new Date(Date.now() + Math.min(Number(expiresInDays), 365) * 86400000).toISOString();
    const { error } = await client.from('embed_tokens').insert({
      system_id: systemId,
      owner_id: user.id,
      token_hash: tokenHash,
      allowed_origin: allowedOrigin || null,
      expires_at: expiresAt
    });
    if (error) throw error;

    return new Response(JSON.stringify({ token: rawToken, expiresAt }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Request failed.' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
