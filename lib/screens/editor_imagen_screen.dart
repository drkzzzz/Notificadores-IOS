import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../app_theme.dart';
import '../services/auto_scan.dart';

/// Editor tipo scan para cargos (documentos) y foto de domicilio.
///
/// Sin dependencias nativas: usa `package:image` (Dart puro) para que los
/// ajustes queden grabados en los bytes que se suben al servidor.
/// Ofrece: rotar 90°, voltear H/V, recorte de bordes, brillo, contraste,
/// modo B/N documento y modo Scan (alto contraste), además del auto-recorte
/// que detecta y centra solo el documento.
class EditorImagenScreen extends StatefulWidget {
  const EditorImagenScreen({super.key, required this.bytes, required this.titulo});

  final Uint8List bytes;
  final String titulo;

  @override
  State<EditorImagenScreen> createState() => _EditorImagenScreenState();
}

class _EditorImagenScreenState extends State<EditorImagenScreen> {
  late img.Image _original;
  bool _cargando = true;
  String? _error;

  int _rotaciones = 0; // cuartos de vuelta horarios
  bool _flipH = false;
  bool _flipV = false;
  double _brillo = 0; // -1..1
  double _contraste = 1; // 0.2..2
  double _recorte = 0; // 0..0.25 fracción por borde
  bool _byn = false;
  bool _scan = false;

  Uint8List? _vista;
  bool _procesando = false;
  bool _autoRecorte = false;

  @override
  void initState() {
    super.initState();
    _decodificar();
  }

  void _decodificar() {
    try {
      final dec = img.decodeImage(widget.bytes);
      if (dec == null) throw Exception('Formato no soportado.');
      _original = dec;
      _cargando = false;
    } catch (e) {
      _error = 'No se pudo abrir la imagen: $e';
      _cargando = false;
    }
    setState(() {});
    if (_error == null) _actualizarVista();
  }

  Future<void> _actualizarVista() async {
    if (_cargando || _error != null) return;
    setState(() => _procesando = true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    try {
      final out = _aplicar(_original, miniatura: true);
      final jpg = Uint8List.fromList(img.encodeJpg(out, quality: 70));
      if (mounted) setState(() => _vista = jpg);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo procesar: $e');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  img.Image _aplicar(img.Image src, {bool miniatura = false}) {
    var out = src.clone();
    for (var i = 0; i < (_rotaciones % 4); i++) {
      out = img.copyRotate(out, angle: 90);
    }
    if (_flipH || _flipV) {
      out = img.flip(out, direction: _flipH && _flipV
          ? img.FlipDirection.both
          : _flipH
              ? img.FlipDirection.horizontal
              : img.FlipDirection.vertical);
    }
    if (_recorte > 0) {
      final dx = (out.width * _recorte).round();
      final dy = (out.height * _recorte).round();
      final w = out.width - dx * 2;
      final h = out.height - dy * 2;
      if (w > 50 && h > 50) out = img.copyCrop(out, x: dx, y: dy, width: w, height: h);
    }
    final scan = _scan;
    final byn = _byn || scan;
    if (byn) out = img.grayscale(out);
    final brillo = scan ? 0.15 : _brillo;
    final contraste = scan ? 1.8 : _contraste;
    if ((brillo - 0).abs() > 0.001 || (contraste - 1).abs() > 0.001) {
      out = img.adjustColor(out, brightness: 1 + brillo, contrast: contraste);
    }
    if (miniatura && out.width > 900) out = img.copyResize(out, width: 900);
    return out;
  }

  Future<void> _guardar() async {
    setState(() => _procesando = true);
    try {
      final out = _aplicar(_original);
      final jpg = Uint8List.fromList(img.encodeJpg(out, quality: 82));
      if (!mounted) return;
      Navigator.pop(context, jpg);
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    }
  }

  void _restablecer() {
    setState(() {
      _rotaciones = 0;
      _flipH = false;
      _flipV = false;
      _brillo = 0;
      _contraste = 1;
      _recorte = 0;
      _byn = false;
      _scan = false;
    });
    _actualizarVista();
  }

  /// Auto-recorte offline: detecta el documento en la foto original, lo
  /// endereza, elimina los contornos oscuros y lo centra.
  Future<void> _autoRecortar() async {
    setState(() => _procesando = true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    try {
      final recorte = await recorteAutomatico(widget.bytes);
      if (!mounted) return;
      if (recorte == null) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No se detectó ningún documento. Pruebe Modo scan o recorte manual.')));
        return;
      }
      final dec = img.decodeImage(recorte);
      if (dec == null) {
        setState(() => _procesando = false);
        return;
      }
      setState(() {
        _original = dec;
        _autoRecorte = true;
      });
      _restablecer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Documento detectado: recortado y centrado.')));
    } catch (_) {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisClaro,
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          TextButton(
            onPressed: _restablecer,
            child: const Text('Restablecer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: Colors.black87,
                        child: _vista == null
                            ? const Center(
                                child: CircularProgressIndicator(color: Colors.white))
                            : InteractiveViewer(
                                child: Center(child: Image.memory(_vista!, fit: BoxFit.contain)),
                              ),
                      ),
                    ),
                    if (_procesando) const LinearProgressIndicator(minHeight: 3),
                    _barraBotones(),
                    _controles(),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('CANCELAR'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _procesando ? null : _guardar,
                                icon: const Icon(Icons.check),
                                label: const Text('APLICAR'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _barraBotones() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _btn(Icons.crop, 'Auto-recorte', _autoRecortar,
              activo: _autoRecorte),
          _btn(Icons.document_scanner, 'Modo scan', () {
            setState(() => _scan = !_scan);
            _actualizarVista();
          }, activo: _scan),
          _btn(Icons.rotate_right, 'Rotar', () {
            setState(() => _rotaciones = (_rotaciones + 1) % 4);
            _actualizarVista();
          }),
          _btn(Icons.swap_horiz, 'Voltear H', () {
            setState(() => _flipH = !_flipH);
            _actualizarVista();
          }, activo: _flipH),
          _btn(Icons.swap_vert, 'Voltear V', () {
            setState(() => _flipV = !_flipV);
            _actualizarVista();
          }, activo: _flipV),
          _btn(Icons.filter_b_and_w, 'B/N doc.', () {
            setState(() => _byn = !_byn);
            _actualizarVista();
          }, activo: _byn),
        ],
      ),
    );
  }

  Widget _btn(IconData icono, String texto, VoidCallback onTap, {bool activo = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        selected: activo,
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 18),
          const SizedBox(width: 4),
          Text(texto, style: const TextStyle(fontSize: 12)),
        ]),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _controles() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        children: [
          _slider('Brillo', _brillo, -0.5, 0.5, (v) {
            setState(() => _brillo = v);
            _actualizarVista();
          }),
          _slider('Contraste', _contraste, 0.5, 2.0, (v) {
            setState(() => _contraste = v);
            _actualizarVista();
          }),
          _slider('Recortar bordes', _recorte, 0, 0.2, (v) {
            setState(() => _recorte = v);
            _actualizarVista();
          }),
        ],
      ),
    );
  }

  Widget _slider(String titulo, double valor, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(titulo, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(value: valor, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}