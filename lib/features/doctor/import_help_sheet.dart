import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// ── Guide AlertDialog ─────────────────────────────────────────────────────────

void showImportGuideDialog(
  BuildContext context, {
  VoidCallback? onDownloadTemplate,
}) {
  showDialog(
    context: context,
    builder: (_) => _ImportGuideDialog(onDownloadTemplate: onDownloadTemplate),
  );
}

class _ImportGuideDialog extends StatelessWidget {
  final VoidCallback? onDownloadTemplate;
  const _ImportGuideDialog({this.onDownloadTemplate});

  static const _teal = Color(0xFF0E8C8C);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Excel Import Format',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Columns ─────────────────────────────────────────────────────
            _sectionLabel('Required columns (header row must be first)'),
            const SizedBox(height: 6),
            _colRow('A', 'Date', required: true),
            _colRow('B', 'Patient Name', required: true),
            _colRow('C', 'amount', required: true),
            _colRow('D', 'status', required: false),
            _colRow('E', 'service', required: false),
            _colRow('F', 'note', required: false),

            const SizedBox(height: 14),

            // ── Date formats ────────────────────────────────────────────────
            _sectionLabel('Date column — accepted formats'),
            const SizedBox(height: 6),
            _mono('21/05/2026       DD/MM/YYYY'),
            _mono('2026-05-21       ISO 8601'),
            _mono('21 May 2026      day month year'),
            _mono('Thu, 21 May 2026 weekday prefix OK'),
            _mono('May 21, 2026     month day, year'),
            _mono('21/05/26         2-digit year'),
            const SizedBox(height: 4),
            _note('Numeric dates use DD/MM order (21/05 = 21 May), matching local convention.'),

            const SizedBox(height: 14),

            // ── Amount ──────────────────────────────────────────────────────
            _sectionLabel('amount'),
            const SizedBox(height: 4),
            _note('Numbers only — no currency symbol. Example: 150 or 75.50'),

            const SizedBox(height: 14),

            // ── Status ──────────────────────────────────────────────────────
            _sectionLabel('status — accepted values'),
            const SizedBox(height: 6),
            _mono('paid'),
            _mono('pending'),
            _mono('partially_paid'),
            _mono('cancelled'),
            const SizedBox(height: 4),
            _note('Casing does not matter. Blank or unrecognised values default to pending.'),

            const SizedBox(height: 14),
            Container(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 10),

            // ── Tip ─────────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 14, color: Color(0xFFE65100)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tip: rows with an amount but no parseable date still import'
                    ' as invoices but won\'t appear on the schedule.',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onDownloadTemplate,
          child: const Text('Download template'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _teal),
      );

  Widget _colRow(String col, String name, {required bool required}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(col,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _teal)),
          ),
          const SizedBox(width: 8),
          Text(name,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          Text(
            required ? 'required' : 'optional',
            style: TextStyle(
                fontSize: 10,
                color: required ? _teal : Colors.grey.shade500,
                fontWeight: FontWeight.w500),
          ),
        ]),
      );

  Widget _mono(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2, left: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                letterSpacing: 0.3,
                color: Color(0xFF333333))),
      );

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.4)),
      );
}

// ── Public entry point ────────────────────────────────────────────────────────

void showImportHelpSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<String> columns,
  required List<List<String>> examples,
  required List<String> notes,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _ImportHelpSheet(
      title: title,
      subtitle: subtitle,
      columns: columns,
      examples: examples,
      notes: notes,
    ),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

class _ImportHelpSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> columns;
  final List<List<String>> examples;
  final List<String> notes;

  const _ImportHelpSheet({
    required this.title,
    required this.subtitle,
    required this.columns,
    required this.examples,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ── Title row ───────────────────────────────────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.table_chart_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          // ── Column pills ─────────────────────────────────────────────────
          const Text('Required columns (in order):',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: columns.asMap().entries.map((e) {
                final letter =
                    String.fromCharCode('A'.codeUnitAt(0) + e.key);
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text(letter,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                    const SizedBox(height: 2),
                    Text(e.value,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // ── Example table ────────────────────────────────────────────────
          const Text('Example:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Table(
                defaultColumnWidth:
                    const IntrinsicColumnWidth(),
                border: TableBorder.all(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                children: [
                  // Header row
                  TableRow(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                    children: columns
                        .map((c) => _cell(c, bold: true))
                        .toList(),
                  ),
                  // Example rows
                  ...examples.map((row) => TableRow(
                        children: row
                            .map((v) => _cell(v, bold: false))
                            .toList(),
                      )),
                ],
              ),
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Notes:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            ...notes.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4, right: 6),
                        child: Icon(Icons.circle,
                            size: 5,
                            color: AppColors.textSecondary),
                      ),
                      Expanded(
                        child: Text(n,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.4)),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _cell(String text, {required bool bold}) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal)),
      );
}
