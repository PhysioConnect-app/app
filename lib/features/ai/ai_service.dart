import 'package:supabase_flutter/supabase_flutter.dart';
import 'ai_models.dart';

/// Calls the `ai-doctor-assistant` Supabase Edge Function.
///
/// Design rules (per spec):
/// - Never called automatically — only on explicit user action.
/// - Sends the minimum required context; never the full database.
/// - Returns [AiResult<T>] with either typed data or a user-displayable error.
class AiDoctorAssistantService {
  AiDoctorAssistantService._();

  static final _fn = Supabase.instance.client.functions;

  // ── Feature 1: SOAP documentation assistant ───────────────────────────────
  //
  // Call when the therapist clicks "Generate SOAP with AI Doctor Assistant".
  // Pass the therapist's free-text notes and the minimum patient context
  // needed to organise them into S/O/A/P.

  static Future<AiResult<SoapResult>> generateSoap({
    required String patientName,
    int?    patientAge,
    String? diagnosis,
    required String sessionNotes,
    String? sessionDate,
  }) =>
      _invoke(
        taskType: 'SOAP_GENERATION',
        context: {
          'patientName':  patientName,
          if (patientAge != null) 'patientAge': patientAge,
          if (diagnosis != null && diagnosis.isNotEmpty) 'diagnosis': diagnosis,
          'sessionNotes': sessionNotes,
          if (sessionDate != null) 'sessionDate': sessionDate,
        },
        fromJson: SoapResult.fromJson,
      );

  // ── Feature 2: Patient history summary ────────────────────────────────────
  //
  // Call when the therapist clicks "Summarize Patient History".
  // Pass only the most recent notes (≤ 8) and basic patient info;
  // strip fields the AI doesn't need.

  static Future<AiResult<PatientHistorySummary>> summarizePatientHistory({
    required String patientName,
    required int    noteCount,
    required List<Map<String, dynamic>> recentNotes,
  }) =>
      _invoke(
        taskType: 'PATIENT_HISTORY_SUMMARY',
        context: {
          'patientName':  patientName,
          'noteCount':    noteCount,
          'recentNotes':  recentNotes,
        },
        fromJson: PatientHistorySummary.fromJson,
      );

  // ── Feature 3: Revenue analysis ───────────────────────────────────────────
  //
  // Call when the doctor clicks "Analyze Revenue".
  // Strip patient names / IDs from invoices before sending.

  static Future<AiResult<RevenueSummary>> analyzeRevenue({
    required String dateRange,
    required String currency,
    required double totalInvoiced,
    required List<Map<String, dynamic>> invoices,
  }) =>
      _invoke(
        taskType: 'REVENUE_SUMMARY',
        context: {
          'dateRange':     dateRange,
          'currency':      currency,
          'totalInvoiced': totalInvoiced,
          'invoices':      invoices,
        },
        fromJson: RevenueSummary.fromJson,
      );

  // ── Feature 4: Expense analysis ───────────────────────────────────────────
  //
  // Call when the doctor clicks "Summarize Expenses".

  static Future<AiResult<ExpenseSummary>> analyzeExpenses({
    required String dateRange,
    required String currency,
    required List<Map<String, dynamic>> expenses,
  }) =>
      _invoke(
        taskType: 'EXPENSE_SUMMARY',
        context: {
          'dateRange': dateRange,
          'currency':  currency,
          'expenses':  expenses,
        },
        fromJson: ExpenseSummary.fromJson,
      );

  // ── Feature 5: Financial AI Chat ──────────────────────────────────────────
  //
  // Call when the user sends a message in the Financial AI Chat panel.
  // Pass only aggregated context (never raw record lists for write operations).
  // For read requests, the Flutter client executes the tool and calls this
  // again with `toolResult` to get the final human-readable response.

  static Future<AiResult<FinancialChatResult>> financialChat({
    required String userMessage,
    required Map<String, dynamic> revenueContext,
    required Map<String, dynamic> expenseContext,
    List<Map<String, dynamic>> conversationHistory = const [],
    Map<String, dynamic>? toolResult,
    String? executedTool,
  }) =>
      _invoke(
        taskType: 'FINANCIAL_CHAT',
        context: {
          'userMessage':          userMessage,
          'currentDate':          DateTime.now().toIso8601String().split('T').first,
          'revenueContext':       revenueContext,
          'expenseContext':       expenseContext,
          'conversationHistory':  conversationHistory,
          if (toolResult    != null) 'toolResult':    toolResult,
          if (executedTool  != null) 'executedTool':  executedTool,
        },
        fromJson: FinancialChatResult.fromJson,
      );

  // ── Feature 6: Clinic Business Analytics ──────────────────────────────────
  //
  // Call when the doctor requests a clinic performance analysis.
  // Pass aggregated totals and per-therapist breakdowns, not raw records.

  static Future<AiResult<ClinicAnalyticsResult>> analyzeClinicPerformance({
    required String period,
    required String dateRange,
    required Map<String, dynamic> revenue,
    required Map<String, dynamic> expenses,
    required Map<String, dynamic> sessions,
    String? userPrompt,
  }) =>
      _invoke(
        taskType: 'CLINIC_ANALYTICS',
        context: {
          'period':    period,
          'dateRange': dateRange,
          'revenue':   revenue,
          'expenses':  expenses,
          'sessions':  sessions,
          if (userPrompt != null && userPrompt.isNotEmpty) 'userPrompt': userPrompt,
        },
        fromJson: ClinicAnalyticsResult.fromJson,
      );

  // ── Core invocation ───────────────────────────────────────────────────────

  static Future<AiResult<T>> _invoke<T>({
    required String taskType,
    required Map<String, dynamic> context,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final response = await _fn.invoke(
        'ai-doctor-assistant',
        body: {'taskType': taskType, 'context': context},
      );

      if (response.status != 200) {
        final err = (response.data as Map?)
            ?.cast<String, dynamic>()['error'] as String?;
        return AiResult.error(err ?? 'AI request failed (HTTP ${response.status})');
      }

      final body   = (response.data as Map).cast<String, dynamic>();
      final result = fromJson((body['result'] as Map).cast<String, dynamic>());
      final usageMap = body['usage'] as Map?;

      return AiResult.success(
        result,
        usage: usageMap != null
            ? AiUsage.fromJson(usageMap.cast<String, dynamic>())
            : null,
      );
    } on FunctionException catch (e) {
      final detail = e.details as Map?;
      final msg    = detail?.cast<String, dynamic>()['error'] as String?
          ?? e.reasonPhrase
          ?? 'AI Doctor Assistant request failed (HTTP ${e.status})';
      return AiResult.error(msg);
    } catch (e) {
      return AiResult.error('AI Doctor Assistant error: $e');
    }
  }
}
