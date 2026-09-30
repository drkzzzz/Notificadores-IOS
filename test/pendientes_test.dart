import 'package:flutter_test/flutter_test.dart';
import 'package:notificadores_satt/services/pendientes_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('estadoPara', () {
    test('vacío es borrador', () {
      expect(estadoPara(), EstadoPendiente.borrador);
    });
    test('parcial es incompleto', () {
      expect(estadoPara(dom: '/a.jpg'), EstadoPendiente.incompleto);
      expect(
          estadoPara(dom: '/a.jpg', op: '/b.jpg'),
          EstadoPendiente.incompleto);
      expect(estadoPara(dom: '/a.jpg', lat: 1, lng: 2),
          EstadoPendiente.incompleto);
    });
    test('completo es listo con OP o con RD', () {
      expect(
          estadoPara(dom: '/a.jpg', op: '/b.jpg', lat: 1, lng: 2),
          EstadoPendiente.listo);
      expect(
          estadoPara(dom: '/a.jpg', rd: '/c.jpg', lat: 1, lng: 2),
          EstadoPendiente.listo);
    });
    test('sin cargo y sin pagado es incompleto', () {
      expect(
          estadoPara(dom: '/a.jpg', lat: 1, lng: 2),
          EstadoPendiente.incompleto);
    });
    test('pagado (Finalizado) exige solo domicilio y GPS', () {
      expect(
          estadoPara(dom: '/a.jpg', lat: 1, lng: 2, pagado: true),
          EstadoPendiente.listo);
      expect(
          estadoPara(dom: '/a.jpg', pagado: true),
          EstadoPendiente.incompleto);
      expect(
          estadoPara(lat: 1, lng: 2, pagado: true),
          EstadoPendiente.incompleto);
    });
  });

  group('Pendiente.completo', () {
    test('pagado no requiere cargos', () {
      final p = Pendiente(
        uuid: 'u',
        carteraItemId: 1,
        pagado: true,
        fotoDomicilio: '/a.jpg',
        lat: -6.48,
        lng: -76.37,
        fechaCaptura: '2026-09-22T08:00:00',
      );
      expect(p.completo, isTrue);
    });
    test('no pagado requiere al menos un cargo', () {
      final p = Pendiente(
        uuid: 'u',
        carteraItemId: 1,
        pagado: false,
        fotoDomicilio: '/a.jpg',
        lat: -6.48,
        lng: -76.37,
        fechaCaptura: '2026-09-22T08:00:00',
      );
      expect(p.completo, isFalse);
      p.fotoOp = '/op.jpg';
      expect(p.completo, isTrue);
    });
  });

  group('SQLite', () {
    setUpAll(() {
      sqfliteFfiInit();
      PendientesService.factoryOverride = databaseFactoryFfi;
      PendientesService.pathOverride = inMemoryDatabasePath;
    });
    tearDown(() => PendientesService.vaciar());
    tearDownAll(() => PendientesService.cerrar());

    Pendiente nuevo(String uuid) => Pendiente(
          uuid: uuid,
          carteraItemId: 11,
          codContribuyente: '00000000001',
          nombre: 'Prueba',
          dniNotificador: '12345678',
          condicion: 'Notificado',
          fechaIdentificador: '2026-09-22',
          fotoDomicilio: '/tmp/a.jpg',
          fotoOp: '/tmp/b.jpg',
          lat: -6.48,
          lng: -76.37,
          fechaCaptura: '2026-09-22T08:00:00',
          estado: EstadoPendiente.listo,
        );

    test('guardar y leer por uuid', () async {
      await PendientesService.guardar(nuevo('u1'));
      final leido = await PendientesService.porUuid('u1');
      expect(leido, isNotNull);
      expect(leido!.condicion, 'Notificado');
      expect(leido.completo, isTrue);
      expect(leido.fotoDomicilio, '/tmp/a.jpg');
      expect(leido.pagado, isFalse);
      expect(leido.esEdicion, isFalse);
    });

    test('persiste pagado y esEdicion', () async {
      final p = nuevo('up')..pagado = true ..esEdicion = true ..condicion = 'Finalizado'
        ..fotoOp = null ..fotoRd = null;
      await PendientesService.guardar(p);
      final leido = await PendientesService.porUuid('up');
      expect(leido!.pagado, isTrue);
      expect(leido.esEdicion, isTrue);
      expect(leido.condicion, 'Finalizado');
      expect(leido.completo, isTrue);
    });

    test('upsert actualiza el mismo uuid', () async {
      await PendientesService.guardar(nuevo('u2'));
      final mod = nuevo('u2')..condicion = 'Inubicado';
      await PendientesService.guardar(mod);
      final leido = await PendientesService.porUuid('u2');
      expect(leido!.condicion, 'Inubicado');
      final todos = await PendientesService.porIdentificador('2026-09-22');
      expect(todos.where((p) => p.uuid == 'u2').length, 1);
    });

    test('pendientesEnvio solo listo/error/enviando', () async {
      await PendientesService.guardar(nuevo('u3'));
      await PendientesService.guardar(
          nuevo('u4')..estado = EstadoPendiente.incompleto);
      final cola = await PendientesService.pendientesEnvio();
      expect(cola.any((p) => p.uuid == 'u3'), isTrue);
      expect(cola.any((p) => p.uuid == 'u4'), isFalse);
    });

    test('porCarteraItem devuelve el más reciente', () async {
      await PendientesService.guardar(nuevo('u5'));
      final p = await PendientesService.porCarteraItem(11);
      expect(p, isNotNull);
    });
  });
}