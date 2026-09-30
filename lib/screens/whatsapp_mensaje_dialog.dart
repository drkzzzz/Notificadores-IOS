import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cartera_contribuyente.dart';

String mensajeWhatsapp({required String operador, required CarteraContribuyente grupo,
  double? op, double? rd, double? total, bool horario = false, String consultado = '', bool modoLlamada = false}) {
  final tipos = ['OP', 'RD'].where((t) => grupo.documentos.any((d) => d.tipo.toUpperCase() == t)).join(' / ');
  final dinero = NumberFormat('#,##0.00', 'en_US');
  final lineas = <String>[
    'Hola, soy $operador, trabajador del SAT-T.',
    if (modoLlamada)
      'Estimado(a): ${grupo.nombre}, por este medio se le hace llegar la información de su deuda.'
    else
      'Estimado(a): ${grupo.nombre}, acabamos de entregarle una notificación de ${tipos.isEmpty ? "OP / RD" : tipos} a su domicilio.',
  ];
  if (op != null) lineas.add('Deuda OP (según documentos notificados): S/ ${dinero.format(op)}.');
  if (rd != null) lineas.add('Deuda RD (según documentos notificados): S/ ${dinero.format(rd)}.');
  if (total != null) lineas.add('Deuda total actual de predial y arbitrios: S/ ${dinero.format(total)}.${consultado.isEmpty ? "" : " Consultada: $consultado."}');
  if (horario) lineas.add('Cualquier duda, acercarse a nuestras oficinas de L-V de 8:00 am a 5:00 pm y S de 9:00 am a 12:00 pm.');
  return lineas.join('\n\n');
}

class WhatsappMensajeDialog extends StatefulWidget {
  const WhatsappMensajeDialog({super.key, required this.grupo, required this.operador, required this.cargarImportes, this.modoLlamada = false});
  final CarteraContribuyente grupo;
  final String operador;
  final bool modoLlamada;
  final Future<Map<String, dynamic>> Function() cargarImportes;
  @override
  State<WhatsappMensajeDialog> createState() => _WhatsappMensajeDialogState();
}

class _WhatsappMensajeDialogState extends State<WhatsappMensajeDialog> {
  bool _op = false, _rd = false, _total = false, _horario = false, _cargando = true;
  Map<String, dynamic> _importes = {};
  String? _error;
  double? _monto(String campo) {
    final valor = double.tryParse(_importes[campo]?.toString() ?? '');
    return valor != null && valor.isFinite && valor >= 0 ? valor : null;
  }
  @override
  void initState() { super.initState(); _cargar(); }
  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final datos = await widget.cargarImportes();
      if (mounted) setState(() => _importes = datos);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron consultar los importes. Puede reintentar o continuar sin incluir deuda.');
    } finally { if (mounted) setState(() => _cargando = false); }
  }
  String get _mensaje => mensajeWhatsapp(operador: widget.operador, grupo: widget.grupo,
    op: _op ? _monto('op') : null, rd: _rd ? _monto('rd') : null, total: _total ? _monto('total') : null,
    horario: _horario, consultado: _importes['consultado']?.toString() ?? '', modoLlamada: widget.modoLlamada);
  Widget _opcion(String clave, String titulo, bool valor, ValueChanged<bool> cambiar) {
    final monto = _monto(clave);
    return CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(titulo),
      subtitle: Text(_cargando ? 'Consultando…' : monto == null ? 'Importe no disponible' : 'S/ ${NumberFormat('#,##0.00', 'en_US').format(monto)}', style: const TextStyle(fontSize: 11)),
      value: valor, onChanged: _cargando || monto == null ? null : (v) => setState(() => cambiar(v ?? false)));
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mensaje de WhatsApp'),
    content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.modoLlamada ? 'El saludo y el aviso se incluyen siempre.' : 'El saludo y aviso de entrega se incluyen siempre.', style: const TextStyle(fontSize: 12)),
      _opcion('op', 'Incluir deuda OP', _op, (v) => _op = v),
      _opcion('rd', 'Incluir deuda RD', _rd, (v) => _rd = v),
      _opcion('total', 'Incluir deuda total', _total, (v) => _total = v),
      CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Incluir horario de atención'), value: _horario, onChanged: (v) => setState(() => _horario = v ?? false)),
      if (_error != null) ...[Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)), TextButton(onPressed: _cargar, child: const Text('REINTENTAR'))],
      const Divider(), const Text('Vista previa', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
      SelectableText(_mensaje, style: const TextStyle(fontSize: 13)),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
      FilledButton(onPressed: () => Navigator.pop(context, _mensaje), child: const Text('ABRIR WHATSAPP'))],
  );
}