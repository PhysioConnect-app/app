// AI Doctor Assistant — Supabase Edge Function
//
// Supported task types:
//   SOAP_GENERATION          → organises therapist notes into S/O/A/P
//   PATIENT_HISTORY_SUMMARY  → summarises a patient's clinical history
//   REVENUE_SUMMARY          → analyses clinic revenue for a date range
//   EXPENSE_SUMMARY          → analyses clinic expenses for a date range
//   FINANCIAL_CHAT           → conversational financial AI assistant (Feature 5)
//   CLINIC_ANALYTICS         → deep business & statistics analysis (Feature 6)
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
  | 'FINANCIAL_CHAT'
  | 'CLINIC_ANALYTICS'

interface Prompt {
  system:    string
  user:      string
  maxTokens: number
}

// ── Constants ─────────────────────────────────────────────────────────────────

const GROQ_URL       = 'https://api.groq.com/openai/v1/chat/completions'
const PRIMARY_MODEL  = 'llama-3.3-70b-versatile'
const FALLBACK_MODEL = 'llama-3.1-8b-instant'
const DEFAULT_LIMIT  = 100

const VALID_TASKS: TaskType[] = [
  'SOAP_GENERATION',
  'PATIENT_HISTORY_SUMMARY',
  'REVENUE_SUMMARY',
  'EXPENSE_SUMMARY',
  'FINANCIAL_CHAT',
  'CLINIC_ANALYTICS',
]

// Maximum Groq output tokens per task type
const MAX_TOKENS: Record<TaskType, number> = {
  SOAP_GENERATION:         1400,
  PATIENT_HISTORY_SUMMARY: 1200,
  REVENUE_SUMMARY:         600,
  EXPENSE_SUMMARY:         600,
  FINANCIAL_CHAT:          700,
  CLINIC_ANALYTICS:        1000,
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
      const notes   = cap(str(ctx.sessionNotes), 2500)

      return {
        system: `You are a documentation assistant for a licensed physical therapist (PhysioConnect).
Your ONLY role is to extract and organise information from the therapist's session notes into the PhysioConnect SOAP template fields.
You do NOT diagnose, prescribe exercises, recommend treatments, or make clinical decisions.
You ONLY restructure and extract information the therapist already provided.

CRITICAL RULES:
1. Never fabricate ROM values, strength grades, special test results, medical history, medications, or pain levels.
2. If information for a field is NOT present in the notes, return null or "Not Documented" — never invent it.
3. Extract information into the most specific applicable field. Do NOT dump everything into chiefComplaint.
4. Respond with valid JSON only — no markdown fences, no extra text.`,

        user: `Extract and organise these session notes into the PhysioConnect SOAP template.

Patient: ${patient}${age}${dx ? `\nDiagnosis: ${dx}` : ''}${date}

Therapist notes:
${notes}

Return exactly this JSON structure (use null for fields with no available information):
{
  "subjective": {
    "chiefComplaint": "primary reason for visit in patient's own words",
    "onsetDuration": "when it started and how long it has been present",
    "painLevel": "numeric pain score e.g. 7/10 — null if not mentioned",
    "painCharacteristics": "quality of pain e.g. sharp, dull, burning — null if not mentioned",
    "aggravatingFactors": "what makes it worse — null if not mentioned",
    "relievingFactors": "what makes it better — null if not mentioned",
    "functionalLimitations": "what activities are limited — null if not mentioned",
    "patientGoals": "what the patient wants to achieve — null if not mentioned",
    "medicalSurgicalHistory": "relevant past medical/surgical history — null if not mentioned",
    "medications": "current medications — null if not mentioned",
    "socialOccupationalContext": "occupation, living situation, activity level — null if not mentioned"
  },
  "objective": {
    "observation": "posture, gait, appearance, guarding — null if not mentioned",
    "palpation": "tenderness, swelling, tissue texture — null if not mentioned",
    "rangeOfMotion": "ROM measurements with degrees if given — null if not mentioned",
    "strengthTesting": "muscle strength grades — null if not mentioned",
    "neurologicalExam": "sensation, reflexes, neural tension tests — null if not mentioned",
    "balanceCoordination": "balance and coordination findings — null if not mentioned",
    "specialTests": "named clinical special tests and results — null if not mentioned",
    "functionalTests": "functional movement assessments — null if not mentioned",
    "assistiveDevices": "any devices used e.g. crutches, walker — null if not mentioned"
  },
  "assessment": {
    "clinicalImpression": "therapist's clinical summary and reasoning",
    "severityStage": "severity (Mild/Moderate/Severe) and stage (Acute/Subacute/Chronic) — null if not mentioned",
    "progressTowardGoals": "progress toward established goals — null if not mentioned",
    "barriers": "barriers to recovery — null if not mentioned",
    "responseToTreatment": "how patient responded to treatment — null if not mentioned",
    "prognosis": "expected outcome — null if not mentioned"
  },
  "plan": {
    "treatmentFocus": "primary focus of treatment",
    "interventions": "specific interventions performed or planned",
    "frequencyDuration": "treatment frequency and duration e.g. 3x/week x 4 weeks — null if not mentioned",
    "homeExerciseProgram": "home exercise instructions — null if not mentioned",
    "referrals": "referrals to other providers — null if not mentioned",
    "followUp": "next appointment or follow-up plan — null if not mentioned"
  }
}`,

        maxTokens: MAX_TOKENS.SOAP_GENERATION,
      }
    }

    // ── Patient history summary ────────────────────────────────────────────
    case 'PATIENT_HISTORY_SUMMARY': {
      const patient   = str(ctx.patientName)
      const count     = ctx.noteCount ?? 0
      const rawNotes  = ctx.recentNotes as Array<Record<string, unknown>> | undefined
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

    // ── Financial chat (Feature 5) ─────────────────────────────────────────
    case 'FINANCIAL_CHAT': {
      const userMessage = str(ctx.userMessage)
      const currentDate = str(ctx.currentDate) || new Date().toISOString().slice(0, 10)

      // Financial context — only pre-aggregated totals, never full record lists
      const revCtx  = ctx.revenueContext  as Record<string, unknown> | undefined
      const expCtx  = ctx.expenseContext  as Record<string, unknown> | undefined
      const history = ctx.conversationHistory as Array<{role: string; content: string}> | undefined

      // Tool result from a previously executed action (optional)
      const toolResult = ctx.toolResult as Record<string, unknown> | undefined
      const toolName   = str(ctx.executedTool)

      const revenueBlock = revCtx ? `Revenue (${str(revCtx.period)}):
- Collected: ${str(revCtx.collected)}
- Pending: ${str(revCtx.pending)}
- Invoices: ${str(revCtx.invoiceCount)}
- Overdue: ${str(revCtx.overdue)}` : 'Revenue data: not provided'

      const expenseBlock = expCtx ? `Expenses (${str(expCtx.period)}):
- Total: ${str(expCtx.total)}
- Top category: ${str(expCtx.topCategory)} (${str(expCtx.topCategoryAmount)})
- Pending: ${str(expCtx.pendingAmount)}` : 'Expense data: not provided'

      const toolResultBlock = toolResult
        ? `\nPrevious action "${toolName}" result:\n${cap(JSON.stringify(toolResult), 500)}\n`
        : ''

      // Build conversation history block (last 6 messages max)
      const historyBlock = (history ?? []).slice(-6).map(
        (m) => `${m.role === 'user' ? 'User' : 'Assistant'}: ${cap(m.content, 300)}`
      ).join('\n')

      return {
        system: `You are a Financial AI Assistant for a physiotherapy clinic management system.
You help the clinic doctor manage revenue records (invoices) and expense records conversationally.
You have access to the following tools you can request:
- getRevenueRecords: fetch filtered revenue/invoice records
- addRevenue: add a new revenue/invoice record
- updateRevenue: update an existing revenue record by ID
- deleteRevenue: delete a revenue record by ID
- getExpenseRecords: fetch filtered expense records
- addExpense: add a new expense record
- updateExpense: update an existing expense record by ID
- deleteExpense: delete an expense record by ID
- getClinicSummary: get a combined financial summary

IMPORTANT RULES:
1. You NEVER modify data directly. You always request a tool call and wait for confirmation.
2. For any modification (add/update/delete), return responseType "action" with full details.
3. For read-only queries, return responseType "text" with your answer.
4. If a tool result was provided, incorporate it into your response.
5. Always be concise and specific. Use actual numbers from the context.
6. Currency is USD unless stated otherwise.
7. Today's date is ${currentDate}.
8. If information is insufficient to fulfill a request, ask a clarifying question instead of guessing.

For modifications, the action.data must include ALL required fields for the database record.
For expense: category, amount, expense_date (ISO string), status (pending/paid)
For revenue: patient_name, service, amount, invoice_date (ISO string), status (pending/paid)

Respond with valid JSON only — no markdown, no extra text.`,

        user: `Financial context:
${revenueBlock}
${expenseBlock}
${toolResultBlock}
${historyBlock ? `\nConversation so far:\n${historyBlock}` : ''}

User: ${cap(userMessage, 800)}

Return exactly this JSON structure:
{
  "responseType": "text" | "action" | "clarification",
  "message": "your response to the user",
  "action": {
    "type": "getRevenueRecords|addRevenue|updateRevenue|deleteRevenue|getExpenseRecords|addExpense|updateExpense|deleteExpense|getClinicSummary",
    "description": "plain English summary of what will happen",
    "recordId": "existing record UUID (for update/delete only, else omit)",
    "filters": { "status": "...", "dateFrom": "...", "dateTo": "...", "category": "...", "search": "..." },
    "data": { ... }
  }
}
Note: include "action" only when responseType is "action". Omit it for "text" and "clarification".`,

        maxTokens: MAX_TOKENS.FINANCIAL_CHAT,
      }
    }

    // ── Clinic analytics (Feature 6) ───────────────────────────────────────
    case 'CLINIC_ANALYTICS': {
      const period      = str(ctx.period) || 'monthly'
      const dateRange   = str(ctx.dateRange)
      const userPrompt  = str(ctx.userPrompt)

      const revData  = ctx.revenue  as Record<string, unknown> | undefined
      const expData  = ctx.expenses as Record<string, unknown> | undefined
      const sessData = ctx.sessions as Record<string, unknown> | undefined

      const revBlock = revData ? `Revenue:
- Collected: ${str(revData.collected)}
- Pending: ${str(revData.pending)}
- Total invoices: ${str(revData.invoiceCount)}
- Previous period collected: ${str(revData.previousPeriodCollected)}
- Growth: ${str(revData.growth)}
- By month: ${cap(JSON.stringify(revData.byMonth ?? []), 400)}` : 'Revenue: not provided'

      const expBlock = expData ? `Expenses:
- Total: ${str(expData.total)}
- By category: ${cap(JSON.stringify(expData.byCategory ?? []), 400)}
- Previous period total: ${str(expData.previousPeriodTotal)}` : 'Expenses: not provided'

      const sessBlock = sessData ? `Sessions:
- Total completed: ${str(sessData.total)}
- By therapist: ${cap(JSON.stringify(sessData.byTherapist ?? []), 300)}
- Patient visits: ${str(sessData.patientVisits)}
- New patients: ${str(sessData.newPatients)}` : 'Sessions: not provided'

      return {
        system: `You are a business intelligence assistant for a physiotherapy clinic.
Analyse the provided financial and operational data to generate actionable business insights.
Be specific, data-driven, and focus on practical recommendations.
Respond with valid JSON only.`,

        user: `Analyse clinic performance for: ${dateRange} (${period})

${revBlock}

${expBlock}

${sessBlock}

${userPrompt ? `Specific question: ${cap(userPrompt, 400)}` : ''}

Return exactly this JSON:
{
  "summary": "2–3 sentence executive overview of clinic performance",
  "keyInsights": [
    "specific data-backed insight 1",
    "specific data-backed insight 2",
    "specific data-backed insight 3"
  ],
  "warnings": [
    "risk or concern 1 (only include if genuinely concerning)"
  ],
  "opportunities": [
    "growth or improvement opportunity 1",
    "growth or improvement opportunity 2"
  ],
  "recommendations": [
    "actionable recommendation 1",
    "actionable recommendation 2",
    "actionable recommendation 3"
  ]
}`,

        maxTokens: MAX_TOKENS.CLINIC_ANALYTICS,
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

  let enabled      = (cfg?.enabled      as boolean | undefined) ?? true
  let monthlyLimit = (cfg?.monthly_limit as number  | undefined) ?? DEFAULT_LIMIT

  // If no ai_config row, fall back to users.features (admin-controlled via manage sheet)
  if (!cfg) {
    const { data: userRow } = await admin
      .from('users')
      .select('features')
      .eq('id', userId)
      .maybeSingle()
    const features = (userRow?.features as Record<string, unknown> | null) ?? {}
    if (features.ai_enabled !== undefined && features.ai_enabled !== null) {
      enabled = features.ai_enabled as boolean
    }
    if (features.ai_monthly_limit !== undefined && features.ai_monthly_limit !== null) {
      monthlyLimit = features.ai_monthly_limit as number
    }
  }

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

    // ── 6. Update usage (non-blocking) ───────────────────────────────────
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
