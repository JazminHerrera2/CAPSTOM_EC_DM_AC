import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Sube archivos a Firebase Storage y devuelve la ruta (no la URL de
/// descarga) — así se guarda en Firestore como `foto_path`/`archivo_path`,
/// igual como lo define `04-diccionario-datos.md` (ej:
/// "vehiculos/veh_a91d7e/foto.jpg"). La URL de descarga se resuelve al
/// momento de mostrar la imagen, no se persiste (puede expirar/rotar).
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> subirArchivo({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return path;
  }

  Future<String> obtenerUrlDescarga(String path) {
    return _storage.ref(path).getDownloadURL();
  }
}
