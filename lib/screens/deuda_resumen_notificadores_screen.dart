import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/resumen_notificadores.dart';

class DeudaResumenNotificadoresScreen extends StatelessWidget {
  const DeudaResumenNotificadoresScreen({super.key, required this.resumen});

  final ResumenNotificadores resumen;

  String _fmt(double valor) {
    final numero = valor.toStringAsFixed(2);
    final partes = numero.split('.');
    final miles = partes[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return 'S/ $miles.${partes[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final contribuyente = resumen.contribuyente;
    final usarTodos = resumen.tributos.isNotEmpty;
    final totalNormal = usarTodos ? resumen.totalRegularTodos : resumen.totalRegular;
    final totalAmn = usarTodos ? resumen.totalConAmnistiaTodos : resumen.totalConAmnistia;
    final ahorro = usarTodos ? resumen.ahorroTodos : resumen.ahorro;
    return Scaffold(
      backgroundColor: AppColors.grisClaro,
      appBar: AppBar(title: const Text('Deuda del contribuyente')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
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
                          contribuyente.nombre,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Código: ${contribuyente.codigo}'),
                  if (contribuyente.domicilioFiscal.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Domicilio: ${contribuyente.domicilioFiscal}'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _NotaTributos(),
          const SizedBox(height: 16),
          const _TituloSeccion('Despliega cada nivel para ver el detalle'),
          const SizedBox(height: 8),
          _NodoTotal(
            titulo: 'DEUDA NORMAL',
            total: totalNormal,
            formato: _fmt,
            children: [
              if (usarTodos)
                for (final t in resumen.tributos)
                  _NodoConcepto(
                    titulo: 'Deuda ${t.nombre} (${t.cod})',
                    subtotal: t.regular,
                    icono: _iconoTributo(t.cod),
                    porAno: t.porAnoRegular,
                    formato: _fmt,
                  )
              else ...[
                _NodoConcepto(
                  titulo: 'Predial Normal',
                  subtotal: resumen.predial.regular,
                  icono: Icons.home_work_outlined,
                  porAno: resumen.detallePorAno['predial_regular'] ?? const {},
                  formato: _fmt,
                ),
                _NodoConcepto(
                  titulo: 'Arbitrios Normal',
                  subtotal: resumen.arbitrios.regular,
                  icono: Icons.receipt_long_outlined,
                  porAno: resumen.detallePorAno['arbitrios_regular'] ?? const {},
                  formato: _fmt,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _NodoTotal(
            titulo: 'DEUDA CON AMNISTÍA',
            total: totalAmn,
            ahorro: ahorro,
            formato: _fmt,
            children: [
              if (usarTodos)
                for (final t in resumen.tributos)
                  _NodoConcepto(
                    titulo: 'Deuda ${t.nombre} (${t.cod})',
                    subtotal: t.conAmnistia,
                    icono: _iconoTributo(t.cod),
                    porAno: t.porAnoAmnistia,
                    formato: _fmt,
                  )
              else ...[
                _NodoConcepto(
                  titulo: 'Predial Amnistía',
                  subtotal: resumen.predial.conAmnistia,
                  icono: Icons.home_work_outlined,
                  porAno:
                      resumen.detallePorAno['predial_con_amnistia'] ?? const {},
                  formato: _fmt,
                ),
                _NodoConcepto(
                  titulo: 'Arbitrios Amnistía',
                  subtotal: resumen.arbitrios.conAmnistia,
                  icono: Icons.receipt_long_outlined,
                  porAno: resumen.detallePorAno['arbitrios_con_amnistia'] ??
                      const {},
                  formato: _fmt,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconoTributo(String cod) {
    switch (cod) {
      case '00001':
        return Icons.home_work_outlined;
      case '00003':
        return Icons.directions_car_outlined;
      case '00007':
      case '00008':
      case '00026':
        return Icons.receipt_long_outlined;
      case '00012':
      case '00013':
      case '00014':
        return Icons.gavel_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.grisMedio,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _NotaTributos extends StatelessWidget {
  const _NotaTributos();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.verdeOscuro.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.verdeOscuro.withValues(alpha: 0.15),
        ),
      ),
      child: const Text(
        'Valores en estado P/A agrupados por código tributario y luego por año. '
        'Incluye predial, arbitrios, vehicular, infracciones y demás tributos.',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.grisMedio,
          height: 1.35,
        ),
      ),
    );
  }
}

class _NodoTotal extends StatelessWidget {
  const _NodoTotal({
    required this.titulo,
    required this.total,
    required this.children,
    required this.formato,
    this.ahorro,
  });

  final String titulo;
  final double total;
  final List<Widget> children;
  final String Function(double) formato;
  final double? ahorro;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.verdeOscuro.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.account_balance,
              color: AppColors.verdeOscuro),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formato(total),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.verdeOscuro,
              ),
            ),
            if (ahorro != null && ahorro! > 0)
              Text(
                'Ahorro: ${formato(ahorro!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        children: children,
      ),
    );
  }
}

class _NodoConcepto extends StatelessWidget {
  const _NodoConcepto({
    required this.titulo,
    required this.subtotal,
    required this.icono,
    required this.porAno,
    required this.formato,
  });

  final String titulo;
  final double subtotal;
  final IconData icono;
  final Map<String, double> porAno;
  final String Function(double) formato;

  @override
  Widget build(BuildContext context) {
    final entradas = porAno.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.verdeOscuro.withValues(alpha: 0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(icono, color: AppColors.verdeOscuro),
          title: Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            formato(subtotal),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.verdeOscuro,
            ),
          ),
          children: entradas.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No se registran deudas por año.',
                      style: TextStyle(color: AppColors.grisMedio),
                    ),
                  ),
                ]
              : [
                  for (var i = 0; i < entradas.length; i++)
                    _FilaAno(
                      ano: entradas[i].key,
                      subtotal: entradas[i].value,
                      formato: formato,
                      primero: i == 0,
                    ),
                ],
        ),
      ),
    );
  }
}

class _FilaAno extends StatelessWidget {
  const _FilaAno({
    required this.ano,
    required this.subtotal,
    required this.formato,
    required this.primero,
  });

  final String ano;
  final double subtotal;
  final String Function(double) formato;
  final bool primero;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.grisClaro.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
            color: primero ? Colors.transparent : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Año $ano',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            formato(subtotal),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.verdeOscuro,
            ),
          ),
        ],
      ),
    );
  }
}
