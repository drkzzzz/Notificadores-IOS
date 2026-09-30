import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../services/api_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _claveActualCtrl = TextEditingController();
  final _claveNuevaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  final _focusNodeActual = FocusNode();
  final _focusNodeNueva = FocusNode();
  final _focusNodeConfirmar = FocusNode();
  bool _cargando = false;
  String? _error;
  bool _exito = false;

  @override
  void dispose() {
    _claveActualCtrl.dispose();
    _claveNuevaCtrl.dispose();
    _confirmarCtrl.dispose();
    _focusNodeActual.dispose();
    _focusNodeNueva.dispose();
    _focusNodeConfirmar.dispose();
    super.dispose();
  }

  Future<void> _cambiarClave() async {
    if (_cargando || !_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
      _exito = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final dni = prefs.getString('operador_dni') ?? '';
      if (dni.isEmpty) throw Exception('Inicie sesión nuevamente.');
      await ApiService.cambiarClave(
        dni: dni,
        claveActual: _claveActualCtrl.text.trim(),
        claveNueva: _claveNuevaCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _exito = true;
        _error = null;
      });
      _claveActualCtrl.clear();
      _claveNuevaCtrl.clear();
      _confirmarCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clave cambiada correctamente.'),
          backgroundColor: Color(0xFF159C38),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = '$e';
        _exito = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisClaro,
      appBar: AppBar(
        title: const Text('CONFIGURACION'),
        backgroundColor: AppColors.verdeOscuro,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              if (_exito) ...[
                _buildExito(),
                const SizedBox(height: 20),
              ],
              _buildSection('Cambiar clave'),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildField(
                      controller: _claveActualCtrl,
                      focusNode: _focusNodeActual,
                      label: 'Clave actual',
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingrese su clave actual';

                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      nextFocus: _focusNodeNueva,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _claveNuevaCtrl,
                      focusNode: _focusNodeNueva,
                      label: 'Clave nueva',
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingrese su clave nueva';
                        if (v.length < 4) return 'Minimo 4 caracteres';
                        if (RegExp(r'\s').hasMatch(v)) return 'La clave no debe contener espacios';
                        if (v == _claveActualCtrl.text.trim()) return 'Ingrese una clave diferente de la actual';
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      nextFocus: _focusNodeConfirmar,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _confirmarCtrl,
                      focusNode: _focusNodeConfirmar,
                      label: 'Confirmar clave nueva',
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Confirme su clave nueva';
                        if (v != _claveNuevaCtrl.text) return 'Las claves no coinciden';
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                      onSubmitted: _cambiarClave,
                    ),
                    const SizedBox(height: 10),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.rojo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.rojo, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _cargando ? null : _cambiarClave,
                  icon: _cargando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.key_rounded),
                  label: Text(_cargando ? 'Cambiando...' : 'CAMBIAR CLAVE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verdeOscuro,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildSection('Acerca de'),
              const SizedBox(height: 12),
              _buildInfoCard('App', 'Notificadores SAT-T'),
              _buildInfoCard('Version', '1.0.0'),
              _buildInfoCard('Desarrollador', 'Programacion OTI/SAT-T'),
              _buildInfoCard('Servidor', 'https://sat-t.gob.pe'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.verdeOscuro,
      ),
    );
  }

  Widget _buildExito() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF159C38).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF159C38), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF159C38), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Clave cambiada exitosamente!',
              style: TextStyle(
                color: Color(0xFF159C38),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool obscureText,
    required String? Function(String?) validator,
    TextInputAction textInputAction = TextInputAction.next,
    FocusNode? nextFocus,
    VoidCallback? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      enabled: !_cargando,
      autocorrect: false,
      enableSuggestions: false,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: (_) {
        if (nextFocus != null) {
          FocusScope.of(context).requestFocus(nextFocus);
        } else if (onSubmitted != null) {
          onSubmitted();
        }
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.grisMedio),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.grisMedio),
      ),
    );
  }

  Widget _buildInfoCard(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.texto,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.grisMedio,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
