import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'api_service.dart';
import 'pendientes_service.dart';

/// Resultado de un intento de sincronización.
class ResumenSync {
  ResumenSync(this.subidos, this.fallidos);
  final int subidos;
  final int fallidos;
}

/// Sube los pendientes de la bandeja offline.
///
/// Seguro ante timeouts: cada pendiente lleva su UUID como clave de
/// idempotencia y el servidor no duplica entregas ya registradas.
class UploadService {
  /// Permite forzar conexión en tests.
  static Future<bool> Function()? conexionOverride;

  static Future<bool> hayConexion() async {
    if (conexionOverride != null) return conexionOverride!();
    try {
      final estado = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 8));
      return !estado.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Escucha cambios de red; retorna la suscripción para cancelarla.
  static StreamSubscription<List<ConnectivityResult>> escucharCambios(
      Future<void> Function() alRecuperar) {
    return Connectivity().onConnectivityChanged.listen((evento) {
      if (!evento.contains(ConnectivityResult.none)) {
        alRecuperar();
      }
    });
  }

  /// Intenta subir un pendiente. True si quedó registrado en el servidor.
  /// Un pendiente en modo edición ([Pendiente.esEdicion]) se envía al
  /// endpoint de modificación; el resto al de finalización.
  static Future<bool> intentar(Pendiente pendiente) async {
    if (!await hayConexion()) {
      pendiente.estado = EstadoPendiente.listo;
      pendiente.ultimoError = 'Sin conexión a internet.';
      await PendientesService.marcar(pendiente);
      return false;
    }
    pendiente.estado = EstadoPendiente.enviando;
    pendiente.intentos += 1;
    await PendientesService.marcar(pendiente);
    try {
      final dom = await File(pendiente.fotoDomicilio!).readAsBytes();
      final op = pendiente.fotoOp == null || pendiente.fotoOp!.isEmpty
          ? null
          : base64Encode(await File(pendiente.fotoOp!).readAsBytes());
      final rd = pendiente.fotoRd == null || pendiente.fotoRd!.isEmpty
          ? null
          : base64Encode(await File(pendiente.fotoRd!).readAsBytes());
      if (pendiente.esEdicion) {
        await ApiService.actualizarEntrega(
          id: pendiente.carteraItemId,
          dni: pendiente.dniNotificador,
          fotoBase64: base64Encode(dom),
          fotoOpBase64: op,
          fotoRdBase64: rd,
          lat: pendiente.lat,
          lng: pendiente.lng,
          condicion: pendiente.condicion,
          idempotencia: pendiente.uuid,
          fechaCaptura: pendiente.fechaCaptura,
        );
      } else {
        await ApiService.finalizarNotificacion(
          id: pendiente.carteraItemId,
          dni: pendiente.dniNotificador,
          fotoBase64: base64Encode(dom),
          fotoOpBase64: op,
          fotoRdBase64: rd,
          lat: pendiente.lat,
          lng: pendiente.lng,
          agrupada: true,
          condicion: pendiente.condicion,
          idempotencia: pendiente.uuid,
          fechaCaptura: pendiente.fechaCaptura,
        );
      }
      await PendientesService.eliminar(pendiente);
      return true;
    } catch (e) {
      pendiente.estado = EstadoPendiente.error;
      pendiente.ultimoError =
          e.toString().replaceFirst('Exception: ', '');
      await PendientesService.marcar(pendiente);
      return false;
    }
  }

  /// Sube todo lo pendiente (listo o con error anterior).
  static Future<ResumenSync> sincronizar() async {
    if (!await hayConexion()) return ResumenSync(0, 0);
    final cola = await PendientesService.pendientesEnvio();
    var subidos = 0, fallidos = 0;
    for (final pendiente in cola) {
      if (await intentar(pendiente)) {
        subidos++;
      } else {
        fallidos++;
      }
    }
    return ResumenSync(subidos, fallidos);
  }
}