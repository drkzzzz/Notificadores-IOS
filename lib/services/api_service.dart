import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'api_response.dart';
import '../models/resumen_notificadores.dart';

class ApiService {
  static const String _baseUrl = 'https://sat-t.gob.pe/api';
  static const String _notificadoresBaseUrl = String.fromEnvironment(
    'NOTIFICADORES_API_BASE_URL',
    defaultValue: 'http://190.119.38.13',
  );
  static const String _notificadoresApiKey = String.fromEnvironment(
    'NOTIFICADORES_API_KEY',
    defaultValue: 'L3nsd@ys',
  );

  static Future<Map<String, dynamic>> importesWhatsapp(int id, String dni) async {
    final uri = Uri.parse('$_notificadoresBaseUrl/api/notificadores/cartera-op-rd/importes-whatsapp/$id/').replace(queryParameters: {'dni': dni});
    try {
      final res = await http.get(uri, headers: {'Accept': 'application/json', 'X-API-Key': _notificadoresApiKey}).timeout(const Duration(seconds: 45));
      final data = decodeApiResponse(res);
      if (res.statusCode != 200 || data['status'] != 'ok') throw Exception(data['detail'] ?? 'No se pudieron consultar los importes.');
      return Map<String, dynamic>.from(data);
    } on TimeoutException {
      throw Exception('La consulta de importes tardó demasiado. Reintente.');
    } on http.ClientException {
      throw Exception('No se pudieron consultar los importes. Revise su conexión.');
    }
  }

  static Future<FiscalizadorSesion> login(String dni, String clave) async {
    if (_notificadoresApiKey.isEmpty) {
      throw Exception('La aplicación no tiene configurada la clave de acceso.');
    }

    final uri = Uri.parse('$_notificadoresBaseUrl/api/notificadores/login/');

    try {
      final res = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'X-API-Key': _notificadoresApiKey,
            },
            body: jsonEncode({'dni': dni, 'clave': clave}),
          )
          .timeout(const Duration(seconds: 30));
      final data = decodeApiResponse(res);

      if (res.statusCode == 200) {
        return parseFiscalizadorSesion(data, dni);
      }

      final detail = data['detail']?.toString();
      if (res.statusCode == 401) {
        throw Exception(detail ?? 'DNI o clave incorrectos.');
      }
      throw Exception(detail ?? 'No se pudo iniciar sesión.');
    } on http.ClientException {
      throw Exception('No se pudo conectar con el servidor. Revise su conexión e intente nuevamente.');
    } on SocketException {
      throw Exception('Sin conexión a la red municipal.');
    } on FormatException {
      throw Exception('Respuesta inválida del servidor.');
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado en responder. Inténtalo de nuevo.');
    }
  }

  static FiscalizadorSesion parseFiscalizadorSesion(Map<String, dynamic> data, String dni) {
    final fiscal = data['fiscalizador'];
    if (data['status'] != 'ok' || fiscal is! Map ||
        fiscal['id'] is! num || (fiscal['id'] as num) <= 0 ||
        fiscal['dni']?.toString() != dni) {
      throw Exception('El servidor no devolvió una sesión válida. Intente nuevamente.');
    }
    return FiscalizadorSesion(
      id: (fiscal['id'] as num).toInt(),
      dni: fiscal['dni'].toString(),
      nombre: fiscal['nombre']?.toString() ?? '',
      email: fiscal['email']?.toString() ?? '',
    );
  }

  static Future<ResumenNotificadores> consultarResumenNotificadores(
    String codContribuyente,
  ) async {
    if (_notificadoresApiKey.isEmpty) {
      throw Exception('La aplicación no tiene configurada la clave de acceso.');
    }

    final cod = codContribuyente.trim().padLeft(11, '0');
    final uri = Uri.parse(
      '$_notificadoresBaseUrl/api/notificadores/deuda-consolidada/$cod/',
    );

    try {
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        'X-API-Key': _notificadoresApiKey,
      }).timeout(const Duration(seconds: 120));
      final data = decodeApiResponse(res);

      if (res.statusCode == 200) {
        return ResumenNotificadores.fromJson(Map<String, dynamic>.from(data));
      }

      final detail = data['detail']?.toString();
      if (res.statusCode == 401) {
        throw Exception('La aplicación no está autorizada para consultar deudas.');
      }
      throw Exception(detail ?? 'No se pudo consultar la deuda.');
    } on http.ClientException {
      throw Exception('No se pudo conectar con el servidor. Revise su conexión e intente nuevamente.');
    } on SocketException {
      throw Exception('Sin conexión a la red municipal.');
    } on FormatException {
      throw Exception('Respuesta inválida del servidor.');
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado en responder. Inténtalo de nuevo.');
    }
  }

  static Future<DeudaConsolidado> consultarDeuda(String codContribuyente) async {
    final cod = codContribuyente.padLeft(11, '0');
    final uri = Uri.parse('$_baseUrl/deudas/$cod');

    try {
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 30));

      final data = decodeApiResponse(res);

      if (data['success'] == true) {
        return DeudaConsolidado.fromJson(data);
      }

      // Si pide email, lanzar excepción especial
      if (data['need_email'] == true) {
        throw NeedEmailException(
          message: data['message'] ?? 'Ingresa un correo',
          contribuyente: data['contribuyente'] ?? {},
        );
      }

      throw Exception(data['message'] ?? 'Error al consultar deudas');
    } on http.ClientException {
      throw Exception('No se pudo conectar con el servidor. Revise su conexión e intente nuevamente.');
    } on SocketException {
      throw Exception('Sin conexión a internet');
    } on HttpException {
      throw Exception('Error de conexión con el servidor');
    } on FormatException {
      throw Exception('Respuesta inválida del servidor');
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado en responder');
    }
  }

  static Future<DeudaConsolidado> consultarDeudaConEmail(
      String codContribuyente, String email) async {
    final cod = codContribuyente.padLeft(11, '0');
    final uri = Uri.parse('$_baseUrl/deudas/por-email');

    try {
      final res = await http.post(uri, headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      }, body: {
        'cod': cod,
        'email': email,
      }).timeout(const Duration(seconds: 30));

      final data = decodeApiResponse(res);

      if (data['success'] == true) {
        return DeudaConsolidado.fromJson(data);
      }

      throw Exception(data['message'] ?? 'Error al consultar deudas');
    } on http.ClientException {
      throw Exception('No se pudo conectar con el servidor. Revise su conexión e intente nuevamente.');
    } on SocketException {
      throw Exception('Sin conexión a internet');
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado en responder');
    }
  }

  static Future<List<IdentificadorOpRd>> obtenerIdentificadores() async {
    if (_notificadoresApiKey.isEmpty) {
      throw Exception('La aplicación no tiene configurada la clave de acceso.');
    }

    final uri = Uri.parse(
      '$_notificadoresBaseUrl/api/notificadores/cartera-op-rd/identificadores/',
    );

    try {
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        'X-API-Key': _notificadoresApiKey,
      }).timeout(const Duration(seconds: 30));
      final data = decodeApiResponse(res);

      if (res.statusCode == 200 && data['status'] == 'ok') {
        final lista = (data['data'] as List?)
                ?.map((e) => IdentificadorOpRd.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return lista;
      }

      final detail = data['detail']?.toString();
      if (res.statusCode == 401) {
        throw Exception('La aplicación no está autorizada.');
      }
      throw Exception(detail ?? 'No se pudieron cargar los identificadores.');
    } on http.ClientException {
      throw Exception('No se pudo conectar con el servidor. Revise su conexión e intente nuevamente.');
    } on SocketException {
      throw Exception('Sin conexión a la red municipal.');
    } on FormatException {
      throw Exception('Respuesta inválida del servidor.');
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado en responder. Inténtalo de nuevo.');
    }
  }

  static Future<List<CarteraItem>> obtenerCarteraAsignada(
    String fecha,
    String dni, {
    bool incluirSaldo = true,
    bool incluirLlamadas = false,
  }) async {
    if (_notificadoresApiKey.isEmpty) {
      throw Exception('La aplicación no tiene configurada la clave de acceso.');
    }

    final uri = Uri.parse(
      '$_notificadoresBaseUrl/api/notificadores/cartera-op-rd/cartera/$fecha/?dni=$dni&incluir_saldo=${incluirSaldo ? 1 : 0}&incluir_llamadas=${incluirLlamadas ? 1 : 0}',
    );

    try {
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        'X-API-Key': _notificadoresApiKey,
      }).timeout(const Duration(seconds: 120));
      final data = decodeApiResponse(res);

      if (res.statusCode == 200 && data['status'] == 'ok') {
        final lista = (data['data'] as List?)
                ?.map((e) => CarteraItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return lista;
      }

      final detail = data['detail']?.toString();
      if (res.statusCode == 401) {
        throw Exception('La aplicación no está autorizada.');
      }
      if (res.statusCode == 404) {
        throw Exception(detail ?? 'El notificador no está registrado.');
      }
      throw Exception(detail ?? 'No se pudo cargar la cartera asignada.');
    } on http.ClientException {
      throw Exception('No se pudo conectar con el servidor. Revise su conexión e intente nuevamente.');
    } on SocketException {
      throw Exception('Sin conexión a la red municipal.');
    } on FormatException {
      throw Exception('Respuesta inválida del servidor.');
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado en responder. Inténtalo de nuevo.');
    }
  }

  static Future<int> obtenerTareasAsignadas(String dni) async {
    if (_notificadoresApiKey.isEmpty) {
      throw Exception('La aplicación no tiene configurada la clave de acceso.');
    }

    final uri = Uri.parse(
      '$_notificadoresBaseUrl/api/notificadores/cartera-op-rd/tareas/?dni=$dni',
    );

    try {
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        'X-API-Key': _notificadoresApiKey,
      }).timeout(const Duration(seconds: 30));
      final data = decodeApiResponse(res);

      if (res.statusCode == 200) {
        return (data['count'] as num?)?.toInt() ?? 0;
      }

      final detail = data['detail']?.toString();
      if (res.statusCode == 401) {
        throw Exception('La aplicación no está autorizada.');
      }
      if (res.statusCode == 404) {
        throw Exception(detail ?? 'El notificador no está registrado.');
      }
      throw Exception(detail ?? 'No se pudo contar las tareas asignadas.');
    } on http.ClientException {
      throw Exception('No se pudo conectar con el servidor. Revise su conexión e intente nuevamente.');
    } on SocketException {
      throw Exception('Sin conexión a la red municipal.');
    } on FormatException {
      throw Exception('Respuesta inválida del servidor.');
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado en responder. Inténtalo de nuevo.');
    }
  }

  /// Condiciones vigentes: Notificado / Inubicado (entrega normal) y
  /// 'Finalizado' (registro ya pagado: solo domicilio fiscal + GPS).
  static const Set<String> condicionesEntrega = {'Notificado', 'Inubicado'};

  /// Resultados posibles de una llamada y compromisos del contribuyente.
  static const List<String> resultadosLlamada = [
    'Atendida',
    'No contestada',
    'Numero no existe',
  ];
  static const List<String> compromisosLlamada = [
    'Vendra a pagar',
    'No acepta la deuda',
  ];

  /// Registra el resultado de una llamada en BDSGTM01.dbo.LlamadasContribuyentes.
  ///
  /// Valida en el equipo lo mismo que el servidor para dar aviso inmediato:
  /// resultado obligatorio; si es 'Atendida' se exige el compromiso y, si el
  /// compromiso es 'Vendra a pagar', una fecha.
  static Future<void> registrarLlamada({
    required int id,
    required String dni,
    required String resultado,
    String compromiso = '',
    String? fechaCompromiso,
    String observaciones = '',
    String? idempotencia,
    String? fechaCaptura,
  }) async {
    if (_notificadoresApiKey.isEmpty) {
      throw Exception('La aplicación no tiene configurada la clave de acceso.');
    }
    if (!resultadosLlamada.contains(resultado)) {
      throw Exception('Seleccione el resultado de la llamada.');
    }
    if (resultado == 'Atendida') {
      if (!compromisosLlamada.contains(compromiso)) {
        throw Exception('Indique qué dijo el contribuyente.');
      }
      if (compromiso == 'Vendra a pagar' &&
          (fechaCompromiso == null || fechaCompromiso.isEmpty)) {
        throw Exception('Seleccione la fecha en que vendrá a pagar.');
      }
    }
    final uri = Uri.parse(
      '$_notificadoresBaseUrl/api/notificadores/llamadas/finalizar/',
    );
    try {
      final res = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': _notificadoresApiKey,
        },
        body: jsonEncode({
          'id': id,
          'dni': dni,
          'resultado': resultado,
          'compromiso': resultado == 'Atendida' ? compromiso : '',
          'fecha_compromiso': fechaCompromiso ?? '',
          'observaciones': observaciones,
          if (idempotencia != null) 'idempotencia': idempotencia,
          if (fechaCaptura != null) 'fecha_captura': fechaCaptura,
        }),
      ).timeout(const Duration(seconds: 60));
      final data = decodeApiResponse(res);

      if (res.statusCode == 200 && data['status'] == 'ok') {
        return;
      }
      if (data['detail'] != null && data['detail'].toString().contains('ya fue')) {
        // Reintento de una llamada ya registrada: se trata como éxito.
        return;
      }

      final detail = data['detail']?.toString();
      if (res.statusCode == 401) {
        throw Exception('La aplicación no está autorizada.');
      }
      if (res.statusCode == 404) {
        throw Exception(detail ?? 'La asignación no pertenece al notificador.');
      }
      throw Exception(detail ?? 'No se pudo registrar la llamada.');
    } on http.ClientException {
      throw Exception('No se pudo conectar con el servidor. Revise su conexión e intente nuevamente.');
    } on SocketException {
      throw Exception('Sin conexión a la red municipal.');
    } on FormatException {
      throw Exception('Respuesta inválida del servidor.');
    } on TimeoutException {
      throw Exception('No se recibió la confirmación a tiempo. Verifique en la grilla si la llamada quedó registrada antes de reintentar.');
    }
  }

  static Future<void> actualizarEntrega({
    required int id,
    required String dni,
    required String fotoBase64,
    String? fotoOpBase64,
    String? fotoRdBase64,
    double? lat,
    double? lng,
    required String condicion,
    String? idempotencia,
    String? fechaCaptura,
  }) async {
    if (_notificadoresApiKey.isEmpty) {
      throw Exception('La aplicación no tiene configurada la clave de acceso.');
    }
    if (condicion != 'Finalizado' && !condicionesEntrega.contains(condicion)) {
      throw Exception('Seleccione una condición válida.');
    }
    if (fotoBase64.isEmpty) {
      throw Exception('Debe tomar la fotografía del domicilio fiscal.');
    }
    if (condicion != 'Finalizado' &&
        (fotoOpBase64 ?? '').isEmpty &&
        (fotoRdBase64 ?? '').isEmpty) {
      throw Exception('Debe registrar por lo menos el cargo OP o el cargo RD.');
    }
    if (lat == null || lng == null) {
      throw Exception('Debe registrar la ubicación GPS del domicilio.');
    }
    final uri = Uri.parse(
      '$_notificadoresBaseUrl/api/notificadores/cartera-op-rd/actualizar/',
    );
    try {
      final res = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': _notificadoresApiKey,
        },
        body: jsonEncode({
          'id': id,
          'dni': dni,
          'condicion': condicion,
          'foto': fotoBase64,
          'foto_op': ?fotoOpBase64,
          'foto_rd': ?fotoRdBase64,
          'lat': lat,
          'lng': lng,
          'idempotencia': ?idempotencia,
          'fecha_captura': ?fechaCaptura,
        }),
      ).timeout(const Duration(seconds: 120));
      if (res.statusCode == 413) throw Exception('Las fotos superan el tamaño permitido. Vuelva a tomarlas.');
      final data = decodeApiResponse(res);
      if (res.statusCode == 200 && data['status'] == 'ok') return;
      final detail = data['detail']?.toString();
      if (res.statusCode == 401) throw Exception('La aplicación no está autorizada.');
      if (res.statusCode == 404) throw Exception(detail ?? 'La asignación no pertenece al notificador.');
      throw Exception(detail ?? 'No se pudo actualizar la entrega.');
    } on http.ClientException {
      throw Exception('No se pudo conectar con el servidor. Revise su conexión e intente nuevamente.');
    } on SocketException {
      throw Exception('Sin conexión a la red municipal.');
    } on FormatException {
      throw Exception('Respuesta inválida del servidor.');
    } on TimeoutException {
      throw Exception('No se recibió la confirmación a tiempo. Actualice la cartera para comprobar si se guardó antes de reintentar.');
    }
  }

  static Future<void> finalizarNotificacion({
    required int id,
    required String dni,
    required String fotoBase64,
    String? fotoOpBase64,
    String? fotoRdBase64,
    double? lat,
    double? lng,
    @Deprecated('Ya no se usa: el flujo actual no registra suministro. Se ignora.')
    String numeroSuministro = '',
    bool agrupada = false,
    String? condicion,
    @Deprecated('Ya no se usa: el flujo actual no pide datos de receptor. Se ignora.')
    bool seNegoDni = false,
    @Deprecated('Ya no se usa: el flujo actual no pide datos de receptor. Se ignora.')
    String? dniReceptor,
    @Deprecated('Ya no se usa: el flujo actual no pide datos de receptor. Se ignora.')
    String? nombreReceptor,
    @Deprecated('Ya no se usa: el flujo actual no pide datos de receptor. Se ignora.')
    String? parentesco,
    @Deprecated('Ya no se usa: el flujo actual no pide datos de receptor. Se ignora.')
    String? observaciones,
    String? idempotencia,
    String? fechaCaptura,
  }) async {
    if (_notificadoresApiKey.isEmpty) {
      throw Exception('La aplicación no tiene configurada la clave de acceso.');
    }

    if (condicion != null && condicion != 'Finalizado' &&
        !condicionesEntrega.contains(condicion)) {
      throw Exception('Seleccione una condición válida.');
    }
    if (condicion != null && condicion != 'Finalizado') {
      if (fotoBase64.isEmpty) {
        throw Exception('Debe tomar la fotografía del domicilio fiscal.');
      }
      if ((fotoOpBase64 ?? '').isEmpty && (fotoRdBase64 ?? '').isEmpty) {
        throw Exception('Debe registrar por lo menos el cargo OP o el cargo RD.');
      }
      if (lat == null || lng == null) {
        throw Exception('Debe registrar la ubicación GPS del domicilio.');
      }
    }
    if (condicion == 'Finalizado') {
      if (fotoBase64.isEmpty) {
        throw Exception('Debe tomar la fotografía del domicilio fiscal.');
      }
      if (lat == null || lng == null) {
        throw Exception('Debe registrar la ubicación GPS del domicilio.');
      }
    }

    if (fotoBase64.length + (fotoOpBase64?.length ?? 0) + (fotoRdBase64?.length ?? 0) > 18 * 1024 * 1024) {
      throw Exception('Las fotos son demasiado grandes. Vuelva a tomarlas para reducir su tamaño.');
    }
    final uri = Uri.parse(
      '$_notificadoresBaseUrl/api/notificadores/cartera-op-rd/finalizar/',
    );

    try {
      final res = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': _notificadoresApiKey,
        },
        body: jsonEncode({
          'id': id,
          if (agrupada) 'agrupada': true,
          'condicion': ?condicion,
          'idempotencia': ?idempotencia,
          'fecha_captura': ?fechaCaptura,
          'dni': dni,
          'foto': fotoBase64,
          'foto_op': ?fotoOpBase64,
          'foto_rd': ?fotoRdBase64,
          'lat': lat,
          'lng': lng,
        }),
      ).timeout(const Duration(seconds: 120));
      if (res.statusCode == 413) throw Exception('Las fotos superan el tamaño permitido. Vuelva a tomarlas.');
      final data = decodeApiResponse(res);

      if (res.statusCode == 200 && data['status'] == 'ok') {
        return;
      }

      final detail = data['detail']?.toString();
      if (res.statusCode == 401) {
        throw Exception('La aplicación no está autorizada.');
      }
      if (res.statusCode == 404) {
        throw Exception(detail ?? 'La asignación no pertenece al notificador.');
      }
      throw Exception(detail ?? 'No se pudo finalizar la notificación.');
    } on http.ClientException {
      throw Exception('No se pudo conectar con el servidor. Revise su conexión e intente nuevamente.');
    } on SocketException {
      throw Exception('Sin conexión a la red municipal.');
    } on FormatException {
      throw Exception('Respuesta inválida del servidor.');
    } on TimeoutException {
      throw Exception('No se recibió la confirmación a tiempo. Actualice la cartera para comprobar si se guardó antes de reintentar.');
    }
  }

  static Future<void> cambiarClave({
    required String dni,
    required String claveActual,
    required String claveNueva,
  }) async {
    if (_notificadoresApiKey.isEmpty) {
      throw Exception('La aplicacion no tiene configurada la clave de acceso.');
    }

    final uri = Uri.parse(
      '$_notificadoresBaseUrl/api/notificadores/cambiar-clave/',
    );

    try {
      final res = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': _notificadoresApiKey,
        },
        body: jsonEncode({
          'dni': dni,
          'clave_actual': claveActual,
          'clave_nueva': claveNueva,
        }),
      ).timeout(const Duration(seconds: 30));
      final data = decodeApiResponse(res);

      if (res.statusCode == 200 && data['status'] == 'ok') {
        return;
      }

      final detail = data['detail']?.toString();
      if (res.statusCode == 401) {
        throw Exception(detail ?? 'Clave actual incorrecta.');
      }
      throw Exception(detail ?? 'No se pudo cambiar la clave.');
    } on http.ClientException {
      throw Exception('No se pudo conectar con el servidor. Revise su conexión e intente nuevamente.');
    } on SocketException {
      throw Exception('Sin conexion a la red municipal.');
    } on FormatException {
      throw Exception('Respuesta invalida del servidor.');
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado en responder. Inténtalo de nuevo.');
    }
  }
}

class NeedEmailException implements Exception {
  final String message;
  final Map<String, dynamic> contribuyente;

  NeedEmailException({required this.message, required this.contribuyente});
}

class FiscalizadorSesion {
  final int id;
  final String dni;
  final String nombre;
  final String email;

  const FiscalizadorSesion({
    required this.id,
    required this.dni,
    required this.nombre,
    required this.email,
  });
}
