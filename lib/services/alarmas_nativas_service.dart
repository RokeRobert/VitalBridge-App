import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:vital_bridge/models/toma_model.dart';
import 'package:vital_bridge/screens/alarma_screen.dart';
import 'package:vital_bridge/services/fcm_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Callback en segundo plano para cumplir contrato de flutter_local_notifications
}

/// Servicio centralizado de Alarmas Nativas para el Paciente.
/// Utiliza Android AlarmManager (AlarmClock) para despertar el dispositivo
/// a la hora exacta de la toma, incluso si la app está completamente cerrada.
class AlarmasNativasService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Key global para navegar a la pantalla de alarma en pantalla completa desde cualquier lugar
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Bandera para evitar abrir pantallas de alarma duplicadas
  static bool alarmaAbierta = false;

  static const String _channelId = 'vitalbridge_alarmas_medicas_v4';
  static const String _channelName = 'Alarmas de Medicamentos';
  static const String _channelDesc =
      'Alarmas críticas de tomas de medicamentos que despiertan el teléfono';

  /// Inicializa el motor de notificaciones y detecta la zona horaria real del teléfono
  static Future<void> inicializar() async {
    // 1. Inicializar Timezones con la zona horaria REAL del dispositivo
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = tzInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('AlarmasNativas: Zona horaria detectada: $timeZoneName');
    } catch (e) {
      debugPrint('AlarmasNativas: Error detectando zona horaria: $e. Usando offset local.');
      try {
        final offset = DateTime.now().timeZoneOffset;
        for (final loc in tz.timeZoneDatabase.locations.values) {
          if (loc.currentTimeZone.offset == offset) {
            tz.setLocalLocation(loc);
            debugPrint('AlarmasNativas: Zona asignada por offset: ${loc.name}');
            break;
          }
        }
      } catch (_) {}
    }

    // 2. Configuración nativa de Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _alRecibirNotificacion,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _configurarOyenteIntentNativo();

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
      cancelarTodasLasNotificacionesActivas();
      if (datos['tipo'] == 'SOS') {
        FcmService.abrirPantallaAlertaSos(datos);
        return;
      }
      if (alarmaAbierta) {
        debugPrint('AlarmasNativas: Alarma ya en pantalla, omitiendo duplicado.');
        return;
      }
      _abrirPantallaAlarma(
        idHorario: int.tryParse(datos['idHorario']?.toString() ?? ''),
        nombreMedicamento: datos['nombreMedicamento']?.toString() ?? 'Medicamento',
        dosis: datos['dosis']?.toString() ?? '',
        hora: datos['hora']?.toString() ?? '',
        indicaciones: datos['indicaciones']?.toString() ?? '',
      );
    } catch (_) {}
  }

  /// Configura el listener para intents nativos cuando Android despierta MainActivity
  static void _configurarOyenteIntentNativo() {
    _channelPermisos.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmaRecibida') {
        final payloadStr = call.arguments?.toString();
        if (payloadStr != null && payloadStr.isNotEmpty) {
          try {
            final Map<String, dynamic> datos = jsonDecode(payloadStr);
            cancelarTodasLasNotificacionesActivas();
            if (datos['tipo'] == 'SOS') {
              FcmService.abrirPantallaAlertaSos(datos);
            } else {
              abrirPantallaAlarmaDirecta(
                idHorario: int.tryParse(datos['idHorario']?.toString() ?? ''),
                nombreMedicamento: datos['nombreMedicamento']?.toString() ?? 'Medicamento',
                dosis: datos['dosis']?.toString() ?? '',
                hora: datos['hora']?.toString() ?? '',
                indicaciones: datos['indicaciones']?.toString() ?? '',
              );
            }
          } catch (e) {
            debugPrint('AlarmasNativas: Error procesando intent nativo: $e');
          }
        }
      }
    });
  }

  /// Retorna el payload de notificación si la app fue abierta por una alarma
  static Future<Map<String, dynamic>?> obtenerPayloadLanzamiento() async {
    try {
      final details = await _notifications.getNotificationAppLaunchDetails();
      if (details != null &&
          details.didNotificationLaunchApp &&
          details.notificationResponse?.payload != null) {
        final payload = details.notificationResponse!.payload!;
        if (payload.isNotEmpty) {
          return jsonDecode(payload) as Map<String, dynamic>;
        }
      }
    } catch (_) {}

    // Respaldo desde el intent nativo de Android
    try {
      final payloadNativo = await _channelPermisos.invokeMethod<String>('obtenerPayloadAlarmaActual');
      if (payloadNativo != null && payloadNativo.isNotEmpty) {
        return jsonDecode(payloadNativo) as Map<String, dynamic>;
      }
    } catch (_) {}

    return null;
  }

  /// Verifica si la aplicación fue abierta por una alarma nativa mientras estaba cerrada
  static Future<void> verificarLanzamientoDesdeNotificacion() async {
    if (alarmaAbierta) return;
    try {
      final datos = await obtenerPayloadLanzamiento();
      if (datos != null) {
        _abrirPantallaAlarma(
          idHorario: int.tryParse(datos['idHorario']?.toString() ?? ''),
          nombreMedicamento: datos['nombreMedicamento']?.toString() ?? 'Medicamento',
          dosis: datos['dosis']?.toString() ?? '',
          hora: datos['hora']?.toString() ?? '',
          indicaciones: datos['indicaciones']?.toString() ?? '',
        );
      }
    } catch (e) {
      debugPrint('AlarmasNativas: Error al verificar lanzamiento: $e');
    }
  }

  /// Abre la pantalla de alarma directamente sin depender de la interacción del usuario
  static void abrirPantallaAlarmaDirecta({
    required int? idHorario,
    required String nombreMedicamento,
    required String dosis,
    required String hora,
    required String indicaciones,
  }) {
    if (alarmaAbierta) return;
    cancelarTodasLasNotificacionesActivas();
    _abrirPantallaAlarma(
      idHorario: idHorario,
      nombreMedicamento: nombreMedicamento,
      dosis: dosis,
      hora: hora,
      indicaciones: indicaciones,
    );
  }

  /// Navega directamente a la pantalla de alarma en pantalla completa
  static void _abrirPantallaAlarma({
    required int? idHorario,
    required String nombreMedicamento,
    required String dosis,
    required String hora,
    required String indicaciones,
  }) {
    if (alarmaAbierta) return;
    alarmaAbierta = true;

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
    ).then((_) {
      alarmaAbierta = false;
    });
  }

  /// Parsea la hora en formato '08:00 AM', '14:30', '08:00:00', etc.
  static TimeOfDay? parsearHora(String horaStr) {
    try {
      final match = RegExp(r'(\d+):(\d+)(?::\d+)?\s*(AM|PM)?', caseSensitive: false)
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
    if (horaMinuto == null) {
      debugPrint('AlarmasNativas: No se pudo parsear hora: ${toma.horaProgramada}');
      return;
    }

    final ahora = tz.TZDateTime.now(tz.local);
    var fechaAlarma = tz.TZDateTime(
      tz.local,
      ahora.year,
      ahora.month,
      ahora.day,
      horaMinuto.hour,
      horaMinuto.minute,
      0,
    );

    // Si la hora ya pasó hoy por más de 15 minutos, no la programamos en el pasado lejano
    if (fechaAlarma.isBefore(ahora.subtract(const Duration(minutes: 15)))) {
      debugPrint('AlarmasNativas: Toma ${toma.medicamento} a las ${toma.horaProgramada} ya expiro hoy.');
      return;
    }

    // Si la hora coincide con el minuto actual o pasó hace unos instantes,
    // la programamos 5 segundos hacia el futuro para que suene de inmediato sin crashear el AlarmManager
    if (!fechaAlarma.isAfter(ahora)) {
      fechaAlarma = ahora.add(const Duration(seconds: 5));
      debugPrint('AlarmasNativas: Toma en curso/inmediata. Programada en 5 segundos: $fechaAlarma');
    } else {
      debugPrint('AlarmasNativas: Toma futura programada a las: $fechaAlarma (Ahora: $ahora)');
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
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

    final payload = jsonEncode({
      'idHorario': toma.idHorario,
      'nombreMedicamento': toma.medicamento,
      'dosis': toma.dosis,
      'hora': toma.horaProgramada,
      'indicaciones': toma.indicaciones ?? 'Tomar según prescripción médica',
    });

    try {
      // AndroidScheduleMode.alarmClock es el modo más potente de Android:
      // Se registra como reloj de alarma del sistema y despierta el teléfono incluso en modo Doze
      await _notifications.zonedSchedule(
        id: toma.idHorario,
        title: '¡Hora de tu medicamento!',
        body: 'Es momento de tomar ${toma.medicamento} (${toma.dosis}).',
        scheduledDate: fechaAlarma,
        notificationDetails: NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: payload,
      );
      debugPrint('AlarmasNativas: Alarma registrada exitosamente para id ${toma.idHorario}');
    } catch (e) {
      debugPrint('AlarmasNativas: Aviso: Falló exactAlarmClock, intentando exactAllowWhileIdle: $e');
      try {
        await _notifications.zonedSchedule(
          id: toma.idHorario,
          title: '¡Hora de tu medicamento!',
          body: 'Es momento de tomar ${toma.medicamento} (${toma.dosis}).',
          scheduledDate: fechaAlarma,
          notificationDetails: NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
      } catch (e2) {
        debugPrint('AlarmasNativas: Error definitivo al programar alarma: $e2');
      }
    }

    // Programar también con el AlarmManager nativo para garantizar despertar de pantalla completa
    await programarAlarmaExactaNativa(
      toma.idHorario,
      fechaAlarma.millisecondsSinceEpoch,
      payload,
    );
  }

  /// Cancela una alarma de toma (por ejemplo cuando el usuario ya confirmó que la tomó)
  static Future<void> cancelarAlarma(int idHorario) async {
    try {
      await _notifications.cancel(id: idHorario);
      debugPrint('AlarmasNativas: Alarma cancelada para id $idHorario');
    } catch (_) {}
    await cancelarAlarmaNativa(idHorario);
  }

  /// Cancela todas las notificaciones activas para silenciar de inmediato el sonido del sistema
  static Future<void> cancelarTodasLasNotificacionesActivas() async {
    try {
      await _notifications.cancelAll();
      debugPrint('AlarmasNativas: Todas las notificaciones activas canceladas');
    } catch (_) {}
    try {
      await _channelPermisos.invokeMethod('cancelarTodasLasNotificaciones');
    } catch (_) {}
  }

  /// Cancela específicamente la notificación de alerta SOS de alta prioridad (id 9999)
  static Future<void> cancelarNotificacionSos() async {
    try {
      await _notifications.cancel(id: 9999);
    } catch (_) {}
    await cancelarTodasLasNotificacionesActivas();
  }

  /// Sincroniza todas las tomas del día: programa las pendientes y cancela las tomadas
  static Future<void> sincronizarAlarmasDelDia(List<TomaModel> tomas) async {
    debugPrint('AlarmasNativas: Sincronizando ${tomas.length} tomas del día...');
    for (final toma in tomas) {
      if (toma.esTomada) {
        await cancelarAlarma(toma.idHorario);
      } else {
        await programarAlarmaParaToma(toma);
      }
    }
  }

  // --- MÉTODOS DE COMPROBACIÓN Y ACCESO A PERMISOS NATIVOS ---
  static const MethodChannel _channelPermisos =
      MethodChannel('vital_bridge/permisos_sistema');

  static Future<bool> tienePermisoAlarmasExactas() async {
    try {
      final res = await _channelPermisos.invokeMethod<bool>('verificarPermisoAlarmasExactas');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> abrirAjustesAlarmasExactas() async {
    try {
      await _channelPermisos.invokeMethod('abrirAjustesAlarmasExactas');
    } catch (_) {}
  }

  static Future<bool> tienePermisoAparecerEncima() async {
    try {
      final res = await _channelPermisos.invokeMethod<bool>('verificarPermisoAparecerEncima');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> abrirAjustesAparecerEncima() async {
    try {
      await _channelPermisos.invokeMethod('abrirAjustesAparecerEncima');
    } catch (_) {}
  }

  static Future<bool> tienePermisoPantallaCompleta() async {
    try {
      final res = await _channelPermisos.invokeMethod<bool>('verificarPermisoPantallaCompleta');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> abrirAjustesPantallaCompleta() async {
    try {
      await _channelPermisos.invokeMethod('abrirAjustesPantallaCompleta');
    } catch (_) {}
  }

  static Future<void> abrirAjustesApp() async {
    try {
      await _channelPermisos.invokeMethod('abrirAjustesApp');
    } catch (_) {}
  }

  static Future<bool> estaPantallaBloqueada() async {
    try {
      final res = await _channelPermisos.invokeMethod<bool>('estaPantallaBloqueada');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cerrarPantallaAlarma() async {
    try {
      await _channelPermisos.invokeMethod('cerrarPantallaAlarma');
    } catch (_) {
      SystemNavigator.pop();
    }
  }

  static Future<void> programarAlarmaExactaNativa(int idHorario, int triggerTimeMillis, String payloadJson) async {
    try {
      await _channelPermisos.invokeMethod('programarAlarmaExactaNativa', {
        'idHorario': idHorario,
        'triggerTimeMillis': triggerTimeMillis,
        'payload': payloadJson,
      });
    } catch (_) {}
  }

  static Future<void> cancelarAlarmaNativa(int idHorario) async {
    try {
      await _channelPermisos.invokeMethod('cancelarAlarmaNativa', {'idHorario': idHorario});
    } catch (_) {}
  }

  static Future<void> abrirEnlace(String url) async {
    try {
      await _channelPermisos.invokeMethod('abrirEnlace', {'url': url});
    } catch (_) {}
  }
}
