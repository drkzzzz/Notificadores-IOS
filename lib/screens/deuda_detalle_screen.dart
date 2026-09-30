import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../models/models.dart';

class DeudaDetalleScreen extends StatefulWidget {
  const DeudaDetalleScreen({super.key, required this.consolidado});

  final DeudaConsolidado consolidado;

  @override
  State<DeudaDetalleScreen> createState() => _DeudaDetalleScreenState();
}

class _DeudaDetalleScreenState extends State<DeudaDetalleScreen> {
  String _fmt(double v) {
    return 'S/ ${v.toStringAsFixed(2)}';
  }

  Color _colorMonto(double monto) {
    if (monto > 10000) return AppColors.rojo;
    if (monto > 1000) return AppColors.verdeOscuro;
    return AppColors.texto;
  }

  Future<void> _llamar() async {
    final tel = widget.consolidado.contribuyente.telefonoLimpio;
    if (tel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró número de teléfono')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: tel);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el marcador')),
        );
      }
    }
  }

  Future<void> _whatsapp() async {
    final tel = widget.consolidado.contribuyente.telefonoLimpio;
    if (tel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró número de teléfono')),
      );
      return;
    }
    final c = widget.consolidado.contribuyente;
    final r = widget.consolidado.resumen;
    final lines = <String>[
      '=== CONSOLIDADO DE DEUDA ===',
      'Contribuyente: ${c.nombre}',
      'Código: ${c.codContribuyente}',
      'Dirección: ${c.direccion ?? "N/D"}',
      '',
      'TOTAL: ${_fmt(r.totalGeneral)}',
      'Insoluto: ${_fmt(r.totalInsoluto)}',
      'Reajuste: ${_fmt(r.totalReajuste)}',
      'Interés: ${_fmt(r.totalInteres)}',
      'Gasto: ${_fmt(r.totalGasto)}',
    ];
    if (r.tieneCoactivo) {
      lines.add('⚠ En coactivo: ${_fmt(r.totalCoactivo)}');
    }
    if (r.totalAmnistia > 0) {
      lines.addAll([
        '',
        '=== BENEFICIO AMNISTÍA ===',
        'Total amnistía: ${_fmt(r.totalAmnistia)}',
        'Ahorro: ${_fmt(r.ahorroAmnistia)}',
      ]);
    }
    lines.addAll(['', 'Deudas: ${r.cantidadDeudas} registros', '']);

    for (final ano in widget.consolidado.porAno) {
      lines.add('--- AÑO ${ano.ano} (${_fmt(ano.totalAno)}) ---');
      if (ano.totalAmnistiaAno > 0) {
        lines.add(
            '  Amnistía: ${_fmt(ano.totalAmnistiaAno)} · Ahorro: ${_fmt(ano.ahorroAno)}');
      }
      for (final t in ano.tributos) {
        lines.add('  ${t.nomTributo}: ${_fmt(t.totalTributo)}');
        if (t.totalAmnistiaTributo > 0) {
          lines.add('    → Amnistía: ${_fmt(t.totalAmnistiaTributo)}');
        }
        for (final cu in t.cuotas) {
          lines.add(
              '    Cuota ${cu.cuota ?? "-"} · Venc: ${cu.fechaVenc ?? "-"} · ${_fmt(cu.monto)}');
          if (cu.montoAmnistia > 0) {
            lines.add(
                '      → Amnistía: ${_fmt(cu.montoAmnistia)} (ahorro: ${_fmt(cu.ahorro)})');
          }
        }
      }
    }

    final texto = Uri.encodeComponent(lines.join('\n'));
    final uri = Uri.parse('https://wa.me/51$tel?text=$texto');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consolidado.contribuyente;
    final r = widget.consolidado.resumen;

    return Scaffold(
      backgroundColor: AppColors.grisClaro,
      appBar: AppBar(
        title: const Text('Consolidado de Deuda'),
        backgroundColor: AppColors.verdeOscuro,
        actions: [
          IconButton(
            tooltip: 'Llamar',
            icon: const Icon(Icons.phone),
            onPressed: _llamar,
          ),
          IconButton(
            tooltip: 'WhatsApp',
            icon: const Icon(Icons.message),
            onPressed: _whatsapp,
          ),
        ],
      ),
      body: Column(
        children: [
          // Datos contribuyente
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: AppColors.verdeOscuro),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.nombre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Cód: ${c.codContribuyente}',
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.grisMedio),
                ),
                if (c.direccion != null && c.direccion!.isNotEmpty)
                  Text(
                    'Dir: ${c.direccion}',
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.grisMedio),
                  ),
                if (c.telefonos != null && c.telefonos!.isNotEmpty)
                  Text(
                    'Tel: ${c.telefonos}',
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.grisMedio),
                  ),
              ],
            ),
          ),

          // Resumen principal
          Container(
            width: double.infinity,
            color: r.tieneCoactivo ? AppColors.rojo : AppColors.verdeOscuro,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DEUDA TOTAL',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _fmt(r.totalGeneral),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${r.cantidadDeudas} deudas',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    if (r.tieneCoactivo)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'COACTIVO: ${_fmt(r.totalCoactivo)}',
                          style: const TextStyle(
                            color: AppColors.rojo,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Amnistía banner
          if (r.totalAmnistia > 0)
            Container(
              width: double.infinity,
              color: AppColors.verde,
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.savings, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BENEFICIO AMNISTÍA',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Paga con amnistía: ${_fmt(r.totalAmnistia)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'AHORRAS ${_fmt(r.ahorroAmnistia)}',
                      style: const TextStyle(
                        color: AppColors.verde,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Desglose
          Container(
            width: double.infinity,
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ChipDesglose(
                      label: 'Insoluto', value: _fmt(r.totalInsoluto)),
                  const SizedBox(width: 16),
                  _ChipDesglose(
                      label: 'Reajuste', value: _fmt(r.totalReajuste)),
                  const SizedBox(width: 16),
                  _ChipDesglose(
                      label: 'Interés', value: _fmt(r.totalInteres)),
                  const SizedBox(width: 16),
                  _ChipDesglose(label: 'Gasto', value: _fmt(r.totalGasto)),
                  if (r.totalProntoPago > 0) ...[
                    const SizedBox(width: 16),
                    _ChipDesglose(
                        label: 'P.Pago', value: _fmt(r.totalProntoPago)),
                  ],
                  if (r.totalPagoPuntual > 0) ...[
                    const SizedBox(width: 16),
                    _ChipDesglose(
                        label: 'P.Puntual',
                        value: _fmt(r.totalPagoPuntual)),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Lista agrupada por año
          Expanded(
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: widget.consolidado.porAno.length,
              itemBuilder: (ctx, i) {
                final ano = widget.consolidado.porAno[i];
                return _TarjetaAno(
                  ano: ano,
                  fmt: _fmt,
                  colorMonto: _colorMonto,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipDesglose extends StatelessWidget {
  const _ChipDesglose({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.grisMedio),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.texto,
          ),
        ),
      ],
    );
  }
}

class _TarjetaAno extends StatefulWidget {
  const _TarjetaAno({
    required this.ano,
    required this.fmt,
    required this.colorMonto,
  });

  final AnoDeuda ano;
  final String Function(double) fmt;
  final Color Function(double) colorMonto;

  @override
  State<_TarjetaAno> createState() => _TarjetaAnoState();
}

class _TarjetaAnoState extends State<_TarjetaAno> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final ano = widget.ano;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expandido = !_expandido),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.verdeOscuro.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event,
                      color: AppColors.verdeOscuro, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AÑO ${ano.ano}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.texto,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${ano.tributos.length} tributo(s)',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.grisMedio),
                            ),
                            if (ano.totalAmnistiaAno > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.verde,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'AMNISTÍA: ${widget.fmt(ano.totalAmnistiaAno)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.fmt(ano.totalAno),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: widget.colorMonto(ano.totalAno),
                        ),
                      ),
                      if (ano.totalAmnistiaAno > 0)
                        Text(
                          'Amnistía: ${widget.fmt(ano.totalAmnistiaAno)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.verde,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expandido
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.grisMedio,
                  ),
                ],
              ),
            ),
          ),
          if (_expandido)
            ...ano.tributos.map((tributo) => _TarjetaTributo(
                  tributo: tributo,
                  fmt: widget.fmt,
                  colorMonto: widget.colorMonto,
                )),
        ],
      ),
    );
  }
}

class _TarjetaTributo extends StatefulWidget {
  const _TarjetaTributo({
    required this.tributo,
    required this.fmt,
    required this.colorMonto,
  });

  final TributoAgrupado tributo;
  final String Function(double) fmt;
  final Color Function(double) colorMonto;

  @override
  State<_TarjetaTributo> createState() => _TarjetaTributoState();
}

class _TarjetaTributoState extends State<_TarjetaTributo> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tributo;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expandido = !_expandido),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long,
                      color: AppColors.verdeOscuro, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.nomTributo,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${t.cuotas.length} cuota(s)',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.grisMedio),
                            ),
                            if (t.totalAmnistiaTributo > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.verde,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'AHORRO: ${widget.fmt(t.ahorroTributo)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.fmt(t.totalTributo),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: widget.colorMonto(t.totalTributo),
                        ),
                      ),
                      if (t.totalAmnistiaTributo > 0)
                        Text(
                          '→ ${widget.fmt(t.totalAmnistiaTributo)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.verde,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expandido
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.grisMedio,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expandido)
            ...t.cuotas.map((cu) => _FilaCuota(
                  cuota: cu,
                  fmt: widget.fmt,
                )),
        ],
      ),
    );
  }
}

class _FilaCuota extends StatelessWidget {
  const _FilaCuota({required this.cuota, required this.fmt});

  final CuotaDeuda cuota;
  final String Function(double) fmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: cuota.esCoactivo
            ? AppColors.rojo.withValues(alpha: 0.08)
            : cuota.montoAmnistia > 0
                ? AppColors.verde.withValues(alpha: 0.06)
                : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: cuota.esCoactivo
            ? Border.all(color: AppColors.rojo.withValues(alpha: 0.3))
            : cuota.montoAmnistia > 0
                ? Border.all(color: AppColors.verde.withValues(alpha: 0.3))
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cuota ${cuota.cuota ?? "-"} · ${cuota.fechaVenc ?? "S/F"}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                fmt(cuota.monto),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color:
                      cuota.esCoactivo ? AppColors.rojo : AppColors.texto,
                ),
              ),
            ],
          ),
          if (cuota.montoAmnistia > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  const Icon(Icons.savings,
                      color: AppColors.verde, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Amnistía: ${fmt(cuota.montoAmnistia)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.verde,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.verde.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'AHORRAS ${fmt(cuota.ahorro)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.verde,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (cuota.esCoactivo)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.rojo,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'COACTIVO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (cuota.ubicacionPredio != null &&
                  cuota.ubicacionPredio!.isNotEmpty)
                Expanded(
                  child: Text(
                    cuota.ubicacionPredio!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.grisMedio),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Insoluto: ${fmt(cuota.insoluto)} · Reaj: ${fmt(cuota.reajuste)} · Interés: ${fmt(cuota.interes)} · Gasto: ${fmt(cuota.gasto)}',
            style:
                const TextStyle(fontSize: 11, color: AppColors.grisMedio),
          ),
        ],
      ),
    );
  }
}
