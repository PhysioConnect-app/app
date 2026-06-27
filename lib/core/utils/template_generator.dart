import 'dart:typed_data';
import 'package:excel/excel.dart';

/// Builds the PhysioConnect import template in memory using the excel package.
/// Returns xlsx bytes ready to pass to downloadExcel().
Uint8List generateImportTemplateBytes() {
  final excel = Excel.createExcel();

  // Remove the default "Sheet1" that Excel.createExcel() adds.
  final defaultSheet = excel.getDefaultSheet();
  final sheet = excel['Import'];
  if (defaultSheet != null && defaultSheet != 'Import') {
    excel.delete(defaultSheet);
  }

  // Header row — must match exactly what the parser looks for.
  sheet.appendRow([
    TextCellValue('Date'),
    TextCellValue('Patient Name'),
    TextCellValue('amount'),
    TextCellValue('status'),
    TextCellValue('service'),
    TextCellValue('note'),
  ]);

  // Example rows: paid, pending, partially_paid — cover common cases.
  sheet.appendRow([
    TextCellValue('21/05/2026'),
    TextCellValue('Ahmed Khalil'),
    TextCellValue('150'),
    TextCellValue('paid'),
    TextCellValue('Physical Therapy'),
    TextCellValue(''),
  ]);
  sheet.appendRow([
    TextCellValue('22/05/2026'),
    TextCellValue('Sara Mansour'),
    TextCellValue('200'),
    TextCellValue('pending'),
    TextCellValue('Follow-up Session'),
    TextCellValue(''),
  ]);
  sheet.appendRow([
    TextCellValue('23/05/2026'),
    TextCellValue('Omar Hassan'),
    TextCellValue('175'),
    TextCellValue('partially_paid'),
    TextCellValue('Initial Evaluation'),
    TextCellValue('First visit'),
  ]);

  return Uint8List.fromList(excel.encode()!);
}
