import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notificadores_satt/models/models.dart';
import 'package:notificadores_satt/screens/llamadas_screen.dart';

Map<String, dynamic> doc(int id, String tipo,
        {String codigo = '00000000001', Map<String, dynamic>? llamada}) =>
    {
      'id': id,
      'cod_contribuyente': codigo,
      'nombre': 'Persona de prueba',
      'tipo': tipo,
      'correlativo': '${tipo}123',
      'direccion': 'Dirección fiscal',
      'direccion_adicional': 'Referencia adicional',
      'telefonos': ['999888777'],
      'saldo_actual': 0,
      'estado_consultado': '2026-09-17 10:00:00',
      'coordenadas': '',
      'condicion_entrega': '',
      'fec_asignacion': '2026-09-16 08:00:00',
      'estado': 'A',
      'dias': 1,
      'pagada': false,
      'estado_pago': 'PENDIENTE',
      'cuotas_pendientes': 0,
      'cuotas_total': 0,
      'llamada': llamada,
    };

http.Response response(Map<String, dynamic> body) => http.Response.bytes(
    utf8.encode(jsonEncode(body)), 200,
    headers: {'content-type': 'application/json'});

/// Cliente que registra las peticiones y responde identificadores,
/// cartera y el POST de llamadas.
MockClient client(List<Map<String, dynamic>> rows, List<http.Request> requests) =>
    MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/identificadores/')) {
        return response({
          'status': 'ok',
          'data': [
            {'fecha': '2026-09-16', 'op_total': 1, 'rd_total': 1, 'identificador': 20260916}
          ]
        });
      }
      if (request.url.path.endsWith('/llamadas/finalizar/')) {
        return response({'status': 'ok', 'message': 'Llamada registrada correctamente.'});
      }
      return response({'status': 'ok', 'data': rows});
    });

Future<void> load(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: LlamadasScreen()));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<IdentificadorOpRd>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('2026-09-16 — OP: 1 | RD: 1').last);
  await tester.pumpAndSettle();
}

void main() {
  test('LlamadaDraft y resumen de LlamadaInfo', () {
    final info = LlamadaInfo.fromJson({
      'resultado': 'Atendida',
      'compromiso': 'Vendra a pagar',
      'fecha_compromiso': '2026-10-05',
      'observaciones': 'Confirmó visita',
      'fec_registro': '2026-09-20 10:00:00',
    });
    expect(info.resumen, contains('Atendida'));
    expect(info.resumen, contains('Vendra a pagar'));
    expect(info.resumen, contains('05/10/2026'));
    final sin = LlamadaInfo.fromJson({});
    expect(sin.resumen, isEmpty);
  });

  testWidgets('carga identificador, grilla con llamada previa y botones de contacto',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'operador_dni': '12345678'});
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await load(tester);
      expect(find.text('Persona de prueba'), findsOneWidget);
      expect(find.text('OP123'), findsOneWidget);
      expect(find.text('RD123'), findsOneWidget);
      // La llamada previa cambia el botón a Editar y no hay columna
      // OBSERVACIONES en la grilla.
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('OBSERVACIONES'), findsNothing);
      // Columnas de contacto: llamar y WhatsApp.
      expect(find.byIcon(Icons.call), findsWidgets);
      expect(find.byType(FaIcon), findsOneWidget);
      // La cartera se pidió con incluir_llamadas=1.
      final carteraReq = requests.firstWhere(
          (r) => r.url.path.contains('/cartera/'));
      expect(carteraReq.url.queryParameters['incluir_llamadas'], '1');
      expect(tester.takeException(), isNull);
    }, () => client([
      doc(1, 'OP', llamada: {
        'resultado': 'Atendida',
        'compromiso': 'Vendra a pagar',
        'fecha_compromiso': '2026-10-05',
        'observaciones': 'Confirmó visita',
        'fec_registro': '2026-09-20 10:00:00',
      }),
      doc(2, 'RD', llamada: {
        'resultado': 'Atendida',
        'compromiso': 'Vendra a pagar',
        'fecha_compromiso': '2026-10-05',
        'observaciones': 'Confirmó visita',
        'fec_registro': '2026-09-20 10:00:00',
      }),
    ], requests));
  });

  testWidgets('código subrayado consulta la deuda y vuelve a la grilla',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'operador_dni': '12345678'});
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await load(tester);
      await tester.tap(find.text('00000000001'));
      await tester.pumpAndSettle();
      expect(find.text('Consultar deuda'), findsOneWidget);
      expect(
          find.text('¿Desea ver la información de deudas de Persona de prueba?'),
          findsOneWidget);
      await tester.tap(find.text('NO'));
      await tester.pumpAndSettle();
      expect(find.text('Consultar deuda'), findsNothing);
      expect(find.text('Persona de prueba'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client([doc(1, 'OP'), doc(2, 'RD')], requests));
  });

  testWidgets('finalizar llamada No contestada registra en el API', (tester) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'operador_dni': '12345678'});
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await load(tester);
      await tester.tap(find.text('Finalizar'));
      await tester.pumpAndSettle();
      expect(find.text('Resultado de la llamada'), findsOneWidget);
      expect(find.text('¿EN QUÉ SITUACIÓN QUEDÓ LA LLAMADA?'), findsOneWidget);
      await tester.tap(find.text('No contestada'));
      await tester.pumpAndSettle();
      expect(find.text('¿QUÉ DIJO EL CONTRIBUYENTE?'), findsNothing);
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();
      final post = requests.firstWhere(
          (r) => r.url.path.endsWith('/llamadas/finalizar/'));
      final body = jsonDecode(post.body) as Map<String, dynamic>;
      expect(body['resultado'], 'No contestada');
      expect(body['compromiso'], '');
      expect(body['fecha_compromiso'], '');
      expect(body['idempotencia'], isNotEmpty);
      expect(body['id'], isNotNull);
      expect(find.text('Llamada registrada correctamente.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client([doc(1, 'OP'), doc(2, 'RD')], requests));
  });

  testWidgets('el diálogo tiene micrófono de dictado y se puede cancelar',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'operador_dni': '12345678'});
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await load(tester);
      await tester.tap(find.text('Finalizar'));
      await tester.pumpAndSettle();
      expect(find.text('OBSERVACIONES (opcional)'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byTooltip('Dictar por voz'), findsOneWidget);
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();
      expect(find.text('Resultado de la llamada'), findsNothing);
      expect(find.text('Persona de prueba'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client([doc(1, 'OP'), doc(2, 'RD')], requests));
  });

  testWidgets('Atendida + Vendrá a pagar exige fecha antes de guardar', (tester) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'operador_dni': '12345678'});
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await load(tester);
      await tester.tap(find.text('Finalizar'));
      await tester.pumpAndSettle();
      // Por defecto: Atendida + Vendra a pagar, sin fecha elegida.
      expect(find.text('Tocar para elegir fecha'), findsOneWidget);
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();
      expect(find.text('Seleccione la fecha en que vendrá a pagar.'), findsOneWidget);
      expect(requests.any((r) => r.url.path.endsWith('/llamadas/finalizar/')),
          isFalse);
      // Elige la fecha de hoy y guarda.
      await tester.tap(find.text('Tocar para elegir fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();
      final post = requests.firstWhere(
          (r) => r.url.path.endsWith('/llamadas/finalizar/'));
      final body = jsonDecode(post.body) as Map<String, dynamic>;
      expect(body['resultado'], 'Atendida');
      expect(body['compromiso'], 'Vendra a pagar');
      expect(body['fecha_compromiso'], isNotEmpty);
      expect(tester.takeException(), isNull);
    }, () => client([doc(1, 'OP'), doc(2, 'RD')], requests));
  });
}