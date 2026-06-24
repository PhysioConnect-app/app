import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/breakpoints.dart';
import '../../core/config/form_factor_features.dart';
import '../ai/ai_service.dart';
import '../ai/financial_ai_chat_screen.dart';
import '../ai/clinic_analytics_sheet.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/language_provider.dart';
import '../../core/utils/file_saver.dart';
import '../../core/utils/excel_compat.dart';
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
  bool _aiLoading = false;

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

  Future<void> _importExpensesFromExcel() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e')),
        );
      }
      return;
    }
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file bytes. Try again.')),
        );
      }
      return;
    }

    xl.Excel excelFile;
    try {
      excelFile = decodeExcelBytes(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to parse Excel file: $e')),
        );
      }
      return;
    }
    final sheet = excelFile.tables[excelFile.tables.keys.first];
    if (sheet == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sheet found in the Excel file.')),
        );
      }
      return;
    }

    // Pre-parse all valid rows before showing the dialog
    // Column order: Date, Category, Description, Amount, Status, Notes
    final rows = <Map<String, dynamic>>[];
    for (final row in sheet.rows.skip(1)) {
      if (row.length < 4) continue;
      final cat    = row[1]?.value?.toString().trim() ?? '';
      final amtStr = row[3]?.value?.toString().trim() ?? '';
      if (cat.isEmpty || amtStr.isEmpty) continue;
      final amt = double.tryParse(amtStr);
      if (amt == null) continue;

      final dateStr = row[0]?.value?.toString().trim() ?? '';
      final desc    = row[2]?.value?.toString().trim() ?? '';
      final status  = row.length > 4
          ? (row[4]?.value?.toString().trim().toLowerCase() ?? 'pending')
          : 'pending';
      final note    = row.length > 5 ? (row[5]?.value?.toString().trim() ?? '') : '';

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

      rows.add({
        'doctor_id':    _uid,
        'category':     cat,
        'description':  desc,
        'amount':       amt,
        'status':       switch (status) {
          'paid'           => 'paid',
          'partially paid' => 'partially_paid',
          _                => 'pending',
        },
        'note':         note,
        'expense_date': expenseDate.toIso8601String(),
        'created_at':   DateTime.now().toIso8601String(),
      });
    }

    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid expense rows found.')),
        );
      }
      return;
    }

    // Show progress dialog
    final progress = ValueNotifier<double>(0);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (_, val, __) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Importing expenses…',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: val),
                  const SizedBox(height: 8),
                  Text(
                    '${(val * 100).round()}%  (${(val * rows.length).round()} / ${rows.length})',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Insert in batches of 20
    const batchSize = 20;
    int imported = 0;
    try {
      for (int i = 0; i < rows.length; i += batchSize) {
        final batch = rows.sublist(i, (i + batchSize).clamp(0, rows.length));
        await _supabase.from('expenses').insert(batch);
        imported += batch.length;
        progress.value = imported / rows.length;
      }
    } finally {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      progress.dispose();
    }

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
      xl.TextCellValue('Date'),
      xl.TextCellValue('Category'),
      xl.TextCellValue('Description'),
      xl.TextCellValue('Amount'),
      xl.TextCellValue('Status'),
      xl.TextCellValue('Notes'),
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
        xl.TextCellValue(date),
        xl.TextCellValue((d['category'] as String?) ?? ''),
        xl.TextCellValue((d['description'] as String?) ?? ''),
        xl.TextCellValue(amtStr),
        xl.TextCellValue(displayStatus),
        xl.TextCellValue((d['note'] ?? d['payment_method'] ?? '') as String),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null || !mounted) return;
    await downloadExcel(Uint8List.fromList(bytes), 'expenses_${_period}_export.xlsx');
  }

  // ── AI Expense Analysis ───────────────────────────────────────────────────

  Future<void> _showAiExpenseSheet(
      List<Map<String, dynamic>> docs, AppStrings s) async {
    setState(() => _aiLoading = true);
    // Strip note/id fields — send only what AI needs
    final slim = docs.map((d) => {
          'date': (d['expense_date'] as String? ?? d['created_at'] as String? ?? '').split('T').first,
          'category': d['category'],
          'amount': d['amount'],
          'desc': (d['description'] as String? ?? '').toString().substring(
              0, ((d['description'] as String? ?? '').length).clamp(0, 60)),
        }).toList();

    final result = await AiDoctorAssistantService.analyzeExpenses(
      dateRange: _rangeLabel,
      currency: 'USD',
      expenses: slim,
    );
    if (!mounted) return;
    setState(() => _aiLoading = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? 'Expense analysis failed'),
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
                    color: _kAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: _kAccent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Expense Analysis',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (result.usage != null)
                    Text(result.usage!.label,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ])),
              ]),
              const SizedBox(height: 16),
              if (summary.totalExpenses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    const Expanded(child: Text('Total Expenses',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                    Text(summary.totalExpenses,
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: _kAccent, fontSize: 14)),
                  ]),
                ),
              if (summary.expenseCategories.isNotEmpty) ...[
                const Text('By Category',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                ...summary.expenseCategories.map((cat) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(child: Text(cat['category'] ?? '',
                        style: const TextStyle(fontSize: 13))),
                    Text('${cat['amount'] ?? ''} (${cat['percentage'] ?? ''})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                  ]),
                )),
              ],
              if (summary.monthlySummary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kAccent.withValues(alpha: 0.2)),
                  ),
                  child: Text(summary.monthlySummary,
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
                    Expanded(child: Text(insight,
                        style: const TextStyle(fontSize: 13))),
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<LanguageProvider>().isArabic);
    final isDesktop = MediaQuery.sizeOf(context).width >= kMobileBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFFEBF2FB),
      floatingActionButton: isDesktop ? null : _buildFab(s),
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

          final all      = snap.data ?? [];
          final filtered = _inPeriod(all);

          // ── KPI calculations ───────────────────────────────────────────
          double paidTotal = 0, pendingTotal = 0, totalAmt = 0;
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

          return LayoutBuilder(
            builder: (ctx, constraints) => Column(children: [
              _expSummaryBand(
                paidTotal: paidTotal,
                pendingTotal: pendingTotal,
                total: totalAmt,
                topCatName: topCatName,
                topCatAmt: topCatAmt,
                isDesktop: isDesktop,
              ),
              _filterBar(s, isDesktop: isDesktop),
              Expanded(
                child: isDesktop
                    ? _desktopTable(filtered, s)
                    : _narrowLayout(s, filtered),
              ),
              _bottomBar(s, filtered, isDesktop: isDesktop),
            ]),
          );
        },
      ),
    );
  }

  // ── Filter bar ────────────────────────────────────────────────────────────

  Widget _filterBar(AppStrings s, {bool isDesktop = false}) {
    Widget periodPicker() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
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
        color: Colors.white, borderRadius: BorderRadius.circular(8)),
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
                    color: _kAccent, fontWeight: FontWeight.w600, fontSize: 12)),
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
      onChanged: (v) => setState(() => _categoryFilter = v),
      decoration: InputDecoration(
        hintText: 'Search category...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        prefixIcon:
            const Icon(Icons.search_rounded, color: Colors.white, size: 16),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          items: [null, 'pending', 'paid', 'partially_paid']
              .map((st) => DropdownMenuItem(
                value: st,
                child: Row(children: [
                  const Icon(Icons.filter_list_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    st == null
                        ? 'All'
                        : st == 'partially_paid'
                            ? 'Partial'
                            : st[0].toUpperCase() + st.substring(1),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ]),
              )).toList(),
          onChanged: (v) => setState(() => _statusFilter = v),
        ),
      ),
    );

    if (isDesktop) {
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

    return Container(
      color: _kAccent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(children: [
        Row(children: [periodPicker(), const Spacer(), datePicker()]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: searchField()),
          const SizedBox(width: 8),
          statusFilter(),
        ]),
      ]),
    );
  }

  static const _catColors = [
    Color(0xFF1565C0),
    Color(0xFF00897B),
    Color(0xFFE53935),
    Color(0xFF7B1FA2),
    Color(0xFFF57C00),
    Color(0xFF00838F),
  ];

  // ── Desktop table ─────────────────────────────────────────────────────────

  Widget _desktopTable(
    List<Map<String, dynamic>> filtered,
    AppStrings s,
  ) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Column(children: [
          Expanded(
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              color: Colors.white,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
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
                    _th('Date',        flex: 2),
                    _th('Category',    flex: 2),
                    _th('Description', flex: 3),
                    _th('Amount',      flex: 2),
                    _th('Status',      flex: 2),
                    const SizedBox(width: 32),
                  ]),
                ),
                if (filtered.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 50, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text(s.noData,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ]),
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
              ]),
            ),
          ),
        ]),
      );

  Widget _th(String label, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      );

  Widget _tableRow(Map<String, dynamic> d, int index, AppStrings s) {
    final cat   = (d['category'] as String?) ?? '';
    final desc  = (d['description'] as String?) ?? '';
    final tsStr = d['expense_date'] as String? ?? d['created_at'] as String?;
    final date  = tsStr != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(tsStr))
        : '—';
    final amt   = (d['amount'] as num?)?.toDouble() ?? 0;
    final st    = _ExpStatusX.fromString(d['status'] as String?);
    final bg    = index.isEven ? Colors.white : const Color(0xFFF8FAFF);
    final docId = d['id'] as String;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(children: [
        Expanded(flex: 2,
            child: Text(date,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13))),
        Expanded(flex: 2,
            child: Text(cat,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(flex: 3,
            child: Text(desc,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2,
            child: Text(_fmtAmt(amt),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13))),
        Expanded(flex: 2, child: _statusBadge(st, s)),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              color: Colors.grey.shade400, size: 18),
          onSelected: (v) async {
            if (v == '__partial__') {
              _showMarkPartialSheet(docId, amt);
              return;
            }
            await _updateStatus(docId, _ExpStatusX.fromString(v));
          },
          itemBuilder: (_) => [
            if (st != _ExpStatus.paid)
              PopupMenuItem(value: _ExpStatus.paid.key,
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2E7D32), size: 18),
                    const SizedBox(width: 8), Text(s.markAsPaid),
                  ])),
            if (st != _ExpStatus.partiallyPaid)
              const PopupMenuItem(value: '__partial__',
                  child: Row(children: [
                    Icon(Icons.payments_rounded,
                        color: Color(0xFFE65100), size: 18),
                    SizedBox(width: 8), Text('Mark Partially Paid'),
                  ])),
            if (st != _ExpStatus.pending)
              PopupMenuItem(value: _ExpStatus.pending.key,
                  child: Row(children: [
                    const Icon(Icons.schedule_rounded,
                        color: Color(0xFFFF8F00), size: 18),
                    const SizedBox(width: 8), Text(s.statusPending),
                  ])),
          ],
        ),
      ]),
    );
  }

  // ── Narrow layout (mobile, grouped by date) ────────────────────────────────

  Widget _narrowLayout(
    AppStrings s,
    List<Map<String, dynamic>> filtered,
  ) {
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
          Text('No expenses in this period',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ]),
      );
    }

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final exp in filtered) {
      final tsStr =
          exp['expense_date'] as String? ?? exp['created_at'] as String?;
      final key = tsStr != null
          ? DateFormat('MMM d, yyyy').format(DateTime.parse(tsStr))
          : 'Unknown';
      groups.putIfAbsent(key, () => []).add(exp);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: [
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.receipt_long_outlined,
                    size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                const Text('No expenses for this period',
                    style: TextStyle(color: AppColors.textSecondary)),
              ]),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${filtered.length} expense${filtered.length == 1 ? '' : 's'}',
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
            for (final exp in entry.value) ...[
              _compactExpenseCard(exp, s),
              const SizedBox(height: 6),
            ],
          ],
        ],
      ],
    );
  }

  // ── Compact expense card (mobile) ─────────────────────────────────────────

  Widget _compactExpenseCard(Map<String, dynamic> d, AppStrings s) {
    final cat     = (d['category'] as String?) ?? '';
    final desc    = (d['description'] as String?) ?? '';
    final tsStr   = d['expense_date'] as String? ?? d['created_at'] as String?;
    final date    = tsStr != null
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(tsStr))
        : '—';
    final amt     = (d['amount'] as num?)?.toDouble() ?? 0;
    final note    = (d['note'] as String?) ?? '';
    final paidAmt = (d['paid_amount'] as num?)?.toDouble();
    final st      = _ExpStatusX.fromString(d['status'] as String?);
    final docId   = d['id'] as String;
    final colorIdx = cat.hashCode.abs() % _catColors.length;
    final catColor = _catColors[colorIdx];

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: st.color),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.10),
                      shape: BoxShape.circle),
                  child: Icon(Icons.label_rounded,
                      color: catColor, size: 15),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 11, 8, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(desc,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ],
                    const SizedBox(height: 2),
                    Text(note.isNotEmpty ? '$date  ·  $note' : date,
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                    if (st == _ExpStatus.partiallyPaid &&
                        paidAmt != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Paid: ${_fmtAmt(paidAmt)}  ·  Rem: ${_fmtAmt((amt - paidAmt).clamp(0, double.infinity))}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFE65100),
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
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
                          color: _kAccent)),
                  const SizedBox(height: 4),
                  _statusBadge(st, s),
                ],
              ),
            ),
            Center(
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: Colors.grey.shade400, size: 18),
                onSelected: (v) async {
                  if (v == '__partial__') {
                    _showMarkPartialSheet(docId, amt);
                    return;
                  }
                  await _updateStatus(docId, _ExpStatusX.fromString(v));
                },
                itemBuilder: (_) => [
                  if (st != _ExpStatus.paid)
                    PopupMenuItem(value: _ExpStatus.paid.key,
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF2E7D32), size: 18),
                          const SizedBox(width: 8), Text(s.markAsPaid),
                        ])),
                  if (st != _ExpStatus.partiallyPaid)
                    const PopupMenuItem(value: '__partial__',
                        child: Row(children: [
                          Icon(Icons.payments_rounded,
                              color: Color(0xFFE65100), size: 18),
                          SizedBox(width: 8), Text('Mark Partially Paid'),
                        ])),
                  if (st != _ExpStatus.pending)
                    PopupMenuItem(value: _ExpStatus.pending.key,
                        child: Row(children: [
                          const Icon(Icons.schedule_rounded,
                              color: Color(0xFFFF8F00), size: 18),
                          const SizedBox(width: 8), Text(s.statusPending),
                        ])),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Bottom action bar (desktop only) ──────────────────────────────────────

  Widget _bottomBar(AppStrings s, List<Map<String, dynamic>> filtered,
      {bool isDesktop = false}) {
    if (!isDesktop) return const SizedBox.shrink();
    final showImport =
        FormFactorFeatures.of(context).showBillingImportExport;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 3,
              shadowColor: _kAccent.withValues(alpha: 0.35),
            ),
            icon: const Icon(Icons.add_circle_rounded, size: 20),
            label: const Text('+ Add Expense',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            onPressed: () => _showAddExpense(s),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _smallActionBtn(
            icon: _aiLoading
                ? Icons.hourglass_top_rounded
                : Icons.auto_awesome_rounded,
            label: _aiLoading ? 'Analyzing…' : 'AI Analysis',
            onTap: (_aiLoading || filtered.isEmpty)
                ? () {}
                : () => _showAiExpenseSheet(filtered, s),
          )),
          const SizedBox(width: 5),
          Expanded(child: _smallActionBtn(
            icon: Icons.chat_rounded,
            label: 'AI Chat',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const FinancialAiChatScreen())),
          )),
          const SizedBox(width: 5),
          Expanded(child: _smallActionBtn(
            icon: Icons.insights_rounded,
            label: 'Analytics',
            onTap: () => showClinicAnalyticsSheet(context),
          )),
          const SizedBox(width: 5),
          Expanded(child: _smallActionBtn(
            icon: Icons.download_rounded,
            label: 'Export',
            onTap: () => _showExport(filtered, s),
          )),
          if (showImport) ...[
            const SizedBox(width: 5),
            Expanded(child: _smallActionBtn(
              icon: Icons.upload_file_rounded,
              label: 'Import',
              onTap: _importExpensesFromExcel,
            )),
          ],
        ]),
      ]),
    );
  }

  Widget _smallActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: _kAccent,
          side: const BorderSide(color: Color(0xFFD4B5AD)),
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFFFAF4F2),
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
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 11)),
            ),
          ],
        ),
      );

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
        Row(mainAxisSize: MainAxisSize.min, children: [
          FloatingActionButton.small(
            heroTag: 'fab_analytics_expenses',
            backgroundColor: Colors.white,
            foregroundColor: _kAccent,
            elevation: 2,
            onPressed: () => showClinicAnalyticsSheet(context),
            tooltip: 'Business Analytics',
            child: const Icon(Icons.insights_rounded, size: 18),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'fab_chat_expenses',
            backgroundColor: Colors.white,
            foregroundColor: _kAccent,
            elevation: 2,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const FinancialAiChatScreen())),
            tooltip: 'AI Financial Assistant',
            child: const Icon(Icons.chat_rounded, size: 18),
          ),
        ]),
        const SizedBox(height: 10),
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
                  'Date', 'Category', 'Description', 'Amount', 'Status', 'Notes'
                ],
                examples: [
                  ['01/15/2024', 'Equipment', 'Therapy bands',
                   '45', 'paid', 'office supplies'],
                  ['02/01/2024', 'Rent', 'Monthly clinic rent',
                   '1200', 'pending', ''],
                ],
                notes: [
                  'Date format: dd/MM/yyyy or yyyy-MM-dd',
                  'Category: expense type, e.g. Equipment, Rent, Utilities',
                  'Description: details about the expense',
                  'Amount: number only, e.g. 45 or 45.00',
                  'Status values: pending · paid · partially paid',
                  'Notes: optional extra information',
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
