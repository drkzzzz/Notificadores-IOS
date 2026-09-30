import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class SunatService {
  static const _base =
      'https://ww1.sunat.gob.pe/ol-ti-itfisdenreg/itfisdenreg.htm';

  static Future<Map<String, dynamic>> _consultar(
    String accion,
    String documento,
  ) async {
    final uri = Uri.parse('$_base?accion=$accion&$documento');
    final res = await http
        .get(uri, headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        })
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('SUNAT no respondió (HTTP ${res.statusCode})');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final message = data['message']?.toString();
    final lista = (data['lista'] as List?) ?? [];
    if (lista.isEmpty || (message != null && message != 'success')) {
      throw Exception('No se encontraron datos para el documento');
    }
    return Map<String, dynamic>.from(lista.first as Map);
  }

  static Future<String> consultarDni(String dni) async {
    try {
      final r = await _consultar('obtenerDatosDni', 'numDocumento=$dni');
      return r['nombresapellidos']?.toString().trim() ?? '';
    } on SocketException {
      throw Exception('Sin conexión a SUNAT');
    } on TimeoutException {
      throw Exception('SUNAT tardó demasiado en responder');
    } on FormatException {
      throw Exception('Respuesta inválida de SUNAT');
    }
  }

  static String formatearNombre(String raw) {
    if (!raw.contains(',')) return raw;
    final partes = raw.split(',');
    final apellidos = partes[0].trim();
    final nombres = partes.length > 1 ? partes[1].trim() : '';
    return '$nombres $apellidos'.trim();
  }
}
