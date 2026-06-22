import 'dart:async';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/language_provider.dart';

class SessionStatsScreen extends StatefulWidget {
  final VoidCallback? onAddAppointment;
  const SessionStatsScreen({super.key, this.onAddAppointment});

  @override
  State<SessionStatsScreen> createState() => _SessionStatsScreenState();
}

class _SessionStatsScreenState extends State<SessionStatsScreen> {
  static const _navy   = Color(0xFF1A3A5C);
  static const _green  = Color(0xFF2E7D32);
  static const _red    = Color(0xFFC62828);
  static const _amber  = Color(0xFFFF8F00);

  String   _period         = 'monthly';
  DateTime _refDate        = DateTime.now();
  bool     _showComparison = false;

  late final StreamSubscription<List<Map<String, dynamic>>> _patientsSub;
  List<Map<String, dynamic>> _allPatients = [];

  @override
  void initState() {
    super.initState();
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    _patientsSub = Supabase.instance.client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('role', 'patient')
        .listen((rows) {
          if (!mounted) return;
          setState(() {
            _allPatients = rows
                .where((u) =>
                    (u['doctor_ids'] as List<dynamic>?)?.contains(uid) == true)
                .toList();
          });
        });
  }

  @override
  void dispose() {
    _patientsSub.cancel();
    super.dispose();
  }

  // ── Period helpers ──────────────────────────────────────────────────────

  // Returns (start, end) for any reference date in the current _period,
  // allowing the same logic to serve both current and previous period.
  (DateTime, DateTime) _rangeForRef(DateTime ref) {
    final start = switch (_period) {
      'daily'  => DateTime(ref.year, ref.month, ref.day),
      'weekly' => () {
          final m = ref.subtract(Duration(days: ref.weekday - 1));
          return DateTime(m.year, m.month, m.day);
        }(),
      'yearly' => DateTime(ref.year, 1, 1),
      _        => DateTime(ref.year, ref.month, 1),
    };
    final end = switch (_period) {
      'daily'  => DateTime(ref.year, ref.month, ref.day, 23, 59, 59),
      'weekly' => () {
          final m = ref.subtract(Duration(days: ref.weekday - 1));
          final s = DateTime(m.year, m.month, m.day);
          final e = s.add(const Duration(days: 6));
          return DateTime(e.year, e.month, e.day, 23, 59, 59);
        }(),
      'yearly' => DateTime(ref.year, 12, 31, 23, 59, 59),
      _        => DateTime(ref.year, ref.month + 1, 0, 23, 59, 59),
    };
    return (start, end);
  }

  DateTime get _start => _rangeForRef(_refDate).$1;
  DateTime get _end   => _rangeForRef(_refDate).$2;

  DateTime get _prevRefDate => switch (_period) {
    'daily'  => _refDate.subtract(const Duration(days: 1)),
    'weekly' => _refDate.subtract(const Duration(days: 7)),
    'yearly' => DateTime(_refDate.year - 1, _refDate.month, _refDate.day),
    _        => DateTime(_refDate.year, _refDate.month - 1, _refDate.day),
  };

  DateTime get _prevStart => _rangeForRef(_prevRefDate).$1;
  DateTime get _prevEnd   => _rangeForRef(_prevRefDate).$2;

  bool _inPrevRange(DateTime dt) =>
      !dt.isBefore(_prevStart) && !dt.isAfter(_prevEnd);

  String get _rangeLabel {
    final s = _start;
    final e = _end;
    return switch (_period) {
      'daily'  => DateFormat('MMM d, yyyy').format(s),
      'yearly' => '${s.year}',
      'weekly' => '${DateFormat('MMM d').format(s)} – ${DateFormat('MMM d').format(e)}',
      _        => DateFormat('MMMM yyyy').format(s),
    };
  }

  void _prev() => setState(() {
    _refDate = switch (_period) {
      'daily'  => _refDate.subtract(const Duration(days: 1)),
      'weekly' => _refDate.subtract(const Duration(days: 7)),
      'yearly' => DateTime(_refDate.year - 1),
      _        => DateTime(_refDate.year, _refDate.month - 1),
    };
  });

  void _next() => setState(() {
    _refDate = switch (_period) {
      'daily'  => _refDate.add(const Duration(days: 1)),
      'weekly' => _refDate.add(const Duration(days: 7)),
      'yearly' => DateTime(_refDate.year + 1),
      _        => DateTime(_refDate.year, _refDate.month + 1),
    };
  });

  bool _inRange(DateTime dt) =>
      !dt.isBefore(_start) && !dt.isAfter(_end);

  // Delta % between current and previous period value; null when prev is 0.
  double? _delta(double current, double previous) =>
      previous == 0 ? null : (current - previous) / previous * 100;

  // Most-common currency across all loaded invoices.
  // TODO: multi-currency — group by currency rather than summing across all.
  String _dominantCurrency(List<Map<String, dynamic>> allInvoices) {
    if (allInvoices.isEmpty) return 'USD';
    final counts = <String, int>{};
    for (final inv in allInvoices) {
      final c = (inv['currency'] as String?) ?? 'USD';
      counts[c] = (counts[c] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F9),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('appointments')
            .stream(primaryKey: ['id'])
            .eq('doctor_id', uid),
        builder: (_, apptSnap) => StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('invoices')
              .stream(primaryKey: ['id'])
              .eq('doctor_id', uid),
          builder: (_, invSnap) => StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('expenses')
                .stream(primaryKey: ['id'])
                .eq('doctor_id', uid),
            builder: (_, expSnap) {
              if (apptSnap.connectionState == ConnectionState.waiting ||
                  invSnap.connectionState  == ConnectionState.waiting ||
                  expSnap.connectionState  == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // ── Filter by period ──────────────────────────────────────
              final appts = (apptSnap.data ?? []).where((d) {
                final tsStr = d['appointment_time'] as String?;
                if (tsStr == null) return false;
                return _inRange(DateTime.parse(tsStr));
              }).toList();

              final invoices = (invSnap.data ?? []).where((d) {
                final tsStr = d['invoice_date'] as String? ?? d['created_at'] as String?;
                if (tsStr == null) return false;
                return _inRange(DateTime.parse(tsStr));
              }).toList();

              final expenses = (expSnap.data ?? []).where((d) {
                final tsStr = d['expense_date'] as String? ?? d['created_at'] as String?;
                if (tsStr == null) return false;
                return _inRange(DateTime.parse(tsStr));
              }).toList();

              // ── Compute KPIs ──────────────────────────────────────────
              final sessions = appts.length;

              double paidIncome = 0, pendingIncome = 0;
              for (final inv in invoices) {
                final amt = (inv['amount'] as num?)?.toDouble() ?? 0;
                if (inv['status'] == 'paid') { paidIncome   += amt; }
                else                         { pendingIncome += amt; }
              }

              double paidExpenses = 0, pendingExpenses = 0;
              for (final exp in expenses) {
                final amt = (exp['amount'] as num?)?.toDouble() ?? 0;
                if (exp['status'] == 'paid') { paidExpenses   += amt; }
                else                         { pendingExpenses += amt; }
              }

              final netProfit = paidIncome - paidExpenses;

              // ── Payment collection: overdue = pending invoices > 30 d ──
              final overdueThreshold =
                  DateTime.now().subtract(const Duration(days: 30));
              double overdueIncome = 0;
              for (final inv in invoices) {
                if (inv['status'] != 'pending') continue;
                final t = inv['invoice_date'] as String?
                    ?? inv['created_at'] as String?;
                if (t != null &&
                    DateTime.parse(t).isBefore(overdueThreshold)) {
                  overdueIncome +=
                      (inv['amount'] as num?)?.toDouble() ?? 0;
                }
              }

              // ── Sessions by day ───────────────────────────────────────
              final days = _end.difference(_start).inDays + 1;
              final sessionsByDay = List<int>.filled(days, 0);
              for (final appt in appts) {
                final tsStr = appt['appointment_time'] as String?;
                if (tsStr == null) continue;
                final idx = DateTime.parse(tsStr).difference(_start).inDays;
                if (idx >= 0 && idx < days) sessionsByDay[idx]++;
              }

              // ── Display currency ──────────────────────────────────────
              final currency = _dominantCurrency(invSnap.data ?? []);

              // ── Previous-period KPIs (for delta badges) ───────────────
              final prevAppts = (apptSnap.data ?? []).where((d) {
                final t = d['appointment_time'] as String?;
                return t != null && _inPrevRange(DateTime.parse(t));
              }).toList();
              final prevInvList = (invSnap.data ?? []).where((d) {
                final t = d['invoice_date'] as String?
                    ?? d['created_at'] as String?;
                return t != null && _inPrevRange(DateTime.parse(t));
              }).toList();
              final prevExpList = (expSnap.data ?? []).where((d) {
                final t = d['expense_date'] as String?
                    ?? d['created_at'] as String?;
                return t != null && _inPrevRange(DateTime.parse(t));
              }).toList();

              final prevSessions = prevAppts.length;
              double prevPaidInc = 0;
              for (final inv in prevInvList) {
                final amt = (inv['amount'] as num?)?.toDouble() ?? 0;
                if (inv['status'] == 'paid') prevPaidInc += amt;
              }
              double prevPaidExp = 0;
              for (final exp in prevExpList) {
                final amt = (exp['amount'] as num?)?.toDouble() ?? 0;
                if (exp['status'] == 'paid') prevPaidExp += amt;
              }
              final prevNetProfit = prevPaidInc - prevPaidExp;

              // ── Sparkline buckets — paid-only, consistent with KPI cards ──
              final incomeSpkl   = List<double>.filled(days, 0);
              final expensesSpkl = List<double>.filled(days, 0);
              for (final inv in invoices) {
                if (inv['status'] != 'paid') continue;
                final t = inv['invoice_date'] as String?
                    ?? inv['created_at'] as String?;
                if (t == null) continue;
                final i = DateTime.parse(t).difference(_start).inDays;
                if (i >= 0 && i < days) {
                  incomeSpkl[i] += (inv['amount'] as num?)?.toDouble() ?? 0;
                }
              }
              for (final exp in expenses) {
                if (exp['status'] != 'paid') continue;
                final t = exp['expense_date'] as String?
                    ?? exp['created_at'] as String?;
                if (t == null) continue;
                final i = DateTime.parse(t).difference(_start).inDays;
                if (i >= 0 && i < days) {
                  expensesSpkl[i] += (exp['amount'] as num?)?.toDouble() ?? 0;
                }
              }

              // ── Busiest-times heatmap [weekday 0=Mon..6=Sun][hour 0..23] ──
              final heatmap =
                  List.generate(7, (_) => List<int>.filled(24, 0));
              for (final appt in appts) {
                final tsStr = appt['appointment_time'] as String?;
                if (tsStr == null) continue;
                final dt = DateTime.parse(tsStr).toLocal();
                heatmap[dt.weekday - 1][dt.hour]++;
              }

              // ── Patient insight KPIs ─────────────────────────────────
              final newPatients = _allPatients.where((u) {
                final t = u['created_at'] as String?;
                return t != null && _inRange(DateTime.parse(t));
              }).length;

              final avgSessionValue =
                  sessions > 0 ? paidIncome / sessions : null;

              // Returning patients: had an appointment in the period AND
              // at least one appointment before _start.
              final periodPids = appts
                  .map((a) => a['patient_id'] as String?)
                  .whereType<String>()
                  .toSet();
              final allAppts = apptSnap.data ?? [];
              final retainedCount = periodPids
                  .where((pid) => allAppts.any((a) =>
                      a['patient_id'] == pid &&
                      DateTime.parse(a['appointment_time'] as String)
                          .isBefore(_start)))
                  .length;
              final retentionRate = periodPids.isEmpty
                  ? 0.0
                  : retainedCount / periodPids.length * 100;

              final cancelledCount =
                  appts.where((a) => a['status'] == 'cancelled').length;
              final cancellationRate =
                  sessions > 0 ? cancelledCount / sessions * 100 : 0.0;

              // ── Top services by revenue ───────────────────────────────
              final svcRevenue = <String, double>{};
              for (final inv in invoices) {
                final svc = (inv['service'] as String?)?.trim();
                if (svc == null || svc.isEmpty) continue;
                svcRevenue[svc] = (svcRevenue[svc] ?? 0) +
                    ((inv['amount'] as num?)?.toDouble() ?? 0);
              }
              final topServices = (svcRevenue.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .take(5)
                  .toList();

              // ── Top diagnoses from doctor's patients ──────────────────
              final diagCounts = <String, int>{};
              for (final u in _allPatients) {
                final dx = (u['primary_diagnosis'] as String?)?.trim();
                if (dx == null || dx.isEmpty) continue;
                diagCounts[dx] = (diagCounts[dx] ?? 0) + 1;
              }
              final topDiagnoses = (diagCounts.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .take(5)
                  .toList();

              return _buildBody(
                sessions:         sessions,
                paidIncome:       paidIncome,
                pendingIncome:    pendingIncome,
                paidExpenses:     paidExpenses,
                pendingExpenses:  pendingExpenses,
                netProfit:        netProfit,
                sessionsByDay:    sessionsByDay,
                currency:         currency,
                overdueIncome:    overdueIncome,
                prevSessions:     prevSessions,
                prevPaidIncome:   prevPaidInc,
                prevPaidExpenses: prevPaidExp,
                prevNetProfit:    prevNetProfit,
                incomeSpkl:       incomeSpkl,
                expensesSpkl:     expensesSpkl,
                newPatients:      newPatients,
                avgSessionValue:  avgSessionValue,
                retentionRate:    retentionRate,
                cancellationRate: cancellationRate,
                topServices:      topServices,
                topDiagnoses:     topDiagnoses,
                heatmap:          heatmap,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required int     sessions,
    required double  paidIncome,
    required double  pendingIncome,
    required double  paidExpenses,
    required double  pendingExpenses,
    required double  netProfit,
    required List<int> sessionsByDay,
    required String  currency,
    required double  overdueIncome,
    required int     prevSessions,
    required double  prevPaidIncome,
    required double  prevPaidExpenses,
    required double  prevNetProfit,
    required List<double> incomeSpkl,
    required List<double> expensesSpkl,
    required int     newPatients,
    required double? avgSessionValue,
    required double  retentionRate,
    required double  cancellationRate,
    required List<MapEntry<String, double>> topServices,
    required List<MapEntry<String, int>>    topDiagnoses,
    required List<List<int>>                heatmap,
  }) {
    final s        = AppStrings(context.watch<LanguageProvider>().isArabic);
    final sessSpkl = sessionsByDay.map((v) => v.toDouble()).toList();
    final netSpkl  = List.generate(
        incomeSpkl.length, (i) => incomeSpkl[i] - expensesSpkl[i]);

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(s),
          // ── Section 2: KPI row — 4 across on desktop, 2×2 on mobile ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: isMobile
                ? Column(children: [
                    Row(children: [
                      Expanded(child: _kpi(
                        label:          s.statsSessions,
                        value:          sessions.toString(),
                        icon:           Icons.event_note_rounded,
                        iconBg:         const Color(0xFFE3F2FD),
                        iconClr:        const Color(0xFF1565C0),
                        deltaPercent:   _showComparison ? _delta(sessions.toDouble(), prevSessions.toDouble()) : null,
                        sparklineData:  sessSpkl,
                        sparklineColor: const Color(0xFF1565C0),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _kpi(
                        label:          s.statsIncome,
                        value:          '$currency ${paidIncome.toStringAsFixed(0)}',
                        icon:           Icons.trending_up_rounded,
                        iconBg:         const Color(0xFFE8F5E9),
                        iconClr:        _green,
                        deltaPercent:   _showComparison ? _delta(paidIncome, prevPaidIncome) : null,
                        sparklineData:  incomeSpkl,
                        sparklineColor: _green,
                      )),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _kpi(
                        label:          s.statsExpenses,
                        value:          '$currency ${paidExpenses.toStringAsFixed(0)}',
                        icon:           Icons.trending_down_rounded,
                        iconBg:         const Color(0xFFFFEBEE),
                        iconClr:        _red,
                        deltaPercent:   _showComparison ? _delta(paidExpenses, prevPaidExpenses) : null,
                        sparklineData:  expensesSpkl,
                        sparklineColor: _red,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _kpi(
                        label:          s.statsNetProfit,
                        value:          '$currency ${netProfit.toStringAsFixed(0)}',
                        icon:           netProfit >= 0 ? Icons.account_balance_wallet_rounded : Icons.warning_amber_rounded,
                        iconBg:         netProfit >= 0 ? const Color(0xFFE0F2F1) : const Color(0xFFFFF3E0),
                        iconClr:        netProfit >= 0 ? const Color(0xFF00695C) : _amber,
                        valueClr:       netProfit >= 0 ? _green : _red,
                        sub:            s.netProfitSublabel,
                        deltaPercent:   _showComparison ? _delta(netProfit, prevNetProfit) : null,
                        sparklineData:  netSpkl,
                        sparklineColor: netProfit >= 0 ? _green : _red,
                      )),
                    ]),
                  ])
                : Row(children: [
                    Expanded(child: _kpi(
                      label:          s.statsSessions,
                      value:          sessions.toString(),
                      icon:           Icons.event_note_rounded,
                      iconBg:         const Color(0xFFE3F2FD),
                      iconClr:        const Color(0xFF1565C0),
                      deltaPercent:   _showComparison ? _delta(sessions.toDouble(), prevSessions.toDouble()) : null,
                      sparklineData:  sessSpkl,
                      sparklineColor: const Color(0xFF1565C0),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _kpi(
                      label:          s.statsIncome,
                      value:          '$currency ${paidIncome.toStringAsFixed(0)}',
                      icon:           Icons.trending_up_rounded,
                      iconBg:         const Color(0xFFE8F5E9),
                      iconClr:        _green,
                      deltaPercent:   _showComparison ? _delta(paidIncome, prevPaidIncome) : null,
                      sparklineData:  incomeSpkl,
                      sparklineColor: _green,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _kpi(
                      label:          s.statsExpenses,
                      value:          '$currency ${paidExpenses.toStringAsFixed(0)}',
                      icon:           Icons.trending_down_rounded,
                      iconBg:         const Color(0xFFFFEBEE),
                      iconClr:        _red,
                      deltaPercent:   _showComparison ? _delta(paidExpenses, prevPaidExpenses) : null,
                      sparklineData:  expensesSpkl,
                      sparklineColor: _red,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _kpi(
                      label:          s.statsNetProfit,
                      value:          '$currency ${netProfit.toStringAsFixed(0)}',
                      icon:           netProfit >= 0 ? Icons.account_balance_wallet_rounded : Icons.warning_amber_rounded,
                      iconBg:         netProfit >= 0 ? const Color(0xFFE0F2F1) : const Color(0xFFFFF3E0),
                      iconClr:        netProfit >= 0 ? const Color(0xFF00695C) : _amber,
                      valueClr:       netProfit >= 0 ? _green : _red,
                      sub:            s.netProfitSublabel,
                      deltaPercent:   _showComparison ? _delta(netProfit, prevNetProfit) : null,
                      sparklineData:  netSpkl,
                      sparklineColor: netProfit >= 0 ? _green : _red,
                    )),
                  ]),
          ),
          // ── Section 3: Revenue trend + Payment collection ─────────────
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _revenueTrendCard(
                        incomeData:   incomeSpkl,
                        expensesData: expensesSpkl,
                        currency:     currency,
                        s:            s,
                      ),
                      const SizedBox(height: 12),
                      _paymentCollectionCard(
                        paidIncome:    paidIncome,
                        pendingIncome: pendingIncome,
                        overdueIncome: overdueIncome,
                        currency:      currency,
                        s:             s,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _revenueTrendCard(
                          incomeData:   incomeSpkl,
                          expensesData: expensesSpkl,
                          currency:     currency,
                          s:            s,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _paymentCollectionCard(
                          paidIncome:    paidIncome,
                          pendingIncome: pendingIncome,
                          overdueIncome: overdueIncome,
                          currency:      currency,
                          s:             s,
                        ),
                      ),
                    ],
                  ),
          ),
          // ── Section 4: Patient Insight row — 4 across on desktop, 2×2 on mobile ──
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: isMobile
                ? Column(children: [
                    Row(children: [
                      Expanded(child: _insightCard(
                        icon:    Icons.person_add_rounded,
                        iconBg:  const Color(0xFFE3F2FD),
                        iconClr: const Color(0xFF1565C0),
                        label:   s.statsNewPatients,
                        value:   '$newPatients',
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _insightCard(
                        icon:    Icons.attach_money_rounded,
                        iconBg:  const Color(0xFFE8F5E9),
                        iconClr: _green,
                        label:   s.statsAvgSession,
                        value:   avgSessionValue != null ? '$currency ${avgSessionValue.toStringAsFixed(0)}' : '—',
                      )),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _insightCard(
                        icon:    Icons.repeat_rounded,
                        iconBg:  const Color(0xFFE0F2F1),
                        iconClr: const Color(0xFF00897B),
                        label:   s.statsRetention,
                        value:   '${retentionRate.toStringAsFixed(0)}%',
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _insightCard(
                        icon:    Icons.cancel_outlined,
                        iconBg:  const Color(0xFFFFEBEE),
                        iconClr: _red,
                        label:   s.statsCancellation,
                        value:   '${cancellationRate.toStringAsFixed(0)}%',
                      )),
                    ]),
                  ])
                : Row(children: [
                    Expanded(child: _insightCard(
                      icon:    Icons.person_add_rounded,
                      iconBg:  const Color(0xFFE3F2FD),
                      iconClr: const Color(0xFF1565C0),
                      label:   s.statsNewPatients,
                      value:   '$newPatients',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _insightCard(
                      icon:    Icons.attach_money_rounded,
                      iconBg:  const Color(0xFFE8F5E9),
                      iconClr: _green,
                      label:   s.statsAvgSession,
                      value:   avgSessionValue != null ? '$currency ${avgSessionValue.toStringAsFixed(0)}' : '—',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _insightCard(
                      icon:    Icons.repeat_rounded,
                      iconBg:  const Color(0xFFE0F2F1),
                      iconClr: const Color(0xFF00897B),
                      label:   s.statsRetention,
                      value:   '${retentionRate.toStringAsFixed(0)}%',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _insightCard(
                      icon:    Icons.cancel_outlined,
                      iconBg:  const Color(0xFFFFEBEE),
                      iconClr: _red,
                      label:   s.statsCancellation,
                      value:   '${cancellationRate.toStringAsFixed(0)}%',
                    )),
                  ]),
          ),
          // ── Section 5: Top Services + Top Diagnoses ───────────────────
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _topServicesCard(
                  entries:  topServices,
                  currency: currency,
                  s:        s,
                )),
                const SizedBox(width: 12),
                Expanded(child: _topDiagnosesCard(
                  entries: topDiagnoses,
                  s:       s,
                )),
              ],
            ),
          ),
          // ── Section 6: Busiest-times heatmap ─────────────────────────
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _heatmapCard(heatmap: heatmap, s: s),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Header with period selector ──────────────────────────────────────────

  Widget _buildHeader(AppStrings s) {
    final periods = ['daily', 'weekly', 'monthly', 'yearly'];
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A3A5C), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bar_chart_rounded,
                color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(s.statistics,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _refDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _refDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_month_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            _comparisonToggle(s),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                    onTap: _prev,
                    child: const Icon(Icons.chevron_left_rounded,
                        color: Colors.white, size: 20)),
                const SizedBox(width: 4),
                Text(_rangeLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
                const SizedBox(width: 4),
                GestureDetector(
                    onTap: _next,
                    child: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 20)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: periods.asMap().entries.map((entry) {
            final p   = entry.value;
            final lbl = s.statsPeriodLabels[entry.key];
            final sel = _period == p;
            return GestureDetector(
              onTap: () => setState(() {
                _period  = p;
                _refDate = DateTime.now();
              }),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lbl,
                  style: TextStyle(
                      color: sel ? _navy : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            );
          }).toList()),
        ],
      ),
    );
  }

  // ── vs-previous-period toggle chip ───────────────────────────────────────

  Widget _comparisonToggle(AppStrings s) {
    return GestureDetector(
      onTap: () => setState(() => _showComparison = !_showComparison),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _showComparison
              ? Colors.white
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.compare_arrows_rounded,
              color: _showComparison ? _navy : Colors.white,
              size: 14),
          const SizedBox(width: 4),
          Text(s.statsVsPrev,
              style: TextStyle(
                  color: _showComparison ? _navy : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  // ── KPI card ──────────────────────────────────────────────────────────────

  Widget _kpi({
    required String   label,
    required String   value,
    required IconData icon,
    required Color    iconBg,
    required Color    iconClr,
    String?           sub,
    Color?            valueClr,
    double?           deltaPercent,
    List<double>?     sparklineData,
    Color?            sparklineColor,
  }) {
    final hasSparkline = sparklineData != null &&
        sparklineData.length > 1 &&
        sparklineData.any((v) => v != 0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconClr, size: 18),
            ),
            const Spacer(),
            if (deltaPercent != null) _deltaChip(deltaPercent),
          ]),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: valueClr ?? _navy)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
          ],
          if (hasSparkline) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 28,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  data:  sparklineData,
                  color: sparklineColor ?? iconClr,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _deltaChip(double percent) {
    final isPos = percent >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isPos ? _green : _red).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          isPos ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 10,
          color: isPos ? _green : _red,
        ),
        const SizedBox(width: 2),
        Text(
          '${isPos ? '+' : ''}${percent.toStringAsFixed(0)}%',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isPos ? _green : _red),
        ),
      ]),
    );
  }

  // ── Section 6: Busiest-times heatmap ─────────────────────────────────────

  Widget _heatmapCard({required List<List<int>> heatmap, required AppStrings s}) {
    final days      = s.statsWeekdayAbbr;
    const startHour = 7;
    const endHour   = 21; // inclusive
    const numHours  = endHour - startHour + 1;

    final allCounts = heatmap
        .expand((row) => row.sublist(startHour, endHour + 1))
        .toList();
    final hasData  = allCounts.any((v) => v > 0);
    final maxCount = hasData
        ? allCounts.reduce(math.max).clamp(1, 9999)
        : 1;

    Color cellColor(int count) => Color.lerp(
      const Color(0xFFE3F2FD),
      const Color(0xFF1565C0),
      count == 0 ? 0.0 : (count / maxCount).clamp(0.05, 1.0),
    )!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.grid_view_rounded, size: 16, color: _navy),
            const SizedBox(width: 6),
            Text(s.statsBusiestTimes,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _navy)),
          ]),
          const SizedBox(height: 14),
          if (!hasData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(s.statsNoAppointmentData,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else ...[
            // Hour labels row
            Row(children: [
              const SizedBox(width: 36),
              ...List.generate(numHours, (i) {
                final hour = startHour + i;
                return Expanded(
                  child: Center(
                    child: Text(
                      hour % 3 == 0 ? '$hour' : '',
                      style: const TextStyle(
                          fontSize: 8,
                          color: AppColors.textSecondary),
                    ),
                  ),
                );
              }),
            ]),
            const SizedBox(height: 4),
            // Grid rows (one per weekday)
            ...List.generate(7, (dayIdx) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(children: [
                SizedBox(
                  width: 32,
                  child: Text(days[dayIdx],
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary)),
                ),
                ...List.generate(numHours, (hIdx) {
                  final count = heatmap[dayIdx][startHour + hIdx];
                  return Expanded(
                    child: Container(
                      height: 18,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: cellColor(count),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ]),
            )),
            const SizedBox(height: 10),
            // Legend: Fewer → More
            Row(children: [
              Text(s.statsHeatmapFewer,
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textSecondary)),
              const SizedBox(width: 6),
              ...List.generate(5, (i) => Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: cellColor(i == 0 ? 0 : (maxCount * i / 4).round()),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(width: 6),
              Text(s.statsHeatmapMore,
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textSecondary)),
            ]),
          ],
        ],
      ),
    );
  }

  // ── Section 4 helpers ─────────────────────────────────────────────────────

  Widget _insightCard({
    required IconData icon,
    required Color    iconBg,
    required Color    iconClr,
    required String   label,
    required String   value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconClr, size: 14),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _navy)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ── Section 5 helpers ─────────────────────────────────────────────────────

  Widget _topServicesCard({
    required List<MapEntry<String, double>> entries,
    required String currency,
    required AppStrings s,
  }) {
    final maxVal = entries.isEmpty ? 1.0 : entries.first.value;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.star_rounded, size: 16, color: _navy),
            const SizedBox(width: 6),
            Text(s.statsTopServices,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _navy)),
          ]),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(s.statsNoServiceData,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...entries.map((e) {
              final pct = maxVal > 0 ? e.value / maxVal : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(e.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ),
                      Text('$currency ${e.value.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _navy)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade100,
                        valueColor:
                            const AlwaysStoppedAnimation(_green),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _topDiagnosesCard({
    required List<MapEntry<String, int>> entries,
    required AppStrings s,
  }) {
    final maxVal = entries.isEmpty ? 1 : entries.first.value;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.medical_information_rounded, size: 16, color: _navy),
            const SizedBox(width: 6),
            Text(s.statsTopDiagnoses,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _navy)),
          ]),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(s.statsNoDiagnosisData,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...entries.map((e) {
              final pct = maxVal > 0 ? e.value / maxVal : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(e.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ),
                      Text(s.statsPatientCount(e.value),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _navy)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF7B1FA2)),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Section 3a: Revenue & Expenses trend chart ───────────────────────────

  Widget _revenueTrendCard({
    required List<double> incomeData,
    required List<double> expensesData,
    required String currency,
    required AppStrings s,
  }) {
    final hasData = incomeData.any((v) => v > 0) ||
        expensesData.any((v) => v > 0);
    final allVals = [...incomeData, ...expensesData];
    final maxVal  = allVals.isEmpty
        ? 1.0
        : allVals.reduce(math.max).clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.show_chart_rounded, size: 16, color: _navy),
            const SizedBox(width: 6),
            Text(s.statsRevenueExpenses,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _navy)),
            const Spacer(),
            _legendDot(_green, s.statsIncome),
            const SizedBox(width: 10),
            _legendDot(_red, s.statsExpenses),
          ]),
          const SizedBox(height: 16),
          if (!hasData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(s.statsNoFinancialData,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxVal * 1.15,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: const Color(0xFFF0F4FA),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        interval: maxVal / 3,
                        getTitlesWidget: (val, _) => Text(
                          '$currency ${val.toInt()}',
                          style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (val, _) {
                          final n   = incomeData.length;
                          final idx = val.toInt();
                          if (n == 0) return const SizedBox.shrink();
                          if (idx != 0 &&
                              idx != n ~/ 2 &&
                              idx != n - 1) {
                            return const SizedBox.shrink();
                          }
                          final date =
                              _start.add(Duration(days: idx));
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('d MMM').format(date),
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: incomeData.asMap().entries
                          .map((e) =>
                              FlSpot(e.key.toDouble(), e.value))
                          .toList(),
                      isCurved: true,
                      color: _green,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _green.withValues(alpha: 0.08),
                      ),
                    ),
                    LineChartBarData(
                      spots: expensesData.asMap().entries
                          .map((e) =>
                              FlSpot(e.key.toDouble(), e.value))
                          .toList(),
                      isCurved: true,
                      color: _red,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _red.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Section 3b: Payment collection donut ─────────────────────────────────

  Widget _paymentCollectionCard({
    required double paidIncome,
    required double pendingIncome,
    required double overdueIncome,
    required String currency,
    required AppStrings s,
  }) {
    final pendingCurrent =
        (pendingIncome - overdueIncome).clamp(0.0, double.infinity);
    final total      = paidIncome + pendingIncome;
    final hasData    = total > 0;
    final pctLabel   = total > 0
        ? '${(paidIncome / total * 100).toStringAsFixed(0)}%'
        : '0%';
    String fmt(double v) => '$currency ${v.toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.donut_large_rounded, size: 16, color: _navy),
            const SizedBox(width: 6),
            Text(s.statsCollection,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _navy)),
          ]),
          const SizedBox(height: 16),
          if (!hasData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(s.statsNoInvoices,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else ...[
            SizedBox(
              height: 130,
              child: Stack(alignment: Alignment.center, children: [
                PieChart(PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 38,
                  sections: [
                    if (paidIncome > 0)
                      PieChartSectionData(
                          value: paidIncome,
                          color: _green,
                          radius: 20,
                          showTitle: false),
                    if (pendingCurrent > 0)
                      PieChartSectionData(
                          value: pendingCurrent,
                          color: _amber,
                          radius: 20,
                          showTitle: false),
                    if (overdueIncome > 0)
                      PieChartSectionData(
                          value: overdueIncome,
                          color: _red,
                          radius: 20,
                          showTitle: false),
                  ],
                )),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(pctLabel,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _navy)),
                  Text(s.statsCollected,
                      style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary)),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            _collectionRow(_green, s.statusPaid,    fmt(paidIncome)),
            const SizedBox(height: 6),
            _collectionRow(_amber, s.statusPending, fmt(pendingCurrent)),
            const SizedBox(height: 6),
            _collectionRow(_red,   s.statsOverdue,  fmt(overdueIncome)),
          ],
        ],
      ),
    );
  }

  Widget _collectionRow(Color color, String label, String value) {
    return Row(children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ),
      Text(value,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
    ]);
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              fontSize: 10, color: AppColors.textSecondary)),
    ]);
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  const _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final maxVal = data.reduce(math.max);
    if (maxVal == 0) return;

    // Fill area under the line.
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    // Stroke the line.
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    Offset point(int i) {
      final x = i / (data.length - 1) * size.width;
      final y = size.height - (data[i] / maxVal) * size.height;
      return Offset(x, y);
    }

    final linePath = Path()..moveTo(point(0).dx, point(0).dy);
    for (int i = 1; i < data.length; i++) {
      linePath.lineTo(point(i).dx, point(i).dy);
    }
    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.data != data || old.color != color;
}
