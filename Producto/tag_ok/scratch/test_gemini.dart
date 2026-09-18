import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
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

  print('API Key leída del .env actual: ${apiKey.substring(0, 10)}... (longitud: ${apiKey.length})');
  if (apiKey.isEmpty) {
    print('Error: GEMINI_API_KEY está vacía en el .env');
    return;
  }

  final modelsToTry = [
    'gemini-flash-latest',
    'gemini-2.5-flash',
    'gemini-3.5-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
  ];

  for (final modelName in modelsToTry) {
    try {
      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
        generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      );
      final response = await model.generateContent([
        Content.text('Responde solo con {"ok": true} en JSON.'),
      ]);
      print('[$modelName] OK -> ${response.text?.trim()}');
    } catch (e) {
      print('[$modelName] FALLÓ -> $e');
    }
  }
}
