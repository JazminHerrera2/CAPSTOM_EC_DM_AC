/// Configuración de la app, tomada del `.env` AL COMPILAR:
///
///   flutter run --dart-define-from-file=.env
///   flutter build web --dart-define-from-file=.env
///
/// El `.env` ya no se empaqueta como archivo (antes quedaba público en
/// `https://<sitio>/assets/.env`). Solo llegan a la app las variables que se
/// leen acá; cualquier otra que tenga el `.env` se ignora al compilar.
///
/// Igual quedan escritas dentro de la app compilada: solo pueden ser datos
/// públicos (configuración de Firebase, token público de Mapbox, URL de
/// Supabase). Las claves secretas van como secretos de las Edge Functions.
///
/// `String.fromEnvironment` solo funciona como `const`: cada variable se lee
/// por su nombre exacto, no se puede armar el nombre en tiempo de ejecución.
abstract final class Entorno {
  // Firebase (las mismas variables de siempre en el .env).
  static const webApiKey = String.fromEnvironment('WEB_API_KEY');
  static const webAppId = String.fromEnvironment('WEB_APP_ID');
  static const androidApiKey = String.fromEnvironment('ANDROID_API_KEY');
  static const androidAppId = String.fromEnvironment('ANDROID_APP_ID');
  static const iosApiKey = String.fromEnvironment('IOS_API_KEY');
  static const iosAppId = String.fromEnvironment('IOS_APP_ID');
  static const iosBundleId = String.fromEnvironment('IOS_BUNDLE_ID');
  static const messagingSenderId = String.fromEnvironment('MESSAGING_SENDER_ID');
  static const projectId = String.fromEnvironment('PROJECT_ID');
  static const storageBucket = String.fromEnvironment('STORAGE_BUCKET');

  /// Token público de Mapbox (mapa, rutas y búsqueda de direcciones).
  static const mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  /// URL del proyecto de Supabase: Edge Functions de archivos e IA.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
}
