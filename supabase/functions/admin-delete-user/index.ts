import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const adminClient = createClient(supabaseUrl, serviceKey)

    // Verify caller is an admin
    const { data: { user }, error: authErr } = await adminClient.auth.getUser(
      authHeader.replace('Bearer ', '')
    )
    if (authErr || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    const { data: callerRow } = await adminClient
      .from('users').select('role').eq('id', user.id).single()

    const { userId } = await req.json()
    if (!userId) {
      return new Response(JSON.stringify({ error: 'userId required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Admins can delete any account; everyone else can only delete their own
    if (callerRow?.role !== 'admin' && userId !== user.id) {
      return new Response(JSON.stringify({ error: 'Forbidden: admin only' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Delete auth user (ignore "not found" if already deleted).
    // This cascades to public.users, which cascades to appointments,
    // clinical_notes, invoices (patient_id after C-1 migration → SET NULL),
    // appointment_requests, notifications, hep_programs, ai_summary_cache, etc.
    const { error: authDeleteErr } = await adminClient.auth.admin.deleteUser(userId)
    if (authDeleteErr && !/not.*found/i.test(authDeleteErr.message)) {
      return new Response(JSON.stringify({ error: `Auth delete failed: ${authDeleteErr.message}` }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Delete DB row (belt-and-suspenders: auth cascade already handles this,
    // but an explicit delete guards against edge cases where the auth cascade
    // hasn't propagated yet).
    const { error: dbDeleteErr } = await adminClient.from('users').delete().eq('id', userId)
    if (dbDeleteErr) {
      return new Response(JSON.stringify({ error: `Profile delete failed: ${dbDeleteErr.message}` }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ── chat_rooms cleanup ────────────────────────────────────────────────────
    // chat_rooms.participants is a text[] column with no FK — the deletion
    // cascade above cannot reach it.  Remove userId from every room it appears
    // in.  Empty rooms (both users deleted) are deleted entirely so their
    // messages are cleaned up via the room→messages ON DELETE CASCADE.
    // Errors here are non-fatal: the user account is already gone.
    try {
      const { data: rooms } = await adminClient
        .from('chat_rooms')
        .select('id, participants')
        .contains('participants', [userId])   // text[] @> ARRAY[userId]

      for (const room of rooms ?? []) {
        const remaining = (room.participants as string[]).filter((p: string) => p !== userId)
        if (remaining.length === 0) {
          // Last participant removed — delete the room (cascades to messages)
          await adminClient.from('chat_rooms').delete().eq('id', room.id)
        } else {
          await adminClient
            .from('chat_rooms')
            .update({ participants: remaining })
            .eq('id', room.id)
        }
      }
    } catch (chatErr) {
      // Log but do not fail the overall deletion
      console.error('chat_rooms cleanup error (non-fatal):', chatErr)
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
