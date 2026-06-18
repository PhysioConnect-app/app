/**
 * session-reminders — Supabase Edge Function (cron / HTTP)
 *
 * Finds appointments starting in the next 2 hours and sends an FCM
 * push notification to the patient's device.
 *
 * Deploy:
 *   supabase functions deploy session-reminders --no-verify-jwt
 *
 * Schedule (run every 10 minutes via Supabase pg_cron — see migration):
 *   select cron.schedule(
 *     'session-reminders',
 *     '*/10 * * * *',
 *     $$ select net.http_post(
 *       url := 'https://<project-ref>.supabase.co/functions/v1/session-reminders',
 *       headers := '{"Authorization":"Bearer <service-role-key>","Content-Type":"application/json"}'::jsonb,
 *       body := '{}'::jsonb
 *     ) $$
 *   );
 *
 * Required env vars (set via `supabase secrets set`):
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FCM_SERVER_KEY
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL      = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE_KEY  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FCM_SERVER_KEY    = Deno.env.get('FCM_SERVER_KEY')!

// Window: appointments starting between now+115min and now+125min
// (run every 10 min → each appointment is caught exactly once)
const WINDOW_MIN = 115
const WINDOW_MAX = 125

Deno.serve(async (_req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)

    const now      = new Date()
    const fromTime = new Date(now.getTime() + WINDOW_MIN * 60_000)
    const toTime   = new Date(now.getTime() + WINDOW_MAX * 60_000)

    // Find upcoming scheduled appointments in the window
    const { data: appointments, error } = await supabase
      .from('appointments')
      .select('id, patient_id, patient_name, appointment_time, notes')
      .eq('status', 'scheduled')
      .gte('appointment_time', fromTime.toISOString())
      .lte('appointment_time', toTime.toISOString())

    if (error) throw error

    if (!appointments || appointments.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 })
    }

    // Fetch FCM tokens for the affected patients
    const patientIds = [...new Set(appointments.map((a: any) => a.patient_id))]
    const { data: patients } = await supabase
      .from('users')
      .select('id, fcm_token')
      .in('id', patientIds)

    const tokenMap: Record<string, string | null> = {}
    for (const p of (patients ?? [])) {
      tokenMap[p.id] = p.fcm_token ?? null
    }

    let sent = 0
    for (const appt of appointments) {
      const token = tokenMap[appt.patient_id]
      if (!token) continue

      const sessionTime = new Date(appt.appointment_time)
      const timeStr = sessionTime.toLocaleTimeString('en-US', {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true,
      })

      const payload = {
        to: token,
        notification: {
          title: 'Session Reminder 🏥',
          body: `Your session is starting at ${timeStr}. See you soon!`,
          sound: 'default',
        },
        data: {
          type: 'session_reminder',
          appointment_id: appt.id,
        },
        android: {
          priority: 'high',
          notification: { channel_id: 'session_reminders' },
        },
        apns: {
          payload: {
            aps: { alert: {}, sound: 'default', badge: 1 },
          },
        },
      }

      const res = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Authorization': `key=${FCM_SERVER_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      })

      if (res.ok) sent++

      // Persist a notification record so the patient sees it in-app too
      await supabase.from('notifications').insert({
        recipient_id: appt.patient_id,
        title:        'Session Reminder',
        body:         `Your session starts at ${timeStr}. Please be ready.`,
        type:         'session_reminder',
        read:         false,
        created_at:   new Date().toISOString(),
      })
    }

    return new Response(JSON.stringify({ sent, total: appointments.length }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('session-reminders error:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
