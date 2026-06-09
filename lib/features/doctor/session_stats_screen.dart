import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';

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

  String   _period  = 'monthly';
  DateTime _refDate = DateTime.now();

  // ── Period helpers ──────────────────────────────────────────────────────

  DateTime get _start {
    final r = _refDate;
    return switch (_period) {
      'daily'  => DateTime(r.year, r.month, r.day),
      'weekly' => () {
          final m = r.subtract(Duration(days: r.weekday - 1));
          return DateTime(m.year, m.month, m.day);
        }(),
      'yearly' => DateTime(r.year, 1, 1),
      _        => DateTime(r.year, r.month, 1),
    };
  }

  DateTime get _end {
    final r = _refDate;
    return switch (_period) {
      'daily'  => DateTime(r.year, r.month, r.day, 23, 59, 59),
      'weekly' => () {
          final m = r.subtract(Duration(days: r.weekday - 1));
          final s = DateTime(m.year, m.month, m.day);
          final e = s.add(const Duration(days: 6));
          return DateTime(e.year, e.month, e.day, 23, 59, 59);
        }(),
      'yearly' => DateTime(r.year, 12, 31, 23, 59, 59),
      _        => DateTime(r.year, r.month + 1, 0, 23, 59, 59),
    };
  }

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

              final totalIncome   = paidIncome + pendingIncome;
              final totalExpenses = paidExpenses + pendingExpenses;
              final netProfit     = paidIncome - paidExpenses;

              // ── Payment methods breakdown ─────────────────────────────
              final methods = <String, int>{};
              for (final inv in invoices) {
                final pm = (inv['payment_method'] as String?)
                               ?.replaceAll('_', ' ')
                               .toTitleCase() ?? 'Cash';
                methods[pm] = (methods[pm] ?? 0) + 1;
              }

              // ── Sessions by day (for bar chart) ───────────────────────
              final days = _end.difference(_start).inDays + 1;
              final sessionsByDay = List<int>.filled(days, 0);
              for (final appt in appts) {
                final tsStr = appt['appointment_time'] as String?;
                if (tsStr == null) continue;
                final idx = DateTime.parse(tsStr).difference(_start).inDays;
                if (idx >= 0 && idx < days) sessionsByDay[idx]++;
              }

              return _buildBody(
                sessions:        sessions,
                paidIncome:      paidIncome,
                pendingIncome:   pendingIncome,
                totalIncome:     totalIncome,
                paidExpenses:    paidExpenses,
                pendingExpenses: pendingExpenses,
                totalExpenses:   totalExpenses,
                netProfit:       netProfit,
                methods:         methods,
                sessionsByDay:   sessionsByDay,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required int sessions,
    required double paidIncome,
    required double pendingIncome,
    required double totalIncome,
    required double paidExpenses,
    required double pendingExpenses,
    required double totalExpenses,
    required double netProfit,
    required Map<String, int> methods,
    required List<int> sessionsByDay,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              Expanded(child: _kpi(
                label:   'Sessions',
                value:   sessions.toString(),
                icon:    Icons.event_note_rounded,
                iconBg:  const Color(0xFFE3F2FD),
                iconClr: const Color(0xFF1565C0),
              )),
              const SizedBox(width: 10),
              Expanded(child: _kpi(
                label:   'Income',
                value:   '\$${totalIncome.toStringAsFixed(0)}',
                icon:    Icons.trending_up_rounded,
                iconBg:  const Color(0xFFE8F5E9),
                iconClr: _green,
                sub:     '\$${paidIncome.toStringAsFixed(0)} paid',
              )),
              const SizedBox(width: 10),
              Expanded(child: _kpi(
                label:   'Expenses',
                value:   '\$${totalExpenses.toStringAsFixed(0)}',
                icon:    Icons.trending_down_rounded,
                iconBg:  const Color(0xFFFFEBEE),
                iconClr: _red,
                sub:     '\$${paidExpenses.toStringAsFixed(0)} paid',
              )),
              const SizedBox(width: 10),
              Expanded(child: _kpi(
                label:   'Net Profit',
                value:   '\$${netProfit.toStringAsFixed(0)}',
                icon:    netProfit >= 0
                             ? Icons.account_balance_wallet_rounded
                             : Icons.warning_amber_rounded,
                iconBg:  netProfit >= 0
                             ? const Color(0xFFE0F2F1)
                             : const Color(0xFFFFF3E0),
                iconClr: netProfit >= 0 ? const Color(0xFF00695C) : _amber,
                valueClr: netProfit >= 0 ? _green : _red,
              )),
            ]),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _sessionsChart(sessionsByDay),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _incomeExpensesCard(
              paidIncome:      paidIncome,
              pendingIncome:   pendingIncome,
              paidExpenses:    paidExpenses,
              pendingExpenses: pendingExpenses,
              netProfit:       netProfit,
            ),
          ),
          const SizedBox(height: 16),
          if (methods.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _paymentMethodsCard(methods, invoiceCount: methods.values.fold(0, (a, b) => a + b)),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Header with period selector ──────────────────────────────────────────

  Widget _buildHeader() {
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
            const Text('Statistics',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
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
          Row(children: ['daily', 'weekly', 'monthly', 'yearly']
              .map((p) {
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
                  p[0].toUpperCase() + p.substring(1),
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

  // ── KPI card ──────────────────────────────────────────────────────────────

  Widget _kpi({
    required String  label,
    required String  value,
    required IconData icon,
    required Color   iconBg,
    required Color   iconClr,
    String?          sub,
    Color?           valueClr,
  }) {
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconClr, size: 18),
          ),
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
        ],
      ),
    );
  }

  // ── Sessions bar chart ────────────────────────────────────────────────────

  Widget _sessionsChart(List<int> sessionsByDay) {
    final activeDays = sessionsByDay.asMap().entries
        .where((e) => e.value > 0)
        .toList();

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
          const Row(children: [
            Icon(Icons.event_note_rounded, size: 16, color: _navy),
            SizedBox(width: 6),
            Text('Sessions per Day',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _navy)),
          ]),
          const SizedBox(height: 16),
          activeDays.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No sessions in this period',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: activeDays.map((e) {
                    final date = _start.add(Duration(days: e.key));
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${e.value}',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1565C0)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('d MMM').format(date),
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  // ── Income vs Expenses card ───────────────────────────────────────────────

  Widget _incomeExpensesCard({
    required double paidIncome,
    required double pendingIncome,
    required double paidExpenses,
    required double pendingExpenses,
    required double netProfit,
  }) {
    final totalIncome   = paidIncome + pendingIncome;
    final totalExpenses = paidExpenses + pendingExpenses;

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
          const Row(children: [
            Icon(Icons.account_balance_rounded, size: 16, color: _navy),
            SizedBox(width: 6),
            Text('Financial Breakdown',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _navy)),
          ]),
          const SizedBox(height: 16),
          _financeRow(
            label:   'Income',
            total:   totalIncome,
            paid:    paidIncome,
            pending: pendingIncome,
            color:   _green,
            bgColor: const Color(0xFFE8F5E9),
            icon:    Icons.arrow_upward_rounded,
          ),
          const SizedBox(height: 12),
          _financeRow(
            label:   'Expenses',
            total:   totalExpenses,
            paid:    paidExpenses,
            pending: pendingExpenses,
            color:   _red,
            bgColor: const Color(0xFFFFEBEE),
            icon:    Icons.arrow_downward_rounded,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF0F4FA)),
          ),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: netProfit >= 0
                    ? const Color(0xFFE0F2F1)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color:
                    netProfit >= 0 ? const Color(0xFF00695C) : _amber,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Net Profit',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14))),
            Text(
              '\$${netProfit.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: netProfit >= 0 ? _green : _red),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _financeRow({
    required String  label,
    required double  total,
    required double  paid,
    required double  pending,
    required Color   color,
    required Color   bgColor,
    required IconData icon,
  }) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Row(children: [
            _dot(_green),
            const SizedBox(width: 4),
            Text('\$${paid.toStringAsFixed(0)} paid',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(width: 10),
            _dot(_amber),
            const SizedBox(width: 4),
            Text('\$${pending.toStringAsFixed(0)} pending',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ]),
      ),
      Text('\$${total.toStringAsFixed(2)}',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color)),
    ]);
  }

  Widget _dot(Color c) => Container(
      width: 6, height: 6,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  // ── Payment methods card ──────────────────────────────────────────────────

  Widget _paymentMethodsCard(
      Map<String, int> methods, {required int invoiceCount}) {
    final sorted = methods.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF00897B),
      const Color(0xFFE53935),
      const Color(0xFF7B1FA2),
      const Color(0xFFF57C00),
    ];

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
          const Row(children: [
            Icon(Icons.credit_card_rounded, size: 16, color: _navy),
            SizedBox(width: 6),
            Text('Payment Methods',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _navy)),
          ]),
          const SizedBox(height: 14),
          ...sorted.asMap().entries.map((entry) {
            final i   = entry.key;
            final e   = entry.value;
            final pct = invoiceCount > 0 ? e.value / invoiceCount : 0.0;
            final clr = colors[i % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _dot(clr),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(e.key,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500))),
                    Text(
                        '${e.value}  ${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation(clr),
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
}

extension _StringExt on String {
  String toTitleCase() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
