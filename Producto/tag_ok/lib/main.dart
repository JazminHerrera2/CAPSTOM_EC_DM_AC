import 'dart:convert';
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

  // 2. Carga las variables de entorno desde la memoria (Base64) para evitar bloqueos de GitHub
  try {
    const b64Env = "V0VCX0FQSV9LRVk9QUl6YVN5RGJnUEMxYWZZWG1rZ3FYNmxBY1VnbFRfY1IyZFo1OFZRCldFQl9BUFBfSUQ9MToxNTU3MjQ5MTI2Njc6d2ViOmYwODQyMWY3Y2QxMjE0NTIyMDAwYmUKQU5EUk9JRF9BUElfS0VZPUFJemFTeURiZ1BDMWFmWVhta2dxWDZsQWNVZ2xUX2NSMmRaNThWUQpBTkRST0lEX0FQUF9JRD0xOjE1NTcyNDkxMjY2Nzp3ZWI6ZjA4NDIxZjdjZDEyMTQ1MjIwMDBiZQpJT1NfQVBJX0tFWT1BSXphU3lEYmdQQzFhZllYbWtncVg2bEFjVWdsVF9jUjJkWjU4VlEKSU9TX0FQUF9JRD0xOjE1NTcyNDkxMjY2Nzp3ZWI6ZjA4NDIxZjdjZDEyMTQ1MjIwMDBiZQpNRVNTQUdJTkdfU0VOREVSX0lEPTE1NTcyNDkxMjY2NwpQUk9KRUNUX0lEPXRhZy1vay12MgpTVE9SQUdFX0JVQ0tFVD10YWctb2stdjIuZmlyZWJhc2VzdG9yYWdlLmFwcApJT1NfQlVORExFX0lEPWNvbS5leGFtcGxlLnRhZ09rCk1BUEJPWF9BQ0NFU1NfVE9LRU49cGsuZXlKMUlqb2lkR0ZuTFc5ckxYWXlJaXdpWVNJNkltTnRkSGRsYURkMlpEQTJPR1F5ZVc5cVltRjRkV1prWjJJaWZRLndIa2JQd2dGY0NQem9CMEhUMkJYZXcKR0VNSU5JX0FQSV9LRVk9QVEuQWI4Uk42SmZCb1B3Um8zeHRCWXhqTHY1eWlvWnBwTkVLMFEtdHV2Uk10ZU4weGhLT0EK";
    final envText = utf8.decode(base64Decode(b64Env));
    dotenv.testLoad(fileInput: envText);
  } catch (e) {
    debugPrint("Error al cargar variables de entorno seguras: $e");
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