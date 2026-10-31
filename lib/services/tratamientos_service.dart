import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_bridge/models/toma_model.dart';
import 'package:vital_bridge/models/tratamiento_model.dart';
import 'package:vital_bridge/services/api_constants.dart';

class TratamientosService {
  // Lista en memoria para modo desarrollo / simulación sin backend encendido
  static final List<TratamientoModel> _tratamientosSimulados = [
    TratamientoModel(
      id: 1,
      medicamento: 'Paracetamol',
      cantidad: 500,
      unidadMedida: 'mg',
      frecuencia: 'Cada 8 horas',
      fechaInicio: DateTime.now().subtract(const Duration(days: 5)),
      fechaFinal: DateTime.now().add(const Duration(days: 5)),
      indicaciones: 'Tomar después de comer con abundante agua.',
      horarios: ['08:00 AM', '04:00 PM', '11:00 PM'],
      presentacion: 'Tableta',
    ),
    TratamientoModel(
      id: 2,
      medicamento: 'Losartán',
      cantidad: 50,
      unidadMedida: 'mg',
      frecuencia: 'Cada 12 horas',
      fechaInicio: DateTime.now().subtract(const Duration(days: 20)),
      indicaciones: 'Para el control de la presión arterial.',
      horarios: ['09:00 AM', '09:00 PM'],
      presentacion: 'Comprimido',
    ),
    TratamientoModel(
      id: 3,
      medicamento: 'Omeprazol',
      cantidad: 20,
      unidadMedida: 'mg',
      frecuencia: 'Cada 24 horas',
      fechaInicio: DateTime.now().subtract(const Duration(days: 10)),
      indicaciones: 'Tomar en ayunas 30 minutos antes del desayuno.',
      horarios: ['07:30 AM'],
      presentacion: 'Cápsula',
    ),
  ];

  // Registro de tomas confirmadas para persistencia en sesión
  static final Map<int, DateTime> _tomasConfirmadasMap = {};

  /// Obtiene los headers de autenticación almacenados
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

  /// Obtiene los tratamientos registrados para el paciente consultando la API en C#
  static Future<List<TratamientoModel>> obtenerTratamientos({String? pacienteId}) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final headers = await _obtenerHeaders();
      final uri = (pacienteId != null && pacienteId.isNotEmpty)
          ? Uri.parse('${ApiConstants.tratamientos}?pacienteId=$pacienteId')
          : Uri.parse(ApiConstants.tratamientos);

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final lista = data.map((item) => TratamientoModel.fromJson(item)).toList();

        // Actualizar respaldo en memoria y caché local
        _tratamientosSimulados.clear();
        _tratamientosSimulados.addAll(lista);
        await prefs.setString('cache_tratamientos_json', jsonEncode(data));

        return lista;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error al consultar tratamientos en la API: $e');
    }

    // Respaldo de persistencia local en caché si la API no está disponible
    final cacheJson = prefs.getString('cache_tratamientos_json');
    if (cacheJson != null && cacheJson.isNotEmpty) {
      try {
        final List decoded = jsonDecode(cacheJson);
        final enCache = decoded.map((item) => TratamientoModel.fromJson(item)).toList();
        if (pacienteId != null && pacienteId.isNotEmpty) {
          final filtrados = enCache.where((t) => t.idPaciente == pacienteId).toList();
          if (filtrados.isNotEmpty) return filtrados;
        }
        return enCache;
      } catch (_) {}
    }

    if (pacienteId != null && pacienteId.isNotEmpty) {
      final filtrados = _tratamientosSimulados.where((t) => t.idPaciente == pacienteId).toList();
      if (filtrados.isNotEmpty) return filtrados;
    }

    return List.from(_tratamientosSimulados);
  }

  /// Agrega un nuevo tratamiento médico en el backend
  static Future<Map<String, dynamic>> agregarTratamiento(TratamientoModel nuevoTratamiento) async {
    try {
      final headers = await _obtenerHeaders();
      final response = await http
          .post(
            Uri.parse(ApiConstants.tratamientos),
            headers: headers,
            body: jsonEncode(nuevoTratamiento.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final TratamientoModel creado = data is Map && data.containsKey('tratamiento')
            ? TratamientoModel.fromJson(data['tratamiento'])
            : TratamientoModel.fromJson(data);

        _tratamientosSimulados.insert(0, creado);
        return {'exito': true, 'tratamiento': creado, 'mensaje': 'Tratamiento registrado con éxito.'};
      } else {
        return {
          'exito': false,
          'mensaje': 'El servidor respondió con error (${response.statusCode}): ${response.body}',
        };
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error de conexión al agregar tratamiento: $e');
      _tratamientosSimulados.insert(0, nuevoTratamiento);
      return {
        'exito': true,
        'modoSimulacion': true,
        'tratamiento': nuevoTratamiento,
        'mensaje': 'Guardado localmente (modo sin conexión)',
      };
    }
  }

  /// Actualiza los datos de un tratamiento existente en el backend
  static Future<Map<String, dynamic>> actualizarTratamiento(TratamientoModel tratamiento) async {
    try {
      final headers = await _obtenerHeaders();
      final response = await http
          .put(
            Uri.parse('${ApiConstants.tratamientos}/${tratamiento.id}'),
            headers: headers,
            body: jsonEncode(tratamiento.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final TratamientoModel actualizado = data is Map && data.containsKey('tratamiento')
            ? TratamientoModel.fromJson(data['tratamiento'])
            : tratamiento;

        final index = _tratamientosSimulados.indexWhere((t) => t.id == tratamiento.id);
        if (index != -1) {
          _tratamientosSimulados[index] = actualizado;
        }

        return {
          'exito': true,
          'mensaje': data is Map ? (data['mensaje'] ?? 'Tratamiento actualizado.') : 'Tratamiento actualizado.',
          'tratamiento': actualizado,
        };
      } else {
        return {
          'exito': false,
          'mensaje': 'Error del servidor (${response.statusCode}): ${response.body}',
        };
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error de conexión al actualizar tratamiento: $e');
      final index = _tratamientosSimulados.indexWhere((t) => t.id == tratamiento.id);
      if (index != -1) {
        _tratamientosSimulados[index] = tratamiento;
      }
      return {
        'exito': true,
        'modoSimulacion': true,
        'tratamiento': tratamiento,
        'mensaje': 'Actualizado localmente (modo sin conexión)',
      };
    }
  }

  /// Elimina un tratamiento por su ID (Borrado lógico en el backend)
  static Future<bool> eliminarTratamiento(int id) async {
    try {
      final headers = await _obtenerHeaders();
      final response = await http
          .delete(
            Uri.parse('${ApiConstants.tratamientos}/$id'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 204) {
        _tratamientosSimulados.removeWhere((t) => t.id == id);
        return true;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error de conexión al eliminar tratamiento: $e');
    }

    _tratamientosSimulados.removeWhere((t) => t.id == id);
    return true;
  }

  /// Obtiene la lista de tomas programadas para hoy para un paciente específico
  static Future<List<TomaModel>> obtenerTomasHoy({String? pacienteId}) async {
    if (pacienteId == null || pacienteId.isEmpty) return [];

    try {
      final headers = await _obtenerHeaders();
      final uri = Uri.parse('${ApiConstants.tomasHoy}?pacienteId=$pacienteId');

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final tomasDesdeApi = data.map((item) => TomaModel.fromJson(item)).toList();
          return tomasDesdeApi;
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error al consultar tomas de la API: $e');
    }

    // Si la API devolvió lista vacía o falló la conexión:
    // Generar las tomas del día directamente a partir de los tratamientos reales del paciente
    final tratamientos = await obtenerTratamientos(pacienteId: pacienteId);
    if (tratamientos.isEmpty) return [];

    final List<TomaModel> tomasPaciente = [];

    for (var trat in tratamientos) {
      if (!trat.activo) continue;

      final horarios = trat.horarios.isNotEmpty ? trat.horarios : ['08:00 AM'];

      for (int i = 0; i < horarios.length; i++) {
        final hora = horarios[i];
        final idHorario = trat.id * 100 + i + 1;
        final horaConfirmada = _tomasConfirmadasMap[idHorario];
        final esTomada = horaConfirmada != null;

        tomasPaciente.add(
          TomaModel(
            idHorario: idHorario,
            idTratamiento: trat.id,
            medicamento: trat.medicamento,
            dosis: trat.dosisLegible,
            horaProgramada: hora,
            horaTomada: horaConfirmada,
            estado: esTomada ? 'Tomada' : 'Pendiente',
          ),
        );
      }
    }

    // Ordenar cronológicamente por hora programada
    tomasPaciente.sort((a, b) => a.horaProgramada.compareTo(b.horaProgramada));
    return tomasPaciente;
  }

  /// Marca una toma como realizada (confirmada por paciente o cuidador)
  static Future<bool> confirmarToma(int idHorario, {String? observaciones}) async {
    _tomasConfirmadasMap[idHorario] = DateTime.now();

    try {
      final headers = await _obtenerHeaders();
      final Map<String, dynamic> body = {
        'idHorario': idHorario,
        'horaTomada': DateTime.now().toIso8601String(),
        if (observaciones != null) 'observaciones': observaciones,
      };

      final response = await http
          .post(
            Uri.parse(ApiConstants.confirmarToma),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Aviso: la toma se confirmó localmente: $e');
    }

    return true;
  }
}
