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
//
// Matches the PhysioConnect SOAP template field-by-field.
// Null means "Not Documented" — never fabricated by the AI.

class SoapResult {
  // Subjective
  final String? chiefComplaint;
  final String? onsetDuration;
  final String? painLevel;
  final String? painCharacteristics;
  final String? aggravatingFactors;
  final String? relievingFactors;
  final String? functionalLimitations;
  final String? patientGoals;
  final String? medicalSurgicalHistory;
  final String? medications;
  final String? socialOccupationalContext;

  // Objective
  final String? observation;
  final String? palpation;
  final String? rangeOfMotion;
  final String? strengthTesting;
  final String? neurologicalExam;
  final String? balanceCoordination;
  final String? specialTests;
  final String? functionalTests;
  final String? assistiveDevices;

  // Assessment
  final String? clinicalImpression;
  final String? severityStage;
  final String? progressTowardGoals;
  final String? barriers;
  final String? responseToTreatment;
  final String? prognosis;

  // Plan
  final String? treatmentFocus;
  final String? interventions;
  final String? frequencyDuration;
  final String? homeExerciseProgram;
  final String? referrals;
  final String? followUp;

  const SoapResult({
    this.chiefComplaint,
    this.onsetDuration,
    this.painLevel,
    this.painCharacteristics,
    this.aggravatingFactors,
    this.relievingFactors,
    this.functionalLimitations,
    this.patientGoals,
    this.medicalSurgicalHistory,
    this.medications,
    this.socialOccupationalContext,
    this.observation,
    this.palpation,
    this.rangeOfMotion,
    this.strengthTesting,
    this.neurologicalExam,
    this.balanceCoordination,
    this.specialTests,
    this.functionalTests,
    this.assistiveDevices,
    this.clinicalImpression,
    this.severityStage,
    this.progressTowardGoals,
    this.barriers,
    this.responseToTreatment,
    this.prognosis,
    this.treatmentFocus,
    this.interventions,
    this.frequencyDuration,
    this.homeExerciseProgram,
    this.referrals,
    this.followUp,
  });

  static String? _field(Map<String, dynamic> j, String key) {
    final v = j[key];
    if (v == null) return null;
    final s = v.toString().trim();
    if (s == 'null' || s == 'Not Documented' || s.isEmpty) return null;
    return s;
  }

  factory SoapResult.fromJson(Map<String, dynamic> j) {
    // Support nested structure {"subjective":{...},"objective":{...},...}
    // as well as flat top-level keys for backward compat.
    Map<String, dynamic> sub  = {};
    Map<String, dynamic> obj  = {};
    Map<String, dynamic> ass  = {};
    Map<String, dynamic> plan = {};

    final rawSub  = j['subjective'];
    final rawObj  = j['objective'];
    final rawAss  = j['assessment'];
    final rawPlan = j['plan'];

    if (rawSub  is Map) sub  = rawSub.cast<String, dynamic>();
    if (rawObj  is Map) obj  = rawObj.cast<String, dynamic>();
    if (rawAss  is Map) ass  = rawAss.cast<String, dynamic>();
    if (rawPlan is Map) plan = rawPlan.cast<String, dynamic>();

    String? f(Map<String, dynamic> m, String k) => _field(m, k) ?? _field(j, k);

    return SoapResult(
      chiefComplaint:         f(sub,  'chiefComplaint'),
      onsetDuration:          f(sub,  'onsetDuration'),
      painLevel:              f(sub,  'painLevel'),
      painCharacteristics:    f(sub,  'painCharacteristics'),
      aggravatingFactors:     f(sub,  'aggravatingFactors'),
      relievingFactors:       f(sub,  'relievingFactors'),
      functionalLimitations:  f(sub,  'functionalLimitations'),
      patientGoals:           f(sub,  'patientGoals'),
      medicalSurgicalHistory: f(sub,  'medicalSurgicalHistory'),
      medications:            f(sub,  'medications'),
      socialOccupationalContext: f(sub, 'socialOccupationalContext'),
      observation:            f(obj,  'observation'),
      palpation:              f(obj,  'palpation'),
      rangeOfMotion:          f(obj,  'rangeOfMotion'),
      strengthTesting:        f(obj,  'strengthTesting'),
      neurologicalExam:       f(obj,  'neurologicalExam'),
      balanceCoordination:    f(obj,  'balanceCoordination'),
      specialTests:           f(obj,  'specialTests'),
      functionalTests:        f(obj,  'functionalTests'),
      assistiveDevices:       f(obj,  'assistiveDevices'),
      clinicalImpression:     f(ass,  'clinicalImpression'),
      severityStage:          f(ass,  'severityStage'),
      progressTowardGoals:    f(ass,  'progressTowardGoals'),
      barriers:               f(ass,  'barriers'),
      responseToTreatment:    f(ass,  'responseToTreatment'),
      prognosis:              f(ass,  'prognosis'),
      treatmentFocus:         f(plan, 'treatmentFocus'),
      interventions:          f(plan, 'interventions'),
      frequencyDuration:      f(plan, 'frequencyDuration'),
      homeExerciseProgram:    f(plan, 'homeExerciseProgram'),
      referrals:              f(plan, 'referrals'),
      followUp:               f(plan, 'followUp'),
    );
  }

  bool get isEmpty =>
      chiefComplaint == null && clinicalImpression == null &&
      interventions == null && observation == null;
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
