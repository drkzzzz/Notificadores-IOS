import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Estados de la bandeja de salida offline.
class EstadoPendiente {
  static const borrador = 'borrador';
  static const incompleto = 'incompleto';
  static const listo = 'listo';
  static const enviando = 'enviando';
  static const error = 'error';
}

/// Entrega guardada en el equipo pendiente de envío al servidor.
///
/// Las fotos viven como archivos en el directorio privado de la app
/// (la cámara las deja en temporales que Android puede borrar); aquí solo
/// se guardan sus rutas.
class Pendiente {
  Pendiente({
    this.localId,
    required this.uuid,
    required this.carteraItemId,
    this.codContribuyente = '',
    this.nombre = '',
    this.direccion = '',
    this.dniNotificador = '',
    this.condicion = 'Notificado',
    this.fechaIdentificador = '',
    this.fotoDomicilio,
    this.fotoOp,
    this.fotoRd,
    this.lat,
    this.lng,
    required this.fechaCaptura,
    this.estado = EstadoPendiente.borrador,
    this.ultimoError = '',
    this.intentos = 0,
    this.pagado = false,
    this.esEdicion = false,
  });

  int? localId;
  String uuid;
  int carteraItemId;
  String codContribuyente;
  String nombre;
  String direccion;
  String dniNotificador;
  String condicion;
  String fechaIdentificador;
  String? fotoDomicilio;
  String? fotoOp;
  String? fotoRd;
  double? lat;
  double? lng;
  String fechaCaptura;
  String estado;
  String ultimoError;
  int intentos;

  /// Registro ya pagado: solo domicilio + GPS, sin cargos OP/RD.
  bool pagado;

  /// Modo edición: al subir se llama a actualizar_entrega en vez de finalizar.
  bool esEdicion;

  bool get tieneDomicilio => (fotoDomicilio ?? '').isNotEmpty;
  bool get tieneUnCargo =>
      (fotoOp ?? '').isNotEmpty || (fotoRd ?? '').isNotEmpty;
  bool get tieneGps => lat != null && lng != null;

  /// Un registro pagado (Finalizado) solo exige domicilio + GPS; el resto
  /// exige además por lo menos un cargo OP/RD.
  bool get completo =>
      tieneDomicilio && tieneGps && (pagado || tieneUnCargo);

  Map<String, Object?> toMap() => {
        'local_id': localId,
        'uuid': uuid,
        'cartera_item_id': carteraItemId,
        'cod_contribuyente': codContribuyente,
        'nombre': nombre,
        'direccion': direccion,
        'dni_notificador': dniNotificador,
        'condicion': condicion,
        'fecha_identificador': fechaIdentificador,
        'foto_domicilio': fotoDomicilio,
        'foto_op': fotoOp,
        'foto_rd': fotoRd,
        'lat': lat,
        'lng': lng,
        'fecha_captura': fechaCaptura,
        'estado': estado,
        'ultimo_error': ultimoError,
        'intentos': intentos,
        'pagado': pagado ? 1 : 0,
        'es_edicion': esEdicion ? 1 : 0,
        'actualizado': DateTime.now().millisecondsSinceEpoch,
      };

  static Pendiente fromMap(Map<String, Object?> m) => Pendiente(
        localId: (m['local_id'] as num?)?.toInt(),
        uuid: m['uuid'].toString(),
        carteraItemId: (m['cartera_item_id'] as num?)?.toInt() ?? 0,
        codContribuyente: m['cod_contribuyente']?.toString() ?? '',
        nombre: m['nombre']?.toString() ?? '',
        direccion: m['direccion']?.toString() ?? '',
        dniNotificador: m['dni_notificador']?.toString() ?? '',
        condicion: m['condicion']?.toString() ?? 'Notificado',
        fechaIdentificador: m['fecha_identificador']?.toString() ?? '',
        fotoDomicilio: m['foto_domicilio']?.toString(),
        fotoOp: m['foto_op']?.toString(),
        fotoRd: m['foto_rd']?.toString(),
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        fechaCaptura: m['fecha_captura']?.toString() ?? '',
        estado: m['estado']?.toString() ?? EstadoPendiente.borrador,
        ultimoError: m['ultimo_error']?.toString() ?? '',
        intentos: (m['intentos'] as num?)?.toInt() ?? 0,
        pagado: (m['pagado'] as num?)?.toInt() == 1,
        esEdicion: (m['es_edicion'] as num?)?.toInt() == 1,
      );
}

/// Calcula el estado según lo capturado (función pura, testeable).
/// Si [pagado] es true (registro ya pagado) no se exigen cargos OP/RD.
String estadoPara(
    {String? dom, String? op, String? rd, double? lat, double? lng, bool pagado = false}) {
  final hayDom = (dom ?? '').isNotEmpty;
  final hayCargo = (op ?? '').isNotEmpty || (rd ?? '').isNotEmpty;
  final hayGps = lat != null && lng != null;
  if (!hayDom && !hayCargo && !hayGps) return EstadoPendiente.borrador;
  if (hayDom && hayGps && (pagado || hayCargo)) return EstadoPendiente.listo;
  return EstadoPendiente.incompleto;
}

class PendientesService {
  static Database? _db;
  static DatabaseFactory? factoryOverride;
  static String? pathOverride;

  static Future<Database> _dbAbierta() async {
    if (_db != null) return _db!;
    final factory = factoryOverride ?? databaseFactory;
    final ruta = pathOverride ??
        p.join(await getDatabasesPath(), 'pendientes.db');
    _db = await factory.openDatabase(ruta, options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE pendientes(
          local_id INTEGER PRIMARY KEY AUTOINCREMENT,
          uuid TEXT UNIQUE NOT NULL,
          cartera_item_id INTEGER NOT NULL DEFAULT 0,
          cod_contribuyente TEXT NOT NULL DEFAULT '',
          nombre TEXT NOT NULL DEFAULT '',
          direccion TEXT NOT NULL DEFAULT '',
          dni_notificador TEXT NOT NULL DEFAULT '',
          condicion TEXT NOT NULL DEFAULT 'Notificado',
          fecha_identificador TEXT NOT NULL DEFAULT '',
          foto_domicilio TEXT, foto_op TEXT, foto_rd TEXT,
          lat REAL, lng REAL,
          fecha_captura TEXT NOT NULL DEFAULT '',
          estado TEXT NOT NULL DEFAULT 'borrador',
          ultimo_error TEXT NOT NULL DEFAULT '',
          intentos INTEGER NOT NULL DEFAULT 0,
          pagado INTEGER NOT NULL DEFAULT 0,
          es_edicion INTEGER NOT NULL DEFAULT 0,
          actualizado INTEGER NOT NULL DEFAULT 0)''');
        await db.execute(
            'CREATE INDEX idx_pendientes_item ON pendientes(cartera_item_id)');
      },
    ));
    return _db!;
  }

  /// Solo soporte/tests: vacía la tabla.
  static Future<void> vaciar() async {
    final db = await _dbAbierta();
    await db.delete('pendientes');
  }

  /// Solo tests: reinicia la conexión.
  static Future<void> cerrar() async {
    await _db?.close();
    _db = null;
  }

  static Future<int> guardar(Pendiente pendiente) async {
    final db = await _dbAbierta();
    final existente = await db.query('pendientes',
        columns: ['local_id'], where: 'uuid = ?', whereArgs: [pendiente.uuid]);
    if (existente.isEmpty) {
      return db.insert('pendientes', pendiente.toMap());
    }
    final mapa = pendiente.toMap()..remove('local_id');
    await db.update('pendientes', mapa,
        where: 'uuid = ?', whereArgs: [pendiente.uuid]);
    return (existente.first['local_id'] as num).toInt();
  }

  static Future<Pendiente?> porUuid(String uuid) async {
    final db = await _dbAbierta();
    final filas = await db
        .query('pendientes', where: 'uuid = ?', whereArgs: [uuid], limit: 1);
    if (filas.isEmpty) return null;
    return Pendiente.fromMap(filas.first);
  }

  /// Último pendiente de un item de cartera (para continuar o reintentar).
  static Future<Pendiente?> porCarteraItem(int itemId) async {
    final db = await _dbAbierta();
    final filas = await db.query('pendientes',
        where: 'cartera_item_id = ?',
        whereArgs: [itemId],
        orderBy: 'actualizado DESC',
        limit: 1);
    if (filas.isEmpty) return null;
    return Pendiente.fromMap(filas.first);
  }

  static Future<List<Pendiente>> pendientesEnvio() async {
    final db = await _dbAbierta();
    final filas = await db.query('pendientes',
        where: 'estado IN (?, ?, ?)',
        whereArgs: [
          EstadoPendiente.listo,
          EstadoPendiente.error,
          EstadoPendiente.enviando
        ],
        orderBy: 'actualizado ASC');
    return filas.map(Pendiente.fromMap).toList();
  }

  static Future<List<Pendiente>> porIdentificador(String fecha) async {
    final db = await _dbAbierta();
    final filas = await db.query('pendientes',
        where: 'fecha_identificador = ?', whereArgs: [fecha]);
    return filas.map(Pendiente.fromMap).toList();
  }

  static Future<void> marcar(Pendiente pendiente) async {
    final db = await _dbAbierta();
    final mapa = pendiente.toMap()..remove('local_id');
    await db.update('pendientes', mapa,
        where: 'uuid = ?', whereArgs: [pendiente.uuid]);
  }

  /// Elimina el registro y sus fotos del equipo.
  static Future<void> eliminar(Pendiente pendiente) async {
    final db = await _dbAbierta();
    await db
        .delete('pendientes', where: 'uuid = ?', whereArgs: [pendiente.uuid]);
    for (final ruta in [
      pendiente.fotoDomicilio,
      pendiente.fotoOp,
      pendiente.fotoRd
    ]) {
      if ((ruta ?? '').isEmpty) continue;
      try {
        final f = File(ruta!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// Copia bytes al almacén permanente de pendientes. Retorna la ruta.
  static Future<String> guardarFoto(
      List<int> bytes, String uuid, String tipo) async {
    final dir = await _dirPendientes();
    final ruta = p.join(dir.path, '${uuid}_$tipo.jpg');
    await File(ruta).writeAsBytes(bytes, flush: true);
    return ruta;
  }

  static Future<Directory> _dirPendientes() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'pendientes'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}