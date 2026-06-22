import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/breakpoints.dart';
import '../../core/config/form_factor_features.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/language_provider.dart';
import '../../core/utils/file_saver.dart';
import 'import_help_sheet.dart';

// ── Status ──────────────────────────────────────────────────────────────────

enum _ExpStatus { pending, paid, partiallyPaid }

extension _ExpStatusX on _ExpStatus {
  String get key => switch (this) {
        _ExpStatus.pending      => 'pending',
        _ExpStatus.paid         => 'paid',
        _ExpStatus.partiallyPaid => 'partially_paid',
      };
  String label(AppStrings s) => switch (this) {
        _ExpStatus.pending      => s.statusPending,
        _ExpStatus.paid         => s.statusPaid,
        _ExpStatus.partiallyPaid => 'Partial',
      };
  Color get color => switch (this) {
        _ExpStatus.pending      => const Color(0xFFFF8F00),
        _ExpStatus.paid         => const Color(0xFF2E7D32),
        _ExpStatus.partiallyPaid => const Color(0xFFE65100),
      };
  Color get bgColor => switch (this) {
        _ExpStatus.pending      => const Color(0xFFFFF3E0),
        _ExpStatus.paid         => const Color(0xFFE8F5E9),
        _ExpStatus.partiallyPaid => const Color(0xFFFBE9E7),
      };
  IconData get icon => switch (this) {
        _ExpStatus.pending      => Icons.schedule_rounded,
        _ExpStatus.paid         => Icons.check_circle_rounded,
        _ExpStatus.partiallyPaid => Icons.hourglass_top_rounded,
      };

  static _ExpStatus fromString(String? raw) => switch (raw) {
        'paid'          => _ExpStatus.paid,
        'partially_paid' => _ExpStatus.partiallyPaid,
        _               => _ExpStatus.pending,
      };
}

// ── Screen ───────────────────────────────────────────────────────────────────

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  static const _kAccent = Color(0xFF993C1D); // expenses coral

  final _supabase = Supabase.instance.client;
  final _uid = Supabase.instance.client.auth.currentUser!.id;

  String _period = 'monthly';
  DateTime _refDate = DateTime.now();
  String _categoryFilter = '';
  String? _statusFilter;

  // ── Period helpers ──────────────────────────────────────────────────────

  DateTime get _start {
    final r = _refDate;
    return switch (_period) {
      'daily' => DateTime(r.year, r.month, r.day),
      'weekly' => () {
          final m = r.subtract(Duration(days: r.weekday - 1));
          return DateTime(m.year, m.month, m.day);
        }(),
      'yearly' => DateTime(r.year, 1, 1),
      _ => DateTime(r.year, r.month, 1),
    };
  }

  DateTime get _end {
    final r = _refDate;
    return switch (_period) {
      'daily' => DateTime(r.year, r.month, r.day, 23, 59, 59),
      'weekly' => () {
          final m = r.subtract(Duration(days: r.weekday - 1));
          final s = DateTime(m.year, m.month, m.day);
          final e = s.add(const Duration(days: 6));
          return DateTime(e.year, e.month, e.day, 23, 59, 59);
        }(),
      'yearly' => DateTime(r.year, 12, 31, 23, 59, 59),
      _ => DateTime(r.year, r.month + 1, 0, 23, 59, 59),
    };
  }

  String get _rangeLabel {
    final s = _start;
    final e = _end;
    return switch (_period) {
      'daily'  => DateFormat('MMMM d, yyyy').format(s),
      'yearly' => '${s.year}',
      _        => '${DateFormat('MMM d').format(s)} – ${DateFormat('MMM d, yyyy').format(e)}',
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
      final tsStr = d['expense_date'] as String? ?? d['created_at'] as String?;
      if (tsStr == null) return false;
      final dt = DateTime.parse(tsStr);
      if (dt.isBefore(s) || dt.isAfter(e)) return false;
      if (_categoryFilter.isNotEmpty) {
        final cat = (d['category'] as String? ?? '').toLowerCase();
        if (!cat.contains(_categoryFilter.toLowerCase())) return false;
      }
      if (_statusFilter != null) {
        final status = d['status'] as String? ?? 'pending';
        if (status != _statusFilter) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final taStr = a['expense_date'] as String? ?? a['created_at'] as String?;
        final tbStr = b['expense_date'] as String? ?? b['created_at'] as String?;
        final ta = taStr != null ? DateTime.parse(taStr) : DateTime(2000);
        final tb = tbStr != null ? DateTime.parse(tbStr) : DateTime(2000);
        return tb.compareTo(ta);
      });
  }

  Future<void> _updateStatus(String id, _ExpStatus s) =>
      _supabase.from('expenses').update({'status': s.key}).eq('id', id);

  // ── Add Expense sheet ────────────────────────────────────────────────────

  void _showAddExpense(AppStrings s) {
    _ExpStatus status = _ExpStatus.pending;
    DateTime expDate = DateTime.now();
    final amtCtrl     = TextEditingController();
    final catCtrl     = TextEditingController();
    final descCtrl    = TextEditingController();
    final noteCtrl    = TextEditingController();
    final paidAmtCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
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
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: _kAccent, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text('Add Expense',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 20),
                _field(catCtrl, 'Category', Icons.label_rounded),
                const SizedBox(height: 12),
                _field(descCtrl, 'Description', Icons.notes_rounded),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: expDate,
                      firstDate: DateTime(2020),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) set(() => expDate = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Expense Date',
                      prefixIcon: const Icon(Icons.calendar_today_rounded,
                          color: _kAccent, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFB),
                    ),
                    child: Text(DateFormat('MMM d, yyyy').format(expDate),
                        style: const TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 12),
                _field(amtCtrl, 'Amount',
                    Icons.attach_money_rounded,
                    type: const TextInputType.numberWithOptions(
                        decimal: true)),
                const SizedBox(height: 12),
                DropdownButtonFormField<_ExpStatus>(
                  initialValue: status,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    prefixIcon: const Icon(Icons.info_outline_rounded,
                        color: _kAccent, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFB),
                  ),
                  items: [
                    _ExpStatus.pending,
                    _ExpStatus.paid,
                    _ExpStatus.partiallyPaid,
                  ].map((st) => DropdownMenuItem(
                        value: st,
                        child: Text(st.label(s)),
                      )).toList(),
                  onChanged: (v) => set(() => status = v!),
                ),
                if (status == _ExpStatus.partiallyPaid) ...[
                  const SizedBox(height: 10),
                  StatefulBuilder(
                    builder: (ctx2, set2) {
                      final total = double.tryParse(amtCtrl.text.trim()) ?? 0;
                      final paid  = double.tryParse(paidAmtCtrl.text.trim()) ?? 0;
                      final remaining =
                          (total - paid).clamp(0, double.infinity);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _field(paidAmtCtrl, 'Amount Paid',
                              Icons.payments_rounded,
                              type: const TextInputType.numberWithOptions(
                                  decimal: true),
                              onChanged: (_) => set2(() {})),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBE9E7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 16,
                                  color: Color(0xFFE65100)),
                              const SizedBox(width: 6),
                              Text(
                                  'Remaining: \$${remaining.toStringAsFixed(2)}',
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
                const SizedBox(height: 12),
                _field(noteCtrl, 'Note', Icons.notes_rounded),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Expense',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final amt  = double.tryParse(amtCtrl.text.trim());
                      final cat  = catCtrl.text.trim();
                      final desc = descCtrl.text.trim();
                      if (cat.isEmpty || amt == null || amt <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text(
                              'Please fill in category and amount.'),
                          backgroundColor: Colors.orange,
                        ));
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final paidAmt =
                            double.tryParse(paidAmtCtrl.text.trim());
                        final data = <String, dynamic>{
                          'doctor_id':   _uid,
                          'category':    cat,
                          'description': desc,
                          'amount':      amt,
                          'status':      status.key,
                          'note':        noteCtrl.text.trim(),
                          'expense_date': expDate.toIso8601String(),
                          'created_at':   DateTime.now().toIso8601String(),
                        };
                        if (status == _ExpStatus.partiallyPaid &&
                            paidAmt != null) {
                          data['paid_amount'] = paidAmt;
                        }
                        await _supabase.from('expenses').insert(data);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        messenger.showSnackBar(const SnackBar(
                          content: Text('Expense added successfully!'),
                          backgroundColor: AppColors.success,
                        ));
                      } catch (e) {
                        if (!ctx.mounted) return;
                        messenger.showSnackBar(SnackBar(
                          content: Text('Failed to add expense: $e'),
                          backgroundColor: Colors.red,
                        ));
                      }
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

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text,
      void Function(String)? onChanged}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _kAccent, size: 20),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: const Color(0xFFF8FAFB),
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
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Total: \$${totalAmt.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  onChanged: (_) => set(() {}),
                  decoration: InputDecoration(
                    labelText: 'Amount Paid',
                    prefixIcon: const Icon(Icons.payments_rounded,
                        color: Color(0xFFE65100)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE9E7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: Color(0xFFE65100)),
                    const SizedBox(width: 6),
                    Text(
                        'Remaining: \$${remaining.toStringAsFixed(2)}',
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
                      final paidAmt =
                          double.tryParse(ctrl.text.trim());
                      if (paidAmt == null || paidAmt <= 0) return;
                      await _supabase
                          .from('expenses')
                          .update({
                        'status':      _ExpStatus.partiallyPaid.key,
                        'paid_amount': paidAmt,
                      }).eq('id', docId);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
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

  Future<void> _importExpensesFromExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    if (mounted) _showLoading('Importing expense records…');

    final excel = xl.Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) return;

    int imported = 0;
    for (final row in sheet.rows.skip(1)) {
      if (row.length < 4) continue;
      final cat     = row[0]?.value?.toString().trim() ?? '';
      final desc    = row[1]?.value?.toString().trim() ?? '';
      final dateStr = row[2]?.value?.toString().trim() ?? '';
      final amtStr  = row[3]?.value?.toString().trim() ?? '';
      final note    = row.length > 4 ? (row[4]?.value?.toString().trim() ?? '') : '';
      final status  = row.length > 5
          ? (row[5]?.value?.toString().trim().toLowerCase() ?? 'pending')
          : 'pending';

      if (cat.isEmpty || amtStr.isEmpty) continue;
      final amt = double.tryParse(amtStr);
      if (amt == null) continue;

      DateTime expenseDate;
      try {
        expenseDate = DateFormat('dd/MM/yyyy').parse(dateStr);
      } catch (_) {
        try {
          expenseDate = DateFormat('yyyy-MM-dd').parse(dateStr);
        } catch (_) {
          expenseDate = DateTime.now();
        }
      }

      final statusKey = switch (status) {
        'paid'           => 'paid',
        'partially paid' => 'partially_paid',
        _                => 'pending',
      };

      await _supabase.from('expenses').insert({
        'doctor_id':   _uid,
        'category':    cat,
        'description': desc,
        'amount':      amt,
        'status':      statusKey,
        'note':        note,
        'expense_date': expenseDate.toIso8601String(),
        'created_at':   DateTime.now().toIso8601String(),
      });
      imported++;
    }

    _hideLoading();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Imported $imported expense(s) successfully.'),
      backgroundColor: AppColors.success,
    ));
    setState(() {});
  }

  // ── Export to Excel ───────────────────────────────────────────────────────

  Future<void> _showExport(
      List<Map<String, dynamic>> docs, AppStrings s) async {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No records to export.')));
      return;
    }

    final excel = xl.Excel.createExcel();
    excel.rename('Sheet1', 'Expenses');
    final sheet = excel['Expenses'];

    sheet.appendRow([
      xl.TextCellValue('Category'),
      xl.TextCellValue('Description'),
      xl.TextCellValue('Date'),
      xl.TextCellValue('Amount'),
      xl.TextCellValue('Notes'),
      xl.TextCellValue('Status'),
    ]);

    for (final d in docs) {
      final tsStr = d['expense_date'] as String? ?? d['created_at'] as String?;
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
        xl.TextCellValue((d['category'] as String?) ?? ''),
        xl.TextCellValue((d['description'] as String?) ?? ''),
        xl.TextCellValue(date),
        xl.TextCellValue(amtStr),
        xl.TextCellValue((d['note'] ?? d['payment_method'] ?? '') as String),
        xl.TextCellValue(displayStatus),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null || !mounted) return;
    await downloadExcel(Uint8List.fromList(bytes), 'expenses_${_period}_export.xlsx');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<LanguageProvider>().isArabic);
    final isDesktop = MediaQuery.sizeOf(context).width >= kMobileBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F9),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('expenses')
            .stream(primaryKey: ['id'])
            .eq('doctor_id', _uid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.red)));
          }

          final all = snap.data ?? [];
          final filtered = _inPeriod(all);

          // ── KPI calculations ───────────────────────────────────────────
          double paidTotal    = 0;
          double pendingTotal = 0;
          double totalAmt     = 0;

          for (final d in filtered) {
            final amt = (d['amount'] as num?)?.toDouble() ?? 0;
            final st  = _ExpStatusX.fromString(d['status'] as String?);
            totalAmt += amt;
            switch (st) {
              case _ExpStatus.paid:
                paidTotal += amt;
              case _ExpStatus.partiallyPaid:
                final pAmt = (d['paid_amount'] as num?)?.toDouble() ?? 0;
                paidTotal    += pAmt;
                pendingTotal += (amt - pAmt).clamp(0, double.infinity);
              case _ExpStatus.pending:
                pendingTotal += amt;
            }
          }

          final categoryTotals = <String, double>{};
          for (final d in filtered) {
            final amt = (d['amount'] as num?)?.toDouble() ?? 0;
            final cat = d['category'] as String? ?? 'Other';
            categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amt;
          }

          String topCatName = '—';
          double topCatAmt  = 0;
          if (categoryTotals.isNotEmpty) {
            final top = categoryTotals.entries
                .reduce((a, b) => a.value > b.value ? a : b);
            topCatName = top.key;
            topCatAmt  = top.value;
          }

          return Column(
            children: [
              _expSummaryBand(
                paidTotal: paidTotal,
                pendingTotal: pendingTotal,
                total: totalAmt,
                topCatName: topCatName,
                topCatAmt: topCatAmt,
                isDesktop: isDesktop,
              ),
              _filterRow(s),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (categoryTotals.isNotEmpty) ...[
                        _categorySection(categoryTotals, totalAmt),
                        const SizedBox(height: 16),
                        _chartSection(categoryTotals, filtered),
                        const SizedBox(height: 16),
                      ],
                      _expenseList(filtered, s, isDesktop: isDesktop),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _buildFab(
          AppStrings(context.watch<LanguageProvider>().isArabic)),
    );
  }

  // ── Filter row ────────────────────────────────────────────────────────────

  Widget _filterRow(AppStrings s) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
        ...['daily', 'weekly', 'monthly', 'yearly'].map((p) {
          final sel = _period == p;
          return GestureDetector(
            onTap: () => setState(() => _period = p),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? _kAccent : const Color(0xFFF2F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                p[0].toUpperCase() + p.substring(1),
                style: TextStyle(
                    color: sel ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight:
                        sel ? FontWeight.bold : FontWeight.normal),
              ),
            ),
          );
        }),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() {
            if (_statusFilter == null) {
              _statusFilter = 'pending';
            } else if (_statusFilter == 'pending') {
              _statusFilter = 'paid';
            } else if (_statusFilter == 'paid') {
              _statusFilter = 'partially_paid';
            } else {
              _statusFilter = null;
            }
          }),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusFilter == null
                  ? const Color(0xFFF2F5F9)
                  : _statusFilter == 'paid'
                      ? const Color(0xFFE8F5E9)
                      : _statusFilter == 'partially_paid'
                          ? const Color(0xFFFBE9E7)
                          : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _statusFilter == null
                      ? Colors.transparent
                      : _statusFilter == 'paid'
                          ? const Color(0xFF2E7D32)
                          : _statusFilter == 'partially_paid'
                              ? const Color(0xFFE65100)
                              : const Color(0xFFFF8F00),
                  width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.filter_list_rounded,
                  size: 14,
                  color: _statusFilter == null
                      ? AppColors.textSecondary
                      : _statusFilter == 'paid'
                          ? const Color(0xFF2E7D32)
                          : _statusFilter == 'partially_paid'
                              ? const Color(0xFFE65100)
                              : const Color(0xFFFF8F00)),
              const SizedBox(width: 4),
              Text(
                _statusFilter == null
                    ? 'All'
                    : _statusFilter == 'partially_paid'
                        ? 'Partial'
                        : _statusFilter![0].toUpperCase() +
                            _statusFilter!.substring(1),
                style: TextStyle(
                    fontSize: 12,
                    color: _statusFilter == null
                        ? AppColors.textSecondary
                        : _statusFilter == 'paid'
                            ? const Color(0xFF2E7D32)
                            : _statusFilter == 'partially_paid'
                                ? const Color(0xFFE65100)
                                : const Color(0xFFFF8F00),
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            onPressed: _prev,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            visualDensity: VisualDensity.compact,
            color: AppColors.textSecondary,
          ),
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
            child: Text(_rangeLabel,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            onPressed: _next,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            visualDensity: VisualDensity.compact,
            color: AppColors.textSecondary,
          ),
        ]),
      ]),
    );
  }

  // ── Category section ──────────────────────────────────────────────────────

  static const _catColors = [
    Color(0xFF1565C0),
    Color(0xFF00897B),
    Color(0xFFE53935),
    Color(0xFF7B1FA2),
    Color(0xFFF57C00),
    Color(0xFF00838F),
  ];

  Widget _categorySection(
      Map<String, double> totals, double grandTotal) {
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.pie_chart_rounded,
                  size: 16, color: _kAccent),
              SizedBox(width: 6),
              Text('By Category',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _kAccent)),
            ]),
            const SizedBox(height: 14),
            ...sorted.take(6).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final pct = grandTotal > 0 ? e.value / grandTotal : 0.0;
              final color = _catColors[i % _catColors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500))),
                      Text(
                          '${_fmtAmt(e.value)}  ${(pct * 100).toStringAsFixed(0)}%',
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
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Chart section ─────────────────────────────────────────────────────────

  Widget _chartSection(Map<String, double> categoryTotals,
      List<Map<String, dynamic>> filtered) {
    final categories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (categories.isEmpty) return const SizedBox.shrink();

    final total = categories.fold(0.0, (s, e) => s + e.value);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.pie_chart_rounded, size: 16, color: _kAccent),
              SizedBox(width: 6),
              Text('Expenses by Category',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _kAccent)),
            ]),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (ctx, bc) {
              final legend = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: categories.asMap().entries.map((e) {
                  final pct = total > 0 ? (e.value.value / total * 100) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: _catColors[e.key % _catColors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(e.value.key,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Text('${pct.toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _kAccent)),
                    ]),
                  );
                }).toList(),
              );
              final pie = SizedBox(
                height: 180,
                width: 180,
                child: PieChart(
                  PieChartData(
                    sections: categories.asMap().entries.map((e) {
                      final pct = total > 0 ? (e.value.value / total * 100) : 0.0;
                      return PieChartSectionData(
                        value: e.value.value,
                        title: '${pct.toStringAsFixed(0)}%',
                        color: _catColors[e.key % _catColors.length],
                        radius: 70,
                        titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                  ),
                ),
              );
              if (bc.maxWidth < 400) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: pie),
                    const SizedBox(height: 16),
                    legend,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  pie,
                  const SizedBox(width: 20),
                  Expanded(child: legend),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Expense list ──────────────────────────────────────────────────────────

  Widget _expenseList(List<Map<String, dynamic>> docs, AppStrings s,
      {bool isDesktop = true}) {
    return Card(
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.receipt_long_rounded,
                      size: 16, color: _kAccent),
                  const SizedBox(width: 6),
                  const Text('Expense Records',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _kAccent)),
                  const Spacer(),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      onChanged: (v) =>
                          setState(() => _categoryFilter = v),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search…',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 18,
                            color: AppColors.textSecondary),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF2F5F9),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ]),
                if (isDesktop) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kAccent,
                        side: const BorderSide(color: _kAccent),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Export Report',
                          style: TextStyle(fontSize: 13)),
                      onPressed: () => _showExport(docs, s),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text('No expenses for this period',
                      style: TextStyle(
                          color: AppColors.textSecondary)),
                ]),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF2F5F9)),
              itemBuilder: (_, i) => _expenseRow(docs[i], i, s),
            ),
        ],
      ),
    );
  }

  Widget _expenseRow(Map<String, dynamic> d, int index, AppStrings s) {
    final cat = (d['category'] as String?) ?? '';
    final desc = (d['description'] as String?) ?? '';
    final tsStr = d['expense_date'] as String? ?? d['created_at'] as String?;
    final date = tsStr != null
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(tsStr))
        : '—';
    final amt  = (d['amount'] as num?)?.toDouble() ?? 0;
    final note = (d['note'] as String?) ?? (d['payment_method'] as String?) ?? '';
    final st   = _ExpStatusX.fromString(d['status'] as String?);
    final paidAmt = (d['paid_amount'] as num?)?.toDouble();
    final colorIdx = cat.hashCode.abs() % _catColors.length;
    final docId = d['id'] as String;

    return Container(
      color: index.isEven ? Colors.white : const Color(0xFFFAFBFC),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _catColors[colorIdx].withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.label_rounded,
              color: _catColors[colorIdx], size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(cat,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            if (desc.isNotEmpty)
              Text(desc,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary)),
            Text(
              note.isNotEmpty ? '$date  ·  $note' : date,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_fmtAmt(amt),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _kAccent)),
          if (st == _ExpStatus.partiallyPaid && paidAmt != null)
            Text('Paid: ${_fmtAmt(paidAmt)}',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFFE65100))),
          const SizedBox(height: 4),
          _statusBadge(st, s),
        ]),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              color: Colors.grey.shade400, size: 18),
          onSelected: (v) async {
            if (v == '__partial__') {
              _showMarkPartialSheet(docId, amt);
              return;
            }
            final newSt = _ExpStatusX.fromString(v);
            await _updateStatus(docId, newSt);
          },
          itemBuilder: (_) => [
            if (st != _ExpStatus.paid)
              PopupMenuItem(
                  value: _ExpStatus.paid.key,
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2E7D32), size: 18),
                    const SizedBox(width: 8),
                    Text(s.markAsPaid),
                  ])),
            if (st != _ExpStatus.partiallyPaid)
              const PopupMenuItem(
                  value: '__partial__',
                  child: Row(children: [
                    Icon(Icons.payments_rounded,
                        color: Color(0xFFE65100), size: 18),
                    SizedBox(width: 8),
                    Text('Mark Partially Paid'),
                  ])),
          ],
        ),
      ]),
    );
  }

  Widget _statusBadge(_ExpStatus st, AppStrings s) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: st.bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(st.icon, color: st.color, size: 11),
          const SizedBox(width: 3),
          Text(st.label(s),
              style: TextStyle(
                  color: st.color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ]),
      );

  // ── Expenses summary band ─────────────────────────────────────────────────

  Widget _expSummaryBand({
    required double paidTotal,
    required double pendingTotal,
    required double total,
    required String topCatName,
    required double topCatAmt,
    required bool isDesktop,
  }) {
    const successColor = Color(0xFF2E7D32);
    const warningColor = Color(0xFFF57F17);

    final cardA = Expanded(child: _kpiCard(title: 'Paid', amount: paidTotal,
        tint: const Color(0xFFE8F5E9), accent: successColor));
    final cardB = Expanded(child: _kpiCard(title: 'Pending', amount: pendingTotal,
        tint: const Color(0xFFFFF8E1), accent: warningColor));
    final cardC = Expanded(child: _kpiCard(title: 'Total', amount: total,
        tint: const Color(0xFFF8F0EE), accent: _kAccent));
    final cardD = Expanded(child: _kpiCard(title: 'Top Category', amount: topCatAmt,
        tint: const Color(0xFFF8F0EE), accent: _kAccent,
        sublabel: topCatName));
    const gap = SizedBox(width: 8);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: isDesktop
          ? Row(children: [cardA, gap, cardB, gap, cardC, gap, cardD])
          : Column(children: [
              Row(children: [cardA, gap, cardB]),
              const SizedBox(height: 8),
              Row(children: [cardC, gap, cardD]),
            ]),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent.withValues(alpha: 0.8))),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _fmtAmt(amount),
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: accent),
              ),
            ),
            if (sublabel != null) ...[
              const SizedBox(height: 2),
              Text(sublabel,
                  style: TextStyle(
                      fontSize: 11, color: accent.withValues(alpha: 0.65)),
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      );

  String _fmtAmt(double amt) =>
      'USD ${NumberFormat('#,##0.00', 'en_US').format(amt)}';

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFab(AppStrings s) {
    final showImport =
        FormFactorFeatures.of(context).showBillingImportExport;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showImport) ...[
          Row(mainAxisSize: MainAxisSize.min, children: [
            FloatingActionButton.small(
              heroTag: 'fab_help_expenses',
              backgroundColor: Colors.white,
              foregroundColor: Colors.grey.shade600,
              elevation: 2,
              onPressed: () => showImportHelpSheet(
                context,
                title: 'Import Expenses',
                subtitle: 'Expected Excel column order',
                columns: [
                  'Category', 'Description', 'Date', 'Amount', 'Notes', 'Status'
                ],
                examples: [
                  ['Equipment', 'Therapy bands', '01/15/2024',
                   '45', 'office supplies', 'paid'],
                  ['Rent', 'Monthly clinic rent', '02/01/2024',
                   '1200', '', 'pending'],
                ],
                notes: [
                  'Category: expense type, e.g. Equipment, Rent, Utilities',
                  'Description: details about the expense',
                  'Date format: dd/MM/yyyy or yyyy-MM-dd',
                  'Amount: number only, e.g. 45 or 45.00',
                  'Notes: optional extra information',
                  'Status values: pending · paid · partially paid',
                ],
              ),
              child: const Icon(Icons.help_outline_rounded),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: 'fab_import_expenses',
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              onPressed: _importExpensesFromExcel,
              tooltip: 'Import from Excel',
              child: const Icon(Icons.upload_file_rounded, size: 18),
            ),
          ]),
          const SizedBox(height: 10),
        ],
        FloatingActionButton.extended(
          heroTag: 'fab_add_expenses',
          backgroundColor: _kAccent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Expense',
              style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => _showAddExpense(s),
        ),
      ],
    );
  }
}
