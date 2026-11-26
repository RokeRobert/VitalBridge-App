import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_bridge/models/paciente_model.dart';
import 'package:vital_bridge/services/api_constants.dart';

/// Servicio para la gestión de Pacientes vinculados al Cuidador.
/// Maneja la comunicación con el Backend en C# y proporciona un respaldo en memoria
/// para desarrollo continuo sin interrupciones.
class PacientesService {
  // Caché en memoria para desarrollo y modo offline
  static final List<PacienteModel> _pacientesEnMemoria = [];

  /// Limpia la caché en memoria al cerrar sesión o cambiar de cuenta
  static void limpiarCache() {
    _pacientesEnMemoria.clear();
  }

  /// Clave de almacenamiento para persistir el paciente activo seleccionado
  static String _keyPacienteSeleccionado(String usuarioId) => 'paciente_activo_id_$usuarioId';

  /// Obtiene el ID del paciente actualmente seleccionado por el cuidador
  static Future<String?> obtenerIdPacienteSeleccionado() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioId = prefs.getString('auth_user_id') ?? '';
    if (usuarioId.isEmpty) return null;
    return prefs.getString(_keyPacienteSeleccionado(usuarioId));
  }

  /// Guarda el ID del paciente seleccionado para recordarlo entre pantallas y reinicios
  static Future<void> guardarIdPacienteSeleccionado(String idPaciente) async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioId = prefs.getString('auth_user_id') ?? '';
    if (usuarioId.isNotEmpty) {
      await prefs.setString(_keyPacienteSeleccionado(usuarioId), idPaciente);
    }
  }

  /// Obtiene un paciente específico por su ID desde la lista en memoria o caché
  static Future<PacienteModel?> obtenerPacientePorId(String idPaciente) async {
    if (idPaciente.isEmpty) return null;
    if (_pacientesEnMemoria.isEmpty) {
      await obtenerPacientes();
    }
    try {
      return _pacientesEnMemoria.firstWhere((p) => p.id == idPaciente);
    } catch (_) {
      try {
        final fresca = await obtenerPacientes();
        return fresca.firstWhere((p) => p.id == idPaciente);
      } catch (_) {
        return null;
      }
    }
  }

  /// Cuenta cuántos pacientes tiene actualmente asignados el cuidador
  static Future<int> contarPacientes() async {
    final lista = await obtenerPacientes();
    return lista.length;
  }

  /// Obtiene los pacientes vinculados al cuidador activo
  static Future<List<PacienteModel>> obtenerPacientes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final usuarioId = prefs.getString('auth_user_id') ?? '';

    // Si no hay un usuario cuidador autenticado, no hay pacientes que consultar
    if (usuarioId.isEmpty) {
      _pacientesEnMemoria.clear();
      return [];
    }

    final cacheKey = 'cache_pacientes_json_$usuarioId';

    try {
      final response = await http
          .get(
            Uri.parse(ApiConstants.pacientePerfil),
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
              'X-User-Id': usuarioId,
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> listaJson = jsonDecode(response.body);
        final pacientes = listaJson.map((j) => PacienteModel.fromJson(j)).toList();
        _pacientesEnMemoria.clear();
        _pacientesEnMemoria.addAll(pacientes);
        await prefs.setString(cacheKey, jsonEncode(listaJson));
        return pacientes;
      } else {
        // ignore: avoid_print
        print('PacientesService.obtenerPacientes status: ${response.statusCode} body: ${response.body}');
      }
    } catch (e, stack) {
      // ignore: avoid_print
      print('Error en PacientesService.obtenerPacientes: $e\n$stack');
    }

    // Respaldo de persistencia local indexado por el ID del cuidador activo
    final cachedJson = prefs.getString(cacheKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final cachedPacientes = decoded.map((j) => PacienteModel.fromJson(j)).toList();
        _pacientesEnMemoria.clear();
        _pacientesEnMemoria.addAll(cachedPacientes);
        return cachedPacientes;
      } catch (e) {
        // ignore: avoid_print
        print('Error leyendo $cacheKey: $e');
      }
    }

    return List.unmodifiable(_pacientesEnMemoria);
  }

  /// Registra un nuevo paciente y genera su token único para el código QR
  static Future<Map<String, dynamic>> registrarPaciente({
    required String nombre,
    required String apellidos,
    required String telefono,
    required String parentesco,
    int idTipoPaciente = 1, // 1: Adulto Mayor
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final usuarioId = prefs.getString('auth_user_id') ?? '';

    if (usuarioId.isEmpty) {
      return {
        'exito': false,
        'mensaje': 'No se encontró una sesión activa de cuidador.',
      };
    }

    final cacheKey = 'cache_pacientes_json_$usuarioId';

    // Asegurar que la lista en memoria contenga todos los pacientes previos antes de registrar uno nuevo
    if (_pacientesEnMemoria.isEmpty) {
      await obtenerPacientes();
    }

    // Generar un código de token seguro de alta entropía (ej: VB-7K9M-4X2P)
    const alfabeto = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = Random.secure();
    final p1 = List.generate(4, (_) => alfabeto[random.nextInt(alfabeto.length)]).join();
    final p2 = List.generate(4, (_) => alfabeto[random.nextInt(alfabeto.length)]).join();
    final tokenGenerado = 'VB-$p1-$p2';

    final payload = {
      'nombrePaciente': nombre.trim(),
      'apellidosPacientes': apellidos.trim(),
      'telefono': telefono.trim(),
      'parentesco': parentesco.trim(),
      'idTipoPaciente': idTipoPaciente,
      'idUsuario': usuarioId,
      'token': tokenGenerado,
    };

    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.pacientePerfil),
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
              'X-User-Id': usuarioId,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final nuevoPaciente = PacienteModel.fromJson(data['paciente'] ?? data);
        _pacientesEnMemoria.removeWhere((p) => p.id == nuevoPaciente.id);
        _pacientesEnMemoria.add(nuevoPaciente);
        await prefs.setString(
          cacheKey,
          jsonEncode(_pacientesEnMemoria.map((p) => p.toJson()).toList()),
        );
        await guardarIdPacienteSeleccionado(nuevoPaciente.id);

        return {
          'exito': true,
          'mensaje': 'Paciente registrado exitosamente.',
          'paciente': nuevoPaciente,
          'token': nuevoPaciente.token ?? tokenGenerado,
        };
      } else {
        return {
          'exito': false,
          'mensaje': 'Error del servidor (${response.statusCode}) al registrar paciente.',
        };
      }
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'No se pudo conectar con el servidor para registrar al paciente: $e',
      };
    }
  }

  /// Desactiva lógicamente (Soft Delete / Archivar) a un paciente
  static Future<bool> eliminarPaciente(String idPaciente) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final usuarioId = prefs.getString('auth_user_id') ?? '';

      final response = await http
          .delete(
            Uri.parse('${ApiConstants.pacientePerfil}/$idPaciente'),
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
              if (usuarioId.isNotEmpty) 'X-User-Id': usuarioId,
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) {
        _pacientesEnMemoria.removeWhere((p) => p.id == idPaciente);
        if (usuarioId.isNotEmpty) {
          await prefs.setString(
            'cache_pacientes_json_$usuarioId',
            jsonEncode(_pacientesEnMemoria.map((p) => p.toJson()).toList()),
          );
          final idActivo = await obtenerIdPacienteSeleccionado();
          if (idActivo == idPaciente) {
            final siguiente = _pacientesEnMemoria.isNotEmpty ? _pacientesEnMemoria.first.id : '';
            await guardarIdPacienteSeleccionado(siguiente);
          }
        }
        return true;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error al archivar paciente: $e');
    }

    return false;
  }
}

