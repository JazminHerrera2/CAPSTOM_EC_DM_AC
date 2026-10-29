import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importa FirebaseAuth
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Importa dotenv
import 'firebase_options.dart'; // El archivo que generaste recién
import 'screens/login_screen.dart'; // Importa tu nueva pantalla
import 'screens/home_screen.dart'; // Importa la pantalla principal
import 'utils/app_reloader.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart'; // Importa Riverpod


void main() async {
  // 1. Asegura que los widgets estén listos
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Carga las variables de entorno desde el archivo .env local
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Error al cargar variables de entorno: $e");
  }

  // 3. Inicializa Firebase con tus opciones generadas
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Si el .env desplegado está vacío/incompleto, Firebase.initializeApp
    // lanzaba antes una excepción no capturada que mataba la app antes de
    // llegar a runApp(), dejando una pantalla en blanco sin ningún mensaje.
    debugPrint("Error al inicializar Firebase: $e");
    runApp(InitErrorApp(error: e.toString()));
    return;
  }

  runApp(const ProviderScope(child: MyApp()));
}

class InitErrorApp extends StatelessWidget {
  const InitErrorApp({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TagOk',
      home: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFF0F172A), size: 48),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo iniciar TAG OK',
                  style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                  onPressed: reloadApp,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TagOk',
      // Idioma de la app: calendarios, relojes y diálogos de Material en
      // español (Chile), sin depender del idioma del teléfono o navegador.
      locale: const Locale('es', 'CL'),
      supportedLocales: const [
        Locale('es', 'CL'),
        Locale('es'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        // Las tarjetas no cambian de color al pasar el mouse ni al presionarlas:
        // sin gris de hover, sin resaltado y sin ondas. Lo toman por defecto
        // todos los InkWell de la app.
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        // Avisos flotantes: Flutter los coloca encima del botón central del
        // mapa. Los fijos (por defecto) quedan al fondo y ese botón los tapa.
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Si todavía está revisando si hay sesión guardada
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Si encontró una sesión activa, manda directo al Home
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          }
          // Si no hay sesión, muestra el Login
          return const LoginScreen();
        },
      ),
    );
  }
}