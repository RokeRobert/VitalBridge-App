import 'dart:convert';
import 'package:http/http.dart' as http;
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

  static final List<TomaModel> _tomasHoySimuladas = [
    TomaModel(
      idHorario: 101,
      idTratamiento: 3,
      medicamento: 'Omeprazol',
      dosis: '20 mg (1 cápsula)',
      horaProgramada: '07:30 AM',
      horaTomada: DateTime.now().copyWith(hour: 7, minute: 35),
      estado: 'Tomada',
    ),
    TomaModel(
      idHorario: 102,
      idTratamiento: 1,
      medicamento: 'Paracetamol',
      dosis: '500 mg (1 tableta)',
      horaProgramada: '08:00 AM',
      horaTomada: DateTime.now().copyWith(hour: 8, minute: 02),
      estado: 'Tomada',
    ),
    TomaModel(
      idHorario: 103,
      idTratamiento: 2,
      medicamento: 'Losartán',
      dosis: '50 mg (1 comprimido)',
      horaProgramada: '09:00 AM',
      estado: 'Pendiente',
    ),
    TomaModel(
      idHorario: 104,
      idTratamiento: 1,
      medicamento: 'Paracetamol',
      dosis: '500 mg (1 tableta)',
      horaProgramada: '04:00 PM',
      estado: 'Pendiente',
    ),
    TomaModel(
      idHorario: 105,
      idTratamiento: 2,
      medicamento: 'Losartán',
      dosis: '50 mg (1 comprimido)',
      horaProgramada: '09:00 PM',
      estado: 'Pendiente',
    ),
  ];

  /// Obtiene los tratamientos registrados para el paciente
  static Future<List<TratamientoModel>> obtenerTratamientos({String? pacienteId}) async {
    try {
      final uri = pacienteId != null
          ? Uri.parse('${ApiConstants.tratamientos}?pacienteId=$pacienteId')
          : Uri.parse(ApiConstants.tratamientos);

      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) => TratamientoModel.fromJson(item)).toList();
      } else {
        return List.from(_tratamientosSimulados);
      }
    } catch (_) {
      // Modo desarrollo / desconectado
      return List.from(_tratamientosSimulados);
    }
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

  /// Elimina un tratamiento por su ID
  static Future<bool> eliminarTratamiento(int id) async {
    try {
      final response = await http
          .delete(Uri.parse('${ApiConstants.tratamientos}/$id'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 204) {
        _tratamientosSimulados.removeWhere((t) => t.id == id);
        return true;
      }
    } catch (_) {
      _tratamientosSimulados.removeWhere((t) => t.id == id);
      return true;
    }
    _tratamientosSimulados.removeWhere((t) => t.id == id);
    return true;
  }

  /// Obtiene la lista de tomas programadas para hoy para un paciente específico
  static Future<List<TomaModel>> obtenerTomasHoy({String? pacienteId}) async {
    try {
      final uri = pacienteId != null
          ? Uri.parse('${ApiConstants.tomasHoy}?pacienteId=$pacienteId')
          : Uri.parse(ApiConstants.tomasHoy);

      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) => TomaModel.fromJson(item)).toList();
      }
    } catch (_) {}

    // Respaldo en memoria: solo devuelve las tomas que pertenezcan a este paciente
    if (pacienteId == null) return [];

    // Buscar si hay tratamientos registrados para este paciente
    final tratamientosDelPaciente = _tratamientosSimulados
        .where((t) => t.idPaciente == pacienteId)
        .toList();

    if (tratamientosDelPaciente.isEmpty) {
      return [];
    }

    // Generar tomas del día para los tratamientos de este paciente
    final List<TomaModel> tomasPaciente = [];
    for (var trat in tratamientosDelPaciente) {
      for (int i = 0; i < trat.horarios.length; i++) {
        final hora = trat.horarios[i];
        tomasPaciente.add(
          TomaModel(
            idHorario: trat.id * 100 + i + 1,
            idTratamiento: trat.id,
            medicamento: trat.medicamento,
            dosis: trat.dosisLegible,
            horaProgramada: hora,
            estado: 'Pendiente',
          ),
        );
      }
    }

    return tomasPaciente;
  }

  /// Marca una toma como realizada (confirmada por paciente o cuidador)
  static Future<bool> confirmarToma(int idHorario, {String? observaciones}) async {
    try {
      final Map<String, dynamic> body = {
        'idHorario': idHorario,
        'horaTomada': DateTime.now().toIso8601String(),
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
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 204) {
        _actualizarTomaSimulada(idHorario);
        return true;
      }
    } catch (_) {
      _actualizarTomaSimulada(idHorario);
      return true;
    }
    _actualizarTomaSimulada(idHorario);
    return true;
  }

  static void _actualizarTomaSimulada(int idHorario) {
    final index = _tomasHoySimuladas.indexWhere((t) => t.idHorario == idHorario);
    if (index != -1) {
      final antigua = _tomasHoySimuladas[index];
      _tomasHoySimuladas[index] = TomaModel(
        idHorario: antigua.idHorario,
        idTratamiento: antigua.idTratamiento,
        medicamento: antigua.medicamento,
        dosis: antigua.dosis,
        horaProgramada: antigua.horaProgramada,
        horaTomada: DateTime.now(),
        estado: 'Tomada',
        observaciones: antigua.observaciones,
      );
    }
  }
}
