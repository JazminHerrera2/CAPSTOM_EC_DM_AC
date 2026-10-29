import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ImagenBeneficioException implements Exception {
  final String mensaje;
  ImagenBeneficioException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Sube, muestra y borra las imágenes del catálogo de beneficios.
///
/// Igual que la app, nunca habla con Supabase Storage directamente: todo pasa
/// por la Edge Function `secure-document-upload`, que valida el ID Token de
/// Firebase y exige ser super admin para subir o borrar en `beneficios/`.
class BeneficioImagenService {
  static const _funcion = 'secure-document-upload';
  static const _timeout = Duration(seconds: 30);

  /// Tamaño máximo que acepta la función para estas imágenes.
  static const int maxBytes = 5 * 1024 * 1024;

  static const Map<String, String> _tipos = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static List<String> get extensionesPermitidas => _tipos.keys.toList();

  /// `false` si SUPABASE_URL falta en el .env del panel.
  static bool get configurado {
    final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    return url.startsWith('https://') && !url.contains('tu-proyecto-id');
  }

  static String? tipoDe(String extension) => _tipos[extension.toLowerCase()];

  Future<Uri> _endpoint() async {
    if (!configurado) {
      throw ImagenBeneficioException(
        'Falta SUPABASE_URL en el archivo .env del panel admin.',
      );
    }
    final base =
        dotenv.env['SUPABASE_URL']!.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/functions/v1/$_funcion');
  }

  Future<String> _idToken() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) {
      throw ImagenBeneficioException('No hay sesión iniciada.');
    }
    return token;
  }

  Future<http.Response> _enviar(Future<http.Response> Function() peticion) async {
    try {
      return await peticion().timeout(_timeout);
    } on ImagenBeneficioException {
      rethrow;
    } catch (e) {
      throw ImagenBeneficioException('Sin conexión con el servicio de archivos: $e');
    }
  }

  void _verificar(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    var detalle = r.body;
    try {
      detalle = (jsonDecode(r.body) as Map)['error']?.toString() ?? detalle;
    } catch (_) {}
    throw ImagenBeneficioException('($detalle)');
  }

  /// Sube la imagen y devuelve su ruta (`beneficios/{archivo}`), que es lo que
  /// se guarda en `imagen_path`.
  Future<String> subir({
    required Uint8List bytes,
    required String extension,
  }) async {
    final tipo = tipoDe(extension);
    if (tipo == null) {
      throw ImagenBeneficioException('Formato no permitido. Usa JPG, PNG o WEBP.');
    }
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw ImagenBeneficioException('La imagen debe pesar menos de 5 MB.');
    }

    final path =
        'beneficios/${DateTime.now().millisecondsSinceEpoch}.${extension.toLowerCase()}';
    final request = http.MultipartRequest('POST', await _endpoint())
      ..headers['Authorization'] = 'Bearer ${await _idToken()}'
      ..fields['path'] = path
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: path.split('/').last,
        contentType: MediaType.parse(tipo),
      ));

    final respuesta = await _enviar(() async {
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
    _verificar(respuesta);
    return path;
  }

  /// URL firmada (expira en ~10 min) para mostrar una imagen ya subida.
  Future<String> urlFirmada(String path) async {
    final respuesta = await _enviar(
      () async => http.post(
        await _endpoint(),
        headers: {
          'Authorization': 'Bearer ${await _idToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'action': 'sign', 'path': path}),
      ),
    );
    _verificar(respuesta);
    final url = (jsonDecode(respuesta.body) as Map)['signedUrl'];
    if (url is! String) throw ImagenBeneficioException('Respuesta inválida');
    return url;
  }

  Future<void> eliminar(String path) async {
    final respuesta = await _enviar(
      () async => http.post(
        await _endpoint(),
        headers: {
          'Authorization': 'Bearer ${await _idToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'action': 'delete', 'path': path}),
      ),
    );
    _verificar(respuesta);
  }
}
