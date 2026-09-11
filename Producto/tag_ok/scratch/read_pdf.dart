import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  final File file = File('pdf porticos/AUTOPISTA-CENTRAL.pdf');
  final PdfDocument document = PdfDocument(inputBytes: file.readAsBytesSync());
  String text = PdfTextExtractor(document).extractText();
  document.dispose();
  
  // Imprimir solo las primeras 1000 letras para ver el formato
  print(text.substring(0, text.length > 2000 ? 2000 : text.length));
}
