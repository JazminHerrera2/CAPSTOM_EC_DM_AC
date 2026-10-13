import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Lado máximo (px) de la imagen que se envía a la IA. Más grande no mejora la
/// lectura y solo encarece y demora la llamada; más chico pierde letra pequeña.
const int ladoMaximoImagenIa = 2000;

/// Bajo este peso la imagen se envía tal cual: ya es liviana, y decodificarla
/// y recomprimirla cuesta más de lo que aporta (incluso puede dejarla más
/// pesada).
const int umbralPrepararBytes = 1500000;

/// Textos de las etapas que se muestran mientras se procesa un documento.
const String etapaPreparandoImagen = 'Preparando imagen...';
const String etapaAnalizando = 'Analizando con IA...';

/// Resultado de preparar una imagen: los bytes y su tipo MIME real.
typedef ImagenPreparada = ({Uint8List bytes, String mimeType});

/// Deja la imagen lista para la IA: corrige la orientación EXIF, reduce el
/// tamaño si excede [ladoMaximoImagenIa] y la guarda como JPEG de calidad alta.
/// `true` si [prepararImagenParaIa] va a procesar la imagen (y por tanto puede
/// tardar). Sirve para avisar al usuario con "Preparando imagen..." solo cuando
/// de verdad hay trabajo que hacer.
bool imagenRequierePreparacion(
  Uint8List bytes,
  String mimeType, {
  int umbralBytes = umbralPrepararBytes,
}) => mimeType.startsWith('image/') && bytes.length >= umbralBytes;

/// Devuelve la imagen original sin tocar cuando:
/// - pesa menos de [umbralBytes];
/// - algo falla (formato raro, archivo dañado);
/// - el resultado no pesa menos que el original.
/// Preparar es una mejora, nunca debe demorar ni impedir el análisis.
///
/// En Android/iOS/escritorio se ejecuta en un isolate aparte. En web no hay
/// hilos aparte: la pantalla puede dejar de animarse mientras dura, por eso el
/// llamador debe mostrar antes un aviso y ceder un cuadro de pantalla.
Future<ImagenPreparada> prepararImagenParaIa(
  Uint8List bytes,
  String mimeType, {
  int umbralBytes = umbralPrepararBytes,
}) async {
  final original = (bytes: bytes, mimeType: mimeType);
  if (!imagenRequierePreparacion(bytes, mimeType, umbralBytes: umbralBytes)) {
    return original;
  }
  try {
    final resultado = await compute(_procesar, bytes);
    if (resultado == null || resultado.length >= bytes.length) return original;
    return (bytes: resultado, mimeType: 'image/jpeg');
  } catch (e) {
    debugPrint('prepararImagenParaIa: se usa la imagen original ($e)');
    return original;
  }
}

Uint8List? _procesar(Uint8List bytes) {
  final decodificada = img.decodeImage(bytes);
  if (decodificada == null) return null;

  var imagen = img.bakeOrientation(decodificada);

  final mayor = imagen.width > imagen.height ? imagen.width : imagen.height;
  if (mayor > ladoMaximoImagenIa) {
    imagen = imagen.width >= imagen.height
        ? img.copyResize(
            imagen,
            width: ladoMaximoImagenIa,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            imagen,
            height: ladoMaximoImagenIa,
            interpolation: img.Interpolation.average,
          );
  }

  return Uint8List.fromList(img.encodeJpg(imagen, quality: 88));
}
