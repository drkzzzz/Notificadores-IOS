import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cartera_contribuyente.dart';

class UbicacionCartera {
  const UbicacionCartera(this.punto, {this.aproximada = false});
  final LatLng punto;
  final bool aproximada;
}

UbicacionCartera? coordenadaGuardada(String texto) {
  final partes = texto.trim().split(RegExp(r'[,;\s]+'));
  if (partes.length != 2) return null;
  final lat = double.tryParse(partes[0]), lng = double.tryParse(partes[1]);
  if (lat == null || lng == null || !lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180 || (lat == 0 && lng == 0)) return null;
  return UbicacionCartera(LatLng(lat, lng));
}

double distanciaMetros(LatLng desde, LatLng hasta) {
  double rad(double n) => n * math.pi / 180;
  final dlat = rad(hasta.latitude - desde.latitude), dlng = rad(hasta.longitude - desde.longitude);
  final a = math.pow(math.sin(dlat / 2), 2) + math.cos(rad(desde.latitude)) * math.cos(rad(hasta.latitude)) * math.pow(math.sin(dlng / 2), 2);
  return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
}

List<CarteraContribuyente> ordenarPorDistancia(List<CarteraContribuyente> grupos, LatLng desde, Map<String, UbicacionCartera> puntos) {
  final salida = List<CarteraContribuyente>.of(grupos);
  salida.sort((a, b) {
    final pa = puntos[a.codigo], pb = puntos[b.codigo];
    if (pa == null && pb == null) return a.codigo.compareTo(b.codigo);
    if (pa == null) return 1;
    if (pb == null) return -1;
    final comparacion = distanciaMetros(desde, pa.punto).compareTo(distanciaMetros(desde, pb.punto));
    return comparacion == 0 ? a.codigo.compareTo(b.codigo) : comparacion;
  });
  return salida;
}

String distanciaTexto(double metros) => metros < 1000 ? '${metros.round()} m' : '${(metros / 1000).toStringAsFixed(1)} km';

class CarteraUbicaciones {
  static const canal = MethodChannel('sat/ubicaciones');
  final Map<String, UbicacionCartera> _memoria = {};
  SharedPreferences? _prefs;

  Future<LatLng> miUbicacion() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw Exception('Active la ubicación del teléfono.');
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
    if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
      throw Exception('Permita el acceso a su ubicación para ordenar por cercanía o ver el mapa.');
    }
    final posicion = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)));
    return LatLng(posicion.latitude, posicion.longitude);
  }

  Future<UbicacionCartera?> localizar(CarteraContribuyente grupo, {bool buscarDireccion = true}) async {
    final gps = coordenadaGuardada(grupo.principal.coordenadas);
    if (gps != null) return gps;
    final direccion = grupo.principal.direccion.trim();
    if (direccion.isEmpty) return null;
    final key = 'sat_geo_v1_${Uri.encodeComponent('${grupo.codigo}|$direccion')}';
    if (_memoria.containsKey(key)) return _memoria[key];
    _prefs ??= await SharedPreferences.getInstance();
    final guardado = _prefs!.getString(key);
    if (guardado != null) {
      try {
        final j = jsonDecode(guardado) as Map;
        if (DateTime.now().millisecondsSinceEpoch - (j['fecha'] as num) < const Duration(days: 30).inMilliseconds) {
          final p = coordenadaGuardada('${j['lat']},${j['lng']}');
          if (p != null) return _memoria[key] = UbicacionCartera(p.punto, aproximada: true);
        }
      } catch (_) { /* Una caché inválida no bloquea el mapa. */ }
    }
    if (!buscarDireccion) return null;
    final resultado = await canal.invokeMapMethod<String, dynamic>('buscarDireccion', {'direccion': '$direccion, Tarapoto, San Martín, Perú'}).timeout(const Duration(seconds: 15));
    if (resultado == null) return null;
    final punto = coordenadaGuardada('${resultado['lat']},${resultado['lng']}');
    if (punto == null) return null;
    final ubicacion = UbicacionCartera(punto.punto, aproximada: true);
    _memoria[key] = ubicacion;
    await _prefs!.setString(key, jsonEncode({'lat': punto.punto.latitude, 'lng': punto.punto.longitude, 'fecha': DateTime.now().millisecondsSinceEpoch}));
    return ubicacion;
  }
}
