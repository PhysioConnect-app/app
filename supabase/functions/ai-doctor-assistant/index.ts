// AI Doctor Assistant — Supabase Edge Function
//
// Supported task types:
//   SOAP_GENERATION          → organises therapist notes into S/O/A/P
//   PATIENT_HISTORY_SUMMARY  → summarises a patient's clinical history
//   REVENUE_SUMMARY          → analyses clinic revenue for a date range
//   EXPENSE_SUMMARY          → analyses clinic expenses for a date range
//
// Required secrets (set with `supabase secrets set KEY=value`):
//   GROQ_API_KEY             → your Groq API key
//   SUPABASE_URL             → injected automatically
//   SUPABASE_SERVICE_ROLE_KEY → injected automatically
//
// Deploy: supabase functions deploy ai-doctor-assistant

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ── CORS ──────────────────────────────────────────────────────────────────────

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ── Types ─────────────────────────────────────────────────────────────────────

type TaskType =
  | 'SOAP_GENERATION'
  | 'PATIENT_HISTORY_SUMMARY'
  | 'REVENUE_SUMMARY'
  | 'EXPENSE_SUMMARY'

interface Prompt {
  system:    string
  user:      string
  maxTokens: number
}

// ── Constants ─────────────────────────────────────────────────────────────────

const GROQ_URL       = 'https://api.groq.com/openai/v1/chat/completions'
const PRIMARY_MODEL  = 'llama-3.1-70b-versatile'
const FALLBACK_MODEL = 'mixtral-8x7b-32768'
const DEFAULT_LIMIT  = 100

const VALID_TASKS: TaskType[] = [
  'SOAP_GENERATION',
  'PATIENT_HISTORY_SUMMARY',
  'REVENUE_SUMMARY',
  'EXPENSE_SUMMARY',
]

// Maximum Groq output tokens per task type
const MAX_TOKENS: Record<TaskType, number> = {
  SOAP_GENERATION:         800,
  PATIENT_HISTORY_SUMMARY: 1200,
  REVENUE_SUMMARY:         600,
  EXPENSE_SUMMARY:         600,
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function jsonResp(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

/** Truncate a string to `max` characters to keep prompts within token limits. */
function cap(s: string | undefined | null, max: number): string {
  if (!s) return ''
  return s.length <= max ? s : s.slice(0, max) + '…'
}

function str(v: unknown): string {
  return v == null ? '' : String(v)
}

// ── Prompt builders ───────────────────────────────────────────────────────────

function buildPrompt(taskType: TaskType, ctx: Record<string, unknown>): Prompt {
  switch (taskType) {

    // ── SOAP generation ────────────────────────────────────────────────────
    case 'SOAP_GENERATION': {
      const patient = str(ctx.patientName)
      const age     = ctx.patientAge ? `, ${ctx.patientAge} y.o.` : ''
      const dx      = str(ctx.diagnosis)
      const date    = ctx.sessionDate ? `\nSession date: ${ctx.sessionDate}` : ''
      // Hard cap on session notes to control input tokens
      const notes   = cap(str(ctx.sessionNotes), 2500)

      return {
        system: `You are a documentation assistant for a licensed physical therapist.
Your ONLY role is to organise the therapist's session notes into standard SOAP format.
You do NOT diagnose, prescribe exercises, recommend treatments, or make clinical decisions.
You only restructure information the therapist already provided.
Respond with valid JSON only — no extra text, no markdown fences.`,

        user: `Organise these session notes into SOAP format.

Patient: ${patient}${age}${dx ? `\nDiagnosis: ${dx}` : ''}${date}

Therapist notes:
${notes}

Return exactly this JSON:
{
  "subjective": "patient-reported symptoms, pain level, functional limitations",
  "objective": "measurable findings: ROM, strength, special tests, gait, posture",
  "assessment": "therapist's clinical impression and reasoning from the notes",
  "plan": "treatment approach, interventions, frequency, HEP, follow-up"
}`,

        maxTokens: MAX_TOKENS.SOAP_GENERATION,
      }
    }

    // ── Patient history summary ────────────────────────────────────────────
    case 'PATIENT_HISTORY_SUMMARY': {
      const patient   = str(ctx.patientName)
      const count     = ctx.noteCount ?? 0
      const rawNotes  = ctx.recentNotes as Array<Record<string, unknown>> | undefined
      // Strip heavy fields; send only the most recent 8 notes, capped at 7 000 chars
      const slim = (rawNotes ?? []).slice(0, 8).map((n) => ({
        date:          n.created_at ?? n.date,
        chiefComplaint: str(n.chiefComplaint ?? n.subjective).slice(0, 200),
        interventions: str(n.interventions  ?? n.plan).slice(0, 200),
        progress:      str(n.progressTowardGoals ?? n.assessment).slice(0, 150),
      }))
      const notesJson = cap(JSON.stringify(slim), 7000)

      return {
        system: `You are a documentation assistant for a licensed physical therapist.
Summarise a patient's clinical history for the therapist's quick reference.
Do NOT make clinical recommendations or diagnoses.
Respond with valid JSON only.`,

        user: `Summarise this patient's clinical history.

Patient: ${patient}
Total documented sessions: ${count}

Recent SOAP notes (most recent first):
${notesJson}

Return exactly this JSON:
{
  "patientSummary": "2–3 sentence overview of condition and treatment course",
  "visitTimeline": ["key milestone 1", "key milestone 2", "key milestone 3"],
  "documentationSummary": "notes on overall documentation completeness",
  "progressNotes": "observed trends: improving / plateauing / regressing and why",
  "importantRecords": ["notable clinical finding 1", "notable finding 2"]
}`,

        maxTokens: MAX_TOKENS.PATIENT_HISTORY_SUMMARY,
      }
    }

    // ── Revenue summary ────────────────────────────────────────────────────
    case 'REVENUE_SUMMARY': {
      const range    = str(ctx.dateRange)
      const currency = str(ctx.currency) || 'USD'
      const total    = ctx.totalInvoiced ?? 0
      const rawInv   = ctx.invoices as Array<Record<string, unknown>> | undefined
      // Minimal invoice representation — drop patient PII
      const slim = (rawInv ?? []).slice(0, 50).map((inv) => ({
        date:   str(inv.invoice_date ?? inv.date ?? inv.created_at).slice(0, 10),
        amount: inv.amount,
        status: inv.status,
      }))
      const invJson = cap(JSON.stringify(slim), 3500)

      return {
        system: `You are a financial analysis assistant for a physiotherapy clinic.
Analyse revenue data and produce a clear, concise summary for the clinic administrator.
Respond with valid JSON only.`,

        user: `Analyse clinic revenue for: ${range}

Total invoiced: ${currency} ${total}
Invoices:
${invJson}

Return exactly this JSON:
{
  "totalRevenue": "formatted collected amount with currency",
  "paidSessions": "count and total value of paid invoices",
  "unpaidSessions": "count and total value of pending/unpaid invoices",
  "financialSummary": "2–3 sentence narrative of financial performance",
  "keyInsights": ["insight 1", "insight 2", "insight 3"]
}`,

        maxTokens: MAX_TOKENS.REVENUE_SUMMARY,
      }
    }

    // ── Expense summary ────────────────────────────────────────────────────
    case 'EXPENSE_SUMMARY': {
      const range    = str(ctx.dateRange)
      const currency = str(ctx.currency) || 'USD'
      const rawExp   = ctx.expenses as Array<Record<string, unknown>> | undefined
      const slim     = (rawExp ?? []).slice(0, 50).map((e) => ({
        date:     str(e.expense_date ?? e.date ?? e.created_at).slice(0, 10),
        category: e.category,
        amount:   e.amount,
        desc:     str(e.description ?? e.desc ?? '').slice(0, 60),
      }))
      const expJson = cap(JSON.stringify(slim), 3500)

      return {
        system: `You are a financial analysis assistant for a physiotherapy clinic.
Analyse expense data and produce a clear summary for the clinic administrator.
Respond with valid JSON only.`,

        user: `Analyse clinic expenses for: ${range} (${currency})

Expense records:
${expJson}

Return exactly this JSON:
{
  "totalExpenses": "formatted total with currency",
  "expenseCategories": [{"category": "...", "amount": "...", "percentage": "..."}],
  "monthlySummary": "2–3 sentence narrative of expense patterns",
  "keyInsights": ["insight 1", "insight 2", "insight 3"]
}`,

        maxTokens: MAX_TOKENS.EXPENSE_SUMMARY,
      }
    }
  }
}

// ── Groq API call (with automatic model fallback) ─────────────────────────────

async function callGroq(
  prompt:    Prompt,
  modelName: string = PRIMARY_MODEL,
): Promise<{ content: unknown; tokensUsed: number }> {
  const apiKey = Deno.env.get('GROQ_API_KEY')
  if (!apiKey) throw new Error('GROQ_API_KEY is not configured')

  const res = await fetch(GROQ_URL, {
    method: 'POST',
    headers: {
      Authorization:  `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model:           modelName,
      messages: [
        { role: 'system', content: prompt.system },
        { role: 'user',   content: prompt.user   },
      ],
      temperature:     0.3,
      max_tokens:      prompt.maxTokens,
      response_format: { type: 'json_object' },
    }),
  })

  if (!res.ok) {
    const errText = await res.text()
    if (modelName === PRIMARY_MODEL) {
      console.warn(`Primary model failed (HTTP ${res.status}), falling back to ${FALLBACK_MODEL}. ${errText}`)
      return callGroq(prompt, FALLBACK_MODEL)
    }
    throw new Error(`Groq API error ${res.status}: ${errText}`)
  }

  const data      = await res.json()
  const rawJson   = data.choices?.[0]?.message?.content ?? '{}'
  const content   = JSON.parse(rawJson)
  const tokensUsed = (data.usage?.total_tokens as number | undefined) ?? 0

  return { content, tokensUsed }
}

// ── Usage helpers ─────────────────────────────────────────────────────────────

async function getUsage(
  admin:  ReturnType<typeof createClient>,
  userId: string,
) {
  const month = new Date().toISOString().slice(0, 7) // 'YYYY-MM'

  const { data: cfg } = await admin
    .from('ai_config')
    .select('enabled, monthly_limit')
    .eq('user_id', userId)
    .maybeSingle()

  const enabled      = (cfg?.enabled      as boolean | undefined) ?? true
  const monthlyLimit = (cfg?.monthly_limit as number  | undefined) ?? DEFAULT_LIMIT

  // Sum usage across all features for this user/month → single monthly cap
  const { data: rows } = await admin
    .from('ai_usage')
    .select('requests_used')
    .eq('user_id', userId)
    .eq('month', month)

  const requestsUsed = (rows ?? []).reduce(
    (sum: number, r: { requests_used: number }) => sum + (r.requests_used ?? 0),
    0,
  )

  return {
    enabled,
    monthlyLimit,
    requestsUsed,
    remaining: Math.max(0, monthlyLimit - requestsUsed),
    month,
  }
}

async function incrementUsage(
  admin:    ReturnType<typeof createClient>,
  userId:   string,
  taskType: string,
  month:    string,
  tokens:   number,
): Promise<void> {
  const { error } = await admin.rpc('ai_increment_usage', {
    p_user_id: userId,
    p_feature: taskType,
    p_month:   month,
    p_tokens:  tokens,
  })
  if (error) throw error
}

// ── Main handler ──────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // ── 1. Authenticate ──────────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return jsonResp({ error: 'Unauthorized' }, 401)

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { data: { user }, error: authErr } = await adminClient.auth.getUser(
      authHeader.replace('Bearer ', ''),
    )
    if (authErr || !user) return jsonResp({ error: 'Invalid token' }, 401)

    // ── 2. Parse and validate request ────────────────────────────────────
    const body = await req.json() as {
      taskType?: TaskType
      context?:  Record<string, unknown>
    }

    if (!body.taskType || !(VALID_TASKS as string[]).includes(body.taskType)) {
      return jsonResp({
        error: `Invalid taskType. Must be one of: ${VALID_TASKS.join(', ')}`,
      }, 400)
    }
    if (!body.context || typeof body.context !== 'object') {
      return jsonResp({ error: 'Missing or invalid context object' }, 400)
    }

    const taskType = body.taskType
    const context  = body.context

    // ── 3. Usage check ───────────────────────────────────────────────────
    const usage = await getUsage(adminClient, user.id)

    if (!usage.enabled) {
      return jsonResp({
        error: 'AI Doctor Assistant is not enabled for your account. Contact your administrator.',
      }, 403)
    }
    if (usage.remaining <= 0) {
      return jsonResp({
        error: `AI Doctor Assistant limit reached (${usage.monthlyLimit} requests/month). Contact your administrator.`,
        usage: {
          requestsUsed: usage.requestsUsed,
          monthlyLimit: usage.monthlyLimit,
          remaining:    0,
        },
      }, 429)
    }

    // ── 4. Build prompt ──────────────────────────────────────────────────
    const prompt = buildPrompt(taskType, context)

    // ── 5. Call Groq ─────────────────────────────────────────────────────
    const { content, tokensUsed } = await callGroq(prompt)

    // ── 6. Update usage (non-blocking — don't fail the response) ─────────
    incrementUsage(adminClient, user.id, taskType, usage.month, tokensUsed).catch(
      (e) => console.error('Usage tracking error (non-fatal):', e),
    )

    // ── 7. Respond ───────────────────────────────────────────────────────
    return jsonResp({
      success: true,
      result:  content,
      usage: {
        requestsUsed: usage.requestsUsed + 1,
        monthlyLimit: usage.monthlyLimit,
        remaining:    usage.remaining - 1,
      },
    })

  } catch (e) {
    console.error('ai-doctor-assistant unhandled error:', e)
    return jsonResp({ error: String(e) }, 500)
  }
})
