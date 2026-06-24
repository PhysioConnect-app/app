import 'dart:convert' show utf8;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xl;

/// Decodes an xlsx/xls [bytes] buffer into an [xl.Excel] object.
///
/// Some Excel files (created by LibreOffice, older Excel, or certain templates)
/// place built-in numFmt IDs (0–163) in the custom `<numFmts>` section of
/// `xl/styles.xml`. The `excel` Dart package throws on these files.
/// This function transparently retries with those entries stripped from the
/// ZIP before passing to the parser, so such files load correctly.
xl.Excel decodeExcelBytes(List<int> bytes) {
  try {
    return xl.Excel.decodeBytes(bytes);
  } catch (_) {
    return xl.Excel.decodeBytes(_stripBuiltinNumFmts(Uint8List.fromList(bytes)));
  }
}

/// Patches `xl/styles.xml` inside the XLSX ZIP so the `excel` package can
/// parse files that misuse built-in numFmt IDs (0–163) in the custom section.
///
/// Two-step fix:
///  1. Remove every `<numFmt>` element whose `numFmtId` is 0–163 (built-in
///     range). Without this, the package throws
///     "custom numFmtId starts at 164 but found X".
///  2. Remap every remaining `numFmtId="X"` reference (e.g. in `<xf>` cells)
///     where X is 1–163 to `numFmtId="0"` (General format). Without this,
///     the package asserts "missing numFmt for X" because the definition
///     was just removed in step 1.
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
    return Uint8List.fromList(ZipEncoder().encode(out)!);
  } catch (_) {
    return bytes; // patching failed — return original bytes
  }
}
