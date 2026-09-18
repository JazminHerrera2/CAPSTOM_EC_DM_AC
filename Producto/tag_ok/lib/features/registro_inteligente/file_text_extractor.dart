import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Extrae texto plano de archivos PDF/Excel — mismo enfoque que ya usa
/// `screens/audit_screen.dart` para boletas, factorizado acá para que el
/// componente de Registro Inteligente no lo reimplemente.
///
/// Para fotografías (jpg/png) no aplica: esas se envían directamente como
/// imagen a Gemini (multimodal), no se les extrae texto.
class FileTextExtractor {
  static String extraerDePdf(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    final texto = PdfTextExtractor(document).extractText();
    document.dispose();
    return texto;
  }

  static String extraerDeExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final buffer = StringBuffer();
    for (final tabla in excel.tables.keys) {
      final hoja = excel.tables[tabla]!;
      for (final fila in hoja.rows) {
        buffer.writeln(
          fila.map((celda) => celda?.value?.toString() ?? '').join(' '),
        );
      }
    }
    return buffer.toString();
  }

  /// Detecta el formato por extensión y devuelve el texto extraído, o null
  /// si el archivo es una imagen (debe enviarse como bytes, no como texto).
  static String? extraerDeArchivo(String nombreArchivo, Uint8List bytes) {
    final nombre = nombreArchivo.toLowerCase();
    if (nombre.endsWith('.pdf')) return extraerDePdf(bytes);
    if (nombre.endsWith('.xlsx')) return extraerDeExcel(bytes);
    return null;
  }
}
