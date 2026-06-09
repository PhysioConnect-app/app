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
    const callerRole = callerRow?.role as string | undefined

    const { email, password, role, name, specialty, doctor_id, phone, primary_diagnosis, date_of_birth } = await req.json()

    // Admins can create any account type; doctors can only create patient accounts
    if (callerRole !== 'admin' && !(callerRole === 'doctor' && role === 'patient')) {
      return new Response(JSON.stringify({ error: 'Forbidden: insufficient permissions' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Create auth user
    const { data: created, error: createErr } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    })
    if (createErr) {
      return new Response(JSON.stringify({ error: createErr.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const uid = created.user.id
    const now = new Date().toISOString()

    let row: Record<string, unknown> = { id: uid, email, role, name, created_at: now }

    if (role === 'doctor') {
      row = {
        ...row,
        specialization: specialty ?? '',
        subscription: 'basic',
        features: { messages: false, statistics: false, billing: false, expenses: false },
        is_enabled: true,
        show_in_search: true,
        bio: '',
        profile_photo_url: '',
      }
    } else if (role === 'polyclinic') {
      row = {
        ...row,
        linked_doctor_ids: [],
        subscription: 'basic',
        is_enabled: true,
        bio: '',
        profile_photo_url: '',
      }
    } else if (role === 'patient') {
      row = {
        ...row,
        doctor_ids: doctor_id ? [doctor_id] : [],
        phone: phone ?? '',
        primary_diagnosis: primary_diagnosis ?? '',
        ...(date_of_birth ? { date_of_birth } : {}),
        created_by: doctor_id ?? null,
      }
    }

    const { error: insertErr } = await adminClient.from('users').insert(row)
    if (insertErr) {
      // Rollback auth user so no orphan is left
      await adminClient.auth.admin.deleteUser(uid)
      return new Response(JSON.stringify({ error: insertErr.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ id: uid }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
