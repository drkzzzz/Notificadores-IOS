import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notificadores_satt/services/api_service.dart';

http.Response reply(Object body, int code) => http.Response.bytes(
  utf8.encode(jsonEncode(body)), code, headers: {'content-type':'application/json; charset=utf-8'});
Future<T> mocked<T>(Future<T> Function() action, http.Response response) =>
  http.runWithClient(action, () => MockClient((request) async => response));
void main() {
  final calls = <String, Future<Object?> Function()>{
    'login': () => ApiService.login('12345678', 'test'),
    'identificadores': ApiService.obtenerIdentificadores,
    'cartera': () => ApiService.obtenerCarteraAsignada('2026-09-16', '12345678'),
    'tareas': () => ApiService.obtenerTareasAsignadas('12345678'),
    'deuda': () => ApiService.consultarResumenNotificadores('1'),
    'clave': () async {await ApiService.cambiarClave(dni:'12345678', claveActual:'test', claveNueva:'newtest'); return null;},
    'finalizar': () async {await ApiService.finalizarNotificacion(id:1,dni:'12345678',fotoBase64:'test',lat:0,lng:0); return null;},
  };
  for (final entry in calls.entries) {
    test('${entry.key}: página HTML muestra error claro', () async {
      await expectLater(mocked(entry.value, http.Response('<html>Not Found</html>',404)),
        throwsA(predicate((e) => e.toString().contains('HTTP 404'))));
    });
    test('${entry.key}: rechaza JSON de formato incorrecto', () async {
      await expectLater(mocked(entry.value, reply([],200)),
        throwsA(predicate((e) => e.toString().contains('formato inesperado'))));
    });
    test('${entry.key}: informa autorización rechazada', () async {
      await expectLater(mocked(entry.value, reply({'detail':'No autorizado.'},401)), throwsException);
    });
  }
  test('login válido valida sesión y URL correcta', () async {
    final result = await http.runWithClient(() => ApiService.login('12345678','test'), () => MockClient((r) async {
      expect(r.url.host,'190.119.38.13'); expect(r.url.path,'/api/notificadores/login/');
      expect(r.method,'POST'); expect(r.headers['X-API-Key'],isNotEmpty);
      expect(jsonDecode(r.body),{'dni':'12345678','clave':'test'});
      return reply({'status':'ok','fiscalizador':{'id':1,'dni':'12345678','nombre':'Prueba'}},200);
    }));
    expect(result.id,1);
  });
  for (final body in [{}, {'status':'ok'}, {'status':'ok','fiscalizador':{'id':0,'dni':'12345678'}}, {'status':'ok','fiscalizador':{'id':1,'dni':'87654321'}}]) {
    test('login no acepta sesión inválida $body', () async {
      await expectLater(mocked(() => ApiService.login('12345678','test'),reply(body,200)), throwsException);
    });
  }
  test('identificadores, cartera y tareas válidos', () async {
    expect(await mocked(ApiService.obtenerIdentificadores,reply({'status':'ok','data':[]},200)),isEmpty);
    final rows=await mocked(() => ApiService.obtenerCarteraAsignada('2026-09-16','12345678'),reply({'status':'ok','data':[{'id':1,'direccion_adicional':'Referencia','estado':'E'}]},200));
    expect(rows.single.direccionAdicional,'Referencia');expect(rows.single.entregado,isTrue);
    expect(await mocked(() => ApiService.obtenerTareasAsignadas('12345678'),reply({'status':'ok','count':8},200)),8);
  });
  test('cambio de clave y entrega procesan confirmación', () async {
    await mocked(calls['clave']!,reply({'status':'ok'},200));
    await mocked(calls['finalizar']!,reply({'status':'ok'},200));
  });
  test('errores de conexión se convierten en mensaje legible', () async {
    await expectLater(http.runWithClient(() => ApiService.login('12345678','test'),
      () => MockClient((r) async => throw http.ClientException('connection refused'))),
      throwsA(predicate((e) => e.toString().contains('No se pudo conectar'))));
  });
}