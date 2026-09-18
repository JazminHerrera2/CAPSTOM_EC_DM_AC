import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importa FirebaseAuth
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Importa dotenv
import 'firebase_options.dart'; // El archivo que generaste recién
import 'screens/login_screen.dart'; // Importa tu nueva pantalla
import 'screens/home_screen.dart'; // Importa la pantalla principal

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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TagOk',
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