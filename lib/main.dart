import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SatApp());
}

class SatApp extends StatelessWidget {
  const SatApp({super.key});

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
