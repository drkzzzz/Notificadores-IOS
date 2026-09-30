import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:notificadores_satt/services/auto_scan.dart';

/// Hoja blanca sobre fondo negro con margen de 40 px.
Uint8List hojaSobreNegro(int ancho, int alto, {int margen = 40}) {
  final base = img.Image(width: ancho, height: alto);
  img.fill(base, color: img.ColorRgb8(10, 10, 10));
  img.fillRect(base,
      x1: margen,
      y1: margen,
      x2: ancho - margen - 1,
      y2: alto - margen - 1,
      color: img.ColorRgb8(245, 245, 245));
  return Uint8List.fromList(img.encodeJpg(base, quality: 90));
}

void main() {
  test('detecta hoja y elimina contornos oscuros', () {
    final entrada = hojaSobreNegro(400, 500);
    final salida = recorteAutomaticoSync(entrada);
    expect(salida, isNotNull);
    final dec = img.decodeImage(salida!)!;
    final orig = img.decodeImage(entrada)!;
    // Recortada (menos píxeles) y proporción de hoja conservada.
    expect(dec.width * dec.height, lessThan(orig.width * orig.height));
    final propOrig = (400 - 80) / (500 - 80);
    final propSal = dec.width / dec.height;
    expect((propSal - propOrig).abs(), lessThan(0.08));
  });

  test('imagen uniforme retorna null (nada que recortar)', () {
    final gris = img.Image(width: 300, height: 300);
    img.fill(gris, color: img.ColorRgb8(200, 200, 200));
    final bytes = Uint8List.fromList(img.encodeJpg(gris, quality: 90));
    expect(recorteAutomaticoSync(bytes), isNull);
  });

  test('bytes inválidos retornan null sin lanzar', () {
    expect(recorteAutomaticoSync(Uint8List.fromList([0, 1, 2, 3])), isNull);
  });
}
