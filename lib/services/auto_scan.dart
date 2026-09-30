import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Auto-recorte de documentos 100% offline (sin Play Services).
///
/// Detecta la hoja de papel sobre el fondo, endereza la perspectiva aunque la
/// foto se haya tomado de costado, elimina los contornos oscuros y centra el
/// documento. Retorna `null` si no encuentra un documento claro (en ese caso
/// se conserva la foto original).
///
/// Uso en UI (no bloquea): `await compute(recorteAutomaticoSync, bytes)`.
/// Uso en tests: llamar directo a [recorteAutomaticoSync].
Uint8List? recorteAutomaticoSync(Uint8List bytes) {
  try {
    final original = img.decodeImage(bytes);
    if (original == null || original.width < 100 || original.height < 100) {
      return null;
    }
    // Copia de trabajo pequeña para detectar (rápido).
    const maxLado = 800;
    final escalaTrabajo =
        math.min(1.0, maxLado / math.max(original.width, original.height));
    final trabajo = escalaTrabajo < 1
        ? img.copyResize(original,
            width: (original.width * escalaTrabajo).round(),
            height: (original.height * escalaTrabajo).round())
        : original.clone();
    final gris = img.gaussianBlur(img.grayscale(trabajo), radius: 3);
    final umbral = _otsu(gris);
    final bin = _binarizar(gris, umbral);
    final areaTotal = trabajo.width * trabajo.height;
    var blancos = 0;
    for (var i = 0; i < bin.length; i++) {
      if (bin[i] == 1) blancos++;
    }
    final fraccion = blancos / areaTotal;
    // Sin fondo que remover (todo claro) o sin papel visible.
    if (fraccion > 0.97 || fraccion < 0.03) return null;

    final blob = _blobMayor(bin, trabajo.width, trabajo.height);
    if (blob == null) return null;
    final areaBlob = blob.cantidad / areaTotal;
    if (areaBlob < 0.05 || areaBlob > 0.97) return null;

    final k = original.width / trabajo.width; // factor a resolución real.
    final casco = _convexHull(blob.borde);
    final cuad = _aproximarCuadrilatero(casco);
    if (cuad != null) {
      final salida = _warpDocumento(original, cuad, k);
      if (salida != null) {
        return Uint8List.fromList(img.encodeJpg(salida, quality: 85));
      }
    }
    // Respaldo: recorte al rectángulo del documento (quita los contornos).
    final x1 = math.max(0, (blob.minX * k).round() - (original.width * 0.015).round());
    final y1 = math.max(0, (blob.minY * k).round() - (original.height * 0.015).round());
    final x2 = math.min(original.width - 1,
        (blob.maxX * k).round() + (original.width * 0.015).round());
    final y2 = math.min(original.height - 1,
        (blob.maxY * k).round() + (original.height * 0.015).round());
    final ancho = x2 - x1, alto = y2 - y1;
    if (ancho < 50 || alto < 50) return null;
    if (ancho * alto > areaTotal * k * k * 0.93) return null; // nada que quitar.
    final recorte =
        img.copyCrop(original, x: x1, y: y1, width: ancho, height: alto);
    return Uint8List.fromList(img.encodeJpg(recorte, quality: 85));
  } catch (_) {
    return null;
  }
}

/// Envoltorio para la UI.
Future<Uint8List?> recorteAutomatico(Uint8List bytes) =>
    compute(recorteAutomaticoSync, bytes);

// ---------- binarización ----------

int _otsu(img.Image gris) {
  final hist = List<int>.filled(256, 0);
  for (var y = 0; y < gris.height; y++) {
    for (var x = 0; x < gris.width; x++) {
      final p = gris.getPixel(x, y);
      final g = ((p.r + p.g + p.b) / 3).round().clamp(0, 255);
      hist[g]++;
    }
  }
  final total = gris.width * gris.height;
  var suma = 0.0;
  for (var i = 0; i < 256; i++) {
    suma += i * hist[i];
  }
  var sumaFondo = 0.0, pesoFondo = 0, mejor = 0, mejorVar = -1.0;
  for (var t = 0; t < 256; t++) {
    pesoFondo += hist[t];
    if (pesoFondo == 0) continue;
    final pesoObj = total - pesoFondo;
    if (pesoObj == 0) break;
    sumaFondo += t * hist[t];
    final mFondo = sumaFondo / pesoFondo, mObj = (suma - sumaFondo) / pesoObj;
    final entre = pesoFondo * pesoObj * (mFondo - mObj) * (mFondo - mObj);
    if (entre > mejorVar) {
      mejorVar = entre;
      mejor = t;
    }
  }
  return mejor;
}

Uint8List _binarizar(img.Image gris, int umbral) {
  final bin = Uint8List(gris.width * gris.height);
  for (var y = 0; y < gris.height; y++) {
    for (var x = 0; x < gris.width; x++) {
      final p = gris.getPixel(x, y);
      bin[y * gris.width + x] =
          ((p.r + p.g + p.b) / 3).round() >= umbral ? 1 : 0;
    }
  }
  return bin;
}

// ---------- componente mayor ----------

class _Blob {
  _Blob(this.cantidad, this.minX, this.minY, this.maxX, this.maxY, this.borde);
  final int cantidad;
  final int minX, minY, maxX, maxY;
  final List<math.Point<double>> borde;
}

_Blob? _blobMayor(Uint8List bin, int ancho, int alto) {
  final etiquetas = Int32List(ancho * alto);
  etiquetas.fillRange(0, etiquetas.length, -1);
  _Blob? mejor;
  const dx = [1, -1, 0, 0], dy = [0, 0, 1, -1];
  final pila = <int>[];
  for (var i = 0; i < bin.length; i++) {
    if (bin[i] != 1 || etiquetas[i] != -1) continue;
    var cantidad = 0, minX = ancho, minY = alto, maxX = 0, maxY = 0;
    final borde = <math.Point<double>>[];
    pila.add(i);
    etiquetas[i] = 1;
    while (pila.isNotEmpty) {
      final actual = pila.removeLast();
      final x = actual % ancho, y = actual ~/ ancho;
      cantidad++;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      var esBorde = false;
      for (var d = 0; d < 4; d++) {
        final nx = x + dx[d], ny = y + dy[d];
        if (nx < 0 || ny < 0 || nx >= ancho || ny >= alto) {
          esBorde = true;
          continue;
        }
        final ni = ny * ancho + nx;
        if (bin[ni] != 1) {
          esBorde = true;
        } else if (etiquetas[ni] == -1) {
          etiquetas[ni] = 1;
          pila.add(ni);
        }
      }
      if (esBorde && cantidad % 2 == 0) {
        borde.add(math.Point(x.toDouble(), y.toDouble()));
      }
    }
    if (mejor == null || cantidad > mejor.cantidad) {
      mejor = _Blob(cantidad, minX, minY, maxX, maxY, borde);
    }
  }
  if (mejor == null || mejor.borde.length < 16) return null;
  return mejor;
}

// ---------- geometría ----------

List<math.Point<double>> _convexHull(List<math.Point<double>> puntos) {
  final pts = puntos.toSet().toList()
    ..sort((a, b) =>
        a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  if (pts.length < 3) return pts;
  double cruz(math.Point<double> o, math.Point<double> a,
      math.Point<double> b) =>
      (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
  final inferior = <math.Point<double>>[];
  for (final p in pts) {
    while (inferior.length >= 2 &&
        cruz(inferior[inferior.length - 2], inferior.last, p) <= 0) {
      inferior.removeLast();
    }
    inferior.add(p);
  }
  final superior = <math.Point<double>>[];
  for (var i = pts.length - 1; i >= 0; i--) {
    final p = pts[i];
    while (superior.length >= 2 &&
        cruz(superior[superior.length - 2], superior.last, p) <= 0) {
      superior.removeLast();
    }
    superior.add(p);
  }
  inferior.removeLast();
  superior.removeLast();
  return inferior + superior;
}

double _distanciaPuntoSegmento(
    math.Point<double> p, math.Point<double> a, math.Point<double> b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  final base = dx * dx + dy * dy;
  if (base == 0) return math.sqrt((p.x - a.x) * (p.x - a.x) + (p.y - a.y) * (p.y - a.y));
  var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / base;
  t = t.clamp(0.0, 1.0);
  final px = a.x + t * dx - p.x, py = a.y + t * dy - p.y;
  return math.sqrt(px * px + py * py);
}

List<math.Point<double>> _rdp(List<math.Point<double>> pts, double eps) {
  if (pts.length < 3) return pts;
  var maxD = 0.0;
  var indice = 0;
  for (var i = 1; i < pts.length - 1; i++) {
    final d = _distanciaPuntoSegmento(pts[i], pts.first, pts.last);
    if (d > maxD) {
      maxD = d;
      indice = i;
    }
  }
  if (maxD > eps) {
    final izq = _rdp(pts.sublist(0, indice + 1), eps);
    final der = _rdp(pts.sublist(indice), eps);
    return izq.sublist(0, izq.length - 1) + der;
  }
  return [pts.first, pts.last];
}

double _perimetro(List<math.Point<double>> pts) {
  var total = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i], b = pts[(i + 1) % pts.length];
    total += math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));
  }
  return total;
}

/// Aproxima el casco a 4 esquinas; null si no parece un documento.
List<math.Point<double>>? _aproximarCuadrilatero(
    List<math.Point<double>> casco) {
  if (casco.length < 4) return null;
  final cerrado = [...casco, casco.first];
  final aprox = _rdp(cerrado, 0.02 * _perimetro(casco));
  // RDP sobre contorno cerrado devuelve primer==último: quitar duplicado.
  final puntos = aprox.length > 1 &&
          (aprox.first - aprox.last).magnitude < 1.0
      ? aprox.sublist(0, aprox.length - 1)
      : aprox;
  if (puntos.length != 4) return null;
  return _ordenarEsquinas(puntos);
}

List<math.Point<double>> _ordenarEsquinas(List<math.Point<double>> pts) {
  final tl = pts.reduce((a, b) => a.x + a.y < b.x + b.y ? a : b);
  final br = pts.reduce((a, b) => a.x + a.y > b.x + b.y ? a : b);
  final tr = pts.reduce((a, b) => a.x - a.y > b.x - b.y ? a : b);
  final bl = pts.reduce((a, b) => a.x - a.y < b.x - b.y ? a : b);
  return [tl, tr, br, bl];
}

// ---------- warp de perspectiva ----------

List<double>? _homografia(List<math.Point<double>> src,
    List<math.Point<double>> dst) {
  // Resuelve H (3x3, h[8]=1) tal que src = H * dst.
  final a = List<List<double>>.generate(8, (_) => List.filled(9, 0.0));
  for (var i = 0; i < 4; i++) {
    final x = dst[i].x, y = dst[i].y, u = src[i].x, v = src[i].y;
    a[i * 2] = [x, y, 1, 0, 0, 0, -u * x, -u * y, u];
    a[i * 2 + 1] = [0, 0, 0, x, y, 1, -v * x, -v * y, v];
  }
  for (var col = 0; col < 8; col++) {
    var pivote = col;
    for (var fila = col + 1; fila < 8; fila++) {
      if (a[fila][col].abs() > a[pivote][col].abs()) pivote = fila;
    }
    if (a[pivote][col].abs() < 1e-9) return null;
    final tmp = a[col];
    a[col] = a[pivote];
    a[pivote] = tmp;
    for (var fila = 0; fila < 8; fila++) {
      if (fila == col) continue;
      final factor = a[fila][col] / a[col][col];
      for (var k = col; k < 9; k++) {
        a[fila][k] -= factor * a[col][k];
      }
    }
  }
  return List<double>.generate(
      8, (i) => a[i][8] / a[i][i], growable: false);
}

img.Color _muestraBilineal(img.Image src, double x, double y) {
  final x0 = x.floor().clamp(0, src.width - 1);
  final y0 = y.floor().clamp(0, src.height - 1);
  final x1 = (x0 + 1).clamp(0, src.width - 1);
  final y1 = (y0 + 1).clamp(0, src.height - 1);
  final fx = (x - x0).clamp(0.0, 1.0), fy = (y - y0).clamp(0.0, 1.0);
  int canal(num a, num b, num c, num d) =>
      ((a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy)).round().clamp(0, 255);
  final p00 = src.getPixel(x0, y0), p10 = src.getPixel(x1, y0);
  final p01 = src.getPixel(x0, y1), p11 = src.getPixel(x1, y1);
  final r = canal(p00.r, p10.r, p01.r, p11.r);
  final g = canal(p00.g, p10.g, p01.g, p11.g);
  final b = canal(p00.b, p10.b, p01.b, p11.b);
  return img.ColorRgb8(r, g, b);
}

img.Image? _warpDocumento(
    img.Image original, List<math.Point<double>> cuad, double k) {
  final src = cuad
      .map((p) => math.Point(p.x * k, p.y * k))
      .toList(growable: false);
  double lado(List<math.Point<double>> q, int i, int j) =>
      math.sqrt(math.pow(q[i].x - q[j].x, 2) + math.pow(q[i].y - q[j].y, 2));
  var ancho = math.max(lado(src, 0, 1), lado(src, 2, 3)).round();
  var alto = math.max(lado(src, 0, 3), lado(src, 1, 2)).round();
  if (ancho < 50 || alto < 50) return null;
  const maximo = 1500;
  final f = math.min(1.0, maximo / math.max(ancho, alto));
  ancho = (ancho * f).round();
  alto = (alto * f).round();
  final dst = [
    math.Point(0.0, 0.0),
    math.Point(ancho.toDouble(), 0.0),
    math.Point(ancho.toDouble(), alto.toDouble()),
    math.Point(0.0, alto.toDouble()),
  ];
  final h = _homografia(src, dst);
  if (h == null) return null;
  final salida = img.Image(width: ancho, height: alto);
  for (var y = 0; y < alto; y++) {
    for (var x = 0; x < ancho; x++) {
      final w = h[6] * x + h[7] * y + 1;
      final sx = (h[0] * x + h[1] * y + h[2]) / w;
      final sy = (h[3] * x + h[4] * y + h[5]) / w;
      salida.setPixel(x, y,
          _muestraBilineal(original, sx.clamp(0, original.width - 1.0),
              sy.clamp(0, original.height - 1.0)));
    }
  }
  return salida;
}