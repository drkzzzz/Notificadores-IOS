import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/cartera_contribuyente.dart';
import '../services/cartera_ubicaciones.dart';

class CarteraMapaScreen extends StatefulWidget {
  const CarteraMapaScreen({super.key, required this.grupos, required this.origen, required this.servicio, required this.puntos, this.tileProvider});
  final TileProvider? tileProvider;
  final List<CarteraContribuyente> grupos;
  final LatLng origen;
  final CarteraUbicaciones servicio;
  final Map<String, UbicacionCartera> puntos;
  @override
  State<CarteraMapaScreen> createState() => _CarteraMapaScreenState();
}

class _CarteraMapaScreenState extends State<CarteraMapaScreen> {
  final _mapa = MapController();
  final _cantidad = TextEditingController();
  final _intentados = <String>{};
  int _n = 20, _trabajo = 0, _revisados = 0;
  bool _ocupado = false, _listo = false;
  String? _error;
  bool _errorMapa = false;
  int get _ubicadosEnLista => widget.grupos.where((g) => widget.puntos.containsKey(g.codigo)).length;
  List<CarteraContribuyente> get _visibles => ordenarPorDistancia(widget.grupos.where((g) => widget.puntos.containsKey(g.codigo)).toList(), widget.origen, widget.puntos).take(_n).toList();

  @override
  void initState() {
    super.initState();
    _n = widget.grupos.length.clamp(1, 20);
    _cantidad.text = '$_n';
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolver());
  }
  @override
  void dispose() { _trabajo++; _cantidad.dispose(); _mapa.dispose(); super.dispose(); }

  void _encuadrar() {
    if (!_listo) return;
    _mapa.fitCamera(CameraFit.coordinates(coordinates: [widget.origen, ..._visibles.map((g) => widget.puntos[g.codigo]!.punto)], padding: const EdgeInsets.all(45), maxZoom: 16));
  }

  Future<void> _resolver() async {
    final numero = int.tryParse(_cantidad.text);
    if (numero == null || numero < 1 || numero > widget.grupos.length) {
      setState(() => _error = 'Ingrese una cantidad entre 1 y ${widget.grupos.length}.');
      return;
    }
    final trabajo = ++_trabajo;
    setState(() { _n = numero; _ocupado = true; _error = null; _revisados = 0; });
    try {
      for (final g in widget.grupos) {
        if (!mounted || trabajo != _trabajo) return;
        final p = await widget.servicio.localizar(g, buscarDireccion: false);
        if (p != null) widget.puntos[g.codigo] = p;
      }
      if (!mounted || trabajo != _trabajo) return;
      setState(() {}); _encuadrar();
      for (final g in widget.grupos) {
        if (!mounted || trabajo != _trabajo || _ubicadosEnLista >= _n) break;
        if (widget.puntos.containsKey(g.codigo) || !_intentados.add(g.codigo)) continue;
        final p = await widget.servicio.localizar(g);
        if (!mounted || trabajo != _trabajo) return;
        setState(() { _revisados++; if (p != null) widget.puntos[g.codigo] = p; });
      }
    } catch (e) {
      if (mounted && trabajo == _trabajo) setState(() => _error = e is PlatformException ? e.message : e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && trabajo == _trabajo) { setState(() => _ocupado = false); _encuadrar(); }
    }
  }

  void _detalle(CarteraContribuyente g) {
    final ubicacion = widget.puntos[g.codigo]!;
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (context) => SafeArea(
      child: Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(g.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        Text('Código: ${g.codigo}'), Text(g.principal.direccion),
        const SizedBox(height: 8),
        Text('${distanciaTexto(distanciaMetros(widget.origen, ubicacion.punto))} en línea recta · ${ubicacion.aproximada ? "Ubicación aproximada por dirección" : "GPS registrado"}'),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: () async {
          final u = Uri.https('www.google.com', '/maps/dir/', {'api':'1','origin':'${widget.origen.latitude},${widget.origen.longitude}','destination':'${ubicacion.punto.latitude},${ubicacion.punto.longitude}','travelmode':'walking'});
          await launchUrl(u, mode: LaunchMode.externalApplication);
        }, icon: const Icon(Icons.directions_walk), label: const Text('Cómo llegar')),
      ])),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    return Scaffold(appBar: AppBar(title: const Text('Mapa de contribuyentes'), actions: [IconButton(onPressed: _encuadrar, tooltip: 'Ver todos los puntos', icon: const Icon(Icons.center_focus_strong))]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: [
          const Text('Mostrar'), const SizedBox(width: 8),
          SizedBox(width: 64, child: TextField(controller: _cantidad, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)))),
          const SizedBox(width: 8), const Expanded(child: Text('contribuyentes')),
          TextButton(onPressed: _ocupado ? null : _resolver, child: const Text('MOSTRAR')),
        ])),
        if (_ocupado) const LinearProgressIndicator(minHeight: 2),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Row(children: [
          Expanded(child: Text('${visibles.length} puntos · ${widget.grupos.length - _ubicadosEnLista} sin ubicar${_ocupado ? " · buscando $_revisados" : ""}', style: const TextStyle(fontSize: 11))),
          if (_ocupado) TextButton(onPressed: () => setState(() { _trabajo++; _ocupado = false; }), child: const Text('Detener')),
        ])),
        if (_errorMapa) const Padding(padding: EdgeInsets.all(6), child: Text('No se pudo cargar el mapa base. Revise su conexión.', style: TextStyle(fontSize: 11, color: Colors.red))),
        if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
        Expanded(child: FlutterMap(mapController: _mapa,
          options: MapOptions(initialCenter: widget.origen, initialZoom: 14, onMapReady: () { _listo = true; _encuadrar(); }),
          children: [
            TileLayer(tileProvider: widget.tileProvider, urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'pe.gob.sat-t.notificadores', maxZoom: 19,
              errorTileCallback: (tile, error, stack) {
                if (!_errorMapa) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && !_errorMapa) setState(() => _errorMapa = true); });
              }),
            MarkerLayer(markers: [
              Marker(point: widget.origen, width: 34, height: 34, child: Tooltip(message: 'Mi ubicación', child: Container(decoration: BoxDecoration(color: Colors.blue.withValues(alpha: .2), shape: BoxShape.circle), padding: const EdgeInsets.all(7), child: Container(decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))))),
              for (final g in visibles) Marker(point: widget.puntos[g.codigo]!.punto, width: 30, height: 30,
                child: GestureDetector(onTap: () => _detalle(g), child: Tooltip(message: g.nombre, child: Center(child: Container(width: 13, height: 13, decoration: BoxDecoration(shape: BoxShape.circle,
                  color: widget.puntos[g.codigo]!.aproximada ? Colors.orange.shade700 : Colors.green.shade700,
                  border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)])))))),
            ]),
            SimpleAttributionWidget(source: const Text('OpenStreetMap contributors', style: TextStyle(fontSize: 10)), onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'), mode: LaunchMode.externalApplication)),
          ])),
        const SafeArea(top: false, child: Padding(padding: EdgeInsets.all(8), child: Text('Azul: yo · Verde: GPS · Naranja: aproximado\nToque un punto para ver el domicilio. La cercanía es en línea recta entre ubicaciones localizadas.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)))),
      ]),
    );
  }
}