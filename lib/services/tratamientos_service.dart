import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_bridge/models/toma_model.dart';
import 'package:vital_bridge/models/tratamiento_model.dart';
import 'package:vital_bridge/services/api_constants.dart';
import 'package:vital_bridge/services/auth_service.dart';

class TratamientosService {
  // Constantes de persistencia local offline
  static const String _keyCacheTratamientos = 'cache_tratamientos_json';
  static const String _keyCacheTomasHoy = 'cache_tomas_hoy_json';
  static const String _keyColaTomasPendientes = 'cola_tomas_pendientes_json';

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

  // Registro de tomas confirmadas en memoria volátil
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

  /// Sincroniza en segundo plano cualquier toma pendiente de la cola offline
  static Future<void> sincronizarTomasPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final colaJson = prefs.getString(_keyColaTomasPendientes);
    if (colaJson == null || colaJson.isEmpty) return;

    try {
      final List<dynamic> pendientes = jsonDecode(colaJson);
      if (pendientes.isEmpty) return;

      final headers = await _obtenerHeaders();
      final List<dynamic> noSincronizadas = [];

      for (var item in pendientes) {
        try {
          final res = await http
              .post(
                Uri.parse(ApiConstants.confirmarToma),
                headers: headers,
                body: jsonEncode(item),
              )
              .timeout(const Duration(seconds: 5));

          if (res.statusCode != 200 && res.statusCode != 204) {
            noSincronizadas.add(item);
          }
        } catch (_) {
          noSincronizadas.add(item);
        }
      }

      await prefs.setString(_keyColaTomasPendientes, jsonEncode(noSincronizadas));
    } catch (_) {}
  }

  /// Obtiene los tratamientos registrados para el paciente consultando la API en C#
  static Future<List<TratamientoModel>> obtenerTratamientos({String? pacienteId}) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      pacienteId ??= await AuthService.obtenerUsuarioId();
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
        await prefs.setString(_keyCacheTratamientos, jsonEncode(data));

        return lista;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error al consultar tratamientos en la API: $e');
    }

    // Respaldo de persistencia local en caché si la API no está disponible
    final cacheJson = prefs.getString(_keyCacheTratamientos);
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

  /// Elimina un tratamiento por su ID (Borrado lógico en el backend y reflejo inmediato)
  static Future<bool> eliminarTratamiento(int id) async {
    final index = _tratamientosSimulados.indexWhere((t) => t.id == id);
    String medicamentoBorrado = '';
    if (index != -1) {
      medicamentoBorrado = _tratamientosSimulados[index].medicamento.trim().toLowerCase();
      _tratamientosSimulados.removeAt(index);
    }

    _tomasHoySimuladas.removeWhere((toma) {
      final coincideId = toma.idTratamiento == id;
      final coincideNombre = medicamentoBorrado.isNotEmpty &&
          toma.medicamento.trim().toLowerCase() == medicamentoBorrado;
      return coincideId || coincideNombre;
    });

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
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('Error de conexión al eliminar tratamiento: $e');
      _tratamientosSimulados.removeWhere((t) => t.id == id);
      return true;
    }
  }

  /// Obtiene la lista de tomas programadas para hoy para un paciente específico (con soporte Offline-First)
  static Future<List<TomaModel>> obtenerTomasHoy({String? pacienteId}) async {
    final prefs = await SharedPreferences.getInstance();

    // Intentar sincronizar tomas pendientes que se hayan marcado offline
    sincronizarTomasPendientes();

    try {
      pacienteId ??= await AuthService.obtenerUsuarioId();
      final headers = await _obtenerHeaders();

      final uri = (pacienteId != null && pacienteId.isNotEmpty)
          ? Uri.parse('${ApiConstants.tomasHoy}?pacienteId=$pacienteId')
          : Uri.parse(ApiConstants.tomasHoy);

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final tomasDesdeApi = data.map((item) => TomaModel.fromJson(item)).toList();

          // Guardar copia exacta en disco local para modo offline
          await prefs.setString(_keyCacheTomasHoy, jsonEncode(data));
          return tomasDesdeApi;
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Aviso: modo offline para tomas: $e');
    }

    // 1. Respaldo de persistencia local en caché (datos de la última sincronización)
    final cacheTomasJson = prefs.getString(_keyCacheTomasHoy);
    if (cacheTomasJson != null && cacheTomasJson.isNotEmpty) {
      try {
        final List decoded = jsonDecode(cacheTomasJson);
        final tomasEnCache = decoded.map((item) => TomaModel.fromJson(item)).toList();

        // Aplicar estado de tomas confirmadas localmente mientras estuvo offline
        final colaJson = prefs.getString(_keyColaTomasPendientes);
        if (colaJson != null && colaJson.isNotEmpty) {
          final List pendientes = jsonDecode(colaJson);
          for (var p in pendientes) {
            final id = p['idHorario'];
            final index = tomasEnCache.indexWhere((t) => t.idHorario == id);
            if (index != -1) {
              tomasEnCache[index] = tomasEnCache[index].copyWith(
                estado: 'Tomada',
                horaTomada: DateTime.tryParse(p['horaTomada'].toString()) ?? DateTime.now(),
              );
            }
          }
        }

        return tomasEnCache;
      } catch (_) {}
    }

    // 2. Respaldo secundario: Reconstruir a partir de tratamientos en caché
    final tratamientos = await obtenerTratamientos(pacienteId: pacienteId);
    if (tratamientos.isNotEmpty) {
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
              indicaciones: trat.indicaciones,
            ),
          );
        }
      }

      tomasPaciente.sort((a, b) => a.horaProgramada.compareTo(b.horaProgramada));
      return tomasPaciente;
    }

    return List.from(_tomasHoySimuladas);
  }

  /// Marca una toma como realizada (confirmada por paciente o cuidador) con cola de sincronización offline
  static Future<bool> confirmarToma(int idHorario, {String? observaciones}) async {
    final ahoraUtc = DateTime.now().toUtc();
    _tomasConfirmadasMap[idHorario] = DateTime.now();
    _actualizarTomaSimulada(idHorario);

    final prefs = await SharedPreferences.getInstance();

    // 1. Guardar en cola de pendientes local para garantizar persistencia sin red
    final body = {
      'idHorario': idHorario,
      'horaTomada': ahoraUtc.toIso8601String(),
      if (observaciones != null) 'observaciones': observaciones,
    };

    List<dynamic> pendientes = [];
    final colaPrevia = prefs.getString(_keyColaTomasPendientes);
    if (colaPrevia != null && colaPrevia.isNotEmpty) {
      try {
        pendientes = jsonDecode(colaPrevia);
      } catch (_) {}
    }
    pendientes.removeWhere((item) => item['idHorario'] == idHorario);
    pendientes.add(body);
    await prefs.setString(_keyColaTomasPendientes, jsonEncode(pendientes));

    // 2. Actualizar también la caché de tomas locales en disco
    final cacheTomasJson = prefs.getString(_keyCacheTomasHoy);
    if (cacheTomasJson != null && cacheTomasJson.isNotEmpty) {
      try {
        final List decoded = jsonDecode(cacheTomasJson);
        for (var item in decoded) {
          if (item['idHorario'] == idHorario) {
            item['estado'] = 'Tomada';
            item['horaTomada'] = ahoraUtc.toIso8601String();
          }
        }
        await prefs.setString(_keyCacheTomasHoy, jsonEncode(decoded));
      } catch (_) {}
    }

    // 3. Intentar transmitir de inmediato al backend si hay internet
    try {
      final headers = await _obtenerHeaders();
      final response = await http
          .post(
            Uri.parse(ApiConstants.confirmarToma),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Confirmación exitosa en servidor: remover de la cola de pendientes
        pendientes.removeWhere((item) => item['idHorario'] == idHorario);
        await prefs.setString(_keyColaTomasPendientes, jsonEncode(pendientes));
        return true;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Aviso: la toma se confirmó localmente en cola offline: $e');
    }

    return true;
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
