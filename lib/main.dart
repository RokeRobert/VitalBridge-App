import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_bridge/screens/alarma_screen.dart';
import 'package:vital_bridge/screens/alerta_sos_cuidador_screen.dart';
import 'package:vital_bridge/screens/cuidador_dashboard_screen.dart';
import 'package:vital_bridge/screens/login_screen.dart';
import 'package:vital_bridge/screens/paciente_screen.dart';
import 'package:vital_bridge/services/fcm_service.dart';
import 'package:vital_bridge/services/supabase_service.dart';
import 'package:vital_bridge/services/alarmas_nativas_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase y oyente de mensajes en segundo plano
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  await SupabaseService.inicializar();
  await AlarmasNativasService.inicializar();
  await FcmService.inicializar();

  // Comprobar persistencia de sesión previa
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final rol = prefs.getString('auth_rol');

  // Comprobar si la app fue lanzada al despertar por una alarma o SOS
  final payloadAlarma = await AlarmasNativasService.obtenerPayloadLanzamiento();

  Widget pantallaInicial;
  if (payloadAlarma != null) {
    if (payloadAlarma['tipo'] == 'SOS') {
      final idAlerta = int.tryParse(payloadAlarma['idAlerta']?.toString() ?? '0');
      final latitud = double.tryParse(payloadAlarma['latitud']?.toString() ?? '');
      final longitud = double.tryParse(payloadAlarma['longitud']?.toString() ?? '');
      final nombrePaciente = payloadAlarma['nombrePaciente']?.toString() ?? 'Paciente';

      FcmService.alertaSosAbierta = true;
      pantallaInicial = AlertaSosCuidadorScreen(
        nombrePaciente: nombrePaciente,
        idAlerta: idAlerta,
        latitud: latitud,
        longitud: longitud,
        horaAlerta: 'Ahora',
      );
    } else {
      AlarmasNativasService.alarmaAbierta = true;
      pantallaInicial = AlarmaMedicamentoScreen(
        idHorario: payloadAlarma['idHorario'] as int?,
        nombreMedicamento: payloadAlarma['nombreMedicamento'] as String? ?? 'Medicamento',
        dosis: payloadAlarma['dosis'] as String? ?? '',
        hora: payloadAlarma['hora'] as String? ?? '',
        indicaciones: payloadAlarma['indicaciones'] as String? ?? '',
      );
    }
  } else if (token != null && token.isNotEmpty) {
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

  // Respaldo por si la navegación requirió el Navigator montado
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (payloadAlarma == null) {
      AlarmasNativasService.verificarLanzamientoDesdeNotificacion();
      FcmService.verificarLanzamientoSos();
    }
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
