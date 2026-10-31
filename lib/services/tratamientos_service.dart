import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vital_bridge/models/toma_model.dart';
import 'package:vital_bridge/models/tratamiento_model.dart';
import 'package:vital_bridge/services/api_constants.dart';
import 'package:vital_bridge/services/auth_service.dart';

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

  static final List<TomaModel> _tomasHoySimuladas = [
    TomaModel(
      idHorario: 101,
      idTratamiento: 3,
      medicamento: 'Omeprazol',
      dosis: '20 mg (1 cápsula)',
      horaProgramada: '07:30 AM',
      horaTomada: DateTime.now().copyWith(hour: 7, minute: 35),
      estado: 'Tomada',
      indicaciones: 'Tomar en ayunas con agua',
    ),
    TomaModel(
      idHorario: 102,
      idTratamiento: 1,
      medicamento: 'Paracetamol',
      dosis: '500 mg (1 tableta)',
      horaProgramada: '08:00 AM',
      horaTomada: DateTime.now().copyWith(hour: 8, minute: 02),
      estado: 'Tomada',
      indicaciones: 'Después del desayuno',
    ),
    TomaModel(
      idHorario: 103,
      idTratamiento: 2,
      medicamento: 'Losartán',
      dosis: '50 mg (1 comprimido)',
      horaProgramada: '09:00 AM',
      estado: 'Pendiente',
      indicaciones: 'Para la presión arterial',
    ),
    TomaModel(
      idHorario: 104,
      idTratamiento: 1,
      medicamento: 'Paracetamol',
      dosis: '500 mg (1 tableta)',
      horaProgramada: '04:00 PM',
      estado: 'Pendiente',
      indicaciones: 'Con abundante agua',
    ),
    TomaModel(
      idHorario: 105,
      idTratamiento: 2,
      medicamento: 'Losartán',
      dosis: '50 mg (1 comprimido)',
      horaProgramada: '09:00 PM',
      estado: 'Pendiente',
      indicaciones: 'Antes de dormir',
    ),
  ];

  /// Obtiene los tratamientos registrados para el paciente
  static Future<List<TratamientoModel>> obtenerTratamientos({String? pacienteId}) async {
    try {
      pacienteId ??= await AuthService.obtenerUsuarioId();

      final uri = (pacienteId != null && pacienteId.isNotEmpty)
          ? Uri.parse('${ApiConstants.tratamientos}?pacienteId=$pacienteId')
          : Uri.parse(ApiConstants.tratamientos);

      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) => TratamientoModel.fromJson(item)).toList();
      }
    } catch (_) {
      // Modo desarrollo / desconectado
    }

    if (pacienteId != null && pacienteId.isNotEmpty) {
      final filtrados = _tratamientosSimulados
          .where((t) => t.idPaciente == pacienteId)
          .toList();
      return filtrados;
    }

    return List.from(_tratamientosSimulados);
  }

  /// Agrega un nuevo tratamiento médico
  static Future<Map<String, dynamic>> agregarTratamiento(TratamientoModel nuevoTratamiento) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.tratamientos),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(nuevoTratamiento.toJson()),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final creado = TratamientoModel.fromJson(data);
        _tratamientosSimulados.add(creado);
        return {'exito': true, 'tratamiento': creado};
      } else {
        return {'exito': false, 'mensaje': 'Error del servidor al guardar el tratamiento.'};
      }
    } catch (_) {
      // Guardar en la lista simulada para permitir probar la UI
      _tratamientosSimulados.add(nuevoTratamiento);
      return {
        'exito': true,
        'modoSimulacion': true,
        'tratamiento': nuevoTratamiento,
      };
    }
  }

  /// Elimina un tratamiento por su ID (garantiza reflejo inmediato en el paciente)
  static Future<bool> eliminarTratamiento(int id) async {
    // 1. Obtener datos del medicamento antes de borrarlo de memoria
    final index = _tratamientosSimulados.indexWhere((t) => t.id == id);
    String medicamentoBorrado = '';
    if (index != -1) {
      medicamentoBorrado = _tratamientosSimulados[index].medicamento.trim().toLowerCase();
      _tratamientosSimulados.removeAt(index);
    }

    // 2. Eliminar de inmediato las tomas del día asociadas para que
    // el paciente deje de ver las tomas de este medicamento de inmediato.
    _tomasHoySimuladas.removeWhere((toma) {
      final coincideId = toma.idTratamiento == id;
      final coincideNombre = medicamentoBorrado.isNotEmpty &&
          toma.medicamento.trim().toLowerCase() == medicamentoBorrado;
      return coincideId || coincideNombre;
    });

    try {
      final response = await http
          .delete(Uri.parse('${ApiConstants.tratamientos}/$id'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return true;
    }
  }

  /// Obtiene la lista de tomas programadas para hoy para un paciente específico
  static Future<List<TomaModel>> obtenerTomasHoy({String? pacienteId}) async {
    try {
      // Si no se proporcionó pacienteId, obtener el del usuario en sesión
      pacienteId ??= await AuthService.obtenerUsuarioId();

      final uri = (pacienteId != null && pacienteId.isNotEmpty)
          ? Uri.parse('${ApiConstants.tomasHoy}?pacienteId=$pacienteId')
          : Uri.parse(ApiConstants.tomasHoy);

      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) => TomaModel.fromJson(item)).toList();
      }
    } catch (_) {
      // Fallback a simulación si no hay conexión al backend
    }

    // Respaldo en memoria / offline:
    // Solo generamos o mostramos tomas para tratamientos que realmente sigan activos
    final tratamientosActivos = (pacienteId != null && pacienteId.isNotEmpty)
        ? _tratamientosSimulados.where((t) => t.idPaciente == pacienteId).toList()
        : _tratamientosSimulados;

    // Si el paciente no tiene tratamientos activos (fueron borrados o no se han creado),
    // devolvemos lista vacía para mostrar el Empty State correspondiente.
    if (tratamientosActivos.isEmpty) {
      return [];
    }

    // Si existen tratamientos activos, generar sus tomas correspondientes para el día
    final List<TomaModel> tomasGeneradas = [];
    for (var trat in tratamientosActivos) {
      for (int i = 0; i < trat.horarios.length; i++) {
        final hora = trat.horarios[i];
        // Verificar si ya fue marcada como tomada en _tomasHoySimuladas
        final previa = _tomasHoySimuladas.firstWhere(
          (t) => t.idTratamiento == trat.id && t.horaProgramada == hora,
          orElse: () => TomaModel(
            idHorario: trat.id * 100 + i + 1,
            idTratamiento: trat.id,
            medicamento: trat.medicamento,
            dosis: trat.dosisLegible,
            horaProgramada: hora,
            estado: 'Pendiente',
            indicaciones: trat.indicaciones,
          ),
        );
        tomasGeneradas.add(previa);
      }
    }

    return tomasGeneradas;
  }

  /// Marca una toma como realizada (confirmada por paciente o cuidador)
  static Future<bool> confirmarToma(int idHorario, {String? observaciones}) async {
    try {
      final Map<String, dynamic> body = {
        'idHorario': idHorario,
        'horaTomada': DateTime.now().toUtc().toIso8601String(),
      };
      if (observaciones != null) {
        body['observaciones'] = observaciones;
      }

      final response = await http
          .post(
            Uri.parse(ApiConstants.confirmarToma),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200 || response.statusCode == 204) {
        _actualizarTomaSimulada(idHorario);
        return true;
      }
      return false;
    } catch (_) {
      // Respaldo offline / simulación
      _actualizarTomaSimulada(idHorario);
      return true;
    }
  }

  static void _actualizarTomaSimulada(int idHorario) {
    final index = _tomasHoySimuladas.indexWhere((t) => t.idHorario == idHorario);
    if (index != -1) {
      final antigua = _tomasHoySimuladas[index];
      _tomasHoySimuladas[index] = antigua.copyWith(
        horaTomada: DateTime.now(),
        estado: 'Tomada',
      );
    }
  }
}
