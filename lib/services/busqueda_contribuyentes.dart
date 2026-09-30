String normalizarBusqueda(String texto) {
  const originales = 'áàäâãéèëêíìïîóòöôõúùüûñ';
  const reemplazos = 'aaaaaeeeeiiiiooooouuuun';
  var resultado = texto.toLowerCase();
  for (var i = 0; i < originales.length; i++) {
    resultado = resultado.replaceAll(originales[i], reemplazos[i]);
  }
  return resultado.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
}

bool coincideContribuyente(String codigo, String nombre, String consulta) {
  final q = normalizarBusqueda(consulta).trim();
  if (q.isEmpty) return true;
  if (RegExp(r'^\d+$').hasMatch(q)) return codigo.trim().contains(q);
  final terminos = q.split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty).toList();
  if (terminos.isEmpty) return false;
  final palabras = normalizarBusqueda(nombre).split(RegExp(r'[^a-z0-9]+'));
  return terminos.every((termino) => palabras.any((palabra) => palabra.startsWith(termino)));
}
