import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

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
