class ResumenNotificadores {
  final ContribuyenteNotificador contribuyente;
  final ConceptoDeuda predial;
  final ConceptoDeuda arbitrios;
  final double totalRegular;
  final double totalConAmnistia;
  final double ahorro;
  final Map<String, Map<String, double>> detallePorAno;
  final List<TributoDeuda> tributos;
  final double totalRegularTodos;
  final double totalConAmnistiaTodos;
  final double ahorroTodos;
  final String nombreAmnistia;
  final List<String> aplicaA;
  final String fechaConsulta;

  const ResumenNotificadores({
    required this.contribuyente,
    required this.predial,
    required this.arbitrios,
    required this.totalRegular,
    required this.totalConAmnistia,
    required this.ahorro,
    required this.detallePorAno,
    this.tributos = const [],
    this.totalRegularTodos = 0,
    this.totalConAmnistiaTodos = 0,
    this.ahorroTodos = 0,
    required this.nombreAmnistia,
    required this.aplicaA,
    required this.fechaConsulta,
  });

  factory ResumenNotificadores.fromJson(Map<String, dynamic> json) {
    final contribuyente = _asMap(json['contribuyente']);
    final deuda = _asMap(json['deuda']);
    final amnistia = _asMap(json['amnistia']);
    final detalle = _asMap(json['detalle_por_ano']);
    final lista = (json['tributos'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => TributoDeuda.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ResumenNotificadores(
      contribuyente: ContribuyenteNotificador.fromJson(contribuyente),
      predial: ConceptoDeuda.fromJson(_asMap(deuda['predial'])),
      arbitrios: ConceptoDeuda.fromJson(_asMap(deuda['arbitrios'])),
      totalRegular: _asDouble(deuda['total_regular']),
      totalConAmnistia: _asDouble(deuda['total_con_amnistia']),
      ahorro: _asDouble(deuda['ahorro']),
      detallePorAno: detalle.map((clave, valor) =>
          MapEntry(clave, _asDoubleMap(valor))),
      tributos: lista,
      totalRegularTodos: _asDouble(deuda['total_regular_todos']),
      totalConAmnistiaTodos: _asDouble(deuda['total_con_amnistia_todos']),
      ahorroTodos: _asDouble(deuda['ahorro_todos']),
      nombreAmnistia: amnistia['nombre']?.toString() ?? '',
      aplicaA: (amnistia['aplica_a'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      fechaConsulta: json['fecha_consulta']?.toString() ?? '',
    );
  }
}

class TributoDeuda {
  final String cod;
  final String nombre;
  final double regular;
  final double conAmnistia;
  final double descuento;
  final Map<String, double> porAnoRegular;
  final Map<String, double> porAnoAmnistia;

  const TributoDeuda({
    required this.cod,
    required this.nombre,
    required this.regular,
    required this.conAmnistia,
    required this.descuento,
    required this.porAnoRegular,
    required this.porAnoAmnistia,
  });

  factory TributoDeuda.fromJson(Map<String, dynamic> json) {
    return TributoDeuda(
      cod: json['cod']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      regular: _asDouble(json['regular']),
      conAmnistia: _asDouble(json['con_amnistia']),
      descuento: _asDouble(json['descuento']),
      porAnoRegular: _asDoubleMap(json['por_ano_regular']),
      porAnoAmnistia: _asDoubleMap(json['por_ano_amnistia']),
    );
  }

  String get titulo => 'Deuda ${nombre.isEmpty ? cod : nombre}';
}

class ContribuyenteNotificador {
  final String codigo;
  final String nombre;
  final String domicilioFiscal;

  const ContribuyenteNotificador({
    required this.codigo,
    required this.nombre,
    required this.domicilioFiscal,
  });

  factory ContribuyenteNotificador.fromJson(Map<String, dynamic> json) {
    return ContribuyenteNotificador(
      codigo: json['codigo']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      domicilioFiscal: json['domicilio_fiscal']?.toString() ?? '',
    );
  }
}

class ConceptoDeuda {
  final double regular;
  final double conAmnistia;
  final double descuento;

  const ConceptoDeuda({
    required this.regular,
    required this.conAmnistia,
    required this.descuento,
  });

  factory ConceptoDeuda.fromJson(Map<String, dynamic> json) {
    return ConceptoDeuda(
      regular: _asDouble(json['regular']),
      conAmnistia: _asDouble(json['con_amnistia']),
      descuento: _asDouble(json['descuento']),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : const {};
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, double> _asDoubleMap(dynamic value) {
  final map = _asMap(value);
  return map.map((clave, valor) => MapEntry(clave, _asDouble(valor)));
}
