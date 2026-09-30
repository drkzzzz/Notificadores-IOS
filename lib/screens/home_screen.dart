import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../services/api_service.dart';
import 'cartera_op_rd_screen.dart';
import 'configuracion_screen.dart';
import 'consultas_screen.dart';
import 'llamadas_screen.dart';
import 'modulo_pendiente_screen.dart';



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
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _nombreOperador;
  int _tareasAsignadas = 0;

  @override
  void initState() {
    super.initState();
    _cargarOperador();
    _cargarTareas();
  }

  Future<void> _cargarOperador() async {
    final prefs = await SharedPreferences.getInstance();
    final nombre = prefs.getString('operador_nombre') ?? '';
    if (!mounted) return;
    setState(() => _nombreOperador = nombre);
  }

  Future<void> _cargarTareas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dni = prefs.getString('operador_dni') ?? '';
      if (dni.isEmpty) return;
      final tareas = await ApiService.obtenerTareasAsignadas(dni);
      if (!mounted) return;
      setState(() => _tareasAsignadas = tareas);
    } catch (_) {
      if (!mounted) return;
      setState(() => _tareasAsignadas = 0);
    }
  }

  void _abrir(BuildContext context, Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisClaro,
      body: SafeArea(
        child: Column(
          children: [
            // Header verde
            Container(
              width: double.infinity,
              color: AppColors.verdeOscuro,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/logo_sat.png',
                      width: 110,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'DE NOTIFICADORES',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'SAT - TARAPOTO',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ESTA APP ES DE USO EXCLUSIVO DEL PERSONAL DE '
                    'NOTIFICACIONES DEL SATT-TARAPOTO (Su uso es monitoreado)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_nombreOperador != null &&
                      _nombreOperador!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _nombreOperador!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20 + (constraints.maxWidth - 56) * 0.075,
                    vertical: 20,
                  ),
                  children: [
                    _menuBtn(
                      icono: Icons.folder_off,
                      titulo: 'CARTERA OP/RD',
                      subtitulo: _tareasAsignadas > 0
                          ? '($_tareasAsignadas)'
                          : '',
                      onPressed: () => _abrir(context, const CarteraOpRdScreen()),
                    ),
                    _menuBtn(
                      icono: Icons.gavel,
                      titulo: 'NOTIFICACIONES COACTIVOS',
                      subtitulo: '',
                      onPressed: () => _abrir(context,
                          const ModuloPendienteScreen(titulo: 'NOTIFICACIONES COACTIVOS')),
                    ),
                    _menuBtn(
                      icono: Icons.mail,
                      titulo: 'CARTAS',
                      subtitulo: '',
                      onPressed: () => _abrir(context,
                          const ModuloPendienteScreen(titulo: 'NOTIFICACIONES DE CARTAS')),
                    ),
                    _menuBtn(
                      icono: Icons.call,
                      titulo: 'LLAMADAS',
                      subtitulo: '',
                      onPressed: () => _abrir(context, const LlamadasScreen()),
                    ),
                    _menuBtn(
                      icono: Icons.search,
                      titulo: 'CONSULTAS',
                      subtitulo: '',
                      onPressed: () => _abrir(context, const ConsultasScreen()),
                    ),
                    _menuBtn(
                      icono: Icons.settings,
                      titulo: 'CONFIGURACIÓN',
                      subtitulo: '',
                      onPressed: () => _abrir(context, const ConfiguracionScreen()),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              width: double.infinity,
              color: AppColors.verdeOscuro.withValues(alpha: 0.85),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const Text(
                'Desarrollado por Programación OTI/SAT-T',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _menuBtn({
  required IconData icono,
  required String titulo,
  required String subtitulo,
  required VoidCallback onPressed,
}) {
  return GestureDetector(
    onTap: onPressed,
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.verdeOscuro,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.verdeOscuro.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: Colors.deepPurple.shade700, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitulo.isNotEmpty)
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
    ),
  );
}