
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../services/cartera_ubicaciones.dart';
import 'cartera_mapa_screen.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../models/models.dart';
import '../models/cartera_contribuyente.dart';
import '../services/pendientes_service.dart';
import '../services/upload_service.dart';
import 'consultas_screen.dart';
import '../services/api_service.dart';
import '../services/busqueda_contribuyentes.dart';
import 'finalizar_notificacion_screen.dart';
import 'whatsapp_mensaje_dialog.dart';

const double _colId = 30;
const double _colCodigo = 82;
const double _colContribuyente = 176;
const double _colGps = 36;
const double _colDocumento = 68;
const double _colContacto = 44;
const double _colEntregado = 84;
const double _colModificar = 52;
const double _colEstado = 108;
const double _anchoTotal = _colId + _colCodigo + _colContribuyente + _colGps +
    _colDocumento * 2 + _colContacto * 2 + _colEntregado + _colModificar + _colEstado + 12;

class CarteraOpRdScreen extends StatefulWidget {
  const CarteraOpRdScreen({super.key});

  @override
  State<CarteraOpRdScreen> createState() => _CarteraOpRdScreenState();
}

class _CarteraOpRdScreenState extends State<CarteraOpRdScreen> {
  bool _cargandoIdentificadores = true;
  bool _cargandoCartera = false;
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
  final _ubicaciones = CarteraUbicaciones();
  final Map<String, UbicacionCartera> _puntos = {};
  LatLng? _miPosicion;
  bool _porCercania = false, _ubicando = false, _detenerUbicacion = false;
  bool _saldosCargando = false;
  String? _saldoError;
  int _cargaVersion = 0, _ubicados = 0;
  String? _fechaCargada;
  Map<int, Pendiente> _pendientes = {};
  bool _sincronizando = false;
  StreamSubscription<List<ConnectivityResult>>? _subRed;
  List<CarteraContribuyente> get _carteraFiltrada {
    final filtrados = _grupos.where((item) => coincideContribuyente(item.codigo, item.nombre, _busquedaCtrl.text)).toList();
    return _porCercania && _miPosicion != null ? ordenarPorDistancia(filtrados, _miPosicion!, _puntos) : filtrados;
  }

  @override
  void dispose() {
    _cargaVersion++;
    _detenerUbicacion = true;
    _subRed?.cancel();
    _busquedaCtrl.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _cargarIdentificadores();
    // Reintento automático al recuperar conexión.
    _subRed = UploadService.escucharCambios(() async {
      if (_seleccionado == null) return;
      await _sincronizarPendientes(aviso: true);
    });
  }

  /// Sube los pendientes y refresca la vista.
  Future<void> _sincronizarPendientes({bool aviso = false}) async {
    if (_sincronizando || _seleccionado == null) return;
    _sincronizando = true;
    try {
      final resumen = await UploadService.sincronizar();
      await _cargarPendientes();
      if (!mounted) return;
      if (resumen.subidos > 0) {
        await _cargarCartera(_seleccionado!);
        if (!mounted) return;
      }
      if (aviso && mounted && (resumen.subidos > 0 || resumen.fallidos > 0)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Sincronizados: ${resumen.subidos}. Fallidos: ${resumen.fallidos}.')));
      }
    } finally {
      _sincronizando = false;
    }
  }

  Future<void> _cargarPendientes() async {
    final fecha = _seleccionado?.fecha;
    if (fecha == null || fecha.isEmpty) {
      if (mounted) setState(() => _pendientes = {});
      return;
    }
    try {
      final lista = await PendientesService.porIdentificador(fecha);
      if (!mounted) return;
      setState(() {
        _pendientes = {for (final p in lista) p.carteraItemId: p};
      });
    } catch (_) {}
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
      _cargandoCartera = true; _errorCartera = null; _saldoError = null;
      _saldosCargando = false; _detenerUbicacion = true;
      if (_fechaCargada != identificador.fecha) {
        _cartera = []; _gruposCache = []; _puntos.clear(); _porCercania = false;
      }
    });
    try {
      final lista = await ApiService.obtenerCarteraAsignada(identificador.fecha, _dni, incluirSaldo: false);
      if (!mounted || version != _cargaVersion) return;
      setState(() {
        _cartera = lista; _gruposCache = agruparCartera(lista); _fechaCargada = identificador.fecha;
        _cargandoCartera = false; _saldosCargando = lista.isNotEmpty;
      });
      await _cargarPendientes();
      // Si había pendientes listos, se intentan subir y se refresca.
      _sincronizarPendientes();
      if (lista.isNotEmpty) _actualizarSaldos(identificador, version);
    } catch (e) {
      if (!mounted || version != _cargaVersion) return;
      setState(() { _errorCartera = '$e'; _cargandoCartera = false; });
      // Sin conexión igual se muestran los pendientes guardados.
      await _cargarPendientes();
    }
  }

  Future<void> _actualizarSaldos(IdentificadorOpRd identificador, int version) async {
    try {
      final lista = await ApiService.obtenerCarteraAsignada(identificador.fecha, _dni);
      if (!mounted || version != _cargaVersion) return;
      setState(() { _cartera = lista; _gruposCache = agruparCartera(lista); _saldosCargando = false; });
    } catch (_) {
      if (mounted && version == _cargaVersion) setState(() {
        _saldosCargando = false; _saldoError = 'No se pudo actualizar la deuda. Pulse actualizar para reintentar.';
      });
    }
  }

  Future<void> _cercania({bool mapa = false}) async {
    if (_ubicando || _carteraFiltrada.isEmpty) return;
    final version = _cargaVersion;
    final grupos = _carteraFiltrada;
    setState(() { _ubicando = true; _detenerUbicacion = false; _ubicados = 0; });
    try {
      final origen = await _ubicaciones.miUbicacion();
      if (!mounted || version != _cargaVersion) return;
      _miPosicion = origen;
      if (mapa) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => CarteraMapaScreen(grupos: grupos, origen: origen, servicio: _ubicaciones, puntos: _puntos)));
      } else {
        for (final grupo in grupos) {
          if (!mounted || version != _cargaVersion || _detenerUbicacion) break;
          final punto = await _ubicaciones.localizar(grupo);
          if (!mounted || version != _cargaVersion) return;
          setState(() { _ubicados++; if (punto != null) _puntos[grupo.codigo] = punto; _porCercania = true; });
        }
        if (mounted && version == _cargaVersion) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ordenados por distancia en línea recta. ${grupos.where((g) => !_puntos.containsKey(g.codigo)).length} sin ubicación quedan al final.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        e is PlatformException ? e.message ?? 'No se pudo obtener la ubicación.' : e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _ubicando = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisClaro,
      appBar: AppBar(
        title: const Text(
          'CARTERA OP/RD',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        toolbarHeight: 40,
        titleSpacing: 12,
        actions: [IconButton(tooltip: 'Actualizar cartera y deuda',
          onPressed: _seleccionado == null || _cargandoCartera ? null : () => _cargarCartera(_seleccionado!),
          icon: const Icon(Icons.refresh))],
        backgroundColor: AppColors.verdeOscuro,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildCombo(),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              Expanded(child: SizedBox(height: 36, child: TextField(
                controller: _busquedaCtrl, onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(isDense: true, hintText: 'Código o nombre',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  prefixIconConstraints: const BoxConstraints(minWidth: 30),
                  suffixIcon: _busquedaCtrl.text.isEmpty ? null : IconButton(tooltip: 'Limpiar búsqueda', icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _busquedaCtrl.clear())),
                  border: const OutlineInputBorder()),
              ))),
              const SizedBox(width: 4),
              IconButton(visualDensity: VisualDensity.compact, tooltip: 'Ordenar por cercanía',
                onPressed: _ubicando || _carteraFiltrada.isEmpty ? null : () => _cercania(),
                icon: Icon(Icons.near_me_outlined, color: _porCercania ? AppColors.verdeOscuro : null)),
              IconButton(visualDensity: VisualDensity.compact, tooltip: 'Mapa de contribuyentes',
                onPressed: _ubicando || _carteraFiltrada.isEmpty ? null : () => _cercania(mapa: true), icon: const Icon(Icons.map_outlined)),
            ])),
          if (_ubicando) Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(children: [
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8), Expanded(child: Text('Localizando $_ubicados/${_carteraFiltrada.length}…', style: const TextStyle(fontSize: 11))),
            TextButton(onPressed: () => setState(() => _detenerUbicacion = true), child: const Text('Detener')),
          ])),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
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
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
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
            Icon(Icons.folder_open, size: 48, color: AppColors.grisMedio),
            SizedBox(height: 12),
            Text(
              'Selecciona un identificador\npara ver la cartera asignada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.grisMedio,
              ),
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
          child: SizedBox(width: ancho, height: constraints.maxHeight,
            child: Column(children: [
              _buildEncabezado(ancho, nombreAncho),
              Expanded(child: ListView.builder(itemCount: visibles.length,
                itemBuilder: (context, index) => _buildFilaCartera(visibles[index], ancho, nombreAncho))),
            ]),
          ),
        ),
      );
    });
  }

  Widget _buildEstadisticas() {
    final disponible = _seleccionado != null && !_cargandoCartera && _errorCartera == null;
    final contribuyentes = _cartera.map((item) => item.codContribuyente).toSet().length;
    final notificados = _cartera.where((item) => item.entregado)
        .map((item) => item.codContribuyente).toSet().length;
    final pagados = _grupos.where((g) => g.todosPagados).length;
    final totalPendientes = _pendientes.length;
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
                Text('N.º notificados: ${disponible ? notificados : "—"}'),
                Text('Pagados (estado actual): ${disponible ? pagados : "—"}'),
                Text('Pendientes de envío: ${disponible ? totalPendientes : "—"}'),
              ],
            ),
            if (_saldosCargando) const Text('Actualizando saldos… Puede usar la cartera mientras tanto.', style: TextStyle(fontSize: 10, color: AppColors.grisMedio)),
            if (_saldoError != null) Text(_saldoError!, style: const TextStyle(fontSize: 10, color: Colors.red)),
            const SizedBox(height: 4),
            Text(disponible
                ? '${_carteraFiltrada.length} de ${_grupos.length} contribuyentes · ${_cartera.length} documentos. Notificados: al menos una entrega.'
                : 'Seleccione un identificador para consultar el resumen.',
                style: const TextStyle(fontSize: 10, color: AppColors.grisMedio)),
          ],
        ),
      ),
    );
  }


  Future<void> _verDeuda(CarteraContribuyente grupo) async {
    final aceptar = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Consultar deuda'),
      content: Text('¿Desea ver la información de deudas de ${grupo.nombre}?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NO')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('SÍ'))],
    ));
    if (aceptar != true || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ConsultasScreen(codigoInicial: grupo.codigo)));
    if (mounted && _seleccionado != null) await _cargarCartera(_seleccionado!);
  }

  Future<void> _contactar(CarteraContribuyente grupo, bool whatsapp) async {
    final numeros = grupo.telefonos;
    if (numeros.isEmpty) return;
    String? numero = numeros.first;
    if (numeros.length > 1) {
      numero = await showDialog<String>(context: context, builder: (context) => SimpleDialog(
        title: Text(whatsapp ? 'Elegir número para WhatsApp' : 'Elegir número para llamar'),
        children: [for (final n in numeros) SimpleDialogOption(onPressed: () => Navigator.pop(context, n),
          child: Padding(padding: const EdgeInsets.all(8), child: Text(n))),
          SimpleDialogOption(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR'))],
      ));
    }
    if (numero == null || !mounted) return;
    try {
      if (whatsapp) {
        final prefs = await SharedPreferences.getInstance();
        final operador = (prefs.getString('operador_nombre') ?? '').trim();
        if (operador.isEmpty) throw Exception('Vuelva a iniciar sesión para cargar el nombre del operador.');
        if (!mounted) return;
        final mensaje = await showDialog<String>(context: context, builder: (_) => WhatsappMensajeDialog(
          grupo: grupo, operador: operador, cargarImportes: () => ApiService.importesWhatsapp(grupo.principal.id, _dni)));
        if (mensaje == null || !mounted) return;
        var destino = numero.replaceAll('+', '');
        if (!numero.startsWith('+')) {
          // Números fijos peruanos con prefijo nacional.
          if (destino.startsWith('0')) destino = '51${destino.substring(1)}';
          else if (destino.length == 6) destino = '5142$destino';
        }
        if (!await launchUrl(Uri.https('wa.me', '/$destino', {'text': mensaje}), mode: LaunchMode.externalApplication)) {
          throw Exception('No se pudo abrir WhatsApp.');
        }
      } else {
        await const MethodChannel('sat/contacto').invokeMethod<void>('llamar', {'numero': numero});
      }
    } catch (e) {
      if (!mounted) return;
      final mensaje = e is PlatformException ? e.message ?? 'No se pudo iniciar la llamada.' : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  Future<void> _entregarGrupo(CarteraContribuyente grupo) async {
    if (grupo.pendientes.isEmpty) return;
    final fecha = _seleccionado?.fecha ?? '';
    final resultado = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FinalizarNotificacionScreen(
        item: grupo.pendientes.first,
        dni: _dni,
        pagado: grupo.todosPagados,
        fechaIdentificador: fecha,
      ),
    ));
    if (resultado == true && mounted && _seleccionado != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resultado de entrega registrado.')));
      _cargarCartera(_seleccionado!);
    }
  }

  /// Continúa un pendiente (borrador o incompleto) con todo precargado.
  Future<void> _continuarPendiente(
      CarteraContribuyente grupo, Pendiente pendiente) async {
    final fecha = _seleccionado?.fecha ?? '';
    final resultado = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FinalizarNotificacionScreen(
          item: grupo.principal,
          dni: _dni,
          pagado: grupo.todosPagados || pendiente.pagado,
          pendiente: pendiente,
          fechaIdentificador: fecha),
    ));
    if (resultado == true && mounted && _seleccionado != null) {
      _cargarCartera(_seleccionado!);
    }
  }

  /// Reintenta subir un pendiente listo o con error anterior.
  Future<void> _reintentarPendiente(Pendiente pendiente) async {
    if (!await UploadService.hayConexion()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sin conexión. Queda pendiente de envío.')));
      return;
    }
    final ok = await UploadService.intentar(pendiente);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Entrega enviada correctamente.'
            : 'No se pudo enviar: ${pendiente.ultimoError}')));
    if (_seleccionado != null) _cargarCartera(_seleccionado!);
  }

  /// Modifica una entrega ya grabada (o pendiente) sin crear un registro
  /// nuevo. Abre la pantalla en modo edición; para grupos pagados solo
  /// permite foto del domicilio + GPS (Finalizado).
  Future<void> _modificarGrupo(CarteraContribuyente grupo) async {
    final fecha = _seleccionado?.fecha ?? '';
    final resultado = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FinalizarNotificacionScreen(
        item: grupo.principal,
        dni: _dni,
        esEdicion: true,
        pagado: grupo.todosPagados,
        fechaIdentificador: fecha,
      ),
    ));
    if (resultado == true && mounted && _seleccionado != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrega modificada correctamente.')));
      _cargarCartera(_seleccionado!);
    }
  }

  Widget _buildEncabezado(double ancho, double nombreAncho) => Container(
    width: ancho, color: AppColors.verdeOscuro,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    child: Row(children: [
      _celda('ID', _colId), _celda('CÓDIGO', _colCodigo), _celda('CONTRIBUYENTE', nombreAncho),
      _celda('GPS', _colGps), _celda('N.º OP', _colDocumento), _celda('N.º RD', _colDocumento),
      _celda('TEL.', _colContacto), _celda('WA', _colContacto),
      _celda('ENTREGA', _colEntregado), _celda('MODIF.', _colModificar), _celda('ESTADO', _colEstado),
    ]),
  );

  Widget _celda(String texto, double ancho) => SizedBox(width: ancho, child: Text(texto,
    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)));

  Widget _buildFilaCartera(CarteraContribuyente grupo, double ancho, double nombreAncho) {
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
    return Container(width: ancho,
      decoration: BoxDecoration(color: fondo,
        border: const Border(bottom: BorderSide(color: Color(0xFF9AA5AC), width: 1))),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _textoCelda('${item.id}', _colId),
        SizedBox(width: _colCodigo, child: InkWell(onTap: () => _verDeuda(grupo),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(grupo.codigo,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1565C0), decoration: TextDecoration.underline))))),
        SizedBox(width: nombreAncho, child: Padding(padding: const EdgeInsets.only(right: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(grupo.nombre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            if (pagado) const Text('PAGADA · estado actual verificado',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.verdeOscuro)),
            if (parcial) const Text('PAGO PARCIAL OP/RD',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF8D6E00))),
            if (_porCercania && _miPosicion != null) Text(_puntos[grupo.codigo] == null ? 'Sin ubicación' : '${distanciaTexto(distanciaMetros(_miPosicion!, _puntos[grupo.codigo]!.punto))}${_puntos[grupo.codigo]!.aproximada ? " · aproximado" : " · GPS"}', style: const TextStyle(fontSize: 10, color: Color(0xFF1565C0))),
            if (item.direccion.isNotEmpty) Text(item.direccion, style: const TextStyle(fontSize: 10, color: AppColors.grisMedio)),
            if (item.direccionAdicional.isNotEmpty) Text('* ${item.direccionAdicional}',
              style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.grisMedio)),
          ]))),
        SizedBox(width: _colGps, child: IconButton(tooltip: 'Abrir en Google Maps',
          onPressed: item.direccion.isEmpty ? null : () => _abrirGoogleMaps(item.direccion),
          icon: const Icon(Icons.location_on, size: 20), color: AppColors.rojo,
          padding: EdgeInsets.zero, constraints: const BoxConstraints(minHeight: 40))),
        _celdaDocumento(grupo, 'OP'),
        _celdaDocumento(grupo, 'RD'),
        SizedBox(width: _colContacto, child: IconButton(tooltip: grupo.telefonos.isEmpty ? 'Sin teléfono' : 'Llamar',
          onPressed: grupo.telefonos.isEmpty ? null : () => _contactar(grupo, false),
          icon: const Icon(Icons.call, size: 21), color: const Color(0xFF1565C0), disabledColor: Colors.grey)),
        SizedBox(width: _colContacto, child: IconButton(tooltip: grupo.telefonos.isEmpty ? 'Sin teléfono para WhatsApp' : 'WhatsApp',
          onPressed: grupo.telefonos.isEmpty ? null : () => _contactar(grupo, true),
          icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 21), color: const Color(0xFF159C38), disabledColor: Colors.grey)),
        SizedBox(width: _colEntregado, child: _celdaEntrega(grupo)),
        SizedBox(width: _colModificar, child: IconButton(tooltip: 'Modificar entrega',
          onPressed: () => _modificarGrupo(grupo),
          icon: const Icon(Icons.edit_document, size: 21), color: const Color(0xFFE65100),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(minHeight: 40))),
        SizedBox(width: _colEstado, child: Tooltip(
          message: 'Saldo predial/arbitrios y estado actual OP/RD verificado en API. Consultado: ${item.estadoConsultado}. Use actualizar para revisar pagos recientes.',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(saldo == null ? (_saldosCargando ? 'ACTUALIZANDO' : 'SIN CONSULTAR') : sinDeuda ? 'SIN DEUDA' : 'CON DEUDA',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                color: saldo == null ? Colors.grey : sinDeuda ? AppColors.verdeOscuro : AppColors.rojo)),
            if (saldo != null) Text('S/ ${math.max(0, saldo).toStringAsFixed(2)}', style: const TextStyle(fontSize: 10)),
            const Text('Predial / arbitrios', style: TextStyle(fontSize: 9, color: AppColors.grisMedio)),
            Text(pagado ? 'OP/RD: PAGADA' : parcial ? 'OP/RD: PARCIAL' : 'OP/RD: PENDIENTE',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                color: pagado ? AppColors.verdeOscuro : parcial ? const Color(0xFF8D6E00) : AppColors.grisMedio)),
          ]))),
      ]),
    );
  }

  /// Celda de entrega: normal (Entregar/Finalizar o condición ya registrada),
  /// o pendiente de envío (continuar/reintentar).
  Widget _celdaEntrega(CarteraContribuyente grupo) {
    final item = grupo.principal;
    final pagado = grupo.todosPagados;
    final pendiente = _pendientes[item.id];
    if (pendiente != null) {
      final listo = pendiente.estado == EstadoPendiente.listo ||
          pendiente.estado == EstadoPendiente.error;
      return Tooltip(
        message: pendiente.estado == EstadoPendiente.error &&
                pendiente.ultimoError.isNotEmpty
            ? pendiente.ultimoError
            : 'Pendiente de envío guardado en el equipo',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PENDIENTE',
                style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w800)),
            Text(
                pendiente.estado == EstadoPendiente.error
                    ? 'Error de envío'
                    : (pendiente.completo
                        ? 'Listo para enviar'
                        : 'Incompleto'),
                style:
                    const TextStyle(fontSize: 9, color: AppColors.grisMedio)),
            if (pendiente.pagado)
              const Text('FINALIZADO',
                  style: TextStyle(
                      fontSize: 9,
                      color: AppColors.verdeOscuro,
                      fontWeight: FontWeight.w800)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (!pendiente.completo)
                IconButton(
                    tooltip: 'Continuar',
                    onPressed: () => _continuarPendiente(grupo, pendiente),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: const Color(0xFFE65100),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minHeight: 36)),
              if (listo && pendiente.completo)
                IconButton(
                    tooltip: 'Reintentar envío',
                    onPressed: () => _reintentarPendiente(pendiente),
                    icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                    color: AppColors.verdeOscuro,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minHeight: 36)),
            ]),
          ],
        ),
      );
    }
    if (grupo.entregado) {
      return Text(
          item.condicionEntrega.isEmpty
              ? 'ENTREGADO'
              : item.condicionEntrega.toUpperCase(),
          style: const TextStyle(
              fontSize: 10,
              color: AppColors.verdeOscuro,
              fontWeight: FontWeight.w700));
    }
    return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilledButton.icon(
            onPressed: () => _entregarGrupo(grupo),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.verdeOscuro,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.task_alt, size: 16),
            label: Text(pagado ? 'Finalizar' : 'Entregar',
                style: const TextStyle(fontSize: 10))));
  }

  Widget _celdaDocumento(CarteraContribuyente grupo, String tipo) {
    final docs = grupo.documentosPorTipo(tipo);
    if (docs.isEmpty) return _textoCelda('—', _colDocumento);
    final numeros = grupo.numeros(tipo);
    final pagada = docs.every((d) => d.pagada);
    final pendientes = docs.fold<int>(0, (a, d) => a + d.cuotasPendientes);
    final total = docs.fold<int>(0, (a, d) => a + d.cuotasTotal);
    return SizedBox(width: _colDocumento,
      child: Padding(padding: const EdgeInsets.only(right: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(numeros, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: pagada ? AppColors.verdeOscuro : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(pagada ? 'PAGADA' : total > 0 ? '$pendientes/$total pend.' : 'PENDIENTE',
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800,
                color: pagada ? Colors.white : AppColors.grisMedio)),
          ),
        ])));
  }

  Widget _textoCelda(String texto, double ancho) => SizedBox(width: ancho,
    child: Padding(padding: const EdgeInsets.only(right: 4), child: Text(texto, style: const TextStyle(fontSize: 11))));
}
