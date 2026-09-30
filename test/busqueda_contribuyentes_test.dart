import 'package:flutter_test/flutter_test.dart';
import 'package:notificadores_satt/services/busqueda_contribuyentes.dart';
import 'package:notificadores_satt/models/models.dart';

void main() {
  test('busca prefijos de cualquier palabra, sin importar el orden ni tildes', () {
    for (final consulta in ['ju gar', 'gar ju', 'PÉR JU', '  gar   per  ']) {
      expect(coincideContribuyente('00000123456', 'Juan Pérez García', consulta), isTrue);
    }
    expect(coincideContribuyente('00000123456', 'Juan Pérez García', 'uan'), isFalse);
    expect(coincideContribuyente('00000123456', 'Juan Pérez García', 'ju lo'), isFalse);
  });
  test('busca código parcial y permite limpiar el filtro', () {
    expect(coincideContribuyente('00000123456', 'Juan', '123456'), isTrue);
    expect(coincideContribuyente('00000123456', 'Juan', '987'), isFalse);
    expect(coincideContribuyente('00000123456', 'Juan', '  '), isTrue);
  });
  test('normaliza acentos combinados y separadores', () {
    expect(coincideContribuyente('1', 'Jose\u0301 García-Pérez', 'per jose'), isTrue);
    expect(coincideContribuyente('1', 'Juan', '***'), isFalse);
  });
  test('dirección adicional opcional para respuestas anteriores de la API', () {
    expect(CarteraItem.fromJson({'id': 1}).direccionAdicional, '');
    expect(CarteraItem.fromJson({'id': 1, 'direccion_adicional': ' Referencia '}).direccionAdicional, 'Referencia');
  });
}
