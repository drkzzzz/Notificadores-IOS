import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../app_theme.dart';
import '../models/models.dart';
import '../services/auto_scan.dart';
import '../services/pendientes_service.dart';
import '../services/upload_service.dart';
import 'editor_imagen_screen.dart';

/// Registro de entrega OP/RD.
///
/// Condiciones vigentes: Notificado / Inubicado (sin datos de receptor ni
/// suministro). Domicilio + GPS obligatorios; cargos OP/RD: por lo menos uno.
/// Cuando [pagado] es true (grupo ya pagado) el registro se marca 'Finalizado'
/// y solo exige fotografía del domicilio fiscal + ubicación GPS.
///
/// Bandeja offline: todo lo capturado se guarda como borrador en el equipo y,
/// sin conexión, queda pendiente de envío con reintento automático (clave de
/// idempotencia en el servidor). Soporta modo edición vía [esEdicion] (sube al
/// endpoint de modificación) y continuar borrador vía [pendiente].
class FinalizarNotificacionScreen extends StatefulWidget {
  const FinalizarNotificacionScreen({
    super.key,
    required this.item,
    required this.dni,
    this.pagado = false,
    this.esEdicion = false,
    this.pendiente,
    this.fechaIdentificador = '',
  });

  final CarteraItem item;
  final String dni;

  /// True cuando el grupo ya está pagado: el trabajo solo registra la
  /// fotografía del domicilio fiscal y la ubicación, y se marca como
  /// 'Finalizado' (no se solicitan cargos OP/RD).
  final bool pagado;

  /// True cuando se modifica una entrega ya grabada: al subir se usa el
  /// endpoint de modificación.
  final bool esEdicion;

  /// Borrador guardado en el equipo para continuar (fotos + GPS + condición).
  final Pendiente? pendiente;

  final String fechaIdentificador;

  @override
  State<FinalizarNotificacionScreen> createState() =>
      _FinalizarNotificacionScreenState();
}

class _FinalizarNotificacionScreenState
    extends State<FinalizarNotificacionScreen> {
  final _picker = ImagePicker();
  final _form = GlobalKey<FormState>();
  String _condicion = 'Notificado';
  String _condicionInicial = 'Notificado';
  final _fecha = DateTime.now();

  static const _condiciones = ['Notificado', 'Inubicado'];

  late final bool _pagado;
  late final bool _esEdicion;
  late final String _uuid;
  late String _fechaCapturaISO;
  bool _subidaOk = false;

  @override
  void initState() {
    super.initState();
    _pagado = widget.pagado || (widget.pendiente?.pagado ?? false);
    _esEdicion = widget.esEdicion || (widget.pendiente?.esEdicion ?? false);
    if (_pagado) {
      _condicion = 'Finalizado';
    } else {
      final previa = widget.item.condicionEntrega.trim();
      if (_condiciones.contains(previa)) _condicion = previa;
    }
    _condicionInicial = _condicion;
    final borrador = widget.pendiente;
    _uuid = borrador?.uuid ?? const Uuid().v4();
    _fechaCapturaISO =
        borrador?.fechaCaptura ?? DateTime.now().toIso8601String();
    if (borrador != null) {
      _condicion = _condiciones.contains(borrador.condicion)
          ? borrador.condicion
          : _condicion;
      _condicionInicial = _condicion;
      File? existente(String? ruta) {
        if ((ruta ?? '').isEmpty) return null;
        final f = File(ruta!);
        return f.existsSync() ? f : null;
      }
      _foto = existente(borrador.fotoDomicilio);
      _fotoOp = existente(borrador.fotoOp);
      _fotoRd = existente(borrador.fotoRd);
      if (borrador.lat != null && borrador.lng != null) {
        _posicion = Position(
          latitude: borrador.lat!,
          longitude: borrador.lng!,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
    }
  }

  bool get _sucio =>
      !_subidaOk &&
      (_foto != null ||
          _fotoOp != null ||
          _fotoRd != null ||
          _posicion != null ||
          _condicion != _condicionInicial);

  Widget _datosEntrega() {
    if (_pagado) {
      // Registro ya pagado: solo foto del domicilio fiscal + actualización
      // de la ubicación geográfica. Los cargos OP/RD quedan bloqueados.
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.verdeOscuro.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_outlined, color: AppColors.verdeOscuro),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Registro YA PAGADO: el trabajo se marcará como FINALIZADO. '
                'Solo se requiere la fotografía del domicilio fiscal y la '
                'actualización de la ubicación geográfica.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.texto),
              ),
            ),
          ],
        ),
      );
    }
    return Form(key: _form, child: Column(children: [
      TextFormField(initialValue: DateFormat('dd/MM/yyyy HH:mm:ss').format(_fecha), readOnly: true,
        decoration: const InputDecoration(labelText: 'Fecha y hora de registro', prefixIcon: Icon(Icons.lock_clock),
          helperText: 'La fecha y hora definitiva se registra al guardar en el servidor.')),
      const SizedBox(height: 12),
      RadioGroup<String>(groupValue: _condicion, onChanged: (v) { if (v != null && !_guardando) { setState(() => _condicion = v); _guardarBorrador(); } },
        child: Column(children: [for (final c in _condiciones)
          RadioListTile<String>(value: c, title: Text(c), dense: true, contentPadding: EdgeInsets.zero)])),
      const Padding(padding: EdgeInsets.only(top: 4),
        child: Text('Solo se registra la condición, las fotos y la ubicación. Sin conexión queda pendiente de envío.',
          style: TextStyle(fontSize: 12, color: AppColors.grisMedio))),
    ]));
  }

  File? _foto;
  File? _fotoOp;
  File? _fotoRd;
  Position? _posicion;
  bool _obteniendoUbicacion = false;
  bool _guardando = false;

  String? _error;

  /// Guarda el borrador en el equipo (fotos a almacén permanente + SQLite).
  /// Retorna el pendiente o null si no hay nada que guardar.
  Future<Pendiente?> _guardarBorrador() async {
    if (_foto == null &&
        _fotoOp == null &&
        _fotoRd == null &&
        _posicion == null &&
        _condicion == _condicionInicial &&
        widget.pendiente == null) {
      return null;
    }
    try {
      Future<String?> persistir(File? archivo, String tipo) async {
        if (archivo == null) return null;
        final bytes = await archivo.readAsBytes();
        return PendientesService.guardarFoto(bytes, _uuid, tipo);
      }

      final dom = await persistir(_foto, 'dom');
      final op = await persistir(_fotoOp, 'op');
      final rd = await persistir(_fotoRd, 'rd');
      final pendiente = Pendiente(
        uuid: _uuid,
        carteraItemId: widget.item.id,
        codContribuyente: widget.item.codContribuyente,
        nombre: widget.item.nombre,
        direccion: widget.item.direccion,
        dniNotificador: widget.dni,
        condicion: _condicion,
        fechaIdentificador: widget.fechaIdentificador,
        fotoDomicilio: dom,
        fotoOp: op,
        fotoRd: rd,
        lat: _posicion?.latitude,
        lng: _posicion?.longitude,
        fechaCaptura: _fechaCapturaISO,
        estado: estadoPara(
            dom: dom, op: op, rd: rd,
            lat: _posicion?.latitude, lng: _posicion?.longitude,
            pagado: _pagado),
        pagado: _pagado,
        esEdicion: _esEdicion,
      );
      await PendientesService.guardar(pendiente);
      return pendiente;
    } catch (_) {
      return null;
    }
  }

  Future<void> _tomarFoto(void Function(File?) asignar) async {
    try {
      final foto = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (foto == null) return;
      if (!mounted) return;
      setState(() {
        asignar(File(foto.path));
        _error = null;
      });
      _guardarBorrador();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo tomar la fotografía: $e');
    }
  }

  /// Foto manual de cargo con tratamiento scan automático posterior:
  /// detecta el documento, lo endereza y elimina los contornos oscuros.
  Future<void> _tomarFotoCargo(void Function(File?) asignar) async {
    try {
      final foto = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (foto == null || !mounted) return;
      final archivo = File(foto.path);
      setState(() {
        asignar(archivo);
        _error = null;
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      Uint8List? recorte;
      try {
        recorte = await recorteAutomatico(await archivo.readAsBytes());
      } catch (_) {}
      if (!mounted) return;
      if (recorte != null) {
        final scan =
            await File('${foto.path}_scan.jpg').writeAsBytes(recorte, flush: true);
        if (!mounted) return;
        setState(() => asignar(scan));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Documento detectado: recortado y centrado automáticamente.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No se detectó el documento: puede usar Editar / Auto-recorte.')));
      }
      if (mounted) setState(() {});
      _guardarBorrador();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo tomar la fotografía: $e';
      });
    }
  }

  Future<void> _editarFoto(File foto, void Function(File?) asignar) async {
    try {
      final bytes = await foto.readAsBytes();
      if (!mounted) return;
      final editados = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (_) => EditorImagenScreen(
            bytes: bytes,
            titulo: 'Editar imagen',
          ),
        ),
      );
      if (editados == null || !mounted) return;
      final ruta = '${foto.path}_edit.jpg';
      final nuevo = await File(ruta).writeAsBytes(editados, flush: true);
      setState(() {
        asignar(nuevo);
        _error = null;
      });
      _guardarBorrador();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo editar la imagen: $e');
    }
  }

  Future<void> _obtenerUbicacion() async {
    setState(() {
      _obteniendoUbicacion = true;
      _error = null;
    });

    try {
      var habilitado = await Geolocator.isLocationServiceEnabled();
      if (!habilitado) {
        setState(() {
          _obteniendoUbicacion = false;
          _error = 'El GPS está desactivado. Actívalo para continuar.';
        });
        return;
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.deniedForever) {
        setState(() {
          _obteniendoUbicacion = false;
          _error =
              'Se denegó el permiso de ubicación. Habilítalo desde la configuración.';
        });
        return;
      }
      if (permiso == LocationPermission.denied) {
        setState(() {
          _obteniendoUbicacion = false;
          _error = 'Sin permiso de ubicación no puedes guardar.';
        });
        return;
      }

      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _posicion = posicion;
        _obteniendoUbicacion = false;
      });
      _guardarBorrador();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _obteniendoUbicacion = false;
        _error = 'No se pudo obtener la ubicación: $e';
      });
    }
  }

  void _avisarError(String mensaje) {
    setState(() { _guardando = false; _error = mensaje; });
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
      content: Text(mensaje), backgroundColor: AppColors.rojo, duration: const Duration(seconds: 7)));
  }

  Future<void> _finalizar() async {
    if (_guardando) return;
    FocusScope.of(context).unfocus();
    if (_pagado) {
      if (_foto == null) {
        _avisarError('Toma la fotografía del domicilio fiscal.');
        return;
      }
      if (_posicion == null) {
        _avisarError('Obtén la ubicación GPS del domicilio fiscal.');
        return;
      }
    } else {
      if (_foto == null) {
        _avisarError('Tome la fotografía del domicilio fiscal.');
        return;
      }
      if (_fotoOp == null && _fotoRd == null) {
        _avisarError('Registre por lo menos el cargo OP o el cargo RD.');
        return;
      }
      if (_posicion == null) {
        _avisarError('Obtén la ubicación GPS del domicilio fiscal.');
        return;
      }
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final pendiente = await _guardarBorrador();
    if (pendiente == null || !pendiente.completo) {
      _avisarError('No se pudo preparar la entrega. Reintente.');
      return;
    }
    final ok = await UploadService.intentar(pendiente);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) {
      _subidaOk = true;
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
                icon: const Icon(Icons.check_circle,
                    color: AppColors.verdeOscuro, size: 48),
                title: Text(_esEdicion
                    ? 'Actualizado correctamente'
                    : 'Guardado correctamente'),
                content: Text(_pagado
                    ? 'El trabajo quedó registrado como FINALIZADO con la fotografía del domicilio y la ubicación.'
                    : _esEdicion
                        ? 'La entrega y sus datos se actualizaron correctamente.'
                        : 'La entrega y sus datos se registraron correctamente.'),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ACEPTAR'))
                ],
              ));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }
    final actual = await PendientesService.porUuid(_uuid);
    if (!mounted) return;
    _subidaOk = true;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
              icon: const Icon(Icons.cloud_off_outlined,
                  color: Color(0xFFE65100), size: 48),
              title: const Text('Guardado como pendiente de envío'),
              content: Text(
                  'Sin conexión estable. Todo quedó guardado en el equipo y se enviará automáticamente.\n\n${actual?.ultimoError ?? ''}'),
              actions: [
                FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ACEPTAR'))
              ],
            ));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  /// Salida con datos sin guardar: ofrece mantener pendiente o descartar.
  Future<void> _alIntentarSalir() async {
    final eleccion = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Salir sin guardar'),
        content: const Text(
            'Tiene datos capturados. ¿Desea mantenerlos como pendiente de envío? No se perderán las fotografías.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'descartar'),
              child: const Text('DESCARTAR')),
          TextButton(
              onPressed: () => Navigator.pop(context, 'seguir'),
              child: const Text('SEGUIR EDITANDO')),
          FilledButton(
              onPressed: () => Navigator.pop(context, 'pendiente'),
              child: const Text('GUARDAR PENDIENTE')),
        ],
      ),
    );
    if (!mounted) return;
    if (eleccion == 'seguir' || eleccion == null) return;
    if (eleccion == 'descartar') {
      final previo = await PendientesService.porUuid(_uuid);
      if (previo != null) await PendientesService.eliminar(previo);
      _subidaOk = true;
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    // Guardar pendiente (intenta subir si está listo y hay conexión).
    final pendiente = await _guardarBorrador();
    if (!mounted) return;
    if (pendiente != null &&
        pendiente.completo &&
        await UploadService.hayConexion()) {
      final ok = await UploadService.intentar(pendiente);
      if (!mounted) return;
      if (ok) {
        _subidaOk = true;
        await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
                  icon: const Icon(Icons.check_circle,
                      color: AppColors.verdeOscuro, size: 48),
                  title: const Text('Guardado correctamente'),
                  content: const Text(
                      'La entrega se registró correctamente.'),
                  actions: [
                    FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('ACEPTAR'))
                  ],
                ));
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
    }
    _subidaOk = true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Guardado como pendiente de envío.')));
      Navigator.of(context).pop(true);
    }
  }

  String get _coordenadasTexto {
    if (_posicion == null) return 'Pendiente';
    return '${_posicion!.latitude.toStringAsFixed(6)}, '
        '${_posicion!.longitude.toStringAsFixed(6)}';
  }

  String get _tituloAppBar {
    if (widget.pendiente != null) return 'CONTINUAR PENDIENTE';
    if (_esEdicion) return 'MODIFICAR ENTREGA';
    if (_pagado) return 'FINALIZAR TRABAJO';
    return 'REGISTRAR ENTREGA';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: _subidaOk || !_sucio,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _alIntentarSalir();
        },
        child: Scaffold(
      backgroundColor: AppColors.grisClaro,
      appBar: AppBar(
        title: Text(_tituloAppBar),
        backgroundColor: AppColors.verdeOscuro,
        foregroundColor: Colors.white,
      ),
      body: AbsorbPointer(absorbing: _guardando, child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardContribuyente(),
            _datosEntrega(),
            const SizedBox(height: 12),
            if (_pagado) ...[
              _paso(
                1,
                'Fotografía del domicilio fiscal (obligatoria)',
                _buildFoto(
                  _foto,
                  () => _tomarFoto((f) => _foto = f),
                  _foto == null ? null : () => _editarFoto(_foto!, (f) => _foto = f),
                  'Tomar fotografía del domicilio',
                ),
              ),
              const SizedBox(height: 12),
              _paso(2, 'Ubicación geográfica del domicilio fiscal (obligatoria)',
                  _buildUbicacion()),
            ] else ...[
              _paso(
                1,
                'Cargo OP (opcional, con auto-recorte)',
                _buildFoto(
                  _fotoOp,
                  () => _tomarFotoCargo((f) => _fotoOp = f),
                  _fotoOp == null ? null : () => _editarFoto(_fotoOp!, (f) => _fotoOp = f),
                  'Tomar fotografía del cargo OP',
                ),
              ),
              const SizedBox(height: 12),
              _paso(
                2,
                'Cargo RD (opcional, con auto-recorte)',
                _buildFoto(
                  _fotoRd,
                  () => _tomarFotoCargo((f) => _fotoRd = f),
                  _fotoRd == null ? null : () => _editarFoto(_fotoRd!, (f) => _fotoRd = f),
                  'Tomar fotografía del cargo RD',
                ),
              ),
              const SizedBox(height: 12),
              _paso(
                3,
                'Fotografía del domicilio fiscal (obligatoria)',
                _buildFoto(
                  _foto,
                  () => _tomarFoto((f) => _foto = f),
                  _foto == null ? null : () => _editarFoto(_foto!, (f) => _foto = f),
                  'Tomar fotografía del domicilio',
                ),
              ),
              const SizedBox(height: 12),
              _paso(4, 'Ubicación geográfica del domicilio fiscal (obligatoria)',
                  _buildUbicacion()),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rojo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.rojo, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _finalizar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verdeOscuro,
                  foregroundColor: Colors.white,
                ),
                icon: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_guardando
                    ? 'Guardando fotos y entrega...'
                    : _pagado
                        ? 'FINALIZAR'
                        : (_esEdicion ? 'GUARDAR MODIFICACIÓN' : 'GUARDAR ENTREGA')),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      )),
    ));
  }

  Widget _cardContribuyente() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.pendiente != null
                ? 'Pendiente de envío OP / RD'
                : (_esEdicion
                    ? 'Modificación de entrega OP / RD'
                    : (_pagado
                        ? 'Documentos OP / RD — registro pagado'
                        : 'Entrega conjunta de documentos OP / RD')),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.verdeOscuro,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.item.nombre,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.texto,
            ),
          ),
          if (widget.item.direccion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                widget.item.direccion,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.grisMedio,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Código: ${widget.item.codContribuyente}',
            style: const TextStyle(fontSize: 12, color: AppColors.grisMedio),
          ),
        ],
      ),
    );
  }

  Widget _paso(int numero, String titulo, Widget contenido) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.verdeOscuro,
                child: Text(
                  '$numero',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          contenido,
        ],
      ),
    );
  }

  Widget _buildFoto(File? foto, VoidCallback onTomar, VoidCallback? onEditar, String titulo) {
    if (foto != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              foto,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: onTomar,
                icon: const Icon(Icons.refresh),
                label: const Text('Volver a tomar'),
              ),
              if (onEditar != null)
                TextButton.icon(
                  onPressed: onEditar,
                  icon: const Icon(Icons.tune),
                  label: const Text('Editar / scan'),
                ),
            ],
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTomar,
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(titulo),
      ),
    );
  }

  Widget _buildUbicacion() {
    if (_posicion != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.verdeOscuro.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.gps_fixed, color: AppColors.verdeOscuro),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _coordenadasTexto,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.texto,
                ),
              ),
            ),
            TextButton(
              onPressed: _obtenerUbicacion,
              child: const Text('Actualizar'),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: _obteniendoUbicacion
          ? const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.verdeOscuro,
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: _obtenerUbicacion,
              icon: const Icon(Icons.my_location),
              label: const Text('Obtener ubicación GPS (obligatoria)'),
            ),
    );
  }
}