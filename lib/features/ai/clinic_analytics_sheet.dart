// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import 'ai_models.dart';
import 'ai_service.dart';

// ── Quick prompt chips ────────────────────────────────────────────────────────

const _kPrompts = [
  'Analyze clinic performance this quarter',
  'Why did revenue change last month?',
  'Compare this month to the previous month',
  'Show financial risks',
  'Show growth opportunities',
  'Which therapist generated the highest revenue?',
];

// ── Public entry point ────────────────────────────────────────────────────────

/// Shows the Clinic Analytics bottom sheet.
/// Call from any screen that has a [BuildContext].
Future<void> showClinicAnalyticsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ClinicAnalyticsSheet(),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _ClinicAnalyticsSheet extends StatefulWidget {
  const _ClinicAnalyticsSheet();

  @override
  State<_ClinicAnalyticsSheet> createState() => _ClinicAnalyticsSheetState();
}

class _ClinicAnalyticsSheetState extends State<_ClinicAnalyticsSheet> {
  static const _kPrimary = Color(0xFF1565C0);

  final _supabase    = Supabase.instance.client;
  final _uid         = Supabase.instance.client.auth.currentUser!.id;
  final _promptCtrl  = TextEditingController();

  String _period       = 'monthly';
  bool   _loading      = false;
  String? _error;
  ClinicAnalyticsResult? _result;
  AiUsage? _usage;

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  // ── Data collection ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _buildRevenueData(
      DateTime start, DateTime end, DateTime prevStart, DateTime prevEnd) async {
    final thisInvs = await _supabase
        .from('invoices')
        .select('amount, status, invoice_date')
        .eq('doctor_id', _uid)
        .gte('invoice_date', start.toIso8601String())
        .lte('invoice_date', end.toIso8601String());

    final prevInvs = await _supabase
        .from('invoices')
        .select('amount, status')
        .eq('doctor_id', _uid)
        .gte('invoice_date', prevStart.toIso8601String())
        .lte('invoice_date', prevEnd.toIso8601String());

    double thisCollected = 0, thisPending = 0;
    int invoiceCount = 0;
    final byMonth = <String, double>{};

    for (final inv in (thisInvs as List)) {
      final amt = (inv['amount'] as num?)?.toDouble() ?? 0;
      final st  = inv['status'] as String? ?? 'pending';
      if (st == 'cancelled' || st == 'awaiting_review') continue;
      invoiceCount++;
      if (st == 'paid') {
        thisCollected += amt;
      } else if (st == 'partially_paid') {
        thisCollected += amt * 0.5;
        thisPending   += amt * 0.5;
      } else {
        thisPending += amt;
      }
      final dateStr = inv['invoice_date'] as String?;
      if (dateStr != null) {
        final month = dateStr.substring(0, 7);
        byMonth[month] = (byMonth[month] ?? 0) + amt;
      }
    }

    double prevCollected = 0;
    for (final inv in (prevInvs as List)) {
      if (inv['status'] == 'paid') {
        prevCollected += (inv['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    final growthPct = prevCollected > 0
        ? ((thisCollected - prevCollected) / prevCollected * 100).toStringAsFixed(1)
        : '—';

    final fmt = NumberFormat('#,##0.00');
    return {
      'collected':               'USD ${fmt.format(thisCollected)}',
      'pending':                 'USD ${fmt.format(thisPending)}',
      'invoiceCount':            invoiceCount,
      'previousPeriodCollected': 'USD ${fmt.format(prevCollected)}',
      'growth':                  growthPct != '—' ? '$growthPct%' : '—',
      'byMonth': byMonth.entries
          .map((e) => {'month': e.key, 'amount': e.value})
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _buildExpenseData(
      DateTime start, DateTime end, DateTime prevStart, DateTime prevEnd) async {
    final thisExps = await _supabase
        .from('expenses')
        .select('amount, category')
        .eq('doctor_id', _uid)
        .gte('expense_date', start.toIso8601String())
        .lte('expense_date', end.toIso8601String());

    final prevExps = await _supabase
        .from('expenses')
        .select('amount')
        .eq('doctor_id', _uid)
        .gte('expense_date', prevStart.toIso8601String())
        .lte('expense_date', prevEnd.toIso8601String());

    double total = 0, prevTotal = 0;
    final catTotals = <String, double>{};
    for (final exp in (thisExps as List)) {
      final amt = (exp['amount'] as num?)?.toDouble() ?? 0;
      final cat = exp['category'] as String? ?? 'Other';
      total += amt;
      catTotals[cat] = (catTotals[cat] ?? 0) + amt;
    }
    for (final exp in (prevExps as List)) {
      prevTotal += (exp['amount'] as num?)?.toDouble() ?? 0;
    }

    final fmt = NumberFormat('#,##0.00');
    return {
      'total':               'USD ${fmt.format(total)}',
      'previousPeriodTotal': 'USD ${fmt.format(prevTotal)}',
      'byCategory': catTotals.entries
          .map((e) => {
                'category': e.key,
                'amount':   'USD ${fmt.format(e.value)}',
                'pct':      total > 0
                    ? '${(e.value / total * 100).toStringAsFixed(0)}%'
                    : '0%',
              })
          .toList()
        ..sort((a, b) => (b['amount'] as String)
            .compareTo(a['amount'] as String)),
    };
  }

  Future<Map<String, dynamic>> _buildSessionData(
      DateTime start, DateTime end) async {
    final appts = await _supabase
        .from('appointments')
        .select('patient_id, doctor_id')
        .eq('doctor_id', _uid)
        .eq('status', 'completed')
        .gte('appointment_time', start.toIso8601String())
        .lte('appointment_time', end.toIso8601String());

    final total         = (appts as List).length;
    final patientVisits = {for (final a in appts) a['patient_id']: true}.length;

    // New patients this period — a simple heuristic
    final newPatients = await _supabase
        .from('users')
        .select('id')
        .eq('role', 'patient')
        .contains('doctor_ids', [_uid])
        .gte('created_at', start.toIso8601String())
        .lte('created_at', end.toIso8601String());

    return {
      'total':         total,
      'patientVisits': patientVisits,
      'newPatients':   (newPatients as List).length,
      'byTherapist':   [{'name': 'You', 'sessions': total}],
    };
  }

  // ── Period helpers ────────────────────────────────────────────────────────

  ({DateTime start, DateTime end, DateTime prevStart, DateTime prevEnd,
    String label}) _periodDates() {
    final now = DateTime.now();
    final DateTime start, end, prevStart, prevEnd;
    String label;

    switch (_period) {
      case 'weekly':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        start     = DateTime(weekStart.year, weekStart.month, weekStart.day);
        end       = start.add(const Duration(days: 6, hours: 23, minutes: 59));
        prevStart = start.subtract(const Duration(days: 7));
        prevEnd   = end.subtract(const Duration(days: 7));
        label     = 'Week of ${DateFormat('MMM d').format(start)}';
      case 'quarterly':
        final q       = ((now.month - 1) ~/ 3);
        start         = DateTime(now.year, q * 3 + 1, 1);
        end           = DateTime(now.year, q * 3 + 4, 0, 23, 59, 59);
        prevStart     = DateTime(now.year, (q - 1) * 3 + 1, 1);
        prevEnd       = DateTime(now.year, q * 3, 0, 23, 59, 59);
        label         = 'Q${q + 1} ${now.year}';
      case 'yearly':
        start         = DateTime(now.year, 1, 1);
        end           = DateTime(now.year, 12, 31, 23, 59, 59);
        prevStart     = DateTime(now.year - 1, 1, 1);
        prevEnd       = DateTime(now.year - 1, 12, 31, 23, 59, 59);
        label         = '${now.year}';
      default: // monthly
        start         = DateTime(now.year, now.month, 1);
        end           = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        prevStart     = DateTime(now.year, now.month - 1, 1);
        prevEnd       = DateTime(now.year, now.month, 0, 23, 59, 59);
        label         = DateFormat('MMMM yyyy').format(now);
    }

    return (
      start: start, end: end,
      prevStart: prevStart, prevEnd: prevEnd,
      label: label,
    );
  }

  // ── Analyze ───────────────────────────────────────────────────────────────

  Future<void> _analyze() async {
    setState(() { _loading = true; _error = null; _result = null; });

    try {
      final pd = _periodDates();

      final revData  = await _buildRevenueData(pd.start, pd.end, pd.prevStart, pd.prevEnd);
      final expData  = await _buildExpenseData(pd.start, pd.end, pd.prevStart, pd.prevEnd);
      final sessData = await _buildSessionData(pd.start, pd.end);

      final aiResult = await AiDoctorAssistantService.analyzeClinicPerformance(
        period:     _period,
        dateRange:  pd.label,
        revenue:    revData,
        expenses:   expData,
        sessions:   sessData,
        userPrompt: _promptCtrl.text.trim().isEmpty ? null : _promptCtrl.text.trim(),
      );

      if (!mounted) return;

      if (!aiResult.isSuccess) {
        setState(() { _error = aiResult.error; _loading = false; });
        return;
      }

      setState(() {
        _result  = aiResult.data;
        _usage   = aiResult.usage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Failed to collect data: $e'; _loading = false; });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insights_rounded,
                      color: _kPrimary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Business Analytics',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('AI-powered clinic insights',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (_usage != null)
                  Text(_usage!.label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ),
            const Divider(height: 1),
            _buildAiDisclaimer(),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [
                  _buildControls(),
                  const SizedBox(height: 16),
                  if (_loading)  _buildLoading()
                  else if (_error != null) _buildError()
                  else if (_result != null) _buildResult(_result!)
                  else _buildEmpty(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Widget _buildAiDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFFFFF8E1),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFF57F17)),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'AI outputs are not professional financial or medical advice. '
              'Always verify insights against your own records.',
              style: TextStyle(fontSize: 11, color: Color(0xFF6D4C41), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period selector
        Wrap(spacing: 8, children: [
          for (final p in ['weekly', 'monthly', 'quarterly', 'yearly'])
            GestureDetector(
              onTap: () => setState(() => _period = p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _period == p ? _kPrimary : const Color(0xFFF0F4FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  p[0].toUpperCase() + p.substring(1),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _period == p
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        // Optional custom question
        TextField(
          controller: _promptCtrl,
          decoration: InputDecoration(
            hintText: 'Optional: ask a specific question (e.g. "Why did revenue drop?")',
            hintStyle: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.question_answer_outlined,
                color: AppColors.textSecondary, size: 18),
            filled: true,
            fillColor: const Color(0xFFF0F4FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
          ),
          style: const TextStyle(fontSize: 13),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        // Quick prompt chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _kPrompts.map((p) => GestureDetector(
              onTap: () {
                _promptCtrl.text = p;
                setState(() {});
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _kPrimary.withValues(alpha: 0.3)),
                ),
                child: Text(p,
                    style: TextStyle(
                        color: _kPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: _loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(
              _loading ? 'Analyzing…' : 'Analyze Clinic Performance',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold),
            ),
            onPressed: _loading ? null : _analyze,
          ),
        ),
      ],
    );
  }

  // ── States ─────────────────────────────────────────────────────────────────

  Widget _buildLoading() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 40),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Collecting data and generating insights…',
            style: TextStyle(color: AppColors.textSecondary)),
      ]),
    ),
  );

  Widget _buildError() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEBEE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.error_outline_rounded,
          color: AppColors.error, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(_error!,
            style: const TextStyle(
                color: AppColors.error, fontSize: 13)),
      ),
    ]),
  );

  Widget _buildEmpty() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.insights_outlined,
            size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('Select a period and tap Analyze',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 4),
        Text('AI will review your revenues, expenses and sessions.',
            style: TextStyle(
                color: Colors.grey.shade400, fontSize: 12)),
      ]),
    ),
  );

  Widget _buildResult(ClinicAnalyticsResult r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary card
        if (r.summary.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kPrimary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.summarize_rounded,
                      color: _kPrimary, size: 16),
                  const SizedBox(width: 6),
                  Text('Executive Summary',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _kPrimary)),
                ]),
                const SizedBox(height: 8),
                Text(r.summary,
                    style: const TextStyle(
                        fontSize: 14, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Key insights
        if (r.keyInsights.isNotEmpty) ...[
          _sectionHeader('Key Insights', Icons.lightbulb_outline_rounded,
              const Color(0xFF1565C0)),
          const SizedBox(height: 8),
          ...r.keyInsights.map((insight) =>
              _bulletCard(insight, const Color(0xFFE3F2FD),
                  const Color(0xFF1565C0), Icons.chevron_right_rounded)),
          const SizedBox(height: 16),
        ],

        // Warnings
        if (r.warnings.isNotEmpty) ...[
          _sectionHeader('Warnings', Icons.warning_amber_rounded,
              const Color(0xFFE65100)),
          const SizedBox(height: 8),
          ...r.warnings.map((w) =>
              _bulletCard(w, const Color(0xFFFFF3E0),
                  const Color(0xFFE65100), Icons.warning_amber_rounded)),
          const SizedBox(height: 16),
        ],

        // Opportunities
        if (r.opportunities.isNotEmpty) ...[
          _sectionHeader('Opportunities', Icons.trending_up_rounded,
              const Color(0xFF2E7D32)),
          const SizedBox(height: 8),
          ...r.opportunities.map((o) =>
              _bulletCard(o, const Color(0xFFE8F5E9),
                  const Color(0xFF2E7D32), Icons.trending_up_rounded)),
          const SizedBox(height: 16),
        ],

        // Recommendations
        if (r.recommendations.isNotEmpty) ...[
          _sectionHeader('Recommendations', Icons.recommend_rounded,
              const Color(0xFF6A1B9A)),
          const SizedBox(height: 8),
          ...r.recommendations.asMap().entries.map((e) =>
              _bulletCard(
                '${e.key + 1}. ${e.value}',
                const Color(0xFFF3E5F5),
                const Color(0xFF6A1B9A),
                Icons.task_alt_rounded,
              )),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) => Row(
    children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 6),
      Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color)),
    ],
  );

  Widget _bulletCard(
      String text, Color bg, Color accent, IconData icon) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ),
          ],
        ),
      );
}
