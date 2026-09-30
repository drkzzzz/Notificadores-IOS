import 'package:flutter/material.dart';

import '../app_theme.dart';

class ModuloPendienteScreen extends StatelessWidget {
  const ModuloPendienteScreen({super.key, required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisClaro,
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.construction,
              size: 56,
              color: AppColors.grisMedio,
            ),
            const SizedBox(height: 16),
            Text(
              '$titulo\n(en construcción)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.grisMedio,
              ),
            ),
          ],
        ),
      ),
    );
  }
}