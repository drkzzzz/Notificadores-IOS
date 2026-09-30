import 'dart:convert';
import 'package:http/http.dart' as http;

Map<String, dynamic> decodeApiResponse(http.Response response) {
  if (response.statusCode >= 300 && response.statusCode < 400) {
    throw Exception('La dirección de la API está redirigiendo a otra página. Contacte al administrador.');
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(utf8.decode(response.bodyBytes));
  } on FormatException {
    throw Exception('El servidor no devolvió datos de la API (HTTP ${response.statusCode}). Intente nuevamente o contacte al administrador.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw Exception('El servidor devolvió datos con un formato inesperado (HTTP ${response.statusCode}).');
  }
  if (response.statusCode == 404 && decoded['detail'] == null) {
    throw Exception('La ruta de la API no está disponible. Contacte al administrador.');
  }
  return decoded;
}
