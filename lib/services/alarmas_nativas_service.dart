import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:vital_bridge/models/toma_model.dart';
import 'package:vital_bridge/screens/alarma_screen.dart';

/// Servicio centralizado de Alarmas Nativas para el Paciente.
/// Utiliza Android AlarmManager / Exact Alarms para despertar el dispositivo
/// a la hora exacta de la toma, incluso si la app está completamente cerrada.
class AlarmasNativasService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Key global para navegar a la pantalla de alarma en pantalla completa desde cualquier lugar
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _channelId = 'canal_alarmas_medicamentos';
  static const String _channelName = 'Alarmas de Medicamentos';
  static const String _channelDesc =
      'Alarmas críticas de tomas de medicamentos que despiertan el teléfono';

  /// Inicializa el motor de notificaciones y la base de datos de zonas horarias
  static Future<void> inicializar() async {
    // 1. Inicializar Timezones
    tz.initializeTimeZones();

    // 2. Configuración nativa de Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _alRecibirNotificacion,
    );

    // 3. Crear el canal de alta prioridad con sonido de alarma y vibración
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final canal = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('alarma'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      );

      await androidPlugin.createNotificationChannel(canal);

      // Solicitar permisos de notificación (Android 13+) y alarmas exactas (Android 12/13/14+)
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  /// Manejador de evento cuando el usuario interactúa con la notificación o Android dispara el intent
  static void _alRecibirNotificacion(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final Map<String, dynamic> datos = jsonDecode(payload);
      _abrirPantallaAlarma(
        idHorario: datos['idHorario'] as int?,
        nombreMedicamento: datos['nombreMedicamento'] as String? ?? 'Medicamento',
        dosis: datos['dosis'] as String? ?? '',
        hora: datos['hora'] as String? ?? '',
        indicaciones: datos['indicaciones'] as String? ?? '',
      );
    } catch (_) {}
  }

  /// Verifica si la aplicación fue abierta por una alarma nativa mientras estaba cerrada
  static Future<void> verificarLanzamientoDesdeNotificacion() async {
    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details != null &&
        details.didNotificationLaunchApp &&
        details.notificationResponse?.payload != null) {
      final payload = details.notificationResponse!.payload!;
      try {
        final Map<String, dynamic> datos = jsonDecode(payload);
        _abrirPantallaAlarma(
          idHorario: datos['idHorario'] as int?,
          nombreMedicamento: datos['nombreMedicamento'] as String? ?? 'Medicamento',
          dosis: datos['dosis'] as String? ?? '',
          hora: datos['hora'] as String? ?? '',
          indicaciones: datos['indicaciones'] as String? ?? '',
        );
      } catch (_) {}
    }
  }

  /// Navega directamente a la pantalla de alarma en pantalla completa
  static void _abrirPantallaAlarma({
    required int? idHorario,
    required String nombreMedicamento,
    required String dosis,
    required String hora,
    required String indicaciones,
  }) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => AlarmaMedicamentoScreen(
          idHorario: idHorario,
          nombreMedicamento: nombreMedicamento,
          dosis: dosis,
          hora: hora,
          indicaciones: indicaciones,
        ),
      ),
    );
  }

  /// Parsea la hora en formato '08:00 AM', '14:30', etc. y retorna la hora y minuto
  static TimeOfDay? parsearHora(String horaStr) {
    try {
      final match = RegExp(r'(\d+):(\d+)\s*(AM|PM)?', caseSensitive: false)
          .firstMatch(horaStr.trim());
      if (match != null) {
        int hora = int.parse(match.group(1)!);
        final int minuto = int.parse(match.group(2)!);
        final periodo = match.group(3)?.toUpperCase();

        if (periodo == 'PM' && hora < 12) hora += 12;
        if (periodo == 'AM' && hora == 12) hora = 0;

        return TimeOfDay(hour: hora, minute: minuto);
      }
    } catch (_) {}
    return null;
  }

  /// Programa una alarma nativa de alta prioridad para una toma específica
  static Future<void> programarAlarmaParaToma(TomaModel toma) async {
    if (toma.esTomada) {
      await cancelarAlarma(toma.idHorario);
      return;
    }

    final horaMinuto = parsearHora(toma.horaProgramada);
    if (horaMinuto == null) return;

    final ahora = tz.TZDateTime.now(tz.local);
    var fechaAlarma = tz.TZDateTime(
      tz.local,
      ahora.year,
      ahora.month,
      ahora.day,
      horaMinuto.hour,
      horaMinuto.minute,
    );

    // Si la hora ya pasó hoy (por más de 1 minuto), no la programamos en el pasado
    if (fechaAlarma.isBefore(ahora.subtract(const Duration(minutes: 1)))) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound: const RawResourceAndroidNotificationSound('alarma'),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      visibility: NotificationVisibility.public,
    );

    final payload = jsonEncode({
      'idHorario': toma.idHorario,
      'nombreMedicamento': toma.medicamento,
      'dosis': toma.dosis,
      'hora': toma.horaProgramada,
      'indicaciones': toma.indicaciones ?? 'Tomar según prescripción médica',
    });

    try {
      await _notifications.zonedSchedule(
        id: toma.idHorario,
        title: '⏰ ¡Hora de tu medicamento!',
        body: 'Es momento de tomar ${toma.medicamento} (${toma.dosis}).',
        scheduledDate: fechaAlarma,
        notificationDetails: NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {
      // Respaldo con modo inexacto si el dispositivo restringe alarmas exactas
      try {
        await _notifications.zonedSchedule(
          id: toma.idHorario,
          title: '⏰ ¡Hora de tu medicamento!',
          body: 'Es momento de tomar ${toma.medicamento} (${toma.dosis}).',
          scheduledDate: fechaAlarma,
          notificationDetails: NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } catch (_) {}
    }
  }

  /// Cancela una alarma de toma (por ejemplo cuando el usuario ya confirmó que la tomó)
  static Future<void> cancelarAlarma(int idHorario) async {
    try {
      await _notifications.cancel(id: idHorario);
    } catch (_) {}
  }

  /// Sincroniza todas las tomas del día: programa las pendientes y cancela las tomadas
  static Future<void> sincronizarAlarmasDelDia(List<TomaModel> tomas) async {
    for (final toma in tomas) {
      if (toma.esTomada) {
        await cancelarAlarma(toma.idHorario);
      } else {
        await programarAlarmaParaToma(toma);
      }
    }
  }
}
