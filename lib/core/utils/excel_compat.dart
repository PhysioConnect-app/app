import 'dart:convert' show utf8;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/foundation.dart' show debugPrint;

/// Thrown when an xlsx file cannot be parsed — either because it is
/// structurally invalid, uses unsupported features, or hit a null-assertion
/// inside the excel package (e.g. missing shared-strings relationship).
class UnreadableWorkbookException implements Exception {
  final String message;
  const UnreadableWorkbookException(this.message);
  @override
  String toString() => message;
}

/// Decodes an xlsx/xls [bytes] buffer into an [xl.Excel] object.
///
/// The excel package throws two distinct classes of error:
///
///  1. [Exception] with message containing "numFmtId" — some files place
///     built-in numFmt IDs (0–163) in the custom `<numFmts>` section.
///     We retry after stripping those entries from styles.xml.
///
///  2. Everything else (null-assertion [Error], JS TypeError on web, …) —
///     the shared-strings relationship is missing or the archive is corrupt.
///     We rethrow as [UnreadableWorkbookException] so callers can show a
///     specific, human-readable message.
xl.Excel decodeExcelBytes(List<int> bytes) {
  try {
    return xl.Excel.decodeBytes(bytes);
  } on Exception catch (e) {
    // Explicit Exception thrown by the excel package — only the numFmt
    // compatibility path is recoverable with a style-strip retry.
    if (e.toString().contains('numFmtId')) {
      try {
        return xl.Excel.decodeBytes(
            _stripBuiltinNumFmts(Uint8List.fromList(bytes)));
      } catch (e2, st2) {
        debugPrint('excel_compat: stripped-styles retry failed — $e2\n$st2');
        throw const UnreadableWorkbookException(
            'Could not read the file — make sure it is a valid .xlsx and not password-protected.');
      }
    }
    // Any other Exception from the package → wrap and surface cleanly.
    debugPrint('excel_compat: decode Exception — $e');
    throw const UnreadableWorkbookException(
        'Could not read the file — make sure it is a valid .xlsx and not password-protected.');
  } catch (e, st) {
    // Error / JS TypeError / null-check failures (e.g. parse.dart:613
    // sharedString!.textSpan when the shared-strings relationship is absent).
    debugPrint('excel_compat: decode error — $e\n$st');
    throw const UnreadableWorkbookException(
        'Could not read the file — make sure it is a valid .xlsx and not password-protected.');
  }
}

/// Patches `xl/styles.xml` inside the XLSX ZIP so the `excel` package can
/// parse files that misuse built-in numFmt IDs (0–163) in the custom section.
Uint8List _stripBuiltinNumFmts(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final out = Archive();
    for (final file in archive.files) {
      if (file.name == 'xl/styles.xml' && file.isFile) {
        var xml = utf8.decode(file.content as List<int>);

        // Step 1 — remove <numFmt> definitions with built-in IDs (0–163).
        xml = xml.replaceAll(
          RegExp(
            r'<numFmt\b[^>]*\bnumFmtId="(?:[0-9]{1,2}|1[0-5][0-9]|16[0-3])"[^/]*/?>',
            caseSensitive: false,
          ),
          '',
        );

        // Step 2 — remap leftover references (e.g. in <xf> elements) for IDs
        // 1–163 to 0 (General), which the excel package always recognises.
        xml = xml.replaceAllMapped(
          RegExp(r'numFmtId="(\d+)"'),
          (m) {
            final id = int.tryParse(m.group(1)!) ?? 0;
            return (id >= 1 && id <= 163) ? 'numFmtId="0"' : m.group(0)!;
          },
        );

        final fixedBytes = utf8.encode(xml);
        out.addFile(ArchiveFile(file.name, fixedBytes.length, fixedBytes));
      } else {
        out.addFile(file);
      }
    }
    final encoded = ZipEncoder().encode(out);
    if (encoded == null) return bytes; // encoder failed — return original
    return Uint8List.fromList(encoded);
  } catch (_) {
    return bytes; // patching failed — return original bytes
  }
}
