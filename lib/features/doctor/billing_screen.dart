// ignore_for_file: use_build_context_synchronously

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import '../../core/config/form_factor_features.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/patient_search_field.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/language_provider.dart';
import '../../core/utils/file_saver.dart';
import 'import_help_sheet.dart';

// ── Status helpers ─────────────────────────────────────────────────────────

enum _InvStatus { pending, paid, partiallyPaid, insuranceClaim, cancelled }

extension _InvStatusX on _InvStatus {
  String get key => switch (this) {
    _InvStatus.pending        => 'pending',
    _InvStatus.paid           => 'paid',
    _InvStatus.partiallyPaid  => 'partially_paid',
    _InvStatus.insuranceClaim => 'insurance_claim',
    _InvStatus.cancelled      => 'cancelled',
  };
  String label(AppStrings s) => switch (this) {
    _InvStatus.pending        => s.statusPending,
    _InvStatus.paid           => s.statusPaid,
    _InvStatus.partiallyPaid  => 'Partially\nPaid',
    _InvStatus.insuranceClaim => 'Insurance\nClaim',
    _InvStatus.cancelled      => s.statusCancelled,
  };
  Color get color => switch (this) {
    _InvStatus.pending        => const Color(0xFFF57F17),
    _InvStatus.paid           => const Color(0xFF2E7D32),
    _InvStatus.partiallyPaid  => const Color(0xFFE65100),
    _InvStatus.insuranceClaim => const Color(0xFF546E7A),
    _InvStatus.cancelled      => const Color(0xFFC62828),
  };

  static _InvStatus fromString(String? raw) => switch (raw) {
    'paid'            => _InvStatus.paid,
    'partially_paid'  => _InvStatus.partiallyPaid,
    'insurance_claim' => _InvStatus.insuranceClaim,
    'cancelled'       => _InvStatus.cancelled,
    _                 => _InvStatus.pending,
  };
}

// ── Screen ─────────────────────────────────────────────────────────────────

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  static const _navy = Color(0xFF1A3A5C);

  final _supabase = Supabase.instance.client;
  final _uid = Supabase.instance.client.auth.currentUser!.id;

  String   _period  = 'monthly';
  DateTime _refDate = DateTime.now();
  String   _patientFilter = '';
  String?  _statusFilter;

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
        final status = d['status'] as String? ?? 'pending';
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
    String  currency = 'USD';
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
              // Amount + Currency
              Row(children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: amtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: s.amount,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: true, fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: currency,
                    decoration: InputDecoration(
                      labelText: s.currency,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: true, fillColor: Colors.white,
                    ),
                    items: ['USD','EUR','SAR','AED','JOD']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => set(() => currency = v!),
                  ),
                ),
              ]),
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
                        _InvStatus.partiallyPaid,
                        _InvStatus.insuranceClaim].map((st) =>
                  DropdownMenuItem(
                    value: st,
                    child: Text(st.label(s).replaceAll('\n', ' ')),
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
                            Text('Remaining: $currency ${remaining.toStringAsFixed(2)}',
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
                    backgroundColor: _navy,
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
                      'currency':    currency,
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

  void _showMarkPartialSheet(String docId, double totalAmt, String currency) {
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
                Text('Total: $currency ${totalAmt.toStringAsFixed(2)}',
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
                        'Remaining: $currency ${remaining.toStringAsFixed(2)}',
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

  // ── Import from Excel ─────────────────────────────────────────────────────

  void _showLoading(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Flexible(child: Text(msg, style: const TextStyle(fontSize: 14))),
            ]),
          ),
        ),
      ),
    );
  }

  void _hideLoading() {
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _importBillingFromExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    if (mounted) _showLoading('Importing income records…');

    final excel = xl.Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) return;

    int imported = 0;
    final rows = sheet.rows.skip(1);
    for (final row in rows) {
      if (row.length < 5) continue;
      final name    = row[0]?.value?.toString().trim() ?? '';
      final service = row[1]?.value?.toString().trim() ?? '';
      final dateStr = row[2]?.value?.toString().trim() ?? '';
      final amtStr  = row[3]?.value?.toString().trim() ?? '';

      // Detect whether exported format (includes Currency column at index 4)
      final col4 = row[4]?.value?.toString().trim().toLowerCase() ?? '';
      final hasCurrencyCol = row.length >= 6 &&
          ['usd', 'eur', 'gbp', 'jod', 'ils', 'sar', 'aed'].contains(col4);
      final statusRaw = hasCurrencyCol
          ? (row[5]?.value?.toString().trim().toLowerCase() ?? 'pending')
          : col4;
      final note = hasCurrencyCol
          ? (row.length > 6 ? (row[6]?.value?.toString().trim() ?? '') : '')
          : (row.length > 5 ? (row[5]?.value?.toString().trim() ?? '') : '');

      if (name.isEmpty || amtStr.isEmpty) continue;
      final amt = double.tryParse(amtStr);
      if (amt == null) continue;

      DateTime invoiceDate;
      try {
        invoiceDate = DateFormat('dd/MM/yyyy').parse(dateStr);
      } catch (_) {
        try {
          invoiceDate = DateFormat('yyyy-MM-dd').parse(dateStr);
        } catch (_) {
          invoiceDate = DateTime.now();
        }
      }

      final String statusKey;
      if (statusRaw == 'paid') {
        statusKey = 'paid';
      } else if (statusRaw.startsWith('partially_paid') ||
          statusRaw == 'partially paid') {
        statusKey = 'partially_paid';
      } else if (statusRaw.startsWith('cancelled')) {
        statusKey = 'cancelled';
      } else {
        statusKey = 'pending';
      }

      // Find patient by name
      final patSnap = await _supabase
          .from('users')
          .select()
          .eq('role', 'patient');
      final patList = (patSnap as List).cast<Map<String, dynamic>>();
      final patDoc = patList.cast<Map<String, dynamic>?>().firstWhere(
        (p) => (p?['name'] as String? ?? '')
                .toLowerCase()
                .contains(name.toLowerCase()),
        orElse: () => null,
      );

      await _supabase.from('invoices').insert({
        'doctor_id':    _uid,
        'patient_id':   patDoc?['id'] ?? '',
        'patient_name': name,
        'service':     service.isEmpty ? 'Physical Therapy' : service,
        'amount':      amt,
        'currency':    'USD',
        'status':      statusKey,
        'note':        note,
        'invoice_date': invoiceDate.toIso8601String(),
        'created_at':   DateTime.now().toIso8601String(),
      });
      imported++;
    }

    _hideLoading();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Imported $imported invoice(s) successfully.'),
      backgroundColor: AppColors.success,
    ));
    setState(() {});
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

  // ── Submit insurance claim ──────────────────────────────────────────────

  void _showInsuranceClaim(List<Map<String, dynamic>> pending, AppStrings s) {
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending invoices to submit.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.shield_rounded, color: _navy),
              const SizedBox(width: 10),
              const Text('Submit Insurance Claim',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: pending.length,
              itemBuilder: (_, i) {
                final d = pending[i];
                return ListTile(
                  leading: const Icon(Icons.receipt_outlined, color: _navy),
                  title: Text(d['patient_name'] ?? 'Patient',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${d['currency'] ?? 'USD'} ${(d['amount'] as num?)?.toStringAsFixed(2)}  •  ${d['service'] ?? ''}'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF546E7A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () async {
                      await _updateStatus(
                          d['id'] as String, _InvStatus.insuranceClaim);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Insurance claim submitted!'),
                          backgroundColor: AppColors.success,
                        ));
                    },
                    child: const Text('Submit'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<LanguageProvider>().isArabic);

    return Scaffold(
      backgroundColor: const Color(0xFFEBF2FB),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
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

          // Summary calculations
          double totalRevenue = 0, pendingTotal = 0, insuranceTotal = 0;
          int completedCount = 0;
          final pendingDocs = <Map<String, dynamic>>[];

          for (final d in filtered) {
            final amt    = (d['amount'] as num?)?.toDouble() ?? 0;
            final st     = _InvStatusX.fromString(d['status'] as String?);
            switch (st) {
              case _InvStatus.paid:
                totalRevenue += amt;
                completedCount++;
              case _InvStatus.partiallyPaid:
                final paidAmt = (d['paid_amount'] as num?)?.toDouble() ?? 0;
                totalRevenue += paidAmt;
                pendingTotal += (amt - paidAmt).clamp(0, double.infinity);
              case _InvStatus.pending:
                pendingTotal += amt;
                pendingDocs.add(d);
              case _InvStatus.insuranceClaim:
                insuranceTotal += amt;
              case _InvStatus.cancelled:
                break;
            }
          }

          final currency = filtered.isEmpty ? 'USD' :
              filtered.first['currency'] ?? 'USD';

          return LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Column(
                children: [
                  _filterBar(s),
                  Expanded(
                    child: isWide
                      ? _wideLayout(s, filtered, pendingDocs,
                            totalRevenue, pendingTotal, insuranceTotal,
                            completedCount, currency)
                      : _narrowLayout(s, filtered, pendingDocs,
                            totalRevenue, pendingTotal, insuranceTotal,
                            completedCount, currency),
                  ),
                  _bottomBar(s, filtered, pendingDocs),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── Filter bar ───────────────────────────────────────────────────────────────

  Widget _filterBar(AppStrings s) {
    return Container(
      color: const Color(0xFF1A3A5C),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _period,
                  dropdownColor: _navy,
                  icon: const Icon(Icons.arrow_drop_down_rounded,
                      color: Colors.white),
                  items: ['daily', 'weekly', 'monthly', 'yearly'].map((p) =>
                    DropdownMenuItem(
                      value: p,
                      child: Row(children: [
                        const Icon(Icons.calendar_month_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(p[0].toUpperCase() + p.substring(1),
                            style: const TextStyle(color: Colors.white)),
                      ]),
                    )).toList(),
                  onChanged: (v) => setState(() => _period = v!),
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                GestureDetector(
                  onTap: _prev,
                  child: const Icon(Icons.chevron_left_rounded,
                      color: _navy, size: 20)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _refDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _refDate = picked);
                    }
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calendar_month_rounded,
                        color: _navy, size: 15),
                    const SizedBox(width: 4),
                    Text(_rangeLabel,
                        style: const TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ]),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _next,
                  child: const Icon(Icons.chevron_right_rounded,
                      color: _navy, size: 20)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _patientFilter = v),
                decoration: InputDecoration(
                  hintText: 'Search patient...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Colors.white, size: 18),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _statusFilter,
                  dropdownColor: _navy,
                  icon: const Icon(Icons.arrow_drop_down_rounded,
                      color: Colors.white),
                  items: [null, 'pending', 'paid', 'partially_paid',
                          'insurance_claim', 'cancelled']
                      .map((st) => DropdownMenuItem(
                        value: st,
                        child: Row(children: [
                          const Icon(Icons.filter_list_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(st == null ? 'All Status' : st.replaceAll('_', ' '),
                              style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ]),
                      )).toList(),
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Wide layout ───────────────────────────────────────────────────────────

  Widget _wideLayout(AppStrings s,
      List<Map<String, dynamic>> filtered,
      List<Map<String, dynamic>> pendingDocs,
      double totalRevenue, double pendingTotal,
      double insuranceTotal, int completedCount, String currency) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _invoiceTable(filtered, s, scrollable: true)),
          const SizedBox(width: 16),
          SizedBox(
            width: 280,
            child: Column(children: [
              _summaryCard('Total Revenue',
                  '$currency ${totalRevenue.toStringAsFixed(2)}',
                  'This Month', const Color(0xFF2E7D32)),
              const SizedBox(height: 10),
              _summaryCard('Pending Payments',
                  '$currency ${pendingTotal.toStringAsFixed(2)}',
                  'Awaiting', const Color(0xFFF57F17)),
              const SizedBox(height: 10),
              _summaryCard('Insurance Claims',
                  '$currency ${insuranceTotal.toStringAsFixed(2)}',
                  'Processing', const Color(0xFF546E7A)),
              const SizedBox(height: 10),
              _summaryCard('Transactions Completed',
                  '$completedCount',
                  'This Period', _navy),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Narrow layout ─────────────────────────────────────────────────────────

  Widget _narrowLayout(AppStrings s,
      List<Map<String, dynamic>> filtered,
      List<Map<String, dynamic>> pendingDocs,
      double totalRevenue, double pendingTotal,
      double insuranceTotal, int completedCount, String currency) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          Expanded(child: _summaryCard('Total Revenue',
              '$currency ${totalRevenue.toStringAsFixed(2)}',
              'This Period', const Color(0xFF2E7D32))),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('Pending',
              '$currency ${pendingTotal.toStringAsFixed(2)}',
              'Awaiting', const Color(0xFFF57F17))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _summaryCard('Insurance',
              '$currency ${insuranceTotal.toStringAsFixed(2)}',
              'Processing', const Color(0xFF546E7A))),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('Completed',
              '$completedCount', 'Transactions', _navy)),
        ]),
        const SizedBox(height: 14),
        _invoiceTable(filtered, s),
      ]),
    );
  }

  // ── Invoice table ─────────────────────────────────────────────────────────

  Widget _invoiceTable(List<Map<String, dynamic>> docs, AppStrings s,
      {bool scrollable = false}) {
    final header = Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A3A5C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _th('Patient Name', flex: 3),
        _th('Date', flex: 2),
        _th('Service', flex: 3),
        _th('Amount', flex: 2),
        _th('Status', flex: 2),
        const SizedBox(width: 32),
      ]),
    );

    Widget body;
    if (docs.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_outlined,
                size: 50, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text(s.noData,
                style: const TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
      );
      if (scrollable) body = Expanded(child: Center(child: body));
    } else if (scrollable) {
      body = Expanded(
        child: ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFF0F4FA)),
          itemBuilder: (_, i) => _tableRow(docs[i], i, s),
        ),
      );
    } else {
      body = ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: docs.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFF0F4FA)),
        itemBuilder: (_, i) => _tableRow(docs[i], i, s),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [header, body],
      ),
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
    final svc  = (d['service'] as String?) ?? 'Physical Therapy';
    final amt  = (d['amount'] as num?)?.toDouble() ?? 0;
    final cur  = (d['currency'] as String?) ?? 'USD';
    final st   = _InvStatusX.fromString(d['status'] as String?);
    final bg   = index.isEven ? Colors.white : const Color(0xFFF8FAFF);
    final docId = d['id'] as String;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(flex: 3,
          child: Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14))),
        Expanded(flex: 2,
          child: Text(date,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13))),
        Expanded(flex: 3,
          child: Text(svc,
              style: const TextStyle(fontSize: 13))),
        Expanded(flex: 2,
          child: Text('$cur ${amt.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13))),
        Expanded(flex: 2,
          child: _statusBadge(st, s)),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              color: Colors.grey.shade400, size: 18),
          onSelected: (v) async {
            if (v == '__partial__') {
              _showMarkPartialSheet(docId, amt, cur);
              return;
            }
            final newSt = _InvStatusX.fromString(v);
            await _updateStatus(docId, newSt);
          },
          itemBuilder: (_) => [
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
            if (st != _InvStatus.insuranceClaim)
              const PopupMenuItem(value: 'insurance_claim',
                  child: Row(children: [
                    Icon(Icons.shield_rounded,
                        color: Color(0xFF546E7A), size: 18),
                    SizedBox(width: 8),
                    Text('Insurance Claim'),
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

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _summaryCard(String title, String value,
      String subtitle, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22)),
          ),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11)),
        ],
      ),
    );
  }

  // ── Bottom action bar ─────────────────────────────────────────────────────

  Widget _bottomBar(AppStrings s,
      List<Map<String, dynamic>> filtered,
      List<Map<String, dynamic>> pendingDocs) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                  shadowColor: _navy.withValues(alpha: 0.35),
                ),
                icon: const Icon(Icons.add_circle_rounded, size: 24),
                label: const Text('+ Add Income',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17)),
                onPressed: () => _showAddInvoice(s),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              if (FormFactorFeatures.of(context)
                  .showBillingImportExport) ...[
                Expanded(
                  child: _smallActionBtn(
                    icon: Icons.download_rounded,
                    label: 'Export Report',
                    onTap: () => _showExport(filtered, s),
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: _smallActionBtn(
                  icon: Icons.shield_rounded,
                  label: 'Insurance',
                  onTap: () => _showInsuranceClaim(pendingDocs, s),
                ),
              ),
              if (FormFactorFeatures.of(context)
                  .showBillingImportExport) ...[
                const SizedBox(width: 7),
                Expanded(
                  child: _smallActionBtn(
                    icon: Icons.upload_file_rounded,
                    label: 'Import Excel',
                    onTap: _importBillingFromExcel,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => showImportHelpSheet(
                    context,
                    title: 'Import Bills',
                    subtitle: 'Expected Excel column order',
                    columns: [
                      'Name', 'Service', 'Date', 'Amount', 'Status', 'Note'
                    ],
                    examples: [
                      ['John Smith', 'Physical Therapy', '01/15/2024',
                       '150', 'paid', 'Insurance'],
                      ['Sara Lee', 'Follow-up Session', '02/10/2024',
                       '80', 'pending', ''],
                    ],
                    notes: [
                      'Name: patient full name (matched to existing patients)',
                      'Service: description of the billed service',
                      'Date format: dd/MM/yyyy or yyyy-MM-dd',
                      'Amount: number only, e.g. 150 or 150.00',
                      'Status values: pending · paid · partially paid · cancelled',
                      'Note: optional — any extra information about the invoice',
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.help_outline_rounded,
                        color: Colors.grey.shade600, size: 20),
                  ),
                ),
              ],
            ]),
          ],
        ),
    );
  }

  Widget _smallActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: _navy,
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
}
