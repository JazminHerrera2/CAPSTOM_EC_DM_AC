import 'dart:convert';
import 'dart:io';
void main() {
  final map = jsonDecode(File('response.json').readAsStringSync());
  if (map['routes'] != null) {
    print('ROUTES exists');
    print(map['routes'][0].keys.toList());
  } else {
    print('NO ROUTES');
    print(map.keys.toList());
  }
}
