import 'package:flutter/material.dart';
import 'package:vital_bridge/screens/login_screen.dart';

void main() {
  runApp(const VitalBridgeApp());
}

class VitalBridgeApp extends StatelessWidget {
  const VitalBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VitalBridge',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF615586),
          surface: const Color(0xFFF4F6F8),
        ),
      ),
      // Punto de entrada único: Desde el Login puedes acceder tanto al Cuidador como al Paciente
      home: const LoginScreen(),
    );
  }
}