import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class StorageException implements Exception {
  final String mensaje;
  final int? status;
  StorageException(this.mensaje, {this.status});

  @override
  String toString() => 'StorageException(${status ?? '-'}): $mensaje';
}

/// Sube/lee documentos del bucket privado de Supabase Storage.
///
/// El cliente NUNCA habla con Supabase Storage directamente: todo pasa por la
/// Edge Function `secure-document-upload`, que valida el ID Token de Firebase
/// y que el path sea `usuarios/{uid}/...` antes de usar la Service Role Key.
/// En Firestore (`archivo_path`) se guarda el path, no una URL: el bucket es
/// privado y la URL firmada se pide al momento de mostrar el archivo.
class StorageService {
  static const _funcion = 'secure-document-upload';
  static const _timeout = Duration(seconds: 30);

  /// `false` si SUPABASE_URL falta o sigue con el placeholder. En ese caso
  /// quien llama debe guardar el documento sin archivo.
  static bool get configurado {
    final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    return url.startsWith('https://') && !url.contains('tu-proyecto-id');
  }

  /// Path de destino dentro del bucket para el usuario autenticado.
  String pathDocumentoVehicular({
    required String vehiculoId,
    required String extension,
  }) {
    final uid = _uidActual();
    return 'usuarios/$uid/documentos_vehiculares/$vehiculoId/'
        '${DateTime.now().millisecondsSinceEpoch}.$extension';
  }

  Future<String> subirArchivo({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final request = http.MultipartRequest('POST', await _endpoint())
      ..headers['Authorization'] = 'Bearer ${await _idToken()}'
      ..fields['path'] = path
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: path.split('/').last,
          contentType: MediaType.parse(contentType),
        ),
      );

    final response = await _enviar(() async {
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
    _verificar(response);
    return path;
  }

  /// URL firmada (expira en ~10 min) para mostrar un archivo ya subido.
  Future<String> obtenerUrlFirmada(String path) async {
    final response = await _enviar(
      () async => http.post(
        await _endpoint(),
        headers: {
          'Authorization': 'Bearer ${await _idToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'action': 'sign', 'path': path}),
      ),
    );
    _verificar(response);
    final url = (jsonDecode(response.body) as Map)['signedUrl'];
    if (url is! String) throw StorageException('Respuesta inválida');
    return url;
  }

  /// Elimina un archivo propio del bucket (p. ej. al reemplazar un documento).
  Future<void> eliminarArchivo(String path) async {
    final response = await _enviar(
      () async => http.post(
        await _endpoint(),
        headers: {
          'Authorization': 'Bearer ${await _idToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'action': 'delete', 'path': path}),
      ),
    );
    _verificar(response);
  }

  // ---------------------------------------------------------------------

  Future<Uri> _endpoint() async {
    if (!configurado) {
      throw StorageException('SUPABASE_URL no está configurado');
    }
    final base = dotenv.env['SUPABASE_URL']!.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/functions/v1/$_funcion');
  }

  String _uidActual() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StorageException('No hay sesión iniciada');
    return uid;
  }

  Future<String> _idToken() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StorageException('No hay sesión iniciada');
    return token;
  }

  Future<http.Response> _enviar(Future<http.Response> Function() peticion) async {
    try {
      return await peticion().timeout(_timeout);
    } on StorageException {
      rethrow;
    } catch (e) {
      throw StorageException('Sin conexión con el servicio de archivos: $e');
    }
  }

  void _verificar(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var detalle = response.body;
    try {
      detalle = (jsonDecode(response.body) as Map)['error']?.toString() ?? detalle;
    } catch (_) {}
    throw StorageException(detalle, status: response.statusCode);
  }
}
