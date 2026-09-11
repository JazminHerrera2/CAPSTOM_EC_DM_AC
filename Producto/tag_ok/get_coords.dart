import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final env = File('.env').readAsStringSync();
  var token = env.split('\n').firstWhere((l) => l.startsWith('MAPBOX_ACCESS_TOKEN=')).split('=')[1].trim();
  
  final queries = [
    "Enlace Rinconada Ruta 78, Maipu, Chile",
    "Ruta 78 y Avenida Los Pajaritos, Maipu, Chile",
    "Peaje Padre Hurtado Ruta 78, Chile",
  ];
  
  for (var query in queries) {
    final url = Uri.parse('https://api.mapbox.com/search/geocode/v6/forward?q=\${Uri.encodeComponent(query)}&access_token=$token');
    final response = await http.get(url);
    final data = jsonDecode(response.body);
    
    if (data['features'] != null && data['features'].isNotEmpty) {
      final coords = data['features'][0]['geometry']['coordinates'];
      print('Query: $query -> Lat: ${coords[1]}, Lng: ${coords[0]}');
    } else {
      print('Query: $query -> Not found');
    }
  }
}
