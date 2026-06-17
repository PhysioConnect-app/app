import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const PATIENT_ID_TABLES = [
  'appointments',
  'clinical_notes',
  'invoices',
  'notifications',
  'appointment_requests',
] as const

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
    if (callerRow?.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Forbidden: admin only' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { canonicalId, duplicateIds } = await req.json() as {
      canonicalId?: string
      duplicateIds?: string[]
    }
    if (!canonicalId || !Array.isArray(duplicateIds) || duplicateIds.length === 0) {
      return new Response(JSON.stringify({ error: 'canonicalId and duplicateIds[] required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    const dupIds = duplicateIds.filter((id) => id !== canonicalId)
    if (dupIds.length === 0) {
      return new Response(JSON.stringify({ error: 'duplicateIds must not equal canonicalId' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // All ids involved must be existing patient rows
    const { data: rows, error: rowsErr } = await adminClient
      .from('users').select('id, role, doctor_ids')
      .in('id', [canonicalId, ...dupIds])
    if (rowsErr) {
      return new Response(JSON.stringify({ error: rowsErr.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    const byId = new Map<string, { id: string; role: string; doctor_ids: string[] | null }>(
      (rows ?? []).map((r) => [r.id as string, r as { id: string; role: string; doctor_ids: string[] | null }])
    )
    const canonical = byId.get(canonicalId)
    if (!canonical || canonical.role !== 'patient') {
      return new Response(JSON.stringify({ error: 'canonicalId is not a patient' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    const presentDupIds = dupIds.filter((id) => byId.get(id)?.role === 'patient')
    if (presentDupIds.length === 0) {
      return new Response(JSON.stringify({ error: 'none of duplicateIds are existing patient rows' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const moved: Record<string, number> = {}

    // 1. Re-point patient_id on owned record tables
    for (const table of PATIENT_ID_TABLES) {
      const { data, error } = await adminClient
        .from(table)
        .update({ patient_id: canonicalId })
        .in('patient_id', presentDupIds)
        .select('id')
      if (error) {
        return new Response(JSON.stringify({ error: `${table}: ${error.message}` }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      moved[table] = data?.length ?? 0
    }

    // 2. Re-point chat messages sent by the duplicates
    {
      const { data, error } = await adminClient
        .from('messages')
        .update({ sender_id: canonicalId })
        .in('sender_id', presentDupIds)
        .select('id')
      if (error) {
        return new Response(JSON.stringify({ error: `messages: ${error.message}` }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      moved['messages'] = data?.length ?? 0
    }

    // 3. Merge chat_rooms.participants (replace duplicate ids with canonical, de-duped)
    {
      const { data: rooms, error } = await adminClient
        .from('chat_rooms')
        .select('id, participants')
        .overlaps('participants', presentDupIds)
      if (error) {
        return new Response(JSON.stringify({ error: `chat_rooms: ${error.message}` }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      for (const room of rooms ?? []) {
        const participants = (room.participants as string[] ?? [])
          .map((p) => (presentDupIds.includes(p) ? canonicalId : p))
        const deduped = Array.from(new Set(participants))
        const { error: updErr } = await adminClient
          .from('chat_rooms')
          .update({ participants: deduped })
          .eq('id', room.id)
        if (updErr) {
          return new Response(JSON.stringify({ error: `chat_rooms ${room.id}: ${updErr.message}` }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          })
        }
      }
      moved['chat_rooms'] = rooms?.length ?? 0
    }

    // 4. chat_room_unread: (room_id, user_id) is a primary key, so duplicates can't
    //    just be re-pointed if the canonical already has a row for that room.
    {
      const { data: unreadRows, error } = await adminClient
        .from('chat_room_unread')
        .select('room_id, user_id, count')
        .in('user_id', presentDupIds)
      if (error) {
        return new Response(JSON.stringify({ error: `chat_room_unread: ${error.message}` }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      for (const row of unreadRows ?? []) {
        const { data: existing } = await adminClient
          .from('chat_room_unread')
          .select('room_id')
          .eq('room_id', row.room_id).eq('user_id', canonicalId)
          .maybeSingle()
        if (existing) {
          await adminClient
            .from('chat_room_unread')
            .delete()
            .eq('room_id', row.room_id).eq('user_id', row.user_id)
        } else {
          await adminClient
            .from('chat_room_unread')
            .update({ user_id: canonicalId })
            .eq('room_id', row.room_id).eq('user_id', row.user_id)
        }
      }
      moved['chat_room_unread'] = unreadRows?.length ?? 0
    }

    // 5. Merge doctor_ids arrays onto the canonical row
    {
      const merged = new Set<string>(canonical.doctor_ids ?? [])
      for (const id of presentDupIds) {
        for (const docId of byId.get(id)?.doctor_ids ?? []) merged.add(docId)
      }
      const { error } = await adminClient
        .from('users')
        .update({ doctor_ids: Array.from(merged) })
        .eq('id', canonicalId)
      if (error) {
        return new Response(JSON.stringify({ error: `merge doctor_ids: ${error.message}` }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
    }

    // 6. Re-point assigned_patient_ids on every doctor that references a duplicate
    {
      const { data: doctors, error } = await adminClient
        .from('users')
        .select('id, assigned_patient_ids')
        .eq('role', 'doctor')
        .overlaps('assigned_patient_ids', presentDupIds)
      if (error) {
        return new Response(JSON.stringify({ error: `doctors: ${error.message}` }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      for (const doc of doctors ?? []) {
        const ids = new Set<string>(
          (doc.assigned_patient_ids as string[] ?? []).filter((id) => !presentDupIds.includes(id))
        )
        ids.add(canonicalId)
        const { error: updErr } = await adminClient
          .from('users')
          .update({ assigned_patient_ids: Array.from(ids) })
          .eq('id', doc.id)
        if (updErr) {
          return new Response(JSON.stringify({ error: `doctor ${doc.id}: ${updErr.message}` }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          })
        }
      }
      moved['doctor_assignments'] = doctors?.length ?? 0
    }

    // 7. Remove the duplicate patient rows. If a duplicate has a live auth account,
    //    delete that first — `users.id` cascades from `auth.users.id` on delete.
    const removed: string[] = []
    for (const id of presentDupIds) {
      const { error: authDeleteErr } = await adminClient.auth.admin.deleteUser(id)
      if (authDeleteErr && !/not.*found/i.test(authDeleteErr.message)) {
        return new Response(JSON.stringify({ error: `auth delete ${id}: ${authDeleteErr.message}` }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      const { error: dbDeleteErr } = await adminClient.from('users').delete().eq('id', id)
      if (dbDeleteErr) {
        return new Response(JSON.stringify({ error: `profile delete ${id}: ${dbDeleteErr.message}` }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      removed.push(id)
    }

    return new Response(JSON.stringify({ success: true, canonicalId, removed, moved }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
