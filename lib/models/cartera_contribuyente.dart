import 'models.dart';

List<String> normalizarTelefonos(String texto) {
  final salida = <String>{};
  // Separa listas sin confundir guiones o espacios dentro de un número.
  final partes = texto.split(RegExp(r'[,;/|\n\r]+|\s+(?=\+?\d{9}(?:\s|$))'));
  for (final parte in partes) {
    final mobiles = RegExp(r'(?<!\d)(?:\+?51[\s-]*)?9(?:[\s-]*\d){8}(?!\d)').allMatches(parte).toList();
    final candidatos = mobiles.length > 1 ? mobiles.map((m) => m.group(0)!) : [parte];
    for (final candidato in candidatos) {
      var numero = candidato.replaceAll(RegExp(r'[^0-9+]'), '');
      if (numero.startsWith('00')) numero = '+${numero.substring(2)}';
      final digitos = numero.replaceAll('+', '');
      if (digitos.length < 6 || digitos.length > 15 || RegExp(r'^0+$').hasMatch(digitos)) continue;
      if (digitos.length == 9 && digitos.startsWith('9')) numero = '+51$digitos';
      else if (digitos.length == 11 && digitos.startsWith('51')) numero = '+$digitos';
      else numero = numero.startsWith('+') ? '+$digitos' : digitos;
      salida.add(numero);
    }
  }
  return salida.toList();
}

class CarteraContribuyente {
  CarteraContribuyente(this.documentos);
  final List<CarteraItem> documentos;
  CarteraItem get principal => documentos.first;
  String get codigo => principal.codContribuyente.trim();
  String get nombre => principal.nombre;
  List<String> get telefonos => documentos.expand((d) => normalizarTelefonos(d.telefonos)).toSet().toList();
  List<CarteraItem> get pendientes => documentos.where((d) => !d.entregado).toList();
  bool get entregado => pendientes.isEmpty;
  double? get saldo => principal.saldoActual;
  String numeros(String tipo) => documentos.where((d) => d.tipo.toUpperCase() == tipo)
      .map((d) => d.correlativo.trim()).where((n) => n.isNotEmpty).toSet().join('\n');
  List<CarteraItem> documentosPorTipo(String tipo) =>
      documentos.where((d) => d.tipo.toUpperCase() == tipo.toUpperCase()).toList();
  bool get opPagada {
    final ops = documentosPorTipo('OP');
    if (ops.isEmpty) return false;
    return ops.every((d) => d.pagada);
  }
  bool get rdPagada {
    final rds = documentosPorTipo('RD');
    if (rds.isEmpty) return false;
    return rds.every((d) => d.pagada);
  }
  bool get todosPagados {
    if (documentos.isEmpty) return false;
    return documentos.every((d) => d.pagada);
  }
  bool get algunoPagado => documentos.any((d) => d.pagada);
}

List<CarteraContribuyente> agruparCartera(List<CarteraItem> filas) {
  final grupos = <String, List<CarteraItem>>{};
  for (final fila in filas) {
    final grupo = grupos.putIfAbsent(fila.codContribuyente.trim(), () => []);
    if (!grupo.any((d) => d.id == fila.id && d.tipo == fila.tipo && d.correlativo == fila.correlativo)) grupo.add(fila);
  }
  return grupos.values.map(CarteraContribuyente.new).toList();
}
