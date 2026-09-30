import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../app_theme.dart';
import '../models/models.dart';
import '../models/cartera_contribuyente.dart';
import '../services/api_service.dart';
import '../services/busqueda_contribuyentes.dart';
import 'consultas_screen.dart';
import 'whatsapp_mensaje_dialog.dart';

const double _colId = 30;
const double _colCodigo = 82;
const double _colContribuyente = 176;
const double _colGps = 36;
const double _colDocumento = 68;
const double _colContacto = 44;
const double _colLlamada = 92;
const double _anchoTotal = _colId + _colCodigo + _colContribuyente + _colGps +
    _colDocumento * 2 + _colContacto * 2 + _colLlamada + 12;

/// Datos de una llamada capturados en el diálogo, listos para enviar.
class LlamadaDraft {
  LlamadaDraft({
    required this.resultado,
    required this.compromiso,
    this.fechaCompromiso,
    this.observaciones = '',
    required this.idempotencia,
    required this.fechaCaptura,
  });

  final String resultado;
  final String compromiso;
  final String? fechaCompromiso;
  final String observaciones;
  final String idempotencia;
  final String fechaCaptura;
}

class LlamadasScreen extends StatefulWidget {
  const LlamadasScreen({super.key});

  @override
  State<LlamadasScreen> createState() => _LlamadasScreenState();
}

class _LlamadasScreenState extends State<LlamadasScreen> {
  bool _cargandoIdentificadores = true;
  bool _cargandoCartera = false;
  bool _guardando = false;
  String? _errorIdentificadores;
  String? _errorCartera;

  List<IdentificadorOpRd> _identificadores = [];
  IdentificadorOpRd? _seleccionado;
  List<CarteraItem> _cartera = [];
  String _dni = '';
  final _busquedaCtrl = TextEditingController();

  final _horizontal = ScrollController();
  List<CarteraContribuyente> _gruposCache = [];
  List<CarteraContribuyente> get _grupos => _gruposCache;
  int _cargaVersion = 0;
  String? _fechaCargada;

  List<CarteraContribuyente> get _carteraFiltrada => _grupos
      .where((item) => coincideContribuyente(item.codigo, item.nombre, _busquedaCtrl.text))
      .toList();

  @override
  void dispose() {
    _cargaVersion++;
    _busquedaCtrl.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _cargarIdentificadores();
  }

  Future<void> _cargarIdentificadores() async {
    setState(() {
      _cargandoIdentificadores = true;
      _errorIdentificadores = null;
    });
    final prefs = await SharedPreferences.getInstance();
    _dni = prefs.getString('operador_dni') ?? '';
    try {
      final lista = await ApiService.obtenerIdentificadores();
      if (!mounted) return;
      setState(() {
        _identificadores = lista;
        _cargandoIdentificadores = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorIdentificadores = '$e';
        _cargandoIdentificadores = false;
      });
    }
  }

  Future<void> _cargarCartera(IdentificadorOpRd identificador) async {
    final version = ++_cargaVersion;
    setState(() {
      _cargandoCartera = true;
      _errorCartera = null;
      if (_fechaCargada != identificador.fecha) {
        _cartera = [];
        _gruposCache = [];
      }
    });
    try {
      final lista = await ApiService.obtenerCarteraAsignada(
        identificador.fecha,
        _dni,
        incluirSaldo: true,
        incluirLlamadas: true,
      );
      if (!mounted || version != _cargaVersion) return;
      setState(() {
        _cartera = lista;
        _gruposCache = agruparCartera(lista);
        _fechaCargada = identificador.fecha;
        _cargandoCartera = false;
      });
    } catch (e) {
      if (!mounted || version != _cargaVersion) return;
      setState(() {
        _errorCartera = '$e';
        _cargandoCartera = false;
      });
    }
  }

  Future<void> _finalizarLlamada(CarteraContribuyente grupo) async {
    if (_guardando) return;
    final previa = grupo.principal.llamada;
    final draft = await showDialog<LlamadaDraft>(
      context: context,
      builder: (_) => _DialogoLlamada(grupo: grupo, previa: previa),
    );
    if (draft == null || !mounted) return;
    setState(() => _guardando = true);
    try {
      await ApiService.registrarLlamada(
        id: grupo.principal.id,
        dni: _dni,
        resultado: draft.resultado,
        compromiso: draft.compromiso,
        fechaCompromiso: draft.fechaCompromiso,
        observaciones: draft.observaciones,
        idempotencia: draft.idempotencia,
        fechaCaptura: draft.fechaCaptura,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Llamada registrada correctamente.')),
      );
      if (_seleccionado != null) await _cargarCartera(_seleccionado!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisClaro,
      appBar: AppBar(
        title: const Text(
          'LLAMADAS A CONTRIBUYENTES',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        toolbarHeight: 40,
        titleSpacing: 12,
        actions: [
          IconButton(
            tooltip: 'Actualizar cartera',
            onPressed: _seleccionado == null || _cargandoCartera
                ? null
                : () => _cargarCartera(_seleccionado!),
            icon: const Icon(Icons.refresh),
          ),
        ],
        backgroundColor: AppColors.verdeOscuro,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildCombo(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _busquedaCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Código o nombre',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  prefixIconConstraints: const BoxConstraints(minWidth: 30),
                  suffixIcon: _busquedaCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() => _busquedaCtrl.clear()),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          Expanded(child: _buildCartera()),
          _buildEstadisticas(),
        ],
      ),
    );
  }

  Widget _buildCombo() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          const Text(
            'Identificador OP / RD',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.grisMedio,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _cargandoIdentificadores
                ? const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cargando identificadores...',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  )
                : _errorIdentificadores != null
                    ? Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.rojo,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _errorIdentificadores!,
                              style: const TextStyle(
                                color: AppColors.rojo,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: _cargarIdentificadores,
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              minimumSize: const Size(0, 30),
                            ),
                            child: const Text(
                              'Reintentar',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      )
                    : DropdownButtonFormField<IdentificadorOpRd>(
                        isExpanded: true,
                        initialValue: _seleccionado,
                        hint: const Text(
                          '-- Seleccione --',
                          style: TextStyle(fontSize: 12),
                        ),
                        items: _identificadores.map((id) {
                          return DropdownMenuItem<IdentificadorOpRd>(
                            value: id,
                            child: Text(
                              '${id.fecha} — OP: ${id.opTotal} | RD: ${id.rdTotal}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _seleccionado = value);
                          if (value != null) _cargarCartera(value);
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartera() {
    if (_seleccionado == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call, size: 48, color: AppColors.grisMedio),
            SizedBox(height: 12),
            Text(
              'Selecciona un identificador\npara ver la cartera de llamadas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.grisMedio),
            ),
          ],
        ),
      );
    }
    if (_cargandoCartera && _cartera.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.verdeOscuro),
            SizedBox(height: 12),
            Text('Cargando cartera...'),
          ],
        ),
      );
    }
    if (_errorCartera != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.rojo, size: 40),
              const SizedBox(height: 12),
              Text(
                _errorCartera!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.rojo),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _cargarCartera(_seleccionado!),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_cartera.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 48, color: AppColors.grisMedio),
            SizedBox(height: 12),
            Text(
              'No tienes cartera asignada\npara este identificador.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.grisMedio),
            ),
          ],
        ),
      );
    }
    final visibles = _carteraFiltrada;
    if (visibles.isEmpty) {
      return const Center(child: Text('No se encontraron coincidencias.'));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final ancho = math.max(_anchoTotal, constraints.maxWidth);
      final nombreAncho = _colContribuyente + ancho - _anchoTotal;
      return Scrollbar(
        controller: _horizontal,
        thumbVisibility: false,
        thickness: 3,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: ancho,
            height: constraints.maxHeight,
            child: Column(
              children: [
                _buildEncabezado(ancho, nombreAncho),
                Expanded(
                  child: ListView.builder(
                    itemCount: visibles.length,
                    itemBuilder: (context, index) =>
                        _buildFila(visibles[index], ancho, nombreAncho),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildEstadisticas() {
    final disponible =
        _seleccionado != null && !_cargandoCartera && _errorCartera == null;
    final contribuyentes = _cartera
        .map((item) => item.codContribuyente)
        .toSet()
        .length;
    final conLlamada =
        _grupos.where((g) => g.principal.llamada != null).length;
    final pagados = _grupos.where((g) => g.todosPagados).length;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.grisMedio, width: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ESTADÍSTICAS DEL IDENTIFICADOR',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 20,
              runSpacing: 6,
              children: [
                Text('N.º contribuyentes: ${disponible ? contribuyentes : "—"}'),
                Text('Con llamada registrada: ${disponible ? conLlamada : "—"}'),
                Text('Pagados (estado actual): ${disponible ? pagados : "—"}'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              disponible
                  ? '${_carteraFiltrada.length} de ${_grupos.length} contribuyentes · ${_cartera.length} documentos.'
                  : 'Seleccione un identificador para consultar el resumen.',
              style: const TextStyle(fontSize: 10, color: AppColors.grisMedio),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEncabezado(double ancho, double nombreAncho) => Container(
        width: ancho,
        color: AppColors.verdeOscuro,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            _celda('ID', _colId),
            _celda('CÓDIGO', _colCodigo),
            _celda('CONTRIBUYENTE', nombreAncho),
            _celda('GPS', _colGps),
            _celda('N.º OP', _colDocumento),
            _celda('N.º RD', _colDocumento),
            _celda('TEL.', _colContacto),
            _celda('WA', _colContacto),
            _celda('LLAMADA', _colLlamada),
          ],
        ),
      );

  Widget _celda(String texto, double ancho) => SizedBox(
      width: ancho,
      child: Text(texto,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)));

  Widget _buildFila(
      CarteraContribuyente grupo, double ancho, double nombreAncho) {
    final item = grupo.principal;
    final saldo = grupo.saldo;
    final sinDeuda = saldo != null && saldo <= 0.01;
    final pagado = grupo.todosPagados;
    final parcial = !pagado && grupo.algunoPagado;
    final fondo = sinDeuda || pagado
        ? const Color(0xFFE8F5E9)
        : parcial
            ? const Color(0xFFFFF8E1)
            : Colors.white;
    return Container(
      width: ancho,
      decoration: BoxDecoration(
        color: fondo,
        border: const Border(
            bottom: BorderSide(color: Color(0xFF9AA5AC), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _textoCelda('${item.id}', _colId),
          SizedBox(
            width: _colCodigo,
            child: InkWell(
              onTap: () => _verDeuda(grupo),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  grupo.codigo,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1565C0),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: nombreAncho,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(grupo.nombre,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  if (pagado)
                    const Text('PAGADA · estado actual verificado',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.verdeOscuro)),
                  if (parcial)
                    const Text('PAGO PARCIAL OP/RD',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8D6E00))),
                  if (item.direccion.isNotEmpty)
                    Text(item.direccion,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.grisMedio)),
                  if (item.direccionAdicional.isNotEmpty)
                    Text('* ${item.direccionAdicional}',
                        style: const TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: AppColors.grisMedio)),
                ],
              ),
            ),
          ),
          SizedBox(
            width: _colGps,
            child: IconButton(
              tooltip: 'Abrir en Google Maps',
              onPressed: item.direccion.isEmpty
                  ? null
                  : () => _abrirGoogleMaps(item.direccion),
              icon: const Icon(Icons.location_on, size: 20),
              color: AppColors.rojo,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minHeight: 40),
            ),
          ),
          _celdaDocumento(grupo, 'OP'),
          _celdaDocumento(grupo, 'RD'),
          SizedBox(
            width: _colContacto,
            child: IconButton(
              tooltip: grupo.telefonos.isEmpty ? 'Sin teléfono' : 'Llamar',
              onPressed: grupo.telefonos.isEmpty
                  ? null
                  : () => _contactar(grupo, false),
              icon: const Icon(Icons.call, size: 21),
              color: const Color(0xFF1565C0),
              disabledColor: Colors.grey,
            ),
          ),
          SizedBox(
            width: _colContacto,
            child: IconButton(
              tooltip: grupo.telefonos.isEmpty
                  ? 'Sin teléfono para WhatsApp'
                  : 'WhatsApp',
              onPressed: grupo.telefonos.isEmpty
                  ? null
                  : () => _contactar(grupo, true),
              icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 21),
              color: const Color(0xFF159C38),
              disabledColor: Colors.grey,
            ),
          ),
          SizedBox(width: _colLlamada, child: _celdaLlamada(grupo)),
        ],
      ),
    );
  }

  Widget _celdaLlamada(CarteraContribuyente grupo) {
    final ll = grupo.principal.llamada;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: _guardando
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FilledButton.icon(
              onPressed: () => _finalizarLlamada(grupo),
              style: FilledButton.styleFrom(
                backgroundColor: ll != null
                    ? const Color(0xFF1565C0)
                    : AppColors.verdeOscuro,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(ll != null ? Icons.edit : Icons.call, size: 16),
              label: Text(ll != null ? 'Editar' : 'Finalizar',
                  style: const TextStyle(fontSize: 10)),
            ),
    );
  }

  /// Consulta la deuda del contribuyente (igual que la grilla OP/RD) y al
  /// volver recarga la cartera de llamadas.
  Future<void> _verDeuda(CarteraContribuyente grupo) async {
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consultar deuda'),
        content: Text('¿Desea ver la información de deudas de ${grupo.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SÍ'),
          ),
        ],
      ),
    );
    if (aceptar != true || !mounted) return;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ConsultasScreen(codigoInicial: grupo.codigo)));
    if (mounted && _seleccionado != null) await _cargarCartera(_seleccionado!);
  }

  /// Llama al contribuyente o abre WhatsApp con la información de su deuda,
  /// igual que la grilla OP/RD: si hay más de un número permite elegirlo.
  Future<void> _contactar(CarteraContribuyente grupo, bool whatsapp) async {
    final numeros = grupo.telefonos;
    if (numeros.isEmpty) return;
    String? numero = numeros.first;
    if (numeros.length > 1) {
      numero = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(
              whatsapp ? 'Elegir número para WhatsApp' : 'Elegir número para llamar'),
          children: [
            for (final n in numeros)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, n),
                child: Padding(padding: const EdgeInsets.all(8), child: Text(n)),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
          ],
        ),
      );
    }
    if (numero == null || !mounted) return;
    try {
      if (whatsapp) {
        final prefs = await SharedPreferences.getInstance();
        final operador = (prefs.getString('operador_nombre') ?? '').trim();
        if (operador.isEmpty) {
          throw Exception(
              'Vuelva a iniciar sesión para cargar el nombre del operador.');
        }
        if (!mounted) return;
        final mensaje = await showDialog<String>(
          context: context,
          builder: (_) => WhatsappMensajeDialog(
            grupo: grupo,
            operador: operador,
            modoLlamada: true,
            cargarImportes: () =>
                ApiService.importesWhatsapp(grupo.principal.id, _dni),
          ),
        );
        if (mensaje == null || !mounted) return;
        var destino = numero.replaceAll('+', '');
        if (!numero.startsWith('+')) {
          // Números fijos peruanos con prefijo nacional.
          if (destino.startsWith('0')) destino = '51${destino.substring(1)}';
          else if (destino.length == 6) destino = '5142$destino';
        }
        if (!await launchUrl(Uri.https('wa.me', '/$destino', {'text': mensaje}),
            mode: LaunchMode.externalApplication)) {
          throw Exception('No se pudo abrir WhatsApp.');
        }
      } else {
        await const MethodChannel('sat/contacto')
            .invokeMethod<void>('llamar', {'numero': numero});
      }
    } catch (e) {
      if (!mounted) return;
      final mensaje = e is PlatformException
          ? e.message ?? 'No se pudo iniciar la llamada.'
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  void _abrirGoogleMaps(String direccion) {
    if (direccion.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay dirección registrada.')),
      );
      return;
    }
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      {'api': '1', 'query': '$direccion, Tarapoto, Perú'},
    );
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _celdaDocumento(CarteraContribuyente grupo, String tipo) {
    final docs = grupo.documentosPorTipo(tipo);
    if (docs.isEmpty) return _textoCelda('—', _colDocumento);
    final numeros = grupo.numeros(tipo);
    final pagada = docs.every((d) => d.pagada);
    final pendientes = docs.fold<int>(0, (a, d) => a + d.cuotasPendientes);
    final total = docs.fold<int>(0, (a, d) => a + d.cuotasTotal);
    return SizedBox(
      width: _colDocumento,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(numeros, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 2),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: pagada
                    ? AppColors.verdeOscuro
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                pagada
                    ? 'PAGADA'
                    : total > 0
                        ? '$pendientes/$total pend.'
                        : 'PENDIENTE',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: pagada ? Colors.white : AppColors.grisMedio,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textoCelda(String texto, double ancho) => SizedBox(
        width: ancho,
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(texto, style: const TextStyle(fontSize: 11)),
        ),
      );
}

/// Diálogo de resultado de llamada: situación (Atendida / No contestada /
/// Número no existe) y, si fue atendida, el compromiso y la fecha en que
/// vendrá a pagar. Observaciones con dictado por voz (micrófono).
/// Devuelve un [LlamadaDraft] o null si se cancela.
class _DialogoLlamada extends StatefulWidget {
  const _DialogoLlamada({required this.grupo, this.previa});

  final CarteraContribuyente grupo;
  final LlamadaInfo? previa;

  @override
  State<_DialogoLlamada> createState() => _DialogoLlamadaState();
}

class _DialogoLlamadaState extends State<_DialogoLlamada> {
  late String _resultado;
  late String _compromiso;
  DateTime? _fecha;
  final _observaciones = TextEditingController();

  final _stt = SpeechToText();
  bool _escuchando = false;
  String? _sttError;
  String _textoBase = '';

  @override
  void initState() {
    super.initState();
    final previo = widget.previa;
    _resultado = previo?.resultado.isNotEmpty == true
        ? previo!.resultado
        : 'Atendida';
    _compromiso = previo?.compromiso.isNotEmpty == true
        ? previo!.compromiso
        : 'Vendra a pagar';
    if (previo?.fechaCompromiso.isNotEmpty == true) {
      _fecha = DateTime.tryParse(previo!.fechaCompromiso);
    }
    _observaciones.text = previo?.observaciones ?? '';
  }

  @override
  void dispose() {
    _observaciones.dispose();
    _stt.stop();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final now = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Fecha en que vendrá a pagar',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  /// Inicia/detiene el dictado por voz de las observaciones.
  Future<void> _escuchar() async {
    if (_escuchando) {
      await _stt.stop();
      if (mounted) setState(() => _escuchando = false);
      return;
    }
    try {
      final disponible = await _stt.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _escuchando = status == 'listening');
        },
        onError: (error) {
          if (mounted) setState(() => _sttError = error.errorMsg);
        },
      );
      if (!disponible) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Reconocimiento de voz no disponible en este equipo.')));
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _textoBase = _observaciones.text.trim();
        _sttError = null;
        _escuchando = true;
      });
      await _stt.listen(
        onResult: (result) {
          if (!mounted) return;
          final dictado = result.recognizedWords.trim();
          setState(() {
            _observaciones.text = dictado.isEmpty
                ? _textoBase
                : (_textoBase.isEmpty ? dictado : '$_textoBase $dictado');
          });
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          listenFor: Duration(seconds: 30),
          pauseFor: Duration(seconds: 4),
          cancelOnError: true,
          localeId: 'es_PE',
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _sttError = e.message ?? 'No se pudo iniciar el dictado.');
    }
  }

  String get _fechaTexto {
    final f = _fecha;
    if (f == null) return '';
    return '${f.day.toString().padLeft(2, '0')}/'
        '${f.month.toString().padLeft(2, '0')}/${f.year}';
  }

  String get _fechaIso {
    final f = _fecha;
    if (f == null) return '';
    return '${f.year.toString().padLeft(4, '0')}-'
        '${f.month.toString().padLeft(2, '0')}-'
        '${f.day.toString().padLeft(2, '0')}';
  }

  void _guardar() {
    if (_resultado == 'Atendida') {
      if (_compromiso == 'Vendra a pagar' && _fecha == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccione la fecha en que vendrá a pagar.')),
        );
        return;
      }
    } else {
      _compromiso = '';
    }
    Navigator.of(context).pop(LlamadaDraft(
      resultado: _resultado,
      compromiso: _resultado == 'Atendida' ? _compromiso : '',
      fechaCompromiso: _compromiso == 'Vendra a pagar' ? _fechaIso : null,
      observaciones: _observaciones.text.trim(),
      idempotencia: const Uuid().v4(),
      fechaCaptura: DateTime.now().toIso8601String(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final grupo = widget.grupo;
    return AlertDialog(
      title: const Text('Resultado de la llamada',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${grupo.codigo} — ${grupo.nombre}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(grupo.principal.direccion,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.grisMedio)),
            const Divider(height: 20),
            const Text('¿EN QUÉ SITUACIÓN QUEDÓ LA LLAMADA?',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            RadioGroup<String>(
              groupValue: _resultado,
              onChanged: (v) => setState(() {
                if (v != null) _resultado = v;
              }),
              child: Column(
                children: [
                  for (final r in ApiService.resultadosLlamada)
                    RadioListTile<String>(
                      value: r,
                      title: Text(_etiquetaResultado(r),
                          style: const TextStyle(fontSize: 12)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            if (_resultado == 'Atendida') ...[
              const SizedBox(height: 4),
              const Text('¿QUÉ DIJO EL CONTRIBUYENTE?',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              RadioGroup<String>(
                groupValue: _compromiso,
                onChanged: (v) => setState(() {
                  if (v != null) _compromiso = v;
                }),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: 'Vendra a pagar',
                      title: const Text('Dijo que vendrá a pagar',
                          style: TextStyle(fontSize: 12)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      value: 'No acepta la deuda',
                      title: const Text('Dijo que no acepta la deuda',
                          style: TextStyle(fontSize: 12)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              if (_compromiso == 'Vendra a pagar') ...[
                const SizedBox(height: 8),
                const Text('FECHA EN QUE VENDRÁ A PAGAR',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _elegirFecha,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFF9AA5AC)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _fechaTexto.isEmpty
                              ? 'Tocar para elegir fecha'
                              : _fechaTexto,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _fecha == null
                                ? FontWeight.w400
                                : FontWeight.w700,
                            color: _fecha == null
                                ? AppColors.grisMedio
                                : AppColors.verdeOscuro,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            const Text('OBSERVACIONES (opcional)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            TextField(
              controller: _observaciones,
              maxLines: 3,
              maxLength: 2000,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Comentario de la llamada...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _escuchando ? 'Detener dictado' : 'Dictar por voz',
                  iconSize: 30,
                  onPressed: _escuchar,
                  icon: Icon(
                    _escuchando ? Icons.mic : Icons.mic_none,
                    color: _escuchando ? AppColors.rojo : AppColors.verdeOscuro,
                  ),
                ),
              ),
            ),
            if (_escuchando)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Escuchando... hable ahora. Toque el micrófono para detener.',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.rojo)),
                    ),
                  ],
                ),
              )
            else if (_sttError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _sttError!,
                  style: const TextStyle(fontSize: 11, color: AppColors.rojo),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        FilledButton.icon(
          onPressed: _guardar,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('GUARDAR'),
        ),
      ],
    );
  }

  String _etiquetaResultado(String r) => switch (r) {
        'Atendida' => 'Atendida',
        'No contestada' => 'No contestada',
        'Numero no existe' => 'Número no existe',
        _ => r,
      };
}