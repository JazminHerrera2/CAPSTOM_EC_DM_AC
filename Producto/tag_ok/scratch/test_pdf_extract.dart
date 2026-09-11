import 'dart:io';
import 'dart:convert';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void testPdf(String filepath, String regexPattern, String type) {
  print('\n=== PROBANDO PDF: $filepath ($type) ===');
  final fileBytes = File(filepath).readAsBytesSync();
  final PdfDocument document = PdfDocument(inputBytes: fileBytes);
  final PdfTextExtractor extractor = PdfTextExtractor(document);
  final String text = extractor.extractText();
  document.dispose();

  final lines = const LineSplitter().convert(text);
  print('Total líneas extraídas: ${lines.length}');
  
  final regex = RegExp(regexPattern);
  int matchCount = 0;
  List<String> failedLines = [];

  for (var line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    // Si tiene aspecto de transacción (ej. tiene fecha)
    if (trimmed.contains(RegExp(r'\d{2}[-/]\d{2}[-/]\d{4}'))) {
      final match = regex.firstMatch(trimmed);
      if (match != null) {
        matchCount++;
      } else {
        failedLines.add(trimmed);
      }
    }
  }

  print('Líneas con coincidencia de Regex: $matchCount');
  if (failedLines.isNotEmpty) {
    print('Líneas sospechosas que NO coincidieron:');
    for (var l in failedLines) {
      print('  -> "$l"');
    }
  }
}

void main() {
  final basePath = 'pdf_privados';
  
  // Costanera Norte
  testPdf(
    '$basePath/COSTANERA_NORTE.pdf',
    r'(\d{2}/\d{2}/\d{4})\s+(\d{2}:\d{2})\s*([A-Z]+)\s+(.+?)\s*(TS|TBP|TBFP)\s+\$\s*([\d\.,]+)\s*([A-Z0-9]+)',
    'Costanera Norte'
  );

  // Vespucio Sur
  testPdf(
    '$basePath/VESPUCIO_SUR.pdf',
    r'(\d{2}/\d{2}/\d{4})\s+(\d{2}:\d{2})\s*VS\s+(PdC[\d\.]+)\s*(TBFP|TBP|TS)\s+\$\s*([\d\.,]+)\s*([A-Z0-9]+)',
    'Vespucio Sur'
  );

  // Vespucio Norte
  testPdf(
    '$basePath/VESPUCIO_NORTE_1.pdf',
    r'([A-Z0-9]+)\s+(\d{2}-\d{2}-\d{4})\s+(\d{2}:\d{2}:\d{2})\s+(?:O-P|P-O)\s+(\d+)\s+(?:Laboral|Domingo|Sábado)\s+(?:TBFP|TBP|TS)\s+Normal\s+\$\s*([\d\.,]+)',
    'Vespucio Norte'
  );
}
