import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_bridge/screens/cuidador_dashboard_screen.dart';
import 'package:vital_bridge/screens/login_screen.dart';
import 'package:vital_bridge/screens/paciente_screen.dart';
import 'package:vital_bridge/services/supabase_service.dart';
import 'package:vital_bridge/services/alarmas_nativas_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.inicializar();
  await AlarmasNativasService.inicializar();

  // Comprobar persistencia de sesión previa
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final rol = prefs.getString('auth_rol');

  Widget pantallaInicial;
  if (token != null && token.isNotEmpty) {
    if (rol == 'cuidador') {
      pantallaInicial = const CuidadorDashboardScreen();
    } else if (rol == 'paciente') {
      pantallaInicial = const PacienteScreen();
    } else {
      pantallaInicial = const LoginScreen();
    }
  } else {
    pantallaInicial = const LoginScreen();
  }

  runApp(VitalBridgeApp(pantallaInicial: pantallaInicial));

  // Verificar si la app fue abierta directamente al sonar una alarma mientras estaba cerrada
  WidgetsBinding.instance.addPostFrameCallback((_) {
    AlarmasNativasService.verificarLanzamientoDesdeNotificacion();
  });
}

class VitalBridgeApp extends StatelessWidget {
  final Widget pantallaInicial;
  const VitalBridgeApp({super.key, this.pantallaInicial = const LoginScreen()});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AlarmasNativasService.navigatorKey,
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
      home: pantallaInicial,
    );
  }
}
