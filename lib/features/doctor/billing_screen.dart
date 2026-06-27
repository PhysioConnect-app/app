// ignore_for_file: use_build_context_synchronously

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' as xl;
import '../../core/config/form_factor_features.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/breakpoints.dart';
import '../ai/ai_service.dart';
import '../ai/financial_ai_chat_screen.dart';
import '../ai/clinic_analytics_sheet.dart';
import '../../core/widgets/patient_search_field.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/language_provider.dart';
import '../../core/utils/file_saver.dart';

// ── Status helpers ─────────────────────────────────────────────────────────

enum _InvStatus { pending, paid, partiallyPaid, cancelled, awaitingReview }

extension _InvStatusX on _InvStatus {
  String get key => switch (this) {
    _InvStatus.pending        => 'pending',
    _InvStatus.paid           => 'paid',
    _InvStatus.partiallyPaid  => 'partially_paid',
    _InvStatus.cancelled      => 'cancelled',
    _InvStatus.awaitingReview => 'awaiting_review',
  };
  String label(AppStrings s) => switch (this) {
    _InvStatus.pending        => s.statusPending,
    _InvStatus.paid           => s.statusPaid,
    _InvStatus.partiallyPaid  => 'Part. Paid',
    _InvStatus.cancelled      => s.statusCancelled,
    _InvStatus.awaitingReview => 'In Review',
  };
  Color get color => switch (this) {
    _InvStatus.pending        => const Color(0xFFF57F17),
    _InvStatus.paid           => const Color(0xFF2E7D32),
    _InvStatus.partiallyPaid  => const Color(0xFFE65100),
    _InvStatus.cancelled      => const Color(0xFFC62828),
    _InvStatus.awaitingReview => const Color(0xFF1565C0),
  };

  static _InvStatus fromString(String? raw) =>
      switch (raw?.toLowerCase().trim()) {
        'paid'            => _InvStatus.paid,
        'partially_paid'  => _InvStatus.partiallyPaid,
        'cancelled'       => _InvStatus.cancelled,
        'awaiting_review' => _InvStatus.awaitingReview,
        _                 => _InvStatus.pending,
      };
}

// ── Screen ─────────────────────────────────────────────────────────────────

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key, this.invoiceStream});

  /// Overrides the Supabase realtime stream. Provided in tests to inject
  /// deterministic invoice data without a live Supabase connection.
  @visibleForTesting
  final Stream<List<Map<String, dynamic>>>? invoiceStream;

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  static const _kAccent  = Color(0xFF0E8378); // income teal
  static const _kSuccess = Color(0xFF2E7D32);
  static const _kWarning = Color(0xFFF57F17);
  static const _kDanger  = Color(0xFFC62828);

  final _supabase = Supabase.instance.client;
  final _uid = Supabase.instance.client.auth.currentUser!.id;

  String   _period  = 'monthly';
  DateTime _refDate = DateTime.now();
  String   _patientFilter = '';
  String?  _statusFilter;
  bool     _aiLoading = false;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncPastAppointments();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncPastAppointments() async {
    final now = DateTime.now().toIso8601String();
    final appts = await _supabase
        .from('appointments')
        .select()
        .eq('doctor_id', _uid)
        .neq('status', 'cancelled')
        .lt('appointment_time', now);

    if ((appts as List).isEmpty) return;

    final existing = await _supabase
        .from('invoices')
        .select('appointment_id')
        .eq('doctor_id', _uid)
        .not('appointment_id', 'is', null);

    final existingIds = <String>{
      for (final e in existing as List)
        if (e['appointment_id'] != null) e['appointment_id'] as String,
    };

    for (final appt in appts) {
      final apptId = appt['id'] as String?;
      if (apptId == null || existingIds.contains(apptId)) continue;
      await _supabase.from('invoices').insert({
        'doctor_id':      _uid,
        'patient_id':     appt['patient_id'],
        'patient_name':   appt['patient_name'],
        'service':        (appt['notes'] as String?)?.isNotEmpty == true
                              ? appt['notes']
                              : 'Physical Therapy',
        'amount':         0,
        'currency':       'USD',
        'status':         'awaiting_review',
        'appointment_id': apptId,
        'invoice_date':   appt['appointment_time'],
        'created_at':     DateTime.now().toIso8601String(),
      });
    }
  }

  // ── Period helpers ──────────────────────────────────────────────────────

  DateTime get _start {
    final r = _refDate;
    return switch (_period) {
      'daily'   => DateTime(r.year, r.month, r.day),
      'weekly'  => () {
                     final m = r.subtract(Duration(days: r.weekday - 1));
                     return DateTime(m.year, m.month, m.day);
                   }(),
      'yearly'  => DateTime(r.year, 1, 1),
      _         => DateTime(r.year, r.month, 1),
    };
  }

  DateTime get _end {
    final r = _refDate;
    return switch (_period) {
      'daily'   => DateTime(r.year, r.month, r.day, 23, 59, 59),
      'weekly'  => () {
                     final m = r.subtract(Duration(days: r.weekday - 1));
                     final s = DateTime(m.year, m.month, m.day);
                     final e = s.add(const Duration(days: 6));
                     return DateTime(e.year, e.month, e.day, 23, 59, 59);
                   }(),
      'yearly'  => DateTime(r.year, 12, 31, 23, 59, 59),
      _         => DateTime(r.year, r.month + 1, 0, 23, 59, 59),
    };
  }

  String get _rangeLabel {
    final s = _start;
    final e = _end;
    return switch (_period) {
      'daily'  => DateFormat('MMM d, yyyy').format(s),
      'yearly' => '${s.year}',
      'monthly' => DateFormat('MMM yyyy').format(s),
      _        => s.month == e.month
          ? '${DateFormat('MMM d').format(s)} – ${e.day}'
          : '${DateFormat('MMM d').format(s)} – ${DateFormat('MMM d').format(e)}',
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

  List<Map<String, dynamic>> _inPeriod(List<Map<String, dynamic>> docs) {
    final s = _start;
    final e = _end;
    return docs.where((d) {
      final tsStr = d['invoice_date'] as String? ?? d['created_at'] as String?;
      if (tsStr == null) return false;
      final dt = DateTime.parse(tsStr);

      if (dt.isBefore(s) || dt.isAfter(e)) return false;

      if (_patientFilter.isNotEmpty) {
        final patName = (d['patient_name'] as String? ?? '').toLowerCase();
        if (!patName.contains(_patientFilter.toLowerCase())) return false;
      }

      if (_statusFilter != null) {
        final status = (d['status'] as String? ?? 'pending').toLowerCase().trim();
        if (status != _statusFilter) return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        final taStr = a['invoice_date'] as String? ?? a['created_at'] as String?;
        final tbStr = b['invoice_date'] as String? ?? b['created_at'] as String?;
        final ta = taStr != null ? DateTime.parse(taStr) : DateTime(2000);
        final tb = tbStr != null ? DateTime.parse(tbStr) : DateTime(2000);
        return tb.compareTo(ta);
      });
  }

  // ── Firestore actions ───────────────────────────────────────────────────

  Future<void> _updateStatus(String id, _InvStatus s) =>
      _supabase.from('invoices').update({'status': s.key}).eq('id', id);

  // ── Add Invoice form ────────────────────────────────────────────────────

  void _showAddInvoice(AppStrings s) {
    String? patId, patName;
    _InvStatus status = _InvStatus.pending;
    DateTime invDate  = DateTime.now();
    final amtCtrl     = TextEditingController();
    final svcCtrl     = TextEditingController();
    final noteCtrl    = TextEditingController();
    final paidAmtCtrl = TextEditingController();
    final patientSearchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.newInvoice,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              // Patient
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _supabase
                    .from('users')
                    .stream(primaryKey: ['id'])
                    .eq('role', 'patient')
                    .map((list) => list.where((r) {
                          final ids = (r['doctor_ids'] as List?)?.cast<String>() ?? [];
                          return ids.contains(_uid);
                        }).toList()),
                builder: (_, snap) {
                  final pats = snap.data ?? [];
                  return PatientSearchField(
                    patients: pats,
                    labelText: s.selectPatient,
                    controller: patientSearchCtrl,
                    onSelected: (id, name) {
                      set(() {
                        patId   = id;
                        patName = name;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 10),
              // Service
              TextField(
                controller: svcCtrl,
                decoration: InputDecoration(
                  labelText: 'Service (e.g. Physical Therapy)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              // Date
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: invDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) set(() => invDate = d);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Invoice Date',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true, fillColor: Colors.white,
                    suffixIcon: const Icon(Icons.calendar_today_rounded,
                        color: AppColors.primary),
                  ),
                  child: Text(DateFormat('MMM d, yyyy').format(invDate)),
                ),
              ),
              const SizedBox(height: 10),
              // Amount (USD)
              TextField(
                controller: amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${s.amount} (USD)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              // Status
              DropdownButtonFormField<_InvStatus>(
                initialValue: status,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: Colors.white,
                ),
                items: [_InvStatus.pending, _InvStatus.paid,
                        _InvStatus.partiallyPaid].map((st) =>
                  DropdownMenuItem<_InvStatus>(
                    value: st,
                    child: Text(st.label(s)),
                  )).toList(),
                onChanged: (v) => set(() => status = v!),
              ),
              // Partially paid sub-fields
              if (status == _InvStatus.partiallyPaid) ...[
                const SizedBox(height: 10),
                StatefulBuilder(
                  builder: (ctx2, set2) {
                    final total = double.tryParse(amtCtrl.text.trim()) ?? 0;
                    final paid  = double.tryParse(paidAmtCtrl.text.trim()) ?? 0;
                    final remaining = (total - paid).clamp(0, double.infinity);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: paidAmtCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => set2(() {}),
                          decoration: InputDecoration(
                            labelText: 'Amount Paid',
                            prefixIcon: const Icon(Icons.payments_rounded,
                                color: Color(0xFFE65100)),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            filled: true, fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.account_balance_wallet_outlined,
                                size: 16, color: Color(0xFFE65100)),
                            const SizedBox(width: 6),
                            Text('Remaining: USD ${remaining.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFFE65100))),
                          ]),
                        ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 10),
              // Note
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.receipt_rounded),
                  label: Text(s.createInvoice,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final amt = double.tryParse(amtCtrl.text.trim());
                    if (patId == null || amt == null || amt <= 0) return;
                    final paidAmt = double.tryParse(paidAmtCtrl.text.trim());
                    final data = <String, dynamic>{
                      'doctor_id':    _uid,
                      'patient_id':   patId,
                      'patient_name': patName,
                      'service':     svcCtrl.text.trim().isEmpty
                                         ? 'Physical Therapy'
                                         : svcCtrl.text.trim(),
                      'amount':      amt,
                      'currency':    'USD',
                      'status':      status.key,
                      'note':        noteCtrl.text.trim(),
                      'invoice_date': invDate.toIso8601String(),
                      'created_at':   DateTime.now().toIso8601String(),
                    };
                    if (status == _InvStatus.partiallyPaid && paidAmt != null) {
                      data['paid_amount'] = paidAmt;
                    }
                    await _supabase.from('invoices').insert(data);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(s.invoiceCreated),
                      backgroundColor: AppColors.success,
                    ));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mark partially paid sheet ─────────────────────────────────────────────

  void _showMarkPartialSheet(String docId, double totalAmt) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, set) {
            final paid      = double.tryParse(ctrl.text) ?? 0;
            final remaining = (totalAmt - paid).clamp(0, double.infinity);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mark as Partially Paid',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Total: USD ${totalAmt.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => set(() {}),
                  decoration: InputDecoration(
                    labelText: 'Amount Paid',
                    prefixIcon: const Icon(Icons.payments_rounded,
                        color: Color(0xFFE65100)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true, fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 16, color: Color(0xFFE65100)),
                    const SizedBox(width: 6),
                    Text(
                        'Remaining: USD ${remaining.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFFE65100))),
                  ]),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final paidAmt = double.tryParse(ctrl.text.trim());
                      if (paidAmt == null || paidAmt <= 0) return;
                      await _supabase.from('invoices').update({
                        'status':      _InvStatus.partiallyPaid.key,
                        'paid_amount': paidAmt,
                      }).eq('id', docId);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Doctor review sheet ───────────────────────────────────────────────────

  void _showReviewSheet(Map<String, dynamic> doc) {
    final docId   = doc['id'] as String;
    final patName = (doc['patient_name'] as String?) ?? 'Patient';
    final existingAmt = (doc['amount'] as num?)?.toDouble() ?? 0;
    final existingCurrency = (doc['currency'] as String?) ?? 'USD';

    _InvStatus selectedStatus = _InvStatus.pending;
    String currency = existingCurrency;
    final amtCtrl  = TextEditingController(
        text: existingAmt > 0 ? existingAmt.toStringAsFixed(2) : '');
    final svcCtrl  = TextEditingController(
        text: (doc['service'] as String?) ?? 'Physical Therapy');
    final noteCtrl = TextEditingController(
        text: (doc['note'] as String?) ?? '');
    final paidCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Future<void> applyStatus(_InvStatus st) async {
            final amt = double.tryParse(amtCtrl.text.trim());
            if (amt == null || amt <= 0) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Please enter a valid amount.')));
              return;
            }
            final update = <String, dynamic>{
              'status':   st.key,
              'amount':   amt,
              'currency': currency,
              'service':  svcCtrl.text.trim().isEmpty
                              ? 'Physical Therapy'
                              : svcCtrl.text.trim(),
              'note':     noteCtrl.text.trim(),
            };
            if (st == _InvStatus.partiallyPaid) {
              final paidAmt = double.tryParse(paidCtrl.text.trim());
              if (paidAmt == null || paidAmt <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Please enter the amount paid.')));
                return;
              }
              update['paid_amount'] = paidAmt;
            } else {
              update['paid_amount'] = null;
            }
            await _supabase.from('invoices').update(update).eq('id', docId);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
          }
          return Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.rate_review_rounded,
                        color: Color(0xFF1565C0), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Review Session',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(patName,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                // Service
                TextField(
                  controller: svcCtrl,
                  decoration: InputDecoration(
                    labelText: 'Service / Session type',
                    prefixIcon: const Icon(Icons.medical_services_rounded,
                        color: Color(0xFF1565C0), size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFB),
                  ),
                ),
                const SizedBox(height: 12),
                // Amount + currency row
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: amtCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount *',
                        prefixIcon: const Icon(Icons.payments_rounded,
                            color: Color(0xFF1565C0), size: 20),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Currency',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        for (final c in ['USD', 'LBP']) ...[
                          GestureDetector(
                            onTap: () => set(() => currency = c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: currency == c
                                    ? const Color(0xFF1565C0)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: currency == c
                                        ? const Color(0xFF1565C0)
                                        : Colors.grey.shade300),
                              ),
                              child: Text(c,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: currency == c
                                          ? Colors.white
                                          : AppColors.textSecondary)),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ]),
                    ],
                  ),
                ]),
                const SizedBox(height: 12),
                // Note
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: const Icon(Icons.notes_rounded,
                        color: Color(0xFF1565C0), size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFB),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Apply payment status',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final st in [
                    _InvStatus.paid,
                    _InvStatus.partiallyPaid,
                    _InvStatus.pending,
                    _InvStatus.cancelled,
                  ])
                    GestureDetector(
                      onTap: () {
                        if (st == _InvStatus.partiallyPaid) {
                          set(() => selectedStatus = st);
                        } else {
                          applyStatus(st);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedStatus == st
                              ? st.color
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: selectedStatus == st
                                  ? st.color
                                  : Colors.grey.shade300),
                        ),
                        child: Text(
                          st.label(AppStrings(false)).replaceAll('\n', ' '),
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: selectedStatus == st
                                  ? Colors.white
                                  : st.color),
                        ),
                      ),
                    ),
                ]),
                if (selectedStatus == _InvStatus.partiallyPaid) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: paidCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount Paid',
                      prefixIcon: const Icon(Icons.payments_rounded,
                          color: Color(0xFFE65100), size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFB),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _InvStatus.partiallyPaid.color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => applyStatus(_InvStatus.partiallyPaid),
                      child: const Text('Apply Partial Payment',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          );
        },
      ),
    );
  }

  // ── Export to Excel ──────────────────────────────────────────────────────

  Future<void> _showExport(
      List<Map<String, dynamic>> docs, AppStrings s) async {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No records to export.')));
      return;
    }

    final excel = xl.Excel.createExcel();
    excel.rename('Sheet1', 'Income');
    final sheet = excel['Income'];

    sheet.appendRow([
      xl.TextCellValue('Patient Name'),
      xl.TextCellValue('Service'),
      xl.TextCellValue('Date'),
      xl.TextCellValue('Amount'),
      xl.TextCellValue('Currency'),
      xl.TextCellValue('Status'),
      xl.TextCellValue('Note'),
    ]);

    for (final d in docs) {
      final tsStr = d['invoice_date'] as String? ?? d['created_at'] as String?;
      final date = tsStr != null
          ? DateFormat('dd/MM/yyyy').format(DateTime.parse(tsStr))
          : '';
      final paidAmt = (d['paid_amount'] as num?)?.toStringAsFixed(2);
      final amtStr  = (d['amount'] as num?)?.toStringAsFixed(2) ?? '0.00';
      final status  = (d['status'] as String?) ?? 'pending';
      final displayStatus = paidAmt != null && status == 'partially_paid'
          ? 'partially_paid (paid: $paidAmt)'
          : status;
      sheet.appendRow([
        xl.TextCellValue((d['patient_name'] as String?) ?? ''),
        xl.TextCellValue((d['service'] as String?) ?? ''),
        xl.TextCellValue(date),
        xl.TextCellValue(amtStr),
        xl.TextCellValue((d['currency'] as String?) ?? 'USD'),
        xl.TextCellValue(displayStatus),
        xl.TextCellValue((d['note'] as String?) ?? ''),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null || !mounted) return;
    await downloadExcel(Uint8List.fromList(bytes), 'billing_${_period}_export.xlsx');
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<LanguageProvider>().isArabic);

    final isDesktop = MediaQuery.sizeOf(context).width >= kMobileBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFFEBF2FB),
      floatingActionButton: isDesktop
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'billing_fab_analytics',
                  backgroundColor: Colors.white,
                  foregroundColor: _kAccent,
                  elevation: 2,
                  onPressed: () => showClinicAnalyticsSheet(context),
                  tooltip: 'Business Analytics',
                  child: const Icon(Icons.insights_rounded, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  key: const Key('billing_ai_btn'),
                  heroTag: 'billing_fab_chat',
                  backgroundColor: Colors.white,
                  foregroundColor: _kAccent,
                  elevation: 2,
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const FinancialAiChatScreen())),
                  tooltip: 'AI Financial Assistant',
                  child: const Icon(Icons.chat_rounded, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  key: const Key('billing_add_income_btn'),
                  heroTag: 'billing_fab_add',
                  onPressed: () => _showAddInvoice(s),
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New Invoice',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: widget.invoiceStream ??
            _supabase
                .from('invoices')
                .stream(primaryKey: ['id'])
                .eq('doctor_id', _uid)
                .map((list) {
                  final sorted = List<Map<String, dynamic>>.from(list);
                  sorted.sort((a, b) {
                    final aStr = a['created_at'] as String? ?? '';
                    final bStr = b['created_at'] as String? ?? '';
                    return bStr.compareTo(aStr);
                  });
                  return sorted;
                }),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final all      = snap.data ?? [];
          final filtered = _inPeriod(all);

          // ── KPI calculations ────────────────────────────────────────────
          double collected    = 0; // paid amounts + partial-paid portions
          double pendingOnly  = 0; // pending (non-overdue) + remaining partial
          double overdueAmt   = 0; // pending invoices > 30 days old
          int    invoiceCount = 0;
          final  overdueThreshold =
              DateTime.now().subtract(const Duration(days: 30));

          // Count awaiting-review separately so we can show a badge
          final awaitingCount = filtered
              .where((d) => (d['status'] as String?) == 'awaiting_review')
              .length;

          for (final d in filtered) {
            final amt = (d['amount'] as num?)?.toDouble() ?? 0;
            final st  = _InvStatusX.fromString(d['status'] as String?);
            // Awaiting review and cancelled are excluded from financial stats
            if (st == _InvStatus.cancelled ||
                st == _InvStatus.awaitingReview) { continue; }
            invoiceCount++;
            switch (st) {
              case _InvStatus.paid:
                collected += amt;
              case _InvStatus.partiallyPaid:
                final paidAmt = (d['paid_amount'] as num?)?.toDouble() ?? 0;
                collected   += paidAmt;
                pendingOnly += (amt - paidAmt).clamp(0, double.infinity);
              case _InvStatus.pending:
                final dateStr = d['invoice_date'] as String? ??
                    d['created_at'] as String?;
                final dt = dateStr != null
                    ? DateTime.parse(dateStr)
                    : DateTime.now();
                if (dt.isBefore(overdueThreshold)) {
                  overdueAmt += amt;
                } else {
                  pendingOnly += amt;
                }
              case _InvStatus.cancelled:
              case _InvStatus.awaitingReview:
                break;
            }
          }

          final pendingTotal = pendingOnly;
          final invoiced     = collected + pendingTotal + overdueAmt;

          return LayoutBuilder(
            builder: (ctx, constraints) {
              return Column(
                children: [
                  _summaryBand(
                    s,
                    collected: collected,
                    pending: pendingTotal,
                    overdue: overdueAmt,
                    invoiced: invoiced,
                    invoiceCount: invoiceCount,
                    awaitingCount: awaitingCount,
                    isDesktop: isDesktop,
                  ),
                  _filterBar(s, isDesktop: isDesktop),
                  Expanded(
                    child: isDesktop
                      ? _desktopTable(filtered, s)
                      : _narrowLayout(s, filtered),
                  ),
                  _bottomBar(s, filtered, isDesktop: isDesktop),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── Filter bar ───────────────────────────────────────────────────────────────

  Widget _filterBar(AppStrings s, {bool isDesktop = false}) {
    // ── reusable sub-widgets ──────────────────────────────────────────────────
    Widget periodPicker() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('billing_period_dropdown'),
          value: _period,
          dropdownColor: _kAccent,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
          items: ['daily', 'weekly', 'monthly', 'yearly'].map((p) =>
            DropdownMenuItem(
              value: p,
              child: Row(children: [
                const Icon(Icons.calendar_month_rounded,
                    color: Colors.white, size: 14),
                const SizedBox(width: 5),
                Text(p[0].toUpperCase() + p.substring(1),
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ]),
            )).toList(),
          onChanged: (v) => setState(() => _period = v!),
        ),
      ),
    );

    Widget datePicker() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: _prev,
          child: const Icon(Icons.chevron_left_rounded,
              color: _kAccent, size: 18)),
        const SizedBox(width: 6),
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
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_month_rounded, color: _kAccent, size: 13),
            const SizedBox(width: 3),
            Text(_rangeLabel,
                style: const TextStyle(
                    color: _kAccent, fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: _next,
          child: const Icon(Icons.chevron_right_rounded,
              color: _kAccent, size: 18)),
      ]),
    );

    Widget searchField() => TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _patientFilter = v),
      decoration: InputDecoration(
        hintText: 'Search patient...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        prefixIcon: const Icon(Icons.search_rounded,
            color: Colors.white, size: 16),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      style: const TextStyle(color: Colors.white, fontSize: 13),
    );

    Widget statusFilter() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _statusFilter,
          dropdownColor: _kAccent,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
          items: [null, 'awaiting_review', 'pending', 'paid',
                  'partially_paid', 'cancelled']
              .map((st) => DropdownMenuItem(
                value: st,
                child: Row(children: [
                  const Icon(Icons.filter_list_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    st == null ? 'All' : st.replaceAll('_', ' '),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ]),
              )).toList(),
          onChanged: (v) => setState(() => _statusFilter = v),
        ),
      ),
    );

    // ── layout ───────────────────────────────────────────────────────────────
    if (isDesktop) {
      // Single compact row — saves ~52 px vs the two-row mobile layout
      return Container(
        color: _kAccent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(children: [
          periodPicker(),
          const SizedBox(width: 10),
          datePicker(),
          const SizedBox(width: 10),
          Expanded(child: searchField()),
          const SizedBox(width: 8),
          statusFilter(),
        ]),
      );
    }

    // Mobile: two rows
    return Container(
      color: _kAccent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(children: [periodPicker(), const Spacer(), datePicker()]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: searchField()),
            const SizedBox(width: 8),
            statusFilter(),
          ]),
        ],
      ),
    );
  }

  // ── Desktop table (full-width, no sidebar) ───────────────────────────────
  //
  // Layout: Material (elevation + clip) → Column → [teal header, Expanded(body)].
  // The Expanded sits inside the Column that is directly inside Padding, which
  // receives a tight height from the outer Expanded in build(). This avoids the
  // unbounded-height RenderFlex error that occurred when Expanded was nested
  // inside a Card's internal Column (Card adds a Container(margin:…) wrapper
  // that can break tight-constraint propagation).

  Widget _desktopTable(List<Map<String, dynamic>> filtered, AppStrings s) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: _kAccent,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(14)),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(children: [
                  _th('Patient Name', flex: 3),
                  _th('Date',         flex: 2),
                  _th('Service',      flex: 3),
                  _th('Amount',       flex: 2),
                  _th('Status',       flex: 2),
                  const SizedBox(width: 32),
                ]),
              ),
              if (filtered.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 50, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text(s.noData,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF0F4FA)),
                    itemBuilder: (_, i) => _tableRow(filtered[i], i, s),
                  ),
                ),
            ],
          ),
        ),
      );

  // ── Narrow layout (mobile compact cards) ─────────────────────────────────

  Widget _narrowLayout(AppStrings s, List<Map<String, dynamic>> filtered) {
    if (filtered.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(s.noData,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 4),
          Text('No invoices in this period',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ]),
      );
    }

    // Group invoices by calendar date (list is already newest-first).
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final inv in filtered) {
      final tsStr = inv['invoice_date'] as String? ?? inv['created_at'] as String?;
      final key = tsStr != null
          ? DateFormat('MMM d, yyyy').format(DateTime.parse(tsStr))
          : 'Unknown';
      groups.putIfAbsent(key, () => []).add(inv);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${filtered.length} invoice${filtered.length == 1 ? '' : 's'}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500),
          ),
        ),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Row(children: [
              Container(
                width: 3, height: 13,
                decoration: BoxDecoration(
                    color: _kAccent,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 7),
              Text(entry.key,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.2)),
            ]),
          ),
          for (final inv in entry.value) ...[
            _compactInvoiceCard(inv, s),
            const SizedBox(height: 6),
          ],
        ],
      ],
    );
  }

  Widget _th(String label, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      );

  Widget _tableRow(Map<String, dynamic> d, int index, AppStrings s) {
    final name = (d['patient_name'] as String?) ?? 'Patient';
    final tsStr = d['invoice_date'] as String? ?? d['created_at'] as String?;
    final date = tsStr != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(tsStr))
        : '—';
    final svc   = (d['service'] as String?) ?? 'Physical Therapy';
    final amt   = (d['amount'] as num?)?.toDouble() ?? 0;
    final st    = _InvStatusX.fromString(d['status'] as String?);
    final bg    = index.isEven ? Colors.white : const Color(0xFFF8FAFF);
    final docId = d['id'] as String;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(children: [
        Expanded(flex: 3,
          child: Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(flex: 2,
          child: Text(date,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13))),
        Expanded(flex: 3,
          child: Text(svc,
              style: const TextStyle(fontSize: 13))),
        Expanded(flex: 2,
          child: Text(_fmtAmt(amt),
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13))),
        Expanded(flex: 2,
          child: _statusBadge(st, s)),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              color: Colors.grey.shade400, size: 18),
          onSelected: (v) async {
            if (v == '__edit__') {
              _showEditInvoice(d, s);
              return;
            }
            if (v == '__review__') {
              _showReviewSheet(d);
              return;
            }
            if (v == '__partial__') {
              _showMarkPartialSheet(docId, amt);
              return;
            }
            final newSt = _InvStatusX.fromString(v);
            await _updateStatus(docId, newSt);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: '__edit__',
                child: Row(children: [
                  Icon(Icons.edit_rounded,
                      color: Color(0xFF1565C0), size: 18),
                  SizedBox(width: 8),
                  Text('Edit'),
                ])),
            if (st == _InvStatus.awaitingReview)
              const PopupMenuItem(value: '__review__',
                  child: Row(children: [
                    Icon(Icons.rate_review_rounded,
                        color: Color(0xFF1565C0), size: 18),
                    SizedBox(width: 8),
                    Text('Review Session',
                        style: TextStyle(
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.bold)),
                  ])),
            if (st != _InvStatus.paid)
              PopupMenuItem(value: _InvStatus.paid.key,
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2E7D32), size: 18),
                    const SizedBox(width: 8),
                    Text(s.markAsPaid),
                  ])),
            if (st != _InvStatus.partiallyPaid)
              const PopupMenuItem(value: '__partial__',
                  child: Row(children: [
                    Icon(Icons.payments_rounded,
                        color: Color(0xFFE65100), size: 18),
                    SizedBox(width: 8),
                    Text('Mark Partially Paid'),
                  ])),
            if (st != _InvStatus.cancelled)
              PopupMenuItem(value: _InvStatus.cancelled.key,
                  child: Row(children: [
                    const Icon(Icons.cancel_rounded,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Text(s.statusCancelled,
                        style: const TextStyle(color: AppColors.error)),
                  ])),
          ],
        ),
      ]),
    );
  }

  Widget _statusBadge(_InvStatus st, AppStrings s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: st.color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(st.label(s),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );

  // ── Compact invoice card (mobile) ─────────────────────────────────────────
  //
  // Layout: [status strip] [icon] [name / date·svc subtext] [amount / badge] [⋮]
  // Amount uses explicit LTR direction so "USD X,XXX.XX" never reverses in RTL.

  Widget _compactInvoiceCard(Map<String, dynamic> d, AppStrings s) {
    final name    = (d['patient_name'] as String?) ?? 'Patient';
    final tsStr   = d['invoice_date'] as String? ?? d['created_at'] as String?;
    final date    = tsStr != null
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(tsStr))
        : '—';
    final svc     = (d['service'] as String?) ?? 'Physical Therapy';
    final amt     = (d['amount'] as num?)?.toDouble() ?? 0;
    final paidAmt = (d['paid_amount'] as num?)?.toDouble();
    final st      = _InvStatusX.fromString(d['status'] as String?);
    final docId   = d['id'] as String;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status color strip
              Container(width: 4, color: st.color),

              // Leading category icon
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: st.color.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.receipt_long_rounded,
                        color: st.color, size: 15),
                  ),
                ),
              ),

              // Primary label + secondary subtext
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 11, 8, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                      const SizedBox(height: 2),
                      Text('$date · $svc',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                      if (st == _InvStatus.partiallyPaid && paidAmt != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Paid: ${_fmtAmt(paidAmt)}  ·  Rem: ${_fmtAmt((amt - paidAmt).clamp(0, double.infinity))}',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFFE65100),
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Trailing: amount (color-coded, LTR-pinned) + status badge
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_fmtAmt(amt),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: st.color)),
                    const SizedBox(height: 4),
                    _statusBadge(st, s),
                  ],
                ),
              ),

              // Actions menu
              Center(
                child: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: Colors.grey.shade400, size: 18),
                  onSelected: (v) async {
                    if (v == '__edit__') {
                      _showEditInvoice(d, s);
                      return;
                    }
                    if (v == '__review__') {
                      _showReviewSheet(d);
                      return;
                    }
                    if (v == '__partial__') {
                      _showMarkPartialSheet(docId, amt);
                      return;
                    }
                    await _updateStatus(docId, _InvStatusX.fromString(v));
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: '__edit__',
                        child: Row(children: [
                          Icon(Icons.edit_rounded,
                              color: Color(0xFF1565C0), size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ])),
                    if (st == _InvStatus.awaitingReview)
                      const PopupMenuItem(value: '__review__',
                          child: Row(children: [
                            Icon(Icons.rate_review_rounded,
                                color: Color(0xFF1565C0), size: 18),
                            SizedBox(width: 8),
                            Text('Review Session',
                                style: TextStyle(
                                    color: Color(0xFF1565C0),
                                    fontWeight: FontWeight.bold)),
                          ])),
                    if (st != _InvStatus.paid)
                      PopupMenuItem(value: _InvStatus.paid.key,
                          child: Row(children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF2E7D32), size: 18),
                            const SizedBox(width: 8),
                            Text(s.markAsPaid),
                          ])),
                    if (st != _InvStatus.partiallyPaid)
                      const PopupMenuItem(value: '__partial__',
                          child: Row(children: [
                            Icon(Icons.payments_rounded,
                                color: Color(0xFFE65100), size: 18),
                            SizedBox(width: 8),
                            Text('Mark Partially Paid'),
                          ])),
                    if (st != _InvStatus.cancelled)
                      PopupMenuItem(value: _InvStatus.cancelled.key,
                          child: Row(children: [
                            const Icon(Icons.cancel_rounded,
                                color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Text(s.statusCancelled,
                                style:
                                    const TextStyle(color: AppColors.error)),
                          ])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Edit Invoice sheet ────────────────────────────────────────────────────

  void _showEditInvoice(Map<String, dynamic> doc, AppStrings s) {
    final docId = doc['id'] as String;
    String? patId   = doc['patient_id'] as String?;
    String? patName = doc['patient_name'] as String?;
    _InvStatus status = _InvStatusX.fromString(doc['status'] as String?);
    final tsStr = doc['invoice_date'] as String? ?? doc['created_at'] as String?;
    DateTime invDate = tsStr != null ? DateTime.parse(tsStr) : DateTime.now();
    final amtCtrl      = TextEditingController(
        text: (doc['amount'] as num?)?.toStringAsFixed(2) ?? '');
    final svcCtrl      = TextEditingController(
        text: (doc['service'] as String?) ?? '');
    final noteCtrl     = TextEditingController(
        text: (doc['note'] as String?) ?? '');
    final paidAmtCtrl  = TextEditingController(
        text: (doc['paid_amount'] as num?)?.toStringAsFixed(2) ?? '');
    final patSearchCtrl = TextEditingController(text: patName ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Invoice',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase
                      .from('users')
                      .stream(primaryKey: ['id'])
                      .eq('role', 'patient')
                      .map((list) => list.where((r) {
                            final ids =
                                (r['doctor_ids'] as List?)?.cast<String>() ?? [];
                            return ids.contains(_uid);
                          }).toList()),
                  builder: (_, snap) {
                    final pats = snap.data ?? [];
                    return PatientSearchField(
                      patients: pats,
                      labelText: s.selectPatient,
                      controller: patSearchCtrl,
                      onSelected: (id, name) =>
                          set(() { patId = id; patName = name; }),
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: svcCtrl,
                  decoration: InputDecoration(
                    labelText: 'Service',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true, fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: invDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) set(() => invDate = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Invoice Date',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: true, fillColor: Colors.white,
                      suffixIcon: const Icon(Icons.calendar_today_rounded,
                          color: AppColors.primary),
                    ),
                    child: Text(DateFormat('MMM d, yyyy').format(invDate)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amtCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${s.amount} (USD)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true, fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<_InvStatus>(
                  initialValue: status,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true, fillColor: Colors.white,
                  ),
                  items: [
                    if (status == _InvStatus.awaitingReview)
                      _InvStatus.awaitingReview,
                    _InvStatus.pending, _InvStatus.paid,
                    _InvStatus.partiallyPaid, _InvStatus.cancelled,
                  ].map((st) => DropdownMenuItem<_InvStatus>(
                        value: st,
                        child: Text(st.label(s)),
                      )).toList(),
                  onChanged: (v) => set(() => status = v!),
                ),
                if (status == _InvStatus.partiallyPaid) ...[
                  const SizedBox(height: 10),
                  StatefulBuilder(
                    builder: (ctx2, set2) {
                      final total = double.tryParse(amtCtrl.text.trim()) ?? 0;
                      final paid  = double.tryParse(paidAmtCtrl.text.trim()) ?? 0;
                      final remaining = (total - paid).clamp(0, double.infinity);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: paidAmtCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => set2(() {}),
                            decoration: InputDecoration(
                              labelText: 'Amount Paid',
                              prefixIcon: const Icon(Icons.payments_rounded,
                                  color: Color(0xFFE65100)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              filled: true, fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 16, color: Color(0xFFE65100)),
                              const SizedBox(width: 6),
                              Text(
                                  'Remaining: USD ${remaining.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFFE65100))),
                            ]),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Note',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true, fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Changes',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final amt = double.tryParse(amtCtrl.text.trim());
                      if (patId == null || amt == null || amt <= 0) return;
                      final paidAmt = double.tryParse(paidAmtCtrl.text.trim());
                      final data = <String, dynamic>{
                        'patient_id':   patId,
                        'patient_name': patName,
                        'service': svcCtrl.text.trim().isEmpty
                            ? 'Physical Therapy'
                            : svcCtrl.text.trim(),
                        'amount':      amt,
                        'currency':    'USD',
                        'status':      status.key,
                        'note':        noteCtrl.text.trim(),
                        'invoice_date': invDate.toIso8601String(),
                      };
                      if (status == _InvStatus.partiallyPaid &&
                          paidAmt != null) {
                        data['paid_amount'] = paidAmt;
                      } else {
                        data['paid_amount'] = null;
                      }
                      await _supabase
                          .from('invoices')
                          .update(data)
                          .eq('id', docId);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Invoice updated successfully.'),
                        backgroundColor: AppColors.success,
                      ));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── AI Revenue Analysis ───────────────────────────────────────────────────

  Future<void> _showAiRevenueSheet(
      List<Map<String, dynamic>> filtered, AppStrings s) async {
    setState(() => _aiLoading = true);
    final currency = 'USD';
    final totalInvoiced = filtered
        .where((d) => (d['status'] as String?) != 'cancelled')
        .fold<double>(
            0, (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0));
    // Strip patient PII — send only date, amount, status
    final slim = filtered.map((d) => {
          'date': (d['invoice_date'] as String? ?? d['created_at'] as String? ?? '').split('T').first,
          'amount': d['amount'],
          'status': d['status'],
        }).toList();

    final result = await AiDoctorAssistantService.analyzeRevenue(
      dateRange: _rangeLabel,
      currency: currency,
      totalInvoiced: totalInvoiced,
      invoices: slim,
    );
    if (!mounted) return;
    setState(() => _aiLoading = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? 'Revenue analysis failed'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final summary = result.data!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kSuccess.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: _kSuccess, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Revenue Analysis',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (result.usage != null)
                    Text(result.usage!.label,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ])),
              ]),
              const SizedBox(height: 16),
              _aiStatRow('Total Revenue',  summary.totalRevenue,    _kSuccess),
              _aiStatRow('Paid Sessions',  summary.paidSessions,   _kSuccess),
              _aiStatRow('Unpaid Sessions',summary.unpaidSessions,  _kWarning),
              if (summary.financialSummary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FBF9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kAccent.withValues(alpha: 0.2)),
                  ),
                  child: Text(summary.financialSummary,
                      style: const TextStyle(fontSize: 13, height: 1.5)),
                ),
              ],
              if (summary.keyInsights.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Key Insights',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                ...summary.keyInsights.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(insight, style: const TextStyle(fontSize: 13))),
                  ]),
                )),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aiStatRow(String label, String value, Color color) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
      ]),
    );
  }

  // ── Bottom action bar ─────────────────────────────────────────────────────

  Widget _bottomBar(AppStrings s,
      List<Map<String, dynamic>> filtered,
      {bool isDesktop = true}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            if (isDesktop) ...[
              // Primary action
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  key: const Key('billing_add_income_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 3,
                    shadowColor: _kAccent.withValues(alpha: 0.35),
                  ),
                  icon: const Icon(Icons.add_circle_rounded, size: 20),
                  label: const Text('+ Add Income',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: () => _showAddInvoice(s),
                ),
              ),
              const SizedBox(height: 6),
              // All secondary actions in one compact row
              Row(children: [
                Expanded(
                  child: _smallActionBtn(
                    icon: _aiLoading
                        ? Icons.hourglass_top_rounded
                        : Icons.auto_awesome_rounded,
                    label: _aiLoading ? 'Analyzing…' : 'AI Analysis',
                    onTap: (_aiLoading || filtered.isEmpty)
                        ? () {}
                        : () => _showAiRevenueSheet(filtered, s),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _smallActionBtn(
                    key: const Key('billing_ai_btn'),
                    icon: Icons.chat_rounded,
                    label: 'AI Chat',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const FinancialAiChatScreen())),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _smallActionBtn(
                    icon: Icons.insights_rounded,
                    label: 'Analytics',
                    onTap: () => showClinicAnalyticsSheet(context),
                  ),
                ),
                if (FormFactorFeatures.of(context).showBillingImportExport) ...[
                  const SizedBox(width: 5),
                  Expanded(
                    child: _smallActionBtn(
                      key: const Key('billing_export_btn'),
                      icon: Icons.download_rounded,
                      label: 'Export',
                      onTap: () => _showExport(filtered, s),
                    ),
                  ),
                ],
              ]),
            ],
          ],
        ),
    );
  }

  Widget _smallActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Key? key,
  }) =>
      OutlinedButton(
        key: key,
        style: OutlinedButton.styleFrom(
          foregroundColor: _kAccent,
          side: const BorderSide(color: Color(0xFFBBD1EA)),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFFF4F8FC),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 11),
              ),
            ),
          ],
        ),
      );

  // ── Summary band (desktop) ─────────────────────────────────────────────────

  Widget _summaryBand(
    AppStrings s, {
    required double collected,
    required double pending,
    required double overdue,
    required double invoiced,
    required int invoiceCount,
    required int awaitingCount,
    required bool isDesktop,
  }) {
    final total = collected + pending + overdue;
    final collectedPct = total > 0 ? collected / total : 0.0;
    final pendingPct   = total > 0 ? pending   / total : 0.0;
    final overduePct   = total > 0 ? overdue   / total : 0.0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (awaitingCount > 0) ...[
            GestureDetector(
              onTap: () => setState(() => _statusFilter = 'awaiting_review'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.rate_review_rounded,
                      color: Color(0xFF1565C0), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$awaitingCount session${awaitingCount == 1 ? '' : 's'} awaiting your review',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1565C0)),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF1565C0), size: 12),
                ]),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (isDesktop)
            Row(children: [
              Expanded(child: _kpiCard(title: 'Collected', amount: collected,
                  tint: const Color(0xFFE8F5E9), accent: _kSuccess)),
              const SizedBox(width: 8),
              Expanded(child: _kpiCard(title: 'Pending', amount: pending,
                  tint: const Color(0xFFFFF8E1), accent: _kWarning)),
              const SizedBox(width: 8),
              Expanded(child: _kpiCard(title: 'Overdue 30d+', amount: overdue,
                  tint: const Color(0xFFFFEBEE), accent: _kDanger)),
              const SizedBox(width: 8),
              Expanded(child: _kpiCard(title: 'Invoiced', amount: invoiced,
                  tint: const Color(0xFFF0FBF9), accent: _kAccent,
                  sublabel: '$invoiceCount invoice${invoiceCount == 1 ? '' : 's'}')),
            ])
          else
            Column(children: [
              Row(children: [
                Expanded(child: _kpiCard(title: 'Collected', amount: collected,
                    tint: const Color(0xFFE8F5E9), accent: _kSuccess)),
                const SizedBox(width: 8),
                Expanded(child: _kpiCard(title: 'Pending', amount: pending,
                    tint: const Color(0xFFFFF8E1), accent: _kWarning)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _kpiCard(title: 'Overdue 30d+', amount: overdue,
                    tint: const Color(0xFFFFEBEE), accent: _kDanger)),
                const SizedBox(width: 8),
                Expanded(child: _kpiCard(title: 'Invoiced', amount: invoiced,
                    tint: const Color(0xFFF0FBF9), accent: _kAccent,
                    sublabel: '$invoiceCount invoice${invoiceCount == 1 ? '' : 's'}')),
              ]),
            ]),
          if (isDesktop) ...[
            const SizedBox(height: 6),
            _collectionBar(collectedPct, pendingPct, overduePct),
          ],
        ],
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required double amount,
    required Color tint,
    required Color accent,
    String? sublabel,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: accent.withValues(alpha: 0.8))),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _fmtAmt(amount),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: accent),
              ),
            ),
            if (sublabel != null)
              Text(sublabel,
                  style: TextStyle(
                      fontSize: 10,
                      color: accent.withValues(alpha: 0.65))),
          ],
        ),
      );

  Widget _collectionBar(
      double collectedPct, double pendingPct, double overduePct) {
    const barH         = 6.0;
    const successColor = Color(0xFF4CAF50);
    const warningColor = Color(0xFFFFC107);
    const dangerColor  = Color(0xFFF44336);
    final hasData = collectedPct + pendingPct + overduePct > 0;

    // Compact single row: [bar] [X% collected] [● Pending] [● Overdue]
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: hasData
                ? Row(children: [
                    if (collectedPct > 0)
                      Expanded(
                        flex: (collectedPct * 1000).round(),
                        child: Container(height: barH, color: successColor),
                      ),
                    if (pendingPct > 0)
                      Expanded(
                        flex: (pendingPct * 1000).round(),
                        child: Container(height: barH, color: warningColor),
                      ),
                    if (overduePct > 0)
                      Expanded(
                        flex: (overduePct * 1000).round(),
                        child: Container(height: barH, color: dangerColor),
                      ),
                  ])
                : Container(height: barH, color: Colors.grey.shade200),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(collectedPct * 100).toStringAsFixed(1)}% collected',
          style: const TextStyle(
              fontSize: 11, color: _kSuccess, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 10),
        _barDot(warningColor), const SizedBox(width: 3),
        Text('Pending',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(width: 8),
        _barDot(dangerColor), const SizedBox(width: 3),
        Text('Overdue',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _barDot(Color color) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  String _fmtAmt(double amt) =>
      'USD ${NumberFormat('#,##0.00', 'en_US').format(amt)}';
}
