import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_bridge/screens/alerta_sos_cuidador_screen.dart';
import 'package:vital_bridge/services/alarmas_nativas_service.dart';
import 'package:vital_bridge/services/alertas_service.dart';

/// Manejador de mensajes en segundo plano / app cerrada (Top-Level Function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  if (data['tipo'] == 'SOS') {
    final flutterLocalNotifications = FlutterLocalNotificationsPlugin();

    final androidDetails = AndroidNotificationDetails(
      'vitalbridge_alarmas_medicas_v4',
      'Alarmas de Medicamentos y SOS',
      channelDescription: 'Alarmas críticas y alertas de auxilio de pacientes',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound: const RawResourceAndroidNotificationSound('alarma'),
      playSound: true,
      enableVibration: true,
    );

    final nombre = data['nombrePaciente'] ?? 'El paciente';
    await flutterLocalNotifications.show(
      id: 9999,
      title: '¡EMERGENCIA SOS!',
      body: '$nombre ha presionado el botón de auxilio SOS.',
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: jsonEncode(data),
    );
  }
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Inicializa los oyentes de notificaciones push de Firebase
  static Future<void> inicializar() async {
    // 1. Solicitar permisos de notificación (Android 13+ e iOS)
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );
    } catch (_) {}

    // 2. Registrar el token del dispositivo si la sesión es de cuidador
    await sincronizarTokenCuidador();

    // 3. Escuchar actualizaciones periódicas de token FCM
    _messaging.onTokenRefresh.listen((nuevoToken) async {
      await _guardarYEnviarToken(nuevoToken);
    });

    // 4. Oyente de mensajes cuando la aplicación está en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      if (data['tipo'] == 'SOS') {
        _abrirPantallaAlertaSos(data);
      }
    });

    // 5. Oyente cuando el usuario toca la notificación con la app en segundo plano
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final data = message.data;
      if (data['tipo'] == 'SOS') {
        _abrirPantallaAlertaSos(data);
      }
    });
  }

  /// Verifica si la aplicación fue abierta al pulsar una notificación push SOS mientras estaba cerrada
  static Future<void> verificarLanzamientoSos() async {
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null && initialMessage.data['tipo'] == 'SOS') {
        _abrirPantallaAlertaSos(initialMessage.data);
      }
    } catch (_) {}
  }

  /// Obtiene el token FCM y lo registra en el backend si el usuario es cuidador
  static Future<void> sincronizarTokenCuidador() async {
    final prefs = await SharedPreferences.getInstance();
    final rol = prefs.getString('auth_rol');

    if (rol == 'cuidador') {
      try {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await _guardarYEnviarToken(token);
        }
      } catch (_) {}
    }
  }

  static Future<void> _guardarYEnviarToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    await AlertasService.registrarTokenFcm(token);
  }

  /// Navega de inmediato a la pantalla de emergencia SOS en pantalla completa
  static void _abrirPantallaAlertaSos(Map<String, dynamic> data) {
    final context = AlarmasNativasService.navigatorKey.currentContext;
    if (context == null) return;

    final idAlerta = int.tryParse(data['idAlerta']?.toString() ?? '0');
    final latitud = double.tryParse(data['latitud']?.toString() ?? '');
    final longitud = double.tryParse(data['longitud']?.toString() ?? '');
    final nombrePaciente = data['nombrePaciente']?.toString() ?? 'Paciente';

    AlarmasNativasService.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AlertaSosCuidadorScreen(
          nombrePaciente: nombrePaciente,
          idAlerta: idAlerta,
          latitud: latitud,
          longitud: longitud,
          horaAlerta: 'Ahora',
        ),
      ),
    );
  }
}
