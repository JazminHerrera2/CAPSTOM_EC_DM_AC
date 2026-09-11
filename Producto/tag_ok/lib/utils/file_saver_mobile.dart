import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

Future<void> saveFileBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(tempFile.path)],
      subject: 'Reporte de Conciliación',
    );
  } else {
    final String? result = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar Reporte de Conciliación',
      fileName: fileName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result == null) {
      // The user cancelled the dialog, which is not an error but we can throw a silent exception or handle it
      throw Exception('Operación cancelada por el usuario.');
    }
  }
}
