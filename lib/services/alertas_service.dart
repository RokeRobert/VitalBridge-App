import 'dart:convert';
import 'package:http/http.dart' as http;
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
    ),
  ];

  /// Emite una señal de emergencia SOS desde el modo paciente
  static Future<Map<String, dynamic>> emitirAlertaSos({
    required String idPaciente,
    double? latitud,
    double? longitud,
    String? motivo,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.emitirAlertaSOS),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'idPaciente': idPaciente,
              'fechaCreacion': DateTime.now().toIso8601String(),
              'latitud': latitud ?? 19.432608,
              'longitud': longitud ?? -99.133209,
              'motivo': motivo ?? 'Botón de pánico presionado por el paciente',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final nueva = AlertaSosModel.fromJson(data);
        _alertasSimuladas.insert(0, nueva);
        return {'exito': true, 'alerta': nueva};
      }
    } catch (_) {
      // Modo desarrollo
    }

    final simulada = AlertaSosModel(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      idPaciente: idPaciente,
      nombrePaciente: 'Paciente',
      fechaCreacion: DateTime.now(),
      idEstadoAlerta: 1,
      estado: 'Activa',
    );
    _alertasSimuladas.insert(0, simulada);
    return {'exito': true, 'modoSimulacion': true, 'alerta': simulada};
  }

  /// Obtiene las alertas activas pendientes de atención para el cuidador
  static Future<List<AlertaSosModel>> obtenerAlertasActivas() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConstants.alertasActivas))
          .timeout(const Duration(seconds: 5));

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
      final response = await http
          .post(
            Uri.parse(ApiConstants.resolverAlerta),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'idAlerta': idAlerta,
              'resolucion': resolucion,
              'fechaResolucion': DateTime.now().toIso8601String(),
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
      );
    }
  }
}

