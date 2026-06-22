// ── Result wrapper ─────────────────────────────────────────────────────────────
//
// Every AI service method returns AiResult<T>. Callers check isSuccess before
// reading data, or check error for a user-displayable message.

class AiResult<T> {
  final T?      data;
  final String? error;
  final AiUsage? usage;

  bool get isSuccess => error == null && data != null;

  const AiResult._({this.data, this.error, this.usage});

  factory AiResult.success(T data, {AiUsage? usage}) =>
      AiResult._(data: data, usage: usage);

  factory AiResult.error(String message) => AiResult._(error: message);
}

// ── Usage info ─────────────────────────────────────────────────────────────────

class AiUsage {
  final int requestsUsed;
  final int monthlyLimit;
  final int remaining;

  const AiUsage({
    required this.requestsUsed,
    required this.monthlyLimit,
    required this.remaining,
  });

  factory AiUsage.fromJson(Map<String, dynamic> j) => AiUsage(
    requestsUsed: (j['requestsUsed'] as num?)?.toInt() ?? 0,
    monthlyLimit: (j['monthlyLimit'] as num?)?.toInt() ?? 100,
    remaining:    (j['remaining']    as num?)?.toInt() ?? 0,
  );

  String get label => '$remaining / $monthlyLimit AI requests remaining this month';
}

// ── SOAP result (Feature 1) ────────────────────────────────────────────────────

class SoapResult {
  final String subjective;
  final String objective;
  final String assessment;
  final String plan;

  const SoapResult({
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
  });

  factory SoapResult.fromJson(Map<String, dynamic> j) => SoapResult(
    subjective: j['subjective'] as String? ?? '',
    objective:  j['objective']  as String? ?? '',
    assessment: j['assessment'] as String? ?? '',
    plan:       j['plan']       as String? ?? '',
  );

  bool get isEmpty =>
      subjective.isEmpty && objective.isEmpty &&
      assessment.isEmpty && plan.isEmpty;
}

// ── Patient history summary (Feature 2) ───────────────────────────────────────

class PatientHistorySummary {
  final String       patientSummary;
  final List<String> visitTimeline;
  final String       documentationSummary;
  final String       progressNotes;
  final List<String> importantRecords;

  const PatientHistorySummary({
    required this.patientSummary,
    required this.visitTimeline,
    required this.documentationSummary,
    required this.progressNotes,
    required this.importantRecords,
  });

  factory PatientHistorySummary.fromJson(Map<String, dynamic> j) =>
      PatientHistorySummary(
        patientSummary:       j['patientSummary']       as String? ?? '',
        visitTimeline:        _strList(j['visitTimeline']),
        documentationSummary: j['documentationSummary'] as String? ?? '',
        progressNotes:        j['progressNotes']        as String? ?? '',
        importantRecords:     _strList(j['importantRecords']),
      );
}

// ── Revenue summary (Feature 3) ───────────────────────────────────────────────

class RevenueSummary {
  final String       totalRevenue;
  final String       paidSessions;
  final String       unpaidSessions;
  final String       financialSummary;
  final List<String> keyInsights;

  const RevenueSummary({
    required this.totalRevenue,
    required this.paidSessions,
    required this.unpaidSessions,
    required this.financialSummary,
    required this.keyInsights,
  });

  factory RevenueSummary.fromJson(Map<String, dynamic> j) => RevenueSummary(
    totalRevenue:     j['totalRevenue']     as String? ?? '',
    paidSessions:     j['paidSessions']     as String? ?? '',
    unpaidSessions:   j['unpaidSessions']   as String? ?? '',
    financialSummary: j['financialSummary'] as String? ?? '',
    keyInsights:      _strList(j['keyInsights']),
  );
}

// ── Expense summary (Feature 4) ───────────────────────────────────────────────

class ExpenseSummary {
  final String                    totalExpenses;
  final List<Map<String, String>> expenseCategories;
  final String                    monthlySummary;
  final List<String>              keyInsights;

  const ExpenseSummary({
    required this.totalExpenses,
    required this.expenseCategories,
    required this.monthlySummary,
    required this.keyInsights,
  });

  factory ExpenseSummary.fromJson(Map<String, dynamic> j) => ExpenseSummary(
    totalExpenses: j['totalExpenses'] as String? ?? '',
    expenseCategories: ((j['expenseCategories'] as List?) ?? [])
        .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v.toString())))
        .toList(),
    monthlySummary: j['monthlySummary'] as String? ?? '',
    keyInsights:    _strList(j['keyInsights']),
  );
}

// ── Financial chat result (Feature 5) ─────────────────────────────────────────

enum FinancialResponseType { text, action, clarification }

class FinancialActionData {
  final String type;
  final String description;
  final String? recordId;
  final Map<String, dynamic>? filters;
  final Map<String, dynamic>? data;

  const FinancialActionData({
    required this.type,
    required this.description,
    this.recordId,
    this.filters,
    this.data,
  });

  factory FinancialActionData.fromJson(Map<String, dynamic> j) =>
      FinancialActionData(
        type:        j['type']        as String? ?? '',
        description: j['description'] as String? ?? '',
        recordId:    j['recordId']    as String?,
        filters:     (j['filters'] as Map?)?.cast<String, dynamic>(),
        data:        (j['data']    as Map?)?.cast<String, dynamic>(),
      );

  bool get isReadOnly =>
      type == 'getRevenueRecords' ||
      type == 'getExpenseRecords' ||
      type == 'getClinicSummary';

  bool get isRevenue =>
      type.contains('Revenue') || type.contains('revenue');

  bool get isExpense =>
      type.contains('Expense') || type.contains('expense');
}

class FinancialChatResult {
  final FinancialResponseType responseType;
  final String message;
  final FinancialActionData? action;

  const FinancialChatResult({
    required this.responseType,
    required this.message,
    this.action,
  });

  factory FinancialChatResult.fromJson(Map<String, dynamic> j) {
    final typeStr = j['responseType'] as String? ?? 'text';
    final rt = switch (typeStr) {
      'action'        => FinancialResponseType.action,
      'clarification' => FinancialResponseType.clarification,
      _               => FinancialResponseType.text,
    };
    final actionMap = j['action'] as Map?;
    return FinancialChatResult(
      responseType: rt,
      message:      j['message'] as String? ?? '',
      action:       actionMap != null
          ? FinancialActionData.fromJson(actionMap.cast<String, dynamic>())
          : null,
    );
  }
}

// ── Chat message model ─────────────────────────────────────────────────────────

enum ChatRole { user, assistant, system }

class AiChatMessage {
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final bool isLoading;
  final FinancialActionData? pendingAction;

  AiChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isLoading = false,
    this.pendingAction,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toHistoryMap() => {
    'role':    role == ChatRole.user ? 'user' : 'assistant',
    'content': content,
  };
}

// ── Clinic analytics result (Feature 6) ───────────────────────────────────────

class ClinicAnalyticsResult {
  final String       summary;
  final List<String> keyInsights;
  final List<String> warnings;
  final List<String> opportunities;
  final List<String> recommendations;

  const ClinicAnalyticsResult({
    required this.summary,
    required this.keyInsights,
    required this.warnings,
    required this.opportunities,
    required this.recommendations,
  });

  factory ClinicAnalyticsResult.fromJson(Map<String, dynamic> j) =>
      ClinicAnalyticsResult(
        summary:         j['summary']         as String? ?? '',
        keyInsights:     _strList(j['keyInsights']),
        warnings:        _strList(j['warnings']),
        opportunities:   _strList(j['opportunities']),
        recommendations: _strList(j['recommendations']),
      );

  bool get isEmpty =>
      summary.isEmpty &&
      keyInsights.isEmpty &&
      warnings.isEmpty &&
      opportunities.isEmpty &&
      recommendations.isEmpty;
}

// ── Shared helper ──────────────────────────────────────────────────────────────

List<String> _strList(dynamic v) =>
    v == null ? [] : (v as List).map((e) => e.toString()).toList();
