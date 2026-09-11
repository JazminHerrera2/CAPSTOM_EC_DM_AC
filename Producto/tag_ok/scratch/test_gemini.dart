import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  try {
    final envFile = File('.env');
    if (!envFile.existsSync()) {
      print('Error: No se encuentra el archivo .env en el directorio actual.');
      return;
    }
    
    final lines = envFile.readAsLinesSync();
    String apiKey = '';
    for (var line in lines) {
      if (line.startsWith('GEMINI_API_KEY=')) {
        apiKey = line.substring('GEMINI_API_KEY='.length).trim();
      }
    }
    
    print('API Key encontrada: ${apiKey.substring(0, 10)}... (longitud: ${apiKey.length})');
    
    if (apiKey.isEmpty) {
      print('Error: GEMINI_API_KEY está vacía en el .env');
      return;
    }
    
    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );
    
    print('Enviando petición de prueba a Gemini...');
    final response = await model.generateContent([
      Content.text('Hola, responde con la palabra OK si recibes esto correctamente.')
    ]);
    
    print('¡Éxito! Respuesta de Gemini: ${response.text?.trim()}');
  } catch (e) {
    print('Error capturado: $e');
  }
}
