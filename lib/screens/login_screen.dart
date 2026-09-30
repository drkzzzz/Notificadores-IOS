import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'aviso_sistema.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NotificadoresApp());
}

class NotificadoresApp extends StatelessWidget {
  const NotificadoresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notificadores SAT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.verdeOscuro,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.verdeOscuro,
          primary: AppColors.verdeOscuro,
        ),
        scaffoldBackgroundColor: AppColors.grisClaro,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.verdeOscuro,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _dniController = TextEditingController();
  final _claveController = TextEditingController();
  bool _ocultarClave = true;
  bool _ingresando = false;

  @override
  void dispose() {
    _dniController.dispose();
    _claveController.dispose();
    super.dispose();
  }

  bool get _dniValido => _dniController.text.trim().length == 8;

  bool get _puedeIngresar =>
      _dniValido && _claveController.text.isNotEmpty && !_ingresando;

  Future<void> _iniciar() async {
    final dni = _dniController.text.trim();
    final clave = _claveController.text.trim();

    setState(() => _ingresando = true);
    try {
      final sesion = await ApiService.login(dni, clave);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('operador_dni', sesion.dni);
      await prefs.setString('operador_nombre', sesion.nombre);
      await prefs.setInt('operador_id', sesion.id);
      if (!mounted) return;
      await mostrarAvisoSistema(context);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _ingresando = false);
      _aviso(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _aviso(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.grisClaro,
      body: SafeArea(
        child: SingleChildScrollView(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 40),
              Image.asset(
                'assets/logo_sat.png',
                width: 150,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              const Text(
                'DE NOTIFICADORES',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.verdeOscuro,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'SAT - TARAPOTO',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.grisMedio,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Consulta de Deudas Tributarias',
                style: TextStyle(fontSize: 14, color: AppColors.grisMedio),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _dniController,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                maxLength: 8,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'DNI (8 dígitos)',
                  border: OutlineInputBorder(),
                  fillColor: Colors.white,
                  filled: true,
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _claveController,
                onChanged: (_) => setState(() {}),
                obscureText: _ocultarClave,
                decoration: InputDecoration(
                  labelText: 'Clave',
                  border: const OutlineInputBorder(),
                  fillColor: Colors.white,
                  filled: true,
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _ocultarClave
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _ocultarClave = !_ocultarClave),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _puedeIngresar ? _iniciar : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verdeOscuro,
                    foregroundColor: Colors.white,
                  ),
                  child: _ingresando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'INGRESAR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      // Footer at the bottom
      bottomNavigationBar: Container(
        width: double.infinity,
        color: AppColors.verdeOscuro.withValues(alpha: 0.85),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: const Text(
          'Desarrollado por Programación OTI/SAT-T',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
    );
  }
}