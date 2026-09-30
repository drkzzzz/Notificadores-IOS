import 'package:flutter/material.dart';

Future<void> mostrarAvisoSistema(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => PopScope(
    canPop: false,
    child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('BIENVENIDO', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 108, height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF083D35), Color(0xFF159C70)]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x30083D35), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.terminal_rounded, color: Colors.white70, size: 26),
              Text('</>', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('ESTE ES UN SISTEMA DESARROLLADO POR PROGRAMACION DE OTI/SAT-TARAPOTO',
            textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, height: 1.5, fontSize: 14)),
          const SizedBox(height: 16),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF147D59)),
            SizedBox(width: 8), Text('Su uso es monitoreado.'),
          ]),
        ]),
      ),
      actions: [SizedBox(width: double.infinity, child: FilledButton(
        onPressed: () => Navigator.of(context).pop(), child: const Text('ACEPTAR')))],
    ),
  ),
);
