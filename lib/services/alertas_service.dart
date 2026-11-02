import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_bridge/models/alerta_sos_model.dart';
import 'package:vital_bridge/services/api_constants.dart';

class AlertasService {
  // Alertas simuladas para modo desarrollo
  static final List<AlertaSosModel> _alertasSimuladas = [
    AlertaSosModel(
      id: 1,
      idPaciente: '00000000-0000-0000-0000-000000000045',
      nombrePaciente: 'Don Roberto',
      fechaCreacion: DateTime.now().subtract(const Duration(minutes: 5)),
      idEstadoAlerta: 1,
      estado: 'Activa',
      latitud: 19.432608,
      longitud: -99.133209,
    ),
  ];

  /// Obtiene los headers con autenticación almacenada
  static Future<Map<String, String>> _obtenerHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final usuarioId = prefs.getString('auth_user_id') ?? '';

    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (usuarioId.isNotEmpty) 'X-User-Id': usuarioId,
    };
  }

  /// Obtiene la ubicación GPS real del dispositivo (con solicitud de permisos nativos)
  static Future<Position?> obtenerUbicacionGpsActual() async {
    try {
      bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        return null;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) {
          return null;
        }
      }

      if (permiso == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Emite una señal de emergencia SOS desde el modo paciente con geolocalización satelital
  static Future<Map<String, dynamic>> emitirAlertaSos({
    required String idPaciente,
    double? latitud,
    double? longitud,
    String? motivo,
  }) async {
    // Si no se proveyeron coordenadas, capturar la posición GPS en vivo del dispositivo
    if (latitud == null || longitud == null) {
      final pos = await obtenerUbicacionGpsActual();
      if (pos != null) {
        latitud = pos.latitude;
        longitud = pos.longitude;
      }
    }

    try {
      final headers = await _obtenerHeaders();
      final response = await http
          .post(
            Uri.parse(ApiConstants.emitirAlertaSOS),
            headers: headers,
            body: jsonEncode({
              'idPaciente': idPaciente,
              'fechaCreacion': DateTime.now().toUtc().toIso8601String(),
              'latitud': latitud,
              'longitud': longitud,
              'motivo': motivo ?? 'Botón de pánico presionado por el paciente',
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final nueva = AlertaSosModel.fromJson(data);
        _alertasSimuladas.insert(0, nueva);
        return {'exito': true, 'alerta': nueva};
      }
    } catch (_) {
      // Modo desarrollo / offline
    }

    final simulada = AlertaSosModel(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      idPaciente: idPaciente,
      nombrePaciente: 'Paciente',
      fechaCreacion: DateTime.now(),
      idEstadoAlerta: 1,
      estado: 'Activa',
      latitud: latitud,
      longitud: longitud,
    );
    _alertasSimuladas.insert(0, simulada);
    return {'exito': true, 'modoSimulacion': true, 'alerta': simulada};
  }

  /// Obtiene las alertas activas pendientes de atención para el cuidador
  static Future<List<AlertaSosModel>> obtenerAlertasActivas() async {
    try {
      final headers = await _obtenerHeaders();
      final response = await http
          .get(Uri.parse(ApiConstants.alertasActivas), headers: headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) => AlertaSosModel.fromJson(item)).toList();
      }
    } catch (_) {
      // Modo desarrollo
    }
    return _alertasSimuladas.where((a) => a.esActiva).toList();
  }

  /// Marca una alerta como atendida o resuelta
  static Future<bool> resolverAlerta(int idAlerta, {String resolucion = 'Atendida'}) async {
    try {
      final headers = await _obtenerHeaders();
      final response = await http
          .post(
            Uri.parse(ApiConstants.resolverAlerta),
            headers: headers,
            body: jsonEncode({
              'idAlerta': idAlerta,
              'resolucion': resolucion,
              'fechaResolucion': DateTime.now().toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 204) {
        _marcarAlertaResuelta(idAlerta, resolucion);
        return true;
      }
    } catch (_) {
      _marcarAlertaResuelta(idAlerta, resolucion);
      return true;
    }
    _marcarAlertaResuelta(idAlerta, resolucion);
    return true;
  }

  /// Registra el token FCM del cuidador en el backend
  static Future<bool> registrarTokenFcm(String token) async {
    try {
      final headers = await _obtenerHeaders();
      final prefs = await SharedPreferences.getInstance();
      final usuarioId = prefs.getString('auth_user_id');

      final response = await http
          .post(
            Uri.parse(ApiConstants.registrarFcmToken),
            headers: headers,
            body: jsonEncode({
              'token': token,
              if (usuarioId != null && usuarioId.isNotEmpty) 'idUsuario': usuarioId,
            }),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static void _marcarAlertaResuelta(int idAlerta, String resolucion) {
    final index = _alertasSimuladas.indexWhere((a) => a.id == idAlerta);
    if (index != -1) {
      final a = _alertasSimuladas[index];
      _alertasSimuladas[index] = AlertaSosModel(
        id: a.id,
        idPaciente: a.idPaciente,
        nombrePaciente: a.nombrePaciente,
        fechaCreacion: a.fechaCreacion,
        idEstadoAlerta: 2,
        estado: resolucion,
        latitud: a.latitud,
        longitud: a.longitud,
      );
    }
  }
}
