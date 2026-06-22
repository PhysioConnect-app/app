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

// ── Shared helper ──────────────────────────────────────────────────────────────

List<String> _strList(dynamic v) =>
    v == null ? [] : (v as List).map((e) => e.toString()).toList();
