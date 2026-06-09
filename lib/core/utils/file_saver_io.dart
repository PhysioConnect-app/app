import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadExcel(Uint8List bytes, String filename) async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    // Desktop: show native Save As dialog instead of a Share sheet
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save $filename',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (savePath != null) {
      await File(savePath).writeAsBytes(bytes);
    }
    return;
  }
  // Mobile: share via system share sheet
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)], text: filename);
}
