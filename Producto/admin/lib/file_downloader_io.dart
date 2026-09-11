import 'dart:io';

void saveFileImpl(String content, String fileName) {
  final path = 'C:/Users/igna_/Downloads/$fileName';
  final file = File(path);
  final directory = Directory('C:/Users/igna_/Downloads');
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  file.writeAsStringSync(content);
}
