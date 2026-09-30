import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notificadores_satt/models/models.dart';
import 'package:notificadores_satt/screens/finalizar_notificacion_screen.dart';
import 'package:notificadores_satt/services/api_service.dart';

CarteraItem item() => CarteraItem.fromJson({'id': 1});

Future<void> pumpScreen(WidgetTester tester,
    {bool pagado = false, bool esEdicion = false}) async {
  await tester.pumpWidget(MaterialApp(
      home: FinalizarNotificacionScreen(
          item: item(), dni: '12345678', pagado: pagado, esEdicion: esEdicion)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('solo condición: sin suministro, DNI, nombre, parentesco ni observaciones',
      (tester) async {
    await pumpScreen(tester);
    expect(find.text('Notificado'), findsOneWidget);
    expect(find.text('Inubicado'), findsOneWidget);
    expect(find.text('Recepcionado'), findsNothing);
    expect(find.text('Número de suministro'), findsNothing);
    expect(find.text('DNI del receptor'), findsNothing);
    expect(find.text('Nombre de quien recibe'), findsNothing);
    expect(find.text('Relación o parentesco con el contribuyente'),
        findsNothing);
    expect(find.text('Observaciones'), findsNothing);
    // Pasos de foto y GPS siempre visibles en ambas condiciones.
    expect(find.textContaining('Cargo OP'), findsOneWidget);
    expect(find.textContaining('Cargo RD'), findsOneWidget);
    expect(find.textContaining('domicilio fiscal'), findsWidgets);
    await tester.tap(find.text('Inubicado'));
    await tester.pumpAndSettle();
    expect(find.text('DNI del receptor'), findsNothing);
    expect(find.textContaining('Cargo OP'), findsOneWidget);
  });

  testWidgets('registro pagado: solo foto domicilio y GPS, sin cargos ni condición',
      (tester) async {
    await pumpScreen(tester, pagado: true);
    expect(find.text('Notificado'), findsNothing);
    expect(find.text('Inubicado'), findsNothing);
    expect(find.text('Número de suministro'), findsNothing);
    expect(find.text('DNI del receptor'), findsNothing);
    expect(find.textContaining('Cargo OP'), findsNothing);
    expect(find.textContaining('Cargo RD'), findsNothing);
    expect(find.text('FINALIZAR'), findsOneWidget);
    // Sin foto domicilio avisa.
    await tester.ensureVisible(find.text('FINALIZAR'));
    await tester.tap(find.text('FINALIZAR'));
    await tester.pumpAndSettle();
    expect(find.text('Toma la fotografía del domicilio fiscal.'),
        findsWidgets);
  });

  testWidgets('edición: botón guardar modificación', (tester) async {
    await pumpScreen(tester, esEdicion: true);
    expect(find.byType(FinalizarNotificacionScreen), findsOneWidget);
    await tester.ensureVisible(find.text('GUARDAR MODIFICACIÓN'));
    expect(find.text('GUARDAR MODIFICACIÓN'), findsOneWidget);
  });

  testWidgets('guardar sin domicilio avisa foto obligatoria', (tester) async {
    await pumpScreen(tester);
    await tester.ensureVisible(find.text('GUARDAR ENTREGA'));
    await tester.tap(find.text('GUARDAR ENTREGA'));
    await tester.pumpAndSettle();
    expect(find.text('Tome la fotografía del domicilio fiscal.'),
        findsWidgets);
  });

  testWidgets('salir limpio no pregunta', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => ElevatedButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FinalizarNotificacionScreen(
                            item: item(), dni: '12345678'))),
                child: const Text('ir')))));
    await tester.tap(find.text('ir'));
    await tester.pumpAndSettle();
    expect(find.byType(FinalizarNotificacionScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(FinalizarNotificacionScreen), findsNothing);
  });

  test('finalizar envía payload v1.2 sin suministro ni datos de receptor', () async {
    await http.runWithClient(() async {
      await ApiService.finalizarNotificacion(
        id: 1,
        dni: '12345678',
        fotoBase64: 'a',
        fotoOpBase64: 'b',
        lat: -6.48,
        lng: -76.37,
        agrupada: true,
        condicion: 'Notificado',
      );
    }, () => MockClient((req) async {
          final data = jsonDecode(req.body) as Map;
          expect(data.containsKey('numero_suministro'), isFalse);
          expect(data.containsKey('se_nego_dni'), isFalse);
          expect(data.containsKey('fecha_entrega'), isFalse);
          expect(data['agrupada'], true);
          expect(data['condicion'], 'Notificado');
          expect(data['foto'], 'a');
          expect(data['foto_op'], 'b');
          expect(data.containsKey('foto_rd'), isFalse);
          expect(data['lat'], -6.48);
          expect(data['lng'], -76.37);
          return http.Response('{"status":"ok"}', 200);
        }));
  });

  test('finalizar exige domicilio y un cargo mínimo', () async {
    // Solo domicilio, sin cargos.
    await expectLater(
        ApiService.finalizarNotificacion(
          id: 1,
          dni: '12345678',
          fotoBase64: 'a',
          lat: -6.48,
          lng: -76.37,
          condicion: 'Notificado',
        ),
        throwsA(predicate(
            (e) => e.toString().contains('por lo menos el cargo'))));
    // Cargos sin domicilio.
    await expectLater(
        ApiService.finalizarNotificacion(
          id: 1,
          dni: '12345678',
          fotoBase64: '',
          fotoOpBase64: 'b',
          lat: -6.48,
          lng: -76.37,
          condicion: 'Inubicado',
        ),
        throwsA(predicate(
            (e) => e.toString().contains('domicilio fiscal'))));
    // Sin GPS.
    await expectLater(
        ApiService.finalizarNotificacion(
          id: 1,
          dni: '12345678',
          fotoBase64: 'a',
          fotoRdBase64: 'c',
          condicion: 'Inubicado',
        ),
        throwsA(predicate((e) => e.toString().contains('GPS'))));
  });

  test('finalizar admite Finalizado (registro pagado) sin cargos', () async {
    await http.runWithClient(() async {
      await ApiService.finalizarNotificacion(
        id: 1,
        dni: '12345678',
        fotoBase64: 'a',
        lat: -6.48,
        lng: -76.37,
        condicion: 'Finalizado',
        idempotencia: 'uuid-finalizado',
        fechaCaptura: '2026-09-22T08:00:00',
      );
    }, () => MockClient((req) async {
          final data = jsonDecode(req.body) as Map;
          expect(data['condicion'], 'Finalizado');
          expect(data.containsKey('foto_op'), isFalse);
          expect(data.containsKey('foto_rd'), isFalse);
          expect(data.containsKey('numero_suministro'), isFalse);
          expect(data['idempotencia'], 'uuid-finalizado');
          return http.Response('{"status":"ok"}', 200);
        }));
  });

  test('finalizar incluye idempotencia y fecha de captura', () async {
    await http.runWithClient(() async {
      await ApiService.finalizarNotificacion(
        id: 1,
        dni: '12345678',
        fotoBase64: 'a',
        fotoOpBase64: 'b',
        lat: -6.48,
        lng: -76.37,
        condicion: 'Notificado',
        idempotencia: 'uuid-1234',
        fechaCaptura: '2026-09-22T08:00:00',
      );
    }, () => MockClient((req) async {
          final data = jsonDecode(req.body) as Map;
          expect(data['idempotencia'], 'uuid-1234');
          expect(data['fecha_captura'], '2026-09-22T08:00:00');
          return http.Response('{"status":"ok"}', 200);
        }));
  });

  test('actualizar llama al endpoint de modificación', () async {
    await http.runWithClient(() async {
      await ApiService.actualizarEntrega(
        id: 11,
        dni: '12345678',
        fotoBase64: 'a',
        fotoRdBase64: 'c',
        lat: -6.48,
        lng: -76.37,
        condicion: 'Inubicado',
        idempotencia: 'uuid-edit-1',
        fechaCaptura: '2026-09-22T08:00:00',
      );
    }, () => MockClient((req) async {
          expect(req.url.path,
              '/api/notificadores/cartera-op-rd/actualizar/');
          final data = jsonDecode(req.body) as Map;
          expect(data['id'], 11);
          expect(data['condicion'], 'Inubicado');
          expect(data['idempotencia'], 'uuid-edit-1');
          return http.Response('{"status":"ok"}', 200);
        }));
  });

  test('actualizar admite Finalizado (registro pagado) sin cargos', () async {
    await http.runWithClient(() async {
      await ApiService.actualizarEntrega(
        id: 11,
        dni: '12345678',
        fotoBase64: 'a',
        lat: -6.48,
        lng: -76.37,
        condicion: 'Finalizado',
        idempotencia: 'uuid-edit-final',
        fechaCaptura: '2026-09-22T08:00:00',
      );
    }, () => MockClient((req) async {
          final data = jsonDecode(req.body) as Map;
          expect(data['condicion'], 'Finalizado');
          expect(data.containsKey('foto_op'), isFalse);
          expect(data.containsKey('foto_rd'), isFalse);
          expect(data['idempotencia'], 'uuid-edit-final');
          return http.Response('{"status":"ok"}', 200);
        }));
  });

  test('actualizar: Finalizado exige foto y GPS; otros exigen cargo', () async {
    // Finalizado sin foto.
    await expectLater(
        ApiService.actualizarEntrega(
          id: 11,
          dni: '12345678',
          fotoBase64: '',
          lat: -6.48,
          lng: -76.37,
          condicion: 'Finalizado',
        ),
        throwsA(predicate(
            (e) => e.toString().contains('domicilio fiscal'))));
    // Finalizado sin GPS.
    await expectLater(
        ApiService.actualizarEntrega(
          id: 11,
          dni: '12345678',
          fotoBase64: 'a',
          condicion: 'Finalizado',
        ),
        throwsA(predicate((e) => e.toString().contains('GPS'))));
    // Notificado/Inubicado sin cargo.
    await expectLater(
        ApiService.actualizarEntrega(
          id: 11,
          dni: '12345678',
          fotoBase64: 'a',
          lat: -6.48,
          lng: -76.37,
          condicion: 'Notificado',
        ),
        throwsA(predicate(
            (e) => e.toString().contains('por lo menos el cargo'))));
    // Condición inválida.
    await expectLater(
        ApiService.actualizarEntrega(
          id: 11,
          dni: '12345678',
          fotoBase64: 'a',
          lat: -6.48,
          lng: -76.37,
          condicion: 'Negativa',
        ),
        throwsA(predicate((e) => e.toString().contains('condición válida'))));
  });
}