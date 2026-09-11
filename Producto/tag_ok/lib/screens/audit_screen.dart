import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/trip_history.dart';
import '../data/services/history_service.dart';
import '../data/demo_data.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tag_ok/utils/file_saver.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final HistoryService _historyService = HistoryService();

  // Subpestaña activa (0: Consumo e Historial, 1: Auditoría de Boletas)
  int _activeSubTab = 0;
  bool _isExtracting = false;
  bool _useAI = true;

  // Variables de Filtro (Subpestaña 1)
  String _selectedVehicle = 'Todos';
  String _selectedHighway = 'Todas';
  String _selectedDatePreset = 'Todos'; // 'Todos', 'Hoy', 'Últimos 7 días', 'Este Mes', 'Personalizado'
  DateTimeRange? _customDateRange;

  // Colores globales premium (Dark Mode)
  final Color bgColor = const Color(0xFF0F172A);
  final Color surfaceColor = const Color(0xFF1E293B);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color primaryColor = const Color(0xFF4F46E5);

  // Clasificación de Autopistas de Santiago
  String _classifyHighway(String tollName) {
    final name = tollName.toLowerCase();
    
    // 0. Rutas de conexión genéricas
    if (name.contains('autopista de conexión') || name.contains('conexión')) {
      return 'Autopista de Conexión';
    }
    
    // 1. Autopista Central (PA y Ruta 5)
    if (name.startsWith('pa') || name.contains('autopista central') || name.contains('ruta 5')) {
      return 'Autopista Central';
    } 
    
    // 2. Costanera Norte
    if (name.contains('costanera') || 
        name.contains('vivaceta') || 
        name.contains('lo saldes') || 
        name.contains('la dehesa') || 
        name.contains('estoril') || 
        name.contains('padre arteaga') || 
        name.contains('tranqueras') ||
        name.contains('carrascal') ||
        name.contains('padre hurtado') ||
        name.startsWith('ev ') || 
        name.startsWith('sv ')) {
      return 'Costanera Norte';
    }
    
    // 3. Vespucio Oriente (AVO / Kennedy)
    if (name.contains('avo') || 
        name.contains('kennedy') || 
        name.contains('p101') || 
        name.contains('p102') ||
        name.contains('vespucio oriente')) {
      return 'Vespucio Oriente (AVO)';
    }

    // 4. Vespucio Norte
    if (name.contains('vespucio norte') || 
        name.contains('guanaco') || 
        name.contains('el salto') || 
        name.contains('lo boza') || 
        name.contains('recabal') || 
        name.contains('enea') ||
        name.contains('p14') ||
        name.contains('p13') ||
        name.contains('p12') ||
        name.contains('p15')) {
      return 'Vespucio Norte';
    }

    // 5. Vespucio Sur
    if (name.contains('vespucio sur') || 
        name.contains('pvs') || 
        name.contains('velásquez') || 
        name.contains('velasquez') || 
        name.contains('gran avenida') || 
        name.contains('santa rosa') || 
        name.contains('vicuña mackenna') || 
        name.contains('alderete') || 
        name.contains('2a transversal') ||
        name.contains('los mares') ||
        name.contains('coronel') ||
        name.contains('camino a melipilla') ||
        RegExp(r'^p[1-4]\.[0-9]').hasMatch(name) || 
        RegExp(r'^p17').hasMatch(name)) { 
      return 'Vespucio Sur';
    }

    // 6. Rutas de conexión o interurbanas
    if (name.contains('ruta 68')) {
      return 'Ruta 68';
    }
    if (name.contains('ruta 78') || name.contains('autopista del sol')) {
      return 'Ruta 78';
    }

    // Clasificación secundaria inteligente para IDs de pórticos genéricos
    if (name.startsWith('p')) {
      final match = RegExp(r'^p([0-9]+)').firstMatch(name);
      if (match != null) {
        final numVal = int.tryParse(match.group(1) ?? '');
        if (numVal != null) {
          if (numVal >= 10 && numVal <= 16) return 'Vespucio Norte';
          if (numVal >= 1 && numVal <= 9) return 'Vespucio Sur';
        }
      }
    }

    return 'Autopista de Conexión';
  }

  String _formatSpanishDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
      final months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
      
      final weekday = weekdays[date.weekday - 1];
      final day = date.day;
      final month = months[date.month - 1];
      final year = date.year;
      
      return '$weekday, $day de $month de $year';
    } catch (e) {
      return dateStr;
    }
  }

  // Comprueba si un viaje cumple con los filtros activos
  bool _shouldKeepTrip(TripHistory trip) {
    if (_selectedVehicle != 'Todos' && trip.vehicleName != _selectedVehicle) {
      return false;
    }

    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    if (_selectedDatePreset == 'Hoy') {
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    } else if (_selectedDatePreset == 'Últimos 7 días') {
      start = now.subtract(const Duration(days: 7));
      end = now;
    } else if (_selectedDatePreset == 'Este Mes') {
      start = DateTime(now.year, now.month, 1);
      end = now;
    } else if (_selectedDatePreset == 'Personalizado' && _customDateRange != null) {
      start = _customDateRange!.start;
      end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59, 999);
    }

    if (start != null && end != null) {
      if (trip.date.isBefore(start) || trip.date.isAfter(end)) {
        return false;
      }
    }

    if (_selectedHighway != 'Todas') {
      final hasTollInHighway = trip.tolls.any((toll) => _classifyHighway(toll.name) == _selectedHighway);
      if (!hasTollInHighway) {
        return false;
      }
    }

    return true;
  }

  void _clearAllFilters() {
    setState(() {
      _selectedVehicle = 'Todos';
      _selectedHighway = 'Todas';
      _selectedDatePreset = 'Todos';
      _customDateRange = null;
    });
  }

  // --- STREAMS Y ACCIONES FIRESTORE ---

  Stream<List<Map<String, dynamic>>> _getAuditedInvoices() {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(userId)
        .collection('audited_invoices')
        .orderBy('uploadDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<void> _deleteAuditedInvoice(String docId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(userId)
        .collection('audited_invoices')
        .doc(docId)
        .delete();
        
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auditoría eliminada del historial')),
      );
    }
  }

  // --- GENERADOR DEMO JHGK50 (SEED DATABASE) ---

  Future<void> _generateDemoTrips() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final firestore = FirebaseFirestore.instance;
    final tripsCollection = firestore.collection('usuarios').doc(userId).collection('trips');

    setState(() => _isExtracting = true);

    try {
      // 1. Borrar viajes demo anteriores de JHGK50 en un batch
      final query = await tripsCollection.where('vehicleName', isEqualTo: 'Hyundai (JHGK50)').get();
      if (query.docs.isNotEmpty) {
        final deleteBatch = firestore.batch();
        for (var doc in query.docs) {
          deleteBatch.delete(doc.reference);
        }
        await deleteBatch.commit();
      }

      // 2. Insertar todos los viajes estáticos de prueba (40 viajes, 239 peajes) en un batch
      final insertBatch = firestore.batch();
      for (var trip in staticDemoTrips) {
        final docRef = tripsCollection.doc();
        insertBatch.set(docRef, {
          'date': trip['date'],
          'totalCost': (trip['totalCost'] as num).toDouble(),
          'distanceKm': (trip['distanceKm'] as num).toDouble(),
          'duration': trip['duration'],
          'vehicleName': trip['vehicleName'],
          'tolls': (trip['tolls'] as List).map((t) => {
            'name': t['name'],
            'cost': (t['cost'] as num).toDouble(),
            'timestamp': t['timestamp'],
          }).toList(),
        });
      }
      await insertBatch.commit();

      setState(() => _isExtracting = false);

      int totalTollsCount = staticDemoTrips.fold(0, (acc, trip) => acc + (trip['tolls'] as List).length);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Historial demo de la patente JHGK50 (${staticDemoTrips.length} viajes, $totalTollsCount peajes) cargado con éxito!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() => _isExtracting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sembrar viajes demo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildFormattedReport(String text) {
    final lines = text.split('\n');
    List<Widget> children = [];

    for (var line in lines) {
      String trimmed = line.trim();
      if (trimmed.isEmpty) {
        children.add(const SizedBox(height: 4));
        continue;
      }

      // Detectar encabezado
      bool isHeader = false;
      if (trimmed.startsWith('### ')) {
        isHeader = true;
        trimmed = trimmed.substring(4).trim();
      }

      // Detectar viñetas
      bool isBullet = false;
      if (trimmed.startsWith('* ') || trimmed.startsWith('- ')) {
        isBullet = true;
        trimmed = trimmed.substring(2).trim();
      }

      // Procesar texto en negrita inline con **
      final List<TextSpan> spans = [];
      final RegExp regExp = RegExp(r'\*\*(.*?)\*\*');
      int lastIndex = 0;

      for (final Match match in regExp.allMatches(trimmed)) {
        if (match.start > lastIndex) {
          spans.add(TextSpan(
            text: trimmed.substring(lastIndex, match.start),
          ));
        }
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ));
        lastIndex = match.end;
      }

      if (lastIndex < trimmed.length) {
        spans.add(TextSpan(
          text: trimmed.substring(lastIndex),
        ));
      }

      Widget lineWidget = RichText(
        text: TextSpan(
          style: TextStyle(
            color: isHeader ? const Color(0xFFC084FC) : const Color(0xFFE2E8F0),
            fontSize: isHeader ? 12 : 11,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            height: 1.4,
            fontFamily: 'Roboto',
          ),
          children: spans,
        ),
      );

      if (isBullet) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Color(0xFFC084FC), fontSize: 12)),
                Expanded(child: lineWidget),
              ],
            ),
          ),
        );
      } else {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              bottom: isHeader ? 8.0 : 4.0,
              top: isHeader ? 6.0 : 0.0,
            ),
            child: lineWidget,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  // --- ALGORITMO DE AUDITORÍA PDF / CSV ---

  bool _checkPorticoMatch(String dbName, String billPortico) {
    final dbLower = dbName.toLowerCase();
    final billLower = billPortico.toLowerCase();

    final cleanDb = dbLower.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanBill = billLower.replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (cleanDb.contains(cleanBill) || cleanBill.contains(cleanDb)) {
      // Evitar falsos positivos en números de pórtico simples de Vespucio Norte (ej: "1" vs "12" o "17")
      final billDigits = RegExp(r'^\d+$').firstMatch(billLower.trim())?.group(0);
      if (billDigits != null) {
        final dbPortNum = RegExp(r'p(\d+)\b').firstMatch(dbLower)?.group(1);
        if (dbPortNum != null) {
          return dbPortNum == billDigits;
        }
      }
      return true;
    }
    return false;
  }

  Future<void> _createGpsTripsForCrossings(
    List<Map<String, dynamic>> crossings,
    String patent,
    bool withDiscrepancies,
    String concessionaire,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final firestore = FirebaseFirestore.instance;
    final tripsCollection = firestore.collection('usuarios').doc(userId).collection('trips');

    // 1. Borrar viajes anteriores de esta patente en un batch
    final query = await tripsCollection.where('vehicleName', isEqualTo: 'Hyundai ($patent)').get();
    if (query.docs.isNotEmpty) {
      final deleteBatch = firestore.batch();
      for (var doc in query.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
    }

    // Filtrar cruces si es con discrepancias (omitir 1 de cada 8 cruces para probar el sistema de alertas)
    final List<Map<String, dynamic>> crossingsToSimulate = [];
    for (int i = 0; i < crossings.length; i++) {
      if (withDiscrepancies && (i % 8 == 0)) {
        continue;
      }
      crossingsToSimulate.add(crossings[i]);
    }

    // Agrupar cruces por fecha
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var c in crossingsToSimulate) {
      final date = c['date'];
      grouped.putIfAbsent(date, () => []).add(c);
    }

    final List<Map<String, dynamic>> tripsToInsert = [];

    for (var dateStr in grouped.keys) {
      final list = grouped[dateStr]!;
      list.sort((a, b) => a['time'].compareTo(b['time']));

      List<Map<String, dynamic>> currentTolls = [];
      DateTime? firstTime;

      for (var c in list) {
        final cTime = DateTime.parse('${c['date']} ${c['time']}');
        if (firstTime == null) {
          firstTime = cTime;
          currentTolls.add({
            'name': '${c['portico']} - $concessionaire',
            'cost': c['cost'],
            'timestamp': cTime.toIso8601String(),
          });
        } else {
          final diff = cTime.difference(firstTime).inMinutes.abs();
          if (diff <= 120) {
            currentTolls.add({
              'name': '${c['portico']} - $concessionaire',
              'cost': c['cost'],
              'timestamp': cTime.toIso8601String(),
            });
          } else {
            final totalCost = currentTolls.fold(0.0, (acc, t) => acc + (t['cost'] as double));
            tripsToInsert.add({
              'date': firstTime.toIso8601String(),
              'totalCost': totalCost,
              'distanceKm': currentTolls.length * 4.5,
              'duration': '${currentTolls.length * 5} min',
              'vehicleName': 'Hyundai ($patent)',
              'tolls': List.from(currentTolls),
            });

            firstTime = cTime;
            currentTolls = [{
              'name': '${c['portico']} - $concessionaire',
              'cost': c['cost'],
              'timestamp': cTime.toIso8601String(),
            }];
          }
        }
      }

      if (currentTolls.isNotEmpty && firstTime != null) {
        final totalCost = currentTolls.fold(0.0, (acc, t) => acc + (t['cost'] as double));
        tripsToInsert.add({
          'date': firstTime.toIso8601String(),
          'totalCost': totalCost,
          'distanceKm': currentTolls.length * 4.5,
          'duration': '${currentTolls.length * 5} min',
          'vehicleName': 'Hyundai ($patent)',
          'tolls': List.from(currentTolls),
        });
      }
    }

    // 2. Insertar todos los viajes en un batch
    if (tripsToInsert.isNotEmpty) {
      final insertBatch = firestore.batch();
      for (var tripData in tripsToInsert) {
        final docRef = tripsCollection.doc();
        insertBatch.set(docRef, tripData);
      }
      await insertBatch.commit();
    }
  }

  Future<Map<String, dynamic>> _extractDataWithGemini(String rawText, String fileName) async {
    final geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (geminiApiKey.isEmpty) {
      throw Exception('Clave de API de Gemini no configurada.');
    }

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: geminiApiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    final limitedText = rawText.length > 60000 ? rawText.substring(0, 60000) : rawText;

    final prompt = '''
Eres un asistente experto en analizar boletas de peaje y autopistas de Chile.
A continuación te proporcionaré el texto crudo extraído de un archivo llamado "\$fileName".
Tu tarea es encontrar y extraer:
1. La concesionaria de la autopista (ej: Autopista Central, Costanera Norte, Vespucio Sur, Vespucio Norte, etc.). Si no estás seguro, usa "Autopista Desconocida".
2. La patente principal del vehículo cobrado (por lo general 6 caracteres alfanuméricos).
3. Una lista de todos los tránsitos/cobros individuales (fecha, hora, pórtico y costo).
   - Formato de fecha esperado: "YYYY-MM-DD"
   - Formato de hora esperado: "HH:MM:SS" (si falta, usa "00:00:00")
   - Costo: número numérico entero o decimal (sin símbolos de peso).

Texto crudo del archivo:
"""
\$limitedText
"""

Debes devolver EXCLUSIVAMENTE un objeto JSON válido con esta estructura estricta:
{
  "concessionaire": "Nombre de la Autopista",
  "patent": "ABCD12",
  "crossings": [
    {
      "date": "2026-03-15",
      "time": "14:30:00",
      "portico": "Pórtico Nombre",
      "cost": 1500.0
    }
  ]
}
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final responseText = response.text?.trim() ?? '';
    
    try {
      final parsed = jsonDecode(responseText);
      if (parsed['crossings'] == null || (parsed['crossings'] as List).isEmpty) {
         throw Exception('La IA no encontró cruces legibles en el archivo.');
      }
      return parsed;
    } catch (e) {
      debugPrint('Gemini Extraction Error: \$e\\nResponse: \$responseText');
      throw Exception('Gemini no pudo interpretar correctamente el formato de la boleta.');
    }
  }

  Future<void> _runAiAudit({
    required List<Map<String, dynamic>> extractedCrossings,
    required List<TripHistory> trips,
    required String patent,
    required String concessionaire,
  }) async {
    // 1. EJECUCIÓN LOCAL PREVIA (DETERMINISTIC PASS)
    // Ordenar cruces extraídos cronológicamente por fecha y hora antes de conciliar
    extractedCrossings.sort((a, b) {
      final dateCompare = a['date'].compareTo(b['date']);
      if (dateCompare != 0) return dateCompare;
      return a['time'].compareTo(b['time']);
    });

    final String targetPatentClean = patent.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

    List<Map<String, dynamic>> auditedDetails = [];
    double totalBilled = 0.0;
    double totalMatched = 0.0;
    List<Map<String, dynamic>> discrepancies = [];

    for (var crossing in extractedCrossings) {
      final String cDateStr = crossing['date']; 
      final String cTimeStr = crossing['time']; 
      final String cPortico = crossing['portico']; 
      final double cCost = crossing['cost'];

      totalBilled += cCost;

      final cDateTime = DateTime.parse('$cDateStr $cTimeStr');
      bool isMatched = false;

      for (var trip in trips) {
        final tripDateStr = DateFormat('yyyy-MM-dd').format(trip.date);
        if (tripDateStr == cDateStr) {
          for (var toll in trip.tolls) {
            if (_checkPorticoMatch(toll.name, cPortico)) {
              final difference = toll.timestamp.difference(cDateTime).inMinutes.abs();
              if (difference <= 15) { // Ventana flexible de 15 minutos
                isMatched = true;
                totalMatched += cCost;
                break;
              }
            }
          }
        }
        if (isMatched) break;
      }

      final detail = {
        'date': cDateStr,
        'time': cTimeStr,
        'portico': cPortico,
        'cost': cCost,
        'status': isMatched ? 'Correcto' : 'Discrepancia',
      };
      auditedDetails.add(detail);
      if (!isMatched) {
        discrepancies.add(detail);
      }
    }

    final double reconciliationRate = totalBilled > 0 ? (totalMatched / totalBilled) * 100 : 0.0;
    final String finalStatus = reconciliationRate >= 100 
        ? 'Conciliado' 
        : (reconciliationRate > 0 ? 'Discrepancia Parcial' : 'Sin Registro');

    // Determinar periodo
    final firstDate = DateTime.parse(extractedCrossings.first['date']);
    final lastDate = DateTime.parse(extractedCrossings.last['date']);
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    String period = '';
    if (firstDate.month == lastDate.month) {
      period = '${months[firstDate.month - 1]} ${firstDate.year}';
    } else {
      period = '${months[firstDate.month - 1]} - ${months[lastDate.month - 1]} ${firstDate.year}';
    }

    String aiReport = '';

    // 2. BYPASS INSTANTÁNEO SI HAY 100% DE COINCIDENCIA (AHORRA TIEMPO Y COSTE DE API)
    if (reconciliationRate >= 100) {
      aiReport = '### ¡Conciliación Perfecta! 🛡️\n\n'
          'Todos los cobros de la boleta coinciden perfectamente con los viajes registrados en el GPS del vehículo **$patent**.\n\n'
          '* **Cobros Auditados:** ${extractedCrossings.length} tránsitos.\n'
          '* **Total Conciliado:** \$${totalMatched.toStringAsFixed(0)} (100% OK).\n'
          '* **Estado:** No se detectan anomalías ni cobros fantasma.';
    } else {
      // 3. INVOCACIÓN HÍBRIDA OPTIMIZADA (SOLO DISCREPANCIAS Y PROMPT CORTO)
      try {
        final geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
        if (geminiApiKey.isEmpty) {
          throw Exception('Clave de API de Gemini no configurada.');
        }

        // Filtrar viajes GPS para enviar únicamente los días con discrepancias
        final Set<String> discrepancyDates = discrepancies.map((d) => d['date'] as String).toSet();
        final tripsOnDiscrepancyDays = trips
            .where((t) {
              final tripDateStr = DateFormat('yyyy-MM-dd').format(t.date);
              return discrepancyDates.contains(tripDateStr) &&
                  t.vehicleName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase().contains(targetPatentClean);
            })
            .map((t) => {
              'date': DateFormat('yyyy-MM-dd').format(t.date),
              'tolls': t.tolls.map((toll) => {
                'name': toll.name,
                'cost': toll.cost,
                'timestamp': toll.timestamp.toIso8601String(),
              }).toList(),
            })
            .toList();

        final model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: geminiApiKey,
          generationConfig: GenerationConfig(responseMimeType: 'application/json'),
        );

        final prompt = '''
Eres un auditor experto de peajes de autopistas de Santiago de Chile. Tu objetivo es redactar un análisis breve y conciso de auditoría en español ("aiReport") explicando los cobros no conciliados con el GPS del vehículo.

Resumen:
- Concesionaria: $concessionaire
- Vehículo Patente: $patent
- Total Facturado: \$${totalBilled.toStringAsFixed(2)}
- Total Conciliado (correcto): \$${totalMatched.toStringAsFixed(2)}
- Tasa Coincidencia: ${reconciliationRate.toStringAsFixed(1)}%
- Total Tránsitos: ${extractedCrossings.length}
- Total Discrepancias (no encontrados en GPS): ${discrepancies.length}

Detalle de Cobros con Discrepancia:
${jsonEncode(discrepancies)}

Viajes de GPS registrados únicamente en los días con discrepancias:
${jsonEncode(tripsOnDiscrepancyDays)}

Instrucciones para redactar el "aiReport":
1. Sé extremadamente breve y conciso (máximo 120 palabras).
2. Explica brevemente la causa más probable de las discrepancias específicas encontradas.
3. Si no hay viajes de GPS en esos días, alerta de "Falta de Registro GPS o Tránsito Fantasma/Sospecha de Clonación".
4. Retorna la respuesta en formato JSON utilizando exactamente el siguiente esquema de una sola clave:
{
  "aiReport": "Tu informe conciso en español con viñetas breves..."
}
''';

        final content = [Content.text(prompt)];
        final response = await model.generateContent(content);
        final responseText = response.text?.trim() ?? '';

        final Map<String, dynamic> aiResult = jsonDecode(responseText);
        aiReport = aiResult['aiReport'] ?? 'Sin comentarios adicionales.';
      } catch (e) {
        print('Error en auditoría Gemini: $e');
        // Fallback local corto si hay error de API o red
        aiReport = '### Auditoría (Resumen Local) 📋\n\n'
            'Se detectaron discrepancias entre los cobros y el GPS:\n\n'
            '* **Total Facturado:** \$${totalBilled.toStringAsFixed(0)}\n'
            '* **Total Conciliado:** \$${totalMatched.toStringAsFixed(0)} (${reconciliationRate.toStringAsFixed(1)}% de coincidencia)\n\n'
            '**Discrepancias principales:**\n'
            '${discrepancies.take(3).map((d) => '- ${d['date']} ${d['time']}: **${d['portico']}** (Costo: \$${(d['cost'] as num).toStringAsFixed(0)})').join('\n')}'
            '${discrepancies.length > 3 ? '\n- *Y ${discrepancies.length - 3} cobros más con diferencias.*' : ''}\n\n'
            '*Nota: No se pudo conectar con el motor de IA de Gemini, se muestran las discrepancias calculadas localmente.*';
      }
    }

    // Persistir en Firestore
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final firestore = FirebaseFirestore.instance;

    await firestore
        .collection('usuarios')
        .doc(userId)
        .collection('audited_invoices')
        .add({
      'concessionaire': concessionaire,
      'period': period,
      'patent': patent,
      'totalBilled': totalBilled,
      'totalMatched': totalMatched,
      'status': finalStatus,
      'reconciliationRate': reconciliationRate,
      'uploadDate': DateTime.now().toIso8601String(),
      'details': auditedDetails,
      'aiReport': aiReport,
      'auditedBy': 'Gemini 2.5 Flash',
    });
  }

  Future<void> _pickAndAuditInvoice() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'csv', 'xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileBytes = file.bytes;
      if (fileBytes == null) {
        throw Exception('No se pudieron leer los bytes del archivo seleccionado.');
      }

      setState(() => _isExtracting = true);

      String concessionaire = 'Autopista Central';
      String period = 'Marzo 2026';
      String patent = 'JHGK50';
      List<Map<String, dynamic>> extractedCrossings = [];

      final fileNameLower = file.name.toLowerCase();

      // 1. EXTRACCIÓN Y LECTURA
      try {
        if (fileNameLower.endsWith('.csv')) {
          concessionaire = 'Autopista Central';
          final csvText = utf8.decode(fileBytes);
          final lines = const LineSplitter().convert(csvText);

          if (lines.length <= 1) {
            throw Exception('El archivo CSV está vacío o no contiene suficientes filas.');
          }

          final sample = lines.first;
          final delimiter = sample.contains(';') ? ';' : ',';

          // Omitir cabecera (index 0)
          for (int i = 1; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.isEmpty) continue;

            final fields = line.split(delimiter);
            if (fields.length >= 11) {
              final String fPatent = fields[3].trim();
              final String fPortico = fields[4].trim();
              final String fDate = fields[7].trim(); // YYYY-MM-DD
              final String fTime = fields[8].trim(); // HH:MM:SS
              final String fCostRaw = fields[10].trim(); // Costo (512,34)

              patent = fPatent;
              final double cost = double.parse(fCostRaw.replaceAll('.', '').replaceAll(',', '.'));

              extractedCrossings.add({
                'date': fDate,
                'time': fTime,
                'portico': fPortico,
                'cost': cost,
              });
            }
          }
        } else if (fileNameLower.endsWith('.xlsx')) {
          concessionaire = 'Vespucio Norte';
          final excel = Excel.decodeBytes(fileBytes);
          for (var table in excel.tables.keys) {
            final sheet = excel.tables[table]!;
            if (sheet.maxRows <= 1) continue;

            final headerRow = sheet.rows.first;
            int idxPatent = -1;
            int idxDate = -1;
            int idxTime = -1;
            int idxPortico = -1;
            int idxConcession = -1;
            int idxCost = -1;

            for (int i = 0; i < headerRow.length; i++) {
              final val = headerRow[i]?.value?.toString().toLowerCase().trim() ?? '';
              if (val.contains('patente')) idxPatent = i;
              else if (val.contains('fecha')) idxDate = i;
              else if (val.contains('hora')) idxTime = i;
              else if (val.contains('portico') || val.contains('pórtico')) idxPortico = i;
              else if (val.contains('concesionaria')) idxConcession = i;
              else if (val.contains('valor') || val.contains('monto') || val.contains('importe')) idxCost = i;
            }

            if (idxPatent == -1) idxPatent = 0;
            if (idxDate == -1) idxDate = 1;
            if (idxTime == -1) idxTime = 2;
            if (idxPortico == -1) idxPortico = 4;
            if (idxConcession == -1) idxConcession = 6;
            if (idxCost == -1) idxCost = 8;

            for (int i = 1; i < sheet.rows.length; i++) {
              final row = sheet.rows[i];
              if (row.isEmpty || row.length <= idxCost) continue;

              final String fPatent = row[idxPatent]?.value?.toString().trim() ?? '';
              final String fDate = row[idxDate]?.value?.toString().trim() ?? '';
              final String fTime = row[idxTime]?.value?.toString().trim() ?? '';
              final String fPortico = row[idxPortico]?.value?.toString().trim() ?? '';
              final String fConcession = idxConcession < row.length ? (row[idxConcession]?.value?.toString().trim() ?? '') : '';
              final String fCostRaw = row[idxCost]?.value?.toString().trim() ?? '';

              if (fPatent.isEmpty || fDate.isEmpty || fCostRaw.isEmpty) continue;

              patent = fPatent;
              if (fConcession.isNotEmpty) {
                if (fConcession.toUpperCase() == 'AVN') {
                  concessionaire = 'Vespucio Norte';
                } else if (fConcession.toUpperCase() == 'AVS') {
                  concessionaire = 'Vespucio Sur';
                }
              }

              final double cost = double.parse(fCostRaw.replaceAll('.', '').replaceAll(',', '.'));

              String formattedDate = fDate;
              if (fDate.contains('-')) {
                final dateParts = fDate.split('-');
                if (dateParts[0].length == 4) {
                  formattedDate = fDate;
                } else {
                  formattedDate = '\${dateParts[2]}-\${dateParts[1]}-\${dateParts[0]}';
                }
              } else if (fDate.contains('/')) {
                final dateParts = fDate.split('/');
                if (dateParts[0].length == 4) {
                  formattedDate = fDate.replaceAll('/', '-');
                } else {
                  formattedDate = '\${dateParts[2]}-\${dateParts[1]}-\${dateParts[0]}';
                }
              }

              extractedCrossings.add({
                'date': formattedDate,
                'time': fTime.length == 5 ? '\$fTime:00' : fTime,
                'portico': fPortico,
                'cost': cost,
              });
            }
          }
        } else if (fileNameLower.endsWith('.pdf')) {
          // Cargar documento PDF localmente
          final PdfDocument document = PdfDocument(inputBytes: fileBytes);
          final PdfTextExtractor extractor = PdfTextExtractor(document);
          final String text = extractor.extractText();
          document.dispose();

          final lines = const LineSplitter().convert(text);

          // Detectar tipo de boleta en base a su contenido
          if (text.contains('CN ') || text.contains('COSTANERA') || fileNameLower.contains('costanera')) {
            concessionaire = 'Costanera Norte';
            
            for (int i = 0; i < lines.length; i++) {
              final line = lines[i].trim();
              // Formato de fecha y hora: DD/MM/AAAA HH:MM
              if (RegExp(r'^\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}\$').hasMatch(line)) {
                if (i + 5 < lines.length) {
                  final String dateTimeStr = line;
                  final String fPortico = lines[i + 2].trim();
                  final String fCostRaw = lines[i + 4].trim();
                  final String fPatent = lines[i + 5].trim();

                  if (fCostRaw.contains('\$') && fPatent.length == 6) {
                    final dateParts = dateTimeStr.split(' ')[0].split('/');
                    final formattedDate = '\${dateParts[2]}-\${dateParts[1]}-\${dateParts[0]}';
                    final String fTime = '\${dateTimeStr.split(' ')[1]}:00';
                    
                    final double cost = double.parse(
                      fCostRaw.replaceAll('\$', '').replaceAll('.', '').replaceAll(',', '.').trim()
                    );

                    patent = fPatent;
                    extractedCrossings.add({
                      'date': formattedDate,
                      'time': fTime,
                      'portico': fPortico,
                      'cost': cost,
                    });

                    i += 5; // Saltar líneas procesadas
                  }
                }
              }
            }
          } else if (text.contains('VESPUCIO SUR') || text.contains('VS ') || fileNameLower.contains('vespucio_sur') || fileNameLower.contains('vespucio sur')) {
            concessionaire = 'Vespucio Sur';

            for (int i = 0; i < lines.length; i++) {
              final line = lines[i].trim();
              // Formato de fecha y hora: DD/MM/AAAA HH:MM
              if (RegExp(r'^\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}\$').hasMatch(line)) {
                if (i + 5 < lines.length) {
                  final String dateTimeStr = line;
                  final String fPortico = lines[i + 2].trim();
                  final String fCostRaw = lines[i + 4].trim();
                  final String fPatent = lines[i + 5].trim();

                  if (fCostRaw.contains('\$') && fPatent.length == 6) {
                    final dateParts = dateTimeStr.split(' ')[0].split('/');
                    final formattedDate = '\${dateParts[2]}-\${dateParts[1]}-\${dateParts[0]}';
                    final String fTime = '\${dateTimeStr.split(' ')[1]}:00';
                    
                    final double cost = double.parse(
                      fCostRaw.replaceAll('\$', '').replaceAll('.', '').replaceAll(',', '.').trim()
                    );

                    patent = fPatent;
                    extractedCrossings.add({
                      'date': formattedDate,
                      'time': fTime,
                      'portico': fPortico,
                      'cost': cost,
                    });

                    i += 5; // Saltar líneas procesadas
                  }
                }
              }
            }
          } else if (text.contains('VESPUCIO NORTE') || fileNameLower.contains('vespucio_norte') || fileNameLower.contains('vespucio norte')) {
            concessionaire = 'Vespucio Norte';

            // Expresión regular global sin espacios para el texto corrido de Syncfusion
            final regex = RegExp(
              r'([A-Z0-9]{6})(\d{2}-\d{2}-\d{4})(\d{2}:\d{2}:\d{2})(O-P|P-O)(\d+)(Laboral|Domingo|Sábado)(TBFP|TBP|TS)Normal\$\s*([\d\.,]+)'
            );

            for (final Match match in regex.allMatches(text)) {
              final String fPatent = match.group(1)!;
              final String fDate = match.group(2)!;
              final String fTime = match.group(3)!;
              final String fPortico = match.group(5)!;
              final String fCostRaw = match.group(8)!;

              patent = fPatent;
              final double cost = double.parse(
                fCostRaw.replaceAll('.', '').replaceAll(',', '.').trim()
              );

              final dateParts = fDate.split('-');
              final formattedDate = '\${dateParts[2]}-\${dateParts[1]}-\${dateParts[0]}';

              extractedCrossings.add({
                'date': formattedDate,
                'time': fTime,
                'portico': fPortico,
                'cost': cost,
              });
            }
          } else {
            throw Exception('No se pudo identificar la estructura de la autopista en el documento.');
          }
        }

        if (extractedCrossings.isEmpty) {
          throw Exception('No se detectaron transacciones legibles localmente.');
        }

      } catch (localParsingError) {
        if (_useAI) {
          // ==========================================
          // FALLBACK A GEMINI (EXTRACCIÓN INTELIGENTE)
          // ==========================================
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content: Text('Formato no reconocido. Analizando con Inteligencia Artificial...'),
                 backgroundColor: Color(0xFF8B5CF6),
                 duration: Duration(seconds: 3),
               ),
             );
          }
          
          String rawText = '';
          if (fileNameLower.endsWith('.pdf')) {
            final PdfDocument document = PdfDocument(inputBytes: fileBytes);
            rawText = PdfTextExtractor(document).extractText();
            document.dispose();
          } else if (fileNameLower.endsWith('.csv')) {
            rawText = utf8.decode(fileBytes);
          } else if (fileNameLower.endsWith('.xlsx')) {
            final excel = Excel.decodeBytes(fileBytes);
            for (var table in excel.tables.keys) {
              final sheet = excel.tables[table]!;
              for (var row in sheet.rows) {
                rawText += row.map((c) => c?.value?.toString() ?? '').join(' ') + '\\n';
              }
            }
          }

          if (rawText.isEmpty) throw Exception('No se pudo leer el contenido del archivo.');

          final aiExtracted = await _extractDataWithGemini(rawText, file.name);
          extractedCrossings = (aiExtracted['crossings'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          patent = aiExtracted['patent'] ?? 'Desconocida';
          concessionaire = aiExtracted['concessionaire'] ?? 'Autopista Genérica';
          
        } else {
          // Re-throw the original error if AI is disabled
          throw Exception('Error local: \$localParsingError. Activa "Auditar con IA" para soportar formatos desconocidos.');
        }
      }

      // 1.5. AUDITAR DE MANERA REAL CON HISTORIAL GPS EXISTENTE

      // 2. CONCILIACIÓN CON GPS EN FIRESTORE
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final firestore = FirebaseFirestore.instance;

      final tripsSnapshot = await firestore
          .collection('usuarios')
          .doc(userId)
          .collection('trips')
          .get();

      final List<TripHistory> trips = tripsSnapshot.docs
          .map((doc) => TripHistory.fromFirestore(doc))
          .toList();

      if (_useAI) {
        await _runAiAudit(
          extractedCrossings: extractedCrossings,
          trips: trips,
          patent: patent,
          concessionaire: concessionaire,
        );
      } else {
        // Ordenar cruces extraídos cronológicamente por fecha y hora antes de conciliar
        extractedCrossings.sort((a, b) {
          final dateCompare = a['date'].compareTo(b['date']);
          if (dateCompare != 0) return dateCompare;
          return a['time'].compareTo(b['time']);
        });

        List<Map<String, dynamic>> auditedDetails = [];
        double totalBilled = 0.0;
        double totalMatched = 0.0;

        for (var crossing in extractedCrossings) {
          final String cDateStr = crossing['date']; 
          final String cTimeStr = crossing['time']; 
          final String cPortico = crossing['portico']; 
          final double cCost = crossing['cost'];

          totalBilled += cCost;

          final cDateTime = DateTime.parse('$cDateStr $cTimeStr');
          bool isMatched = false;

          for (var trip in trips) {
            final tripDateStr = DateFormat('yyyy-MM-dd').format(trip.date);
            if (tripDateStr == cDateStr) {
              for (var toll in trip.tolls) {
                if (_checkPorticoMatch(toll.name, cPortico)) {
                  final difference = toll.timestamp.difference(cDateTime).inMinutes.abs();
                  if (difference <= 15) { // Ventana flexible de 15 minutos
                    isMatched = true;
                    totalMatched += cCost;
                    break;
                  }
                }
              }
            }
            if (isMatched) break;
          }

          auditedDetails.add({
            'date': cDateStr,
            'time': cTimeStr,
            'portico': cPortico,
            'cost': cCost,
            'status': isMatched ? 'Correcto' : 'Discrepancia',
          });
        }

        // 3. DETERMINAR PERIODO DE COBRO
        final firstDate = DateTime.parse(extractedCrossings.first['date']);
        final lastDate = DateTime.parse(extractedCrossings.last['date']);
        final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
        if (firstDate.month == lastDate.month) {
          period = '${months[firstDate.month - 1]} ${firstDate.year}';
        } else {
          period = '${months[firstDate.month - 1]} - ${months[lastDate.month - 1]} ${firstDate.year}';
        }

        final double reconciliationRate = totalBilled > 0 ? (totalMatched / totalBilled) * 100 : 0.0;
        final String finalStatus = reconciliationRate >= 100 
            ? 'Conciliado' 
            : (reconciliationRate > 0 ? 'Discrepancia Parcial' : 'Sin Registro');

        // 4. PERSISTIR EN FIRESTORE
        await firestore
            .collection('usuarios')
            .doc(userId)
            .collection('audited_invoices')
            .add({
          'concessionaire': concessionaire,
          'period': period,
          'patent': patent,
          'totalBilled': totalBilled,
          'totalMatched': totalMatched,
          'status': finalStatus,
          'reconciliationRate': reconciliationRate,
          'uploadDate': DateTime.now().toIso8601String(),
          'details': auditedDetails,
        });
      }

      setState(() {
        _isExtracting = false;
        _activeSubTab = 1; // Ir a la subpestaña de auditorías automáticamente
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_useAI ? 'Auditoría con IA guardada con éxito' : 'Auditoría clásica guardada con éxito'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }

    } catch (e) {
      setState(() => _isExtracting = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                SizedBox(width: 10),
                Text('Fallo de Lectura', style: TextStyle(color: Colors.white, fontSize: 17)),
              ],
            ),
            content: Text(e.toString().replaceAll('Exception:', ''), style: const TextStyle(color: Color(0xFF94A3B8))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('ENTENDIDO', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _exportInvoiceToExcel(Map<String, dynamic> invoice) async {
    try {
      final concessionaire = invoice['concessionaire'] ?? 'Autopista';
      final period = invoice['period'] ?? 'Periodo';
      final patent = invoice['patent'] ?? 'Patente';
      final double totalBilled = (invoice['totalBilled'] as num?)?.toDouble() ?? 0.0;
      final double totalMatched = (invoice['totalMatched'] as num?)?.toDouble() ?? 0.0;
      final double reconciliationRate = (invoice['reconciliationRate'] as num?)?.toDouble() ?? 0.0;
      final status = invoice['status'] ?? 'Desconocido';
      final aiReport = invoice['aiReport'] ?? '';
      
      final detailsList = invoice['details'] as List?;
      final List<Map<String, dynamic>> details = detailsList != null
          ? detailsList.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];

      final excel = Excel.createExcel();
      
      // Hoja de Resumen
      excel.rename('Sheet1', 'Resumen');
      final Sheet sheetSummary = excel['Resumen'];

      // Estilos reutilizables
      final titleStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#4F46E5'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        fontSize: 14,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final labelStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
        fontSize: 11,
        bold: true,
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
      );

      final valueStyle = CellStyle(
        fontSize: 11,
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      final statusStyle = CellStyle(
        backgroundColorHex: status.toString().toLowerCase().contains('conciliado') 
            ? ExcelColor.fromHexString('#D1FAE5') 
            : ExcelColor.fromHexString('#FEE2E2'),
        fontColorHex: status.toString().toLowerCase().contains('conciliado') 
            ? ExcelColor.fromHexString('#065F46') 
            : ExcelColor.fromHexString('#991B1B'),
        fontSize: 11,
        bold: true,
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      // Título del reporte
      final titleCell = sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      titleCell.value = TextCellValue('Reporte de Auditoría e IA - $patent');
      titleCell.cellStyle = titleStyle;
      sheetSummary.setRowHeight(0, 35.0);
      sheetSummary.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0),
      );

      // Configuración de filas del resumen
      final summaryRows = [
        {'label': 'Concesionaria', 'value': concessionaire},
        {'label': 'Periodo', 'value': period},
        {'label': 'Patente', 'value': patent},
        {'label': 'Total Facturado', 'value': '\$ ${totalBilled.toStringAsFixed(0)}'},
        {'label': 'Total Conciliado', 'value': '\$ ${totalMatched.toStringAsFixed(0)}'},
        {'label': 'Tasa de Conciliación', 'value': '${reconciliationRate.toStringAsFixed(1)}%'},
        {'label': 'Estado', 'value': status, 'type': 'status'},
      ];

      sheetSummary.setColumnWidth(0, 25.0);
      sheetSummary.setColumnWidth(1, 35.0);

      for (int i = 0; i < summaryRows.length; i++) {
        final rowData = summaryRows[i];
        final r = i + 2;
        sheetSummary.setRowHeight(r, 22.0);

        final cellLabel = sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r));
        cellLabel.value = TextCellValue(rowData['label'] as String);
        cellLabel.cellStyle = labelStyle;

        final cellVal = sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r));
        cellVal.value = TextCellValue(rowData['value'] as String);
        
        if (rowData['type'] == 'status') {
          cellVal.cellStyle = statusStyle;
        } else {
          cellVal.cellStyle = valueStyle;
        }
      }

      // Reporte de IA
      if (aiReport.isNotEmpty) {
        final aiTitleCell = sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 10));
        aiTitleCell.value = TextCellValue('Reporte Analítico de IA (Gemini)');
        aiTitleCell.cellStyle = CellStyle(
          bold: true,
          fontSize: 12,
          fontColorHex: ExcelColor.fromHexString('#4F46E5'),
          verticalAlign: VerticalAlign.Center,
        );
        sheetSummary.setRowHeight(10, 25.0);

        final aiContentCell = sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 11));
        aiContentCell.value = TextCellValue(aiReport);
        aiContentCell.cellStyle = CellStyle(
          fontSize: 10,
          textWrapping: TextWrapping.WrapText,
          verticalAlign: VerticalAlign.Top,
        );

        sheetSummary.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 11),
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 22),
        );
      }

      // Hoja de Detalles
      final Sheet sheetDetails = excel['Detalle de Cruces'];
      sheetDetails.setRowHeight(0, 28.0);

      final detailHeaders = ['Fecha', 'Hora', 'Pórtico', 'Costo', 'Estado'];
      final headerStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#4F46E5'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        fontSize: 11,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      for (int c = 0; c < detailHeaders.length; c++) {
        final cell = sheetDetails.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = TextCellValue(detailHeaders[c]);
        cell.cellStyle = headerStyle;
      }

      sheetDetails.setColumnWidth(0, 15.0); // Fecha
      sheetDetails.setColumnWidth(1, 12.0); // Hora
      sheetDetails.setColumnWidth(2, 35.0); // Pórtico
      sheetDetails.setColumnWidth(3, 15.0); // Costo
      sheetDetails.setColumnWidth(4, 18.0); // Estado

      for (int i = 0; i < details.length; i++) {
        final crossing = details[i];
        final isEven = i % 2 == 0;
        final baseBgColor = isEven ? '#F8FAFC' : '#FFFFFF';
        final r = i + 1;
        sheetDetails.setRowHeight(r, 20.0);

        // Fecha
        final cellFecha = sheetDetails.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r));
        cellFecha.value = TextCellValue(crossing['date'] ?? '');
        cellFecha.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString(baseBgColor),
          fontSize: 10,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );

        // Hora
        final cellHora = sheetDetails.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r));
        cellHora.value = TextCellValue(crossing['time'] ?? '');
        cellHora.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString(baseBgColor),
          fontSize: 10,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );

        // Pórtico
        final cellPortico = sheetDetails.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r));
        cellPortico.value = TextCellValue(crossing['portico'] ?? '');
        cellPortico.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString(baseBgColor),
          fontSize: 10,
          horizontalAlign: HorizontalAlign.Left,
          verticalAlign: VerticalAlign.Center,
        );

        // Costo
        final cellCosto = sheetDetails.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r));
        final costVal = (crossing['cost'] as num?)?.toDouble() ?? 0.0;
        cellCosto.value = TextCellValue('\$ ${costVal.toStringAsFixed(0)}');
        cellCosto.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString(baseBgColor),
          fontSize: 10,
          horizontalAlign: HorizontalAlign.Right,
          verticalAlign: VerticalAlign.Center,
        );

        // Estado
        final cellEstado = sheetDetails.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r));
        final crossingStatus = crossing['status'] ?? '';
        cellEstado.value = TextCellValue(crossingStatus);

        String statusBgColor = baseBgColor;
        String statusTextColor = '#000000';
        if (crossingStatus.toString().toLowerCase().contains('conciliado')) {
          statusBgColor = '#D1FAE5';
          statusTextColor = '#065F46';
        } else if (crossingStatus.toString().toLowerCase().contains('excedido') || 
                   crossingStatus.toString().toLowerCase().contains('discrepancia') ||
                   crossingStatus.toString().toLowerCase().contains('falta')) {
          statusBgColor = '#FEE2E2';
          statusTextColor = '#991B1B';
        }

        cellEstado.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString(statusBgColor),
          fontColorHex: ExcelColor.fromHexString(statusTextColor),
          fontSize: 10,
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }
      
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Error al codificar el archivo Excel.');
      }
      
      final cleanConcessionaire = concessionaire.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final cleanPeriod = period.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final String fileName = 'reporte_auditoria_${cleanConcessionaire}_${cleanPeriod}_$patent.xlsx';
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generando archivo Excel...'),
          duration: Duration(seconds: 1),
        ),
      );

      await saveFileBytes(
        bytes: Uint8List.fromList(bytes),
        fileName: fileName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte exportado con éxito'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar Excel: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Auditoría y Reportes',
          style: TextStyle(color: textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildSubTabBar(),
          Expanded(
            child: _activeSubTab == 0 
                ? _buildReportsTab() 
                : _buildAuditsTab(),
          ),
        ],
      ),
    );
  }

  // Control deslizante de Subpestañas Premium
  Widget _buildSubTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSubTabItem(0, 'Consumo e Historial', Icons.bar_chart),
          ),
          Expanded(
            child: _buildSubTabItem(1, 'Auditoría de Boletas', Icons.check_circle_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabItem(int index, String title, IconData icon) {
    final isSelected = _activeSubTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeSubTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : textMuted,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : textMuted,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SUBPESTAÑA 1: REPORTES Y CONSUMO ---

  Widget _buildReportsTab() {
    return StreamBuilder<List<TripHistory>>(
      stream: _historyService.getTripHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(textMuted);
        }

        final allTrips = snapshot.data!;
        final filteredTrips = allTrips.where(_shouldKeepTrip).toList();

        final uniqueVehicles = allTrips
            .map((t) => t.vehicleName)
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();
        uniqueVehicles.sort();

        // Calcular desglose exacto por autopista
        final Map<String, double> highwayCosts = {};
        final Map<String, int> highwayTollsCount = {};
        
        for (var trip in filteredTrips) {
          for (var toll in trip.tolls) {
            final hw = _classifyHighway(toll.name);
            highwayCosts[hw] = (highwayCosts[hw] ?? 0.0) + toll.cost;
            highwayTollsCount[hw] = (highwayTollsCount[hw] ?? 0) + 1;
          }
        }

        final sortedHighways = highwayCosts.keys.toList()
          ..sort((a, b) => highwayCosts[b]!.compareTo(highwayCosts[a]!));

        final double totalSpent = filteredTrips.fold(
          0.0,
          (acc, trip) => acc + trip.totalCost,
        );

        return StreamBuilder<double>(
          stream: _historyService.getMonthlyLimit(),
          builder: (context, limitSnapshot) {
            if (!limitSnapshot.hasData) {
              return const SizedBox.shrink();
            }

            final double monthlyLimit = limitSnapshot.data!;
            final double progress = (monthlyLimit > 0)
                ? (totalSpent / monthlyLimit).clamp(0.0, 1.1)
                : 0.0;

            return Column(
              children: [
                _buildFiltersBar(uniqueVehicles),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _buildTotalSpentCard(
                        totalSpent,
                        filteredTrips.length,
                        progress,
                        monthlyLimit,
                        textMain,
                        textMuted,
                      ),
                      if (filteredTrips.isNotEmpty) ...[
                        _buildHighwayBreakdownCard(
                          highwayCosts,
                          highwayTollsCount,
                          sortedHighways,
                          totalSpent,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Text(
                            'VIAJES COINCIDENTES (${filteredTrips.length})',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                      if (filteredTrips.isEmpty)
                        _buildFilteredEmptyState(textMuted)
                      else
                        ...filteredTrips.map((trip) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: _buildTripCard(
                                context,
                                trip,
                                surfaceColor,
                                textMain,
                                textMuted,
                              ),
                            )),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- SUBPESTAÑA 2: AUDITORÍA DE BOLETAS MENSUALES ---

  Widget _buildAuditsTab() {
    if (_isExtracting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Extrayendo datos de boleta...',
              style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Conciliando registros con el GPS local...',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getAuditedInvoices(),
      builder: (context, snapshot) {
        final auditedInvoices = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          children: [
            // Tarjeta de Carga de Archivos
            _buildUploadCard(),
            const SizedBox(height: 24),
            Text(
              'HISTORIAL DE AUDITORÍAS (${auditedInvoices.length})',
              style: TextStyle(
                color: textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            if (auditedInvoices.isEmpty)
              _buildEmptyAuditsState()
            else
              ...auditedInvoices.map((inv) => _buildAuditedInvoiceCard(inv)),
          ],
        );
      },
    );
  }





  Widget _buildUploadCard() {
    final activeColor = _useAI ? const Color(0xFF8B5CF6) : primaryColor;
    return GestureDetector(
      onTap: _pickAndAuditInvoice,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: surfaceColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _useAI ? const Color(0xFF8B5CF6).withValues(alpha: 0.4) : Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _useAI ? Icons.auto_awesome : Icons.cloud_upload_outlined, 
                color: activeColor, 
                size: 28
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _useAI ? 'Auditar Cuenta con IA' : 'Subir Cuenta de Autopista',
              style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _useAI 
                  ? 'Análisis inteligente, semántico y detección de fraude por Gemini' 
                  : 'Soporta formato oficial mensual (PDF / CSV / XLSX)',
              style: TextStyle(color: textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAuditsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_open_outlined, color: textMuted.withValues(alpha: 0.4), size: 48),
          const SizedBox(height: 14),
          Text(
            'Sin boletas auditadas',
            style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Sube tu primer archivo PDF, CSV o XLSX para conciliar tus gastos.',
            style: TextStyle(color: textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Renderiza una boleta mensual auditada
  Widget _buildAuditedInvoiceCard(Map<String, dynamic> invoice) {
    final double billed = invoice['totalBilled'] ?? 0.0;
    final double matched = invoice['totalMatched'] ?? 0.0;
    final double rate = invoice['reconciliationRate'] ?? 0.0;
    final String status = invoice['status'] ?? 'Conciliado';
    final String dateStr = invoice['uploadDate'] ?? '';
    final String id = invoice['id'] ?? '';
    final String? aiReport = invoice['aiReport'];

    String formattedDate = '';
    if (dateStr.isNotEmpty) {
      formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(dateStr));
    }

    final details = (invoice['details'] as List? ?? []).cast<Map<String, dynamic>>();

    Color statusColor = const Color(0xFF10B981); // Verde
    if (status.contains('Discrepancia')) {
      statusColor = Colors.orangeAccent;
    } else if (status.contains('Sin')) {
      statusColor = Colors.redAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: textMuted,
          collapsedIconColor: textMuted,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long, color: primaryColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice['concessionaire'] ?? 'Boleta',
                      style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Periodo: ${invoice['period']}',
                      style: TextStyle(color: textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Boleta', style: TextStyle(color: textMuted, fontSize: 10)),
                    Text('\$${billed.toStringAsFixed(0)} CLP', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Conciliado GPS', style: TextStyle(color: textMuted, fontSize: 10)),
                    Text('\$${matched.toStringAsFixed(0)} CLP', style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${rate.toStringAsFixed(0)}% Match',
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0x1A000000),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Auditado el $formattedDate • Patente: ${invoice['patent']}',
                        style: TextStyle(color: textMuted, fontSize: 10),
                      ),
                      Row(
                        children: [
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.only(right: 12),
                            icon: const Icon(Icons.table_view_rounded, color: Color(0xFF10B981), size: 18),
                            tooltip: 'Exportar a Excel',
                            onPressed: () => _exportInvoiceToExcel(invoice),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                            tooltip: 'Eliminar',
                            onPressed: () => _deleteAuditedInvoice(id),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 16),
                  if (aiReport != null && aiReport.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                            const Color(0xFF6366F1).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: Color(0xFFC084FC), size: 16),
                              SizedBox(width: 8),
                              Text(
                                'REPORTE ANALÍTICO DE IA (GEMINI)',
                                style: TextStyle(
                                  color: Color(0xFFC084FC),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildFormattedReport(aiReport),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 16),
                  ],
                  Text(
                    'DETALLE DE TRANSACCIONES AUDITADAS (AGRUPADO POR FECHA)',
                    style: TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  ...() {
                    // Group details by date
                    final Map<String, List<Map<String, dynamic>>> groupedDetails = {};
                    for (var tr in details) {
                      final date = tr['date'] ?? 'Sin Fecha';
                      groupedDetails.putIfAbsent(date, () => []).add(tr);
                    }

                    // Sort dates chronologically
                    final sortedDates = groupedDetails.keys.toList()..sort();

                    return sortedDates.map<Widget>((dateStr) {
                      final dateCrossings = groupedDetails[dateStr]!;
                      final double dateTotalCost = dateCrossings.fold(0.0, (acc, tr) => acc + (tr['cost'] as num).toDouble());
                      final bool dateHasDiscrepancy = dateCrossings.any((tr) => tr['status'] != 'Correcto');
                      final String formattedDateHeader = _formatSpanishDate(dateStr);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            iconColor: textMuted,
                            collapsedIconColor: textMuted,
                            title: Text(
                              formattedDateHeader,
                              style: TextStyle(color: textMain, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${dateCrossings.length} peajes • \$${dateTotalCost.toStringAsFixed(0)} CLP',
                              style: TextStyle(color: textMuted, fontSize: 10),
                            ),
                            leading: Icon(
                              dateHasDiscrepancy ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                              color: dateHasDiscrepancy ? Colors.orangeAccent : const Color(0xFF10B981),
                              size: 18,
                            ),
                            childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            children: dateCrossings.map<Widget>((tr) {
                              final double trCost = (tr['cost'] as num).toDouble();
                              final String trStatus = tr['status'] ?? 'Correcto';
                              final bool isCorrect = trStatus == 'Correcto';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                tr['portico'] ?? 'Pórtico',
                                                style: TextStyle(color: textMain, fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: isCorrect 
                                                      ? const Color(0xFF10B981).withValues(alpha: 0.15) 
                                                      : Colors.redAccent.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isCorrect ? '✓ Match' : '⚠ Sin registro GPS',
                                                  style: TextStyle(
                                                    color: isCorrect ? const Color(0xFF10B981) : Colors.redAccent,
                                                    fontSize: 7,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Hora: ${tr['time']}',
                                            style: TextStyle(color: textMuted, fontSize: 9),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '\$${trCost.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: isCorrect ? textMain.withValues(alpha: 0.8) : Colors.redAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    });
                  }(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FILTROS DE CONSUMO Y DETALLES DE VIAJES ---

  Widget _buildFiltersBar(List<String> vehicles) {
    final bool hasActiveFilters = _selectedVehicle != 'Todos' || _selectedHighway != 'Todas' || _selectedDatePreset != 'Todos';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtros de Reporte',
                style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              if (hasActiveFilters)
                GestureDetector(
                  onTap: _clearAllFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Limpiar',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  icon: Icons.calendar_today,
                  label: _selectedDatePreset == 'Personalizado' && _customDateRange != null
                      ? '${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}'
                      : 'Fecha: $_selectedDatePreset',
                  onTap: _showDateFilterSelector,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  icon: Icons.directions_car,
                  label: _selectedVehicle == 'Todos' ? 'Vehículo: Todos' : _selectedVehicle,
                  onTap: () => _showVehicleSelector(vehicles),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  icon: Icons.alt_route,
                  label: _selectedHighway == 'Todas' ? 'Autopistas: Todas' : _selectedHighway,
                  onTap: _showHighwaySelector,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final bool isActive = !label.contains('Todos') && !label.contains('Todas');
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? Colors.transparent : Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? Colors.white : textMuted, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : textMain,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: isActive ? Colors.white70 : textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  void _showDateFilterSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filtrar por Rango de Fechas',
                style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...['Todos', 'Hoy', 'Últimos 7 días', 'Este Mes'].map((preset) => ListTile(
                title: Text(preset, style: TextStyle(color: textMain, fontSize: 15)),
                trailing: _selectedDatePreset == preset ? Icon(Icons.check_circle, color: primaryColor) : null,
                onTap: () {
                  setState(() {
                    _selectedDatePreset = preset;
                    _customDateRange = null;
                  });
                  Navigator.pop(context);
                },
              )),
              ListTile(
                leading: Icon(Icons.date_range, color: primaryColor),
                title: Text('Rango Personalizado...', style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.bold)),
                trailing: _selectedDatePreset == 'Personalizado' ? Icon(Icons.check_circle, color: primaryColor) : null,
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    initialDateRange: _customDateRange,
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: primaryColor,
                            onPrimary: Colors.white,
                            surface: surfaceColor,
                            onSurface: textMain,
                          ),
                          scaffoldBackgroundColor: bgColor,
                          dialogTheme: DialogThemeData(backgroundColor: surfaceColor),
                          appBarTheme: AppBarTheme(
                            backgroundColor: surfaceColor,
                            iconTheme: const IconThemeData(color: Colors.white),
                          ),
                        ),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              constraints: const BoxConstraints(
                                maxWidth: 420,
                                maxHeight: 580,
                              ),
                              child: child!,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDatePreset = 'Personalizado';
                      _customDateRange = picked;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVehicleSelector(List<String> vehicles) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filtrar por Patente o Auto',
                style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text('Todos los vehículos', style: TextStyle(color: textMain, fontSize: 15)),
                trailing: _selectedVehicle == 'Todos' ? Icon(Icons.check_circle, color: primaryColor) : null,
                onTap: () {
                  setState(() {
                    _selectedVehicle = 'Todos';
                  });
                  Navigator.pop(context);
                },
              ),
              if (vehicles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: Text('No hay vehículos detectados en tus viajes', style: TextStyle(color: textMuted, fontSize: 13)),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final v = vehicles[index];
                      return ListTile(
                        leading: const Icon(Icons.directions_car, color: Colors.white54),
                        title: Text(v, style: TextStyle(color: textMain, fontSize: 15)),
                        trailing: _selectedVehicle == v ? Icon(Icons.check_circle, color: primaryColor) : null,
                        onTap: () {
                          setState(() {
                            _selectedVehicle = v;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showHighwaySelector() {
    final highways = [
      'Todas',
      'Autopista Central',
      'Costanera Norte',
      'Vespucio Norte',
      'Vespucio Sur',
      'Vespucio Oriente (AVO)',
      'Ruta 68',
      'Ruta 78',
      'Autopista de Conexión'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filtrar por Autopista Concesionada',
                style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: highways.length,
                  itemBuilder: (context, index) {
                    final h = highways[index];
                    return ListTile(
                      title: Text(h == 'Todas' ? 'Todas las autopistas' : h, style: TextStyle(color: textMain, fontSize: 15)),
                      trailing: _selectedHighway == h ? Icon(Icons.check_circle, color: primaryColor) : null,
                      onTap: () {
                        setState(() {
                          _selectedHighway = h;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHighwayBreakdownCard(
    Map<String, double> costs,
    Map<String, int> counts,
    List<String> sortedKeys,
    double totalSpent,
  ) {
    if (costs.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consumo por Concesionaria',
                style: TextStyle(
                  color: textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.pie_chart_outline, color: primaryColor, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          ...sortedKeys.map((hw) {
            final double cost = costs[hw] ?? 0.0;
            final int count = counts[hw] ?? 0;
            final double percentage = totalSpent > 0 ? (cost / totalSpent) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          hw,
                          style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$${cost.toStringAsFixed(0)} CLP ($count peajes)',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage.clamp(0.0, 1.0),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotalSpentCard(
    double total,
    int count,
    double progress,
    double limit,
    Color textMain,
    Color textMuted,
  ) {
    Color progressColor = const Color(0xFF4F46E5); 
    if (progress >= 1.0) {
      progressColor = Colors.redAccent;
    } else if (progress >= 0.9) {
      progressColor = Colors.orangeAccent;
    } else if (progress >= 0.75) {
      progressColor = Colors.yellowAccent;
    } else if (progress >= 0.5) {
      progressColor = const Color(0xFF10B981);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gasto Total Filtrado',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(Icons.speed, color: progressColor, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/ \$${limit.toStringAsFixed(0)}',
                style: TextStyle(color: textMuted, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              color: progressColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Equivale al ${(progress * 100).round()}% del presupuesto total',
            style: TextStyle(
              color: progressColor.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textMuted) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay viajes registrados aún',
            style: TextStyle(color: textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredEmptyState(Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off_outlined,
            size: 64,
            color: textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Ningún viaje coincide con los filtros aplicados.',
            style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta cambiar la fecha, auto o autopista seleccionada en el menú superior.',
            style: TextStyle(color: textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(
    BuildContext context,
    TripHistory trip,
    Color surfaceColor,
    Color textMain,
    Color textMuted,
  ) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: textMuted,
          collapsedIconColor: textMuted,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateFormat.format(trip.date),
                style: TextStyle(color: textMain, fontSize: 14),
              ),
              Text(
                '\$${trip.totalCost.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${trip.distanceKm.toStringAsFixed(1)} km • ${trip.tolls.length} pórticos',
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.directions_car_filled, color: textMuted, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    trip.vehicleName,
                    style: TextStyle(
                      color: textMuted.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0x1A000000),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  ...trip.tolls.map((toll) {
                    final hw = _classifyHighway(toll.name);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  toll.name,
                                  style: TextStyle(
                                    color: textMain,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        hw,
                                        style: TextStyle(
                                          color: primaryColor.withValues(alpha: 0.8),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('HH:mm').format(toll.timestamp),
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${toll.cost.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: textMain.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
