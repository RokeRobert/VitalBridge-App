import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_bridge/screens/alerta_sos_cuidador_screen.dart';
import 'package:vital_bridge/services/alarmas_nativas_service.dart';
import 'package:vital_bridge/services/alertas_service.dart';
import 'package:vital_bridge/services/tratamientos_service.dart';

/// Manejador de mensajes en segundo plano / app cerrada (Top-Level Function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  if (data['tipo'] == 'SOS') {
    final flutterLocalNotifications = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await flutterLocalNotifications.initialize(settings: initSettings);

    final androidPlugin = flutterLocalNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final canal = AndroidNotificationChannel(
        'vitalbridge_alarmas_medicas_v4',
        'Alarmas de Medicamentos y SOS',
        description: 'Alarmas críticas y alertas de auxilio de pacientes',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('alarma'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      );
      await androidPlugin.createNotificationChannel(canal);
    }

    final androidDetails = AndroidNotificationDetails(
      'vitalbridge_alarmas_medicas_v4',
      'Alarmas de Medicamentos y SOS',
      channelDescription: 'Alarmas críticas y alertas de auxilio de pacientes',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      autoCancel: true,
      ongoing: false,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound: const RawResourceAndroidNotificationSound('alarma'),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      visibility: NotificationVisibility.public,
    );

    final nombre = data['nombrePaciente'] ?? 'El paciente';
    await flutterLocalNotifications.show(
      id: 9999,
      title: '¡EMERGENCIA SOS!',
      body: '$nombre ha presionado el botón de auxilio SOS.',
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: jsonEncode(data),
    );
  } else if (data['tipo'] == 'SYNC_TRATAMIENTOS') {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rol = prefs.getString('auth_rol');
      final idPacienteLocal = prefs.getString('auth_user_id') ?? '';
      final idPacientePush = data['idPaciente']?.toString() ?? '';

      if (rol == 'paciente' &&
          idPacienteLocal.isNotEmpty &&
          (idPacientePush.isEmpty || idPacientePush == idPacienteLocal)) {
        await AlarmasNativasService.inicializarParaSegundoPlano();
        final tomas = await TratamientosService.obtenerTomasHoy(pacienteId: idPacienteLocal);
        await AlarmasNativasService.sincronizarAlarmasDelDia(tomas);
      }
    } catch (e) {
      debugPrint('FcmService (background): Error sincronizando tratamientos: $e');
    }
  }
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool alertaSosAbierta = false;

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

    // 1.1 Crear canal estándar para avisos de tomas omitidas (sin sirena de emergencia)
    await _crearCanalAvisosTomas();

    // 2. Registrar el token del dispositivo (cuidador o paciente)
    await sincronizarTokenDispositivo();

    // 3. Escuchar actualizaciones periódicas de token FCM
    _messaging.onTokenRefresh.listen((nuevoToken) async {
      await _guardarYEnviarToken(nuevoToken);
    });

    // 4. Oyente de mensajes cuando la aplicación está en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final data = message.data;
      if (data['tipo'] == 'SOS') {
        abrirPantallaAlertaSos(data);
      } else if (data['tipo'] == 'SYNC_TRATAMIENTOS') {
        await _sincronizarTratamientosPaciente(data);
      } else if (data['tipo'] == 'TOMA_OMITIDA') {
        await _mostrarNotificacionTomaOmitida(message);
      }
    });

    // 5. Oyente cuando el usuario toca la notificación con la app en segundo plano
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final data = message.data;
      if (data['tipo'] == 'SOS') {
        abrirPantallaAlertaSos(data);
      }
    });
  }

  static Future<void> _crearCanalAvisosTomas() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final androidPlugin = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        const canal = AndroidNotificationChannel(
          'vitalbridge_avisos_tomas_v1',
          'Avisos de Tomas Pendientes',
          description: 'Notifica al cuidador cuando un paciente no confirma su medicamento tras 15 minutos',
          importance: Importance.high,
          playSound: true,
        );
        await androidPlugin.createNotificationChannel(canal);
      }
    } catch (_) {}
  }

  static Future<void> _sincronizarTratamientosPaciente(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rol = prefs.getString('auth_rol');
      final idPacienteLocal = prefs.getString('auth_user_id') ?? '';
      final idPacientePush = data['idPaciente']?.toString() ?? '';

      if (rol == 'paciente' &&
          idPacienteLocal.isNotEmpty &&
          (idPacientePush.isEmpty || idPacientePush == idPacienteLocal)) {
        final tomas = await TratamientosService.obtenerTomasHoy(pacienteId: idPacienteLocal);
        await AlarmasNativasService.sincronizarAlarmasDelDia(tomas);
      }
    } catch (e) {
      debugPrint('FcmService: Error sincronizando tratamientos en primer plano: $e');
    }
  }

  static Future<void> _mostrarNotificacionTomaOmitida(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('auth_rol') != 'cuidador') return;

      final data = message.data;
      final titulo = message.notification?.title ?? data['titulo']?.toString() ?? 'Toma pendiente sin confirmar';
      final cuerpo = message.notification?.body ?? data['cuerpo']?.toString() ?? 'El paciente no ha confirmado su dosis.';
      final idHorario = int.tryParse(data['idHorario']?.toString() ?? '') ??
          DateTime.now().millisecondsSinceEpoch.remainder(100000);

      final plugin = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'vitalbridge_avisos_tomas_v1',
        'Avisos de Tomas Pendientes',
        channelDescription: 'Notifica al cuidador cuando un paciente no confirma su medicamento tras 15 minutos',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );

      await plugin.show(
        id: 20000 + idHorario,
        title: titulo,
        body: cuerpo,
        notificationDetails: const NotificationDetails(android: androidDetails),
      );
    } catch (_) {}
  }

  /// Verifica si la aplicación fue abierta al pulsar una notificación push SOS mientras estaba cerrada
  static Future<void> verificarLanzamientoSos() async {
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null && initialMessage.data['tipo'] == 'SOS') {
        abrirPantallaAlertaSos(initialMessage.data);
      }
    } catch (_) {}
  }

  /// Obtiene el token FCM y lo registra en el backend según el rol activo (cuidador o paciente)
  static Future<void> sincronizarTokenDispositivo() async {
    final prefs = await SharedPreferences.getInstance();
    final rol = prefs.getString('auth_rol');

    if (rol == 'cuidador' || rol == 'paciente') {
      try {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await _guardarYEnviarToken(token);
        }
      } catch (_) {}
    }
  }

  /// Alias compatible para registrar el token FCM del cuidador
  static Future<void> sincronizarTokenCuidador() => sincronizarTokenDispositivo();

  static Future<void> _guardarYEnviarToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    final rol = prefs.getString('auth_rol');
    final userId = prefs.getString('auth_user_id') ?? '';

    if (rol == 'paciente' && userId.isNotEmpty) {
      await AlertasService.registrarTokenFcmPaciente(token, userId);
    } else if (rol == 'cuidador') {
      await AlertasService.registrarTokenFcm(token);
    }
  }

  /// Navega de inmediato a la pantalla de emergencia SOS en pantalla completa
  static void abrirPantallaAlertaSos(Map<String, dynamic> data) {
    if (alertaSosAbierta) {
      debugPrint('FcmService: Alerta SOS ya abierta en pantalla, ignorando llamada duplicada.');
      return;
    }

    final context = AlarmasNativasService.navigatorKey.currentContext;
    if (context == null) return;

    alertaSosAbierta = true;
    AlarmasNativasService.cancelarNotificacionSos();

    final idAlerta = int.tryParse(data['idAlerta']?.toString() ?? '0');
    final idPaciente = data['idPaciente']?.toString() ?? '';
    final latitud = double.tryParse(data['latitud']?.toString() ?? '');
    final longitud = double.tryParse(data['longitud']?.toString() ?? '');
    final nombrePaciente = data['nombrePaciente']?.toString() ?? 'Paciente';
    final telefono = data['telefono']?.toString();

    AlarmasNativasService.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AlertaSosCuidadorScreen(
          nombrePaciente: nombrePaciente,
          idPaciente: idPaciente,
          telefono: telefono,
          idAlerta: idAlerta,
          latitud: latitud,
          longitud: longitud,
          horaAlerta: 'Ahora',
        ),
      ),
    );
  }
}
