class Contribuyente {
  final String codContribuyente;
  final String nombre;
  final String? direccion;
  final String? documento;
  final String? telefonos;
  final String? email;

  Contribuyente({
    required this.codContribuyente,
    required this.nombre,
    this.direccion,
    this.documento,
    this.telefonos,
    this.email,
  });

  factory Contribuyente.fromJson(Map<String, dynamic> json) {
    return Contribuyente(
      codContribuyente: json['cod_contribuyente']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      direccion: json['direccion']?.toString(),
      documento: json['documento']?.toString(),
      telefonos: json['telefonos']?.toString(),
      email: json['email']?.toString(),
    );
  }

  String get telefonoLimpio {
    if (telefonos == null || telefonos!.isEmpty) return '';
    return telefonos!.replaceAll(RegExp(r'[^0-9]'), '');
  }
}

class CuotaDeuda {
  final String? ubicacionPredio;
  final String? codUnidad;
  final String? cuota;
  final String? estado;
  final String? calificacion;
  final String? fechaVenc;
  final double insoluto;
  final double reajuste;
  final double interes;
  final double gasto;
  final double monto;
  final dynamic coactivo;
  final String? numConv;
  final String? expcoact;
  final double importeProntoPago;
  final double importeProntoPagoTotal;
  final double importePagoPuntual;
  final double montoAmnistia;

  CuotaDeuda({
    this.ubicacionPredio,
    this.codUnidad,
    this.cuota,
    this.estado,
    this.calificacion,
    this.fechaVenc,
    required this.insoluto,
    required this.reajuste,
    required this.interes,
    required this.gasto,
    required this.monto,
    this.coactivo,
    this.numConv,
    this.expcoact,
    required this.importeProntoPago,
    required this.importeProntoPagoTotal,
    required this.importePagoPuntual,
    required this.montoAmnistia,
  });

  factory CuotaDeuda.fromJson(Map<String, dynamic> json) {
    return CuotaDeuda(
      ubicacionPredio: json['ubicacion_predio']?.toString(),
      codUnidad: json['cod_unidad']?.toString(),
      cuota: json['cuota']?.toString(),
      estado: json['estado']?.toString(),
      calificacion: json['calificacion']?.toString(),
      fechaVenc: json['fecha_venc']?.toString(),
      insoluto: _toDouble(json['insoluto']),
      reajuste: _toDouble(json['reajuste']),
      interes: _toDouble(json['interes']),
      gasto: _toDouble(json['gasto']),
      monto: _toDouble(json['monto']),
      coactivo: json['coactivo'],
      numConv: json['num_conv']?.toString(),
      expcoact: json['expcoact']?.toString(),
      importeProntoPago: _toDouble(json['importe_pronto_pago']),
      importeProntoPagoTotal: _toDouble(json['importe_pronto_pago_total']),
      importePagoPuntual: _toDouble(json['importe_pago_puntual']),
      montoAmnistia: _toDouble(json['monto_amnistia']),
    );
  }

  bool get esCoactivo =>
      coactivo == 'S' || coactivo == 1 || coactivo == '1';

  double get ahorro => monto > 0 && montoAmnistia > 0 ? monto - montoAmnistia : 0;

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class TributoAgrupado {
  final String codTributo;
  final String nomTributo;
  final List<CuotaDeuda> cuotas;
  final double totalTributo;
  final double totalAmnistiaTributo;

  TributoAgrupado({
    required this.codTributo,
    required this.nomTributo,
    required this.cuotas,
    required this.totalTributo,
    required this.totalAmnistiaTributo,
  });

  factory TributoAgrupado.fromJson(String cod, Map<String, dynamic> json) {
    final cuotasList = (json['cuotas'] as List?)
            ?.map((c) => CuotaDeuda.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];
    return TributoAgrupado(
      codTributo: cod,
      nomTributo: json['nom_tributo']?.toString() ?? cod,
      cuotas: cuotasList,
      totalTributo: _toDouble(json['total_tributo']),
      totalAmnistiaTributo: _toDouble(json['total_amnistia_tributo']),
    );
  }

  double get ahorroTributo =>
      totalTributo > 0 && totalAmnistiaTributo > 0
          ? totalTributo - totalAmnistiaTributo
          : 0;

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class AnoDeuda {
  final String ano;
  final List<TributoAgrupado> tributos;
  final double totalAno;
  final double totalAmnistiaAno;

  AnoDeuda({
    required this.ano,
    required this.tributos,
    required this.totalAno,
    required this.totalAmnistiaAno,
  });

  factory AnoDeuda.fromJson(Map<String, dynamic> json) {
    final tributosMap = json['tributos'] as Map<String, dynamic>? ?? {};
    final tributos = tributosMap.entries
        .map((e) => TributoAgrupado.fromJson(e.key, e.value))
        .toList();
    return AnoDeuda(
      ano: json['ano']?.toString() ?? '',
      tributos: tributos,
      totalAno: _toDouble(json['total_ano']),
      totalAmnistiaAno: _toDouble(json['total_amnistia_ano']),
    );
  }

  double get ahorroAno =>
      totalAno > 0 && totalAmnistiaAno > 0 ? totalAno - totalAmnistiaAno : 0;

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class ResumenDeuda {
  final double totalGeneral;
  final double totalInsoluto;
  final double totalReajuste;
  final double totalInteres;
  final double totalGasto;
  final bool tieneCoactivo;
  final double totalCoactivo;
  final int cantidadDeudas;
  final double totalAmnistia;
  final double ahorroAmnistia;
  final double totalProntoPago;
  final double totalPagoPuntual;

  ResumenDeuda({
    required this.totalGeneral,
    required this.totalInsoluto,
    required this.totalReajuste,
    required this.totalInteres,
    required this.totalGasto,
    required this.tieneCoactivo,
    required this.totalCoactivo,
    required this.cantidadDeudas,
    required this.totalAmnistia,
    required this.ahorroAmnistia,
    required this.totalProntoPago,
    required this.totalPagoPuntual,
  });

  factory ResumenDeuda.fromJson(Map<String, dynamic> json) {
    return ResumenDeuda(
      totalGeneral: _toDouble(json['total_general']),
      totalInsoluto: _toDouble(json['total_insoluto']),
      totalReajuste: _toDouble(json['total_reajuste']),
      totalInteres: _toDouble(json['total_interes']),
      totalGasto: _toDouble(json['total_gasto']),
      tieneCoactivo: json['tiene_coactivo'] == true,
      totalCoactivo: _toDouble(json['total_coactivo']),
      cantidadDeudas: json['cantidad_deudas'] ?? 0,
      totalAmnistia: _toDouble(json['total_amnistia']),
      ahorroAmnistia: _toDouble(json['ahorro_amnistia']),
      totalProntoPago: _toDouble(json['total_pronto_pago']),
      totalPagoPuntual: _toDouble(json['total_pago_puntual']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class DeudaConsolidado {
  final Contribuyente contribuyente;
  final ResumenDeuda resumen;
  final List<AnoDeuda> porAno;

  DeudaConsolidado({
    required this.contribuyente,
    required this.resumen,
    required this.porAno,
  });

  factory DeudaConsolidado.fromJson(Map<String, dynamic> json) {
    final porAnoList = (json['por_ano'] as List?)
            ?.map((a) => AnoDeuda.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [];
    return DeudaConsolidado(
      contribuyente:
          Contribuyente.fromJson(json['contribuyente'] as Map<String, dynamic>),
      resumen:
          ResumenDeuda.fromJson(json['resumen'] as Map<String, dynamic>),
      porAno: porAnoList,
    );
  }
}

class Operador {
  final String dni;
  final String nombre;

  Operador({required this.dni, required this.nombre});
}

class IdentificadorOpRd {
  final String fecha;
  final int opTotal;
  final int rdTotal;
  final int identificador;

  IdentificadorOpRd({
    required this.fecha,
    required this.opTotal,
    required this.rdTotal,
    required this.identificador,
  });

  factory IdentificadorOpRd.fromJson(Map<String, dynamic> json) {
    return IdentificadorOpRd(
      fecha: json['fecha']?.toString() ?? '',
      opTotal: json['op_total'] is int
          ? json['op_total']
          : int.tryParse(json['op_total'].toString()) ?? 0,
      rdTotal: json['rd_total'] is int
          ? json['rd_total']
          : int.tryParse(json['rd_total'].toString()) ?? 0,
      identificador: json['identificador'] is int
          ? json['identificador']
          : int.tryParse(json['identificador'].toString()) ?? 0,
    );
  }

  @override
  String toString() => '$fecha — OP: $opTotal | RD: $rdTotal';
}

class CarteraItem {
  final int id;
  final String codContribuyente;
  final String nombre;
  final String tipo;
  final String correlativo;
  final String direccion;
  final String direccionAdicional;
  final String telefonos;
  final double? saldoActual;
  final String estadoConsultado;
  final String coordenadas;
  final String condicionEntrega;
  final String? fecAsignacion;
  final String estado;
  final int dias;
  final bool pagada;
  final String estadoPago;
  final int cuotasPendientes;
  final int cuotasTotal;
  final LlamadaInfo? llamada;

  CarteraItem({
    required this.id,
    required this.codContribuyente,
    required this.nombre,
    required this.tipo,
    required this.correlativo,
    required this.direccion,
    this.direccionAdicional = '',
    this.telefonos = '',
    this.saldoActual,
    this.estadoConsultado = '',
    this.coordenadas = '',
    this.condicionEntrega = '',
    this.fecAsignacion,
    this.estado = 'A',
    this.dias = 0,
    this.pagada = false,
    this.estadoPago = 'DESCONOCIDO',
    this.cuotasPendientes = 0,
    this.cuotasTotal = 0,
    this.llamada,
  });

  bool get entregado => estado.trim().toUpperCase() == 'E';

  factory CarteraItem.fromJson(Map<String, dynamic> json) {
    return CarteraItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      codContribuyente: json['cod_contribuyente']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? '',
      correlativo: json['correlativo']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
      direccionAdicional: json['direccion_adicional']?.toString().trim() ?? '',
      telefonos: json['telefonos'] is List ? (json['telefonos'] as List).join(';') : json['telefonos']?.toString() ?? '',
      saldoActual: double.tryParse(json['saldo_actual']?.toString() ?? ''),
      estadoConsultado: json['estado_consultado']?.toString() ?? '',
      coordenadas: json['coordenadas']?.toString() ?? '',
      condicionEntrega: json['condicion_entrega']?.toString() ?? '',
      fecAsignacion: json['fec_asignacion']?.toString(),
      estado: json['estado']?.toString() ?? 'A',
      dias: json['dias'] is int
          ? json['dias']
          : int.tryParse(json['dias'].toString()) ?? 0,
      pagada: json['pagada'] == true,
      estadoPago: json['estado_pago']?.toString() ?? 'DESCONOCIDO',
      cuotasPendientes: json['cuotas_pendientes'] is int
          ? json['cuotas_pendientes']
          : int.tryParse(json['cuotas_pendientes']?.toString() ?? '') ?? 0,
      cuotasTotal: json['cuotas_total'] is int
          ? json['cuotas_total']
          : int.tryParse(json['cuotas_total']?.toString() ?? '') ?? 0,
      llamada: json['llamada'] is Map<String, dynamic>
          ? LlamadaInfo.fromJson(json['llamada'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Resultado de la última llamada registrada para un contribuyente
/// en el módulo Llamadas (BDSGTM01.dbo.LlamadasContribuyentes).
class LlamadaInfo {
  final String resultado;
  final String compromiso;
  final String fechaCompromiso;
  final String observaciones;
  final String fecRegistro;

  LlamadaInfo({
    this.resultado = '',
    this.compromiso = '',
    this.fechaCompromiso = '',
    this.observaciones = '',
    this.fecRegistro = '',
  });

  factory LlamadaInfo.fromJson(Map<String, dynamic> json) {
    return LlamadaInfo(
      resultado: json['resultado']?.toString() ?? '',
      compromiso: json['compromiso']?.toString() ?? '',
      fechaCompromiso: json['fecha_compromiso']?.toString() ?? '',
      observaciones: json['observaciones']?.toString() ?? '',
      fecRegistro: json['fec_registro']?.toString() ?? '',
    );
  }

  /// Descripción corta para la columna de observaciones de la grilla.
  String get resumen {
    final partes = <String>[if (resultado.isNotEmpty) resultado];
    if (compromiso.isNotEmpty) partes.add(compromiso);
    if (fechaCompromiso.isNotEmpty) partes.add(_formatearFecha(fechaCompromiso));
    return partes.join(' · ');
  }

  String _formatearFecha(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
