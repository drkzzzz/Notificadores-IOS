import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../models/resumen_notificadores.dart';
import '../services/api_service.dart';
import 'deuda_resumen_notificadores_screen.dart';

class ConsultasScreen extends StatefulWidget {
  const ConsultasScreen({super.key, this.codigoInicial});
  final String? codigoInicial;

  @override
  State<ConsultasScreen> createState() => _ConsultasScreenState();
}

class _ConsultasScreenState extends State<ConsultasScreen> {
  final _codController = TextEditingController();
  bool _consultando = false;
  String _nombreOperador = '';
  Timer? _debounce;
  ResumenNotificadores? _resumenLive;
  String? _liveError;
  bool _consultandoLive = false;

  @override
  void initState() {
    super.initState();
    _cargarOperador();
    final codigo = widget.codigoInicial;
    if (codigo != null && codigo.trim().isNotEmpty) {
      _codController.text = codigo.trim().padLeft(11, '0');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onCodChanged(_codController.text);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _codController.dispose();
    super.dispose();
  }

  Future<void> _cargarOperador() async {
    final prefs = await SharedPreferences.getInstance();
    final nombre = prefs.getString('operador_nombre') ?? '';
    if (mounted && nombre.isNotEmpty) {
      setState(() => _nombreOperador = nombre);
    }
  }

  bool _esHorarioPermitido() => true;

  String _getMensajeHorario() {
    return 'Consultas fuera del horario permitido';
  }

  void _onCodChanged(String value) {
    final cod = value.trim();
    _debounce?.cancel();
    setState(() {
      _liveError = null;
      if (cod.length != 11) {
        _resumenLive = null;
        _consultandoLive = false;
      }
    });
    if (cod.length == 11 && _esHorarioPermitido()) {
      setState(() => _consultandoLive = true);
      _debounce = Timer(const Duration(milliseconds: 600), () {
        _consultarLive(cod);
      });
    }
  }

  Future<void> _consultarLive(String cod) async {
    try {
      final resumen = await ApiService.consultarResumenNotificadores(cod);
      if (!mounted || _codController.text.trim() != cod) return;
      setState(() {
        _resumenLive = resumen;
        _liveError = null;
        _consultandoLive = false;
      });
    } catch (e) {
      if (!mounted || _codController.text.trim() != cod) return;
      setState(() {
        _resumenLive = null;
        _liveError = '$e';
        _consultandoLive = false;
      });
    }
  }

  Future<void> _buscar() async {
    final cod = _codController.text.trim();
    if (cod.isEmpty) {
      _aviso('Ingresa el código de contribuyente');
      return;
    }

    setState(() => _consultando = true);
    try {
      final resumen = await ApiService.consultarResumenNotificadores(cod);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeudaResumenNotificadoresScreen(resumen: resumen),
        ),
      );
    } catch (e) {
      _aviso('Error: $e');
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  void _aviso(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisClaro,
      appBar: AppBar(title: const Text('Consulta de Deuda')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Consulta de Deuda',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.texto,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresa el código del contribuyente',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.grisMedio,
                ),
                textAlign: TextAlign.center,
              ),
              if (_nombreOperador.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.verdeOscuro.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'OPERADOR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.grisMedio,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _nombreOperador.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.verdeOscuro,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _codController,
                onChanged: _onCodChanged,
                keyboardType: TextInputType.number,
                maxLength: 11,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
                decoration: const InputDecoration(
                  labelText: 'Código Contribuyente',
                  border: OutlineInputBorder(),
                  fillColor: Colors.white,
                  filled: true,
                  counterText: '',
                ),
              ),
              if (_codController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Código completo: ${_codController.text.padLeft(11, '0')}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.verdeOscuro,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              if (_consultandoLive)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.verdeOscuro,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Consultando deuda...',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.grisMedio,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_liveError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.rojo.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.rojo.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _liveError!,
                      style: const TextStyle(
                        color: AppColors.rojo,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (_resumenLive != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeudaResumenNotificadoresScreen(
                            resumen: _resumenLive!,
                          ),
                        ),
                      );
                    },
                    child: _CardResumenLive(resumen: _resumenLive!),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _esHorarioPermitido() ? _buscar : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _esHorarioPermitido()
                        ? AppColors.verdeOscuro
                        : Colors.grey,
                    disabledBackgroundColor: Colors.grey.shade400,
                  ),
                  child: _consultando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'BUSCAR DEUDA',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (!_esHorarioPermitido())
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _getMensajeHorario(),
                    style: const TextStyle(
                      color: AppColors.rojo,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardResumenLive extends StatelessWidget {
  const _CardResumenLive({required this.resumen});

  final ResumenNotificadores resumen;

  String _fmt(double valor) => 'S/ ${valor.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final c = resumen.contribuyente;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.verdeOscuro.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: AppColors.verdeOscuro),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.texto,
                      ),
                    ),
                    Text(
                      'Código: ${c.codigo}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grisMedio,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Text(
            'TOTAL A PAGAR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _fmt(resumen.tributos.isNotEmpty
                ? resumen.totalConAmnistiaTodos
                : resumen.totalConAmnistia),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.verdeOscuro,
            ),
          ),
          if (resumen.tributos.isNotEmpty)
            Text(
              '${resumen.tributos.length} tributos · ver detalle',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.grisMedio,
              ),
            ),
        ],
      ),
    );
  }
}