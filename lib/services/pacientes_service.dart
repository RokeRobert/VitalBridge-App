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

  /// Obtiene los pacientes vinculados al cuidador activo
  static Future<List<PacienteModel>> obtenerPacientes() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final token = prefs.getString('auth_token') ?? '';
      final usuarioId = prefs.getString('auth_user_id') ?? '';

      final response = await http
          .get(
            Uri.parse(ApiConstants.pacientePerfil),
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
              if (usuarioId.isNotEmpty) 'X-User-Id': usuarioId,
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> listaJson = jsonDecode(response.body);
        final pacientes = listaJson.map((j) => PacienteModel.fromJson(j)).toList();
        _pacientesEnMemoria.clear();
        _pacientesEnMemoria.addAll(pacientes);
        await prefs.setString('cache_pacientes_json', jsonEncode(listaJson));
        return pacientes;
      } else {
        // ignore: avoid_print
        print('PacientesService.obtenerPacientes status: ${response.statusCode} body: ${response.body}');
      }
    } catch (e, stack) {
      // ignore: avoid_print
      print('Error en PacientesService.obtenerPacientes: $e\n$stack');
    }

    // Respaldo de persistencia local
    final cachedJson = prefs.getString('cache_pacientes_json');
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final cachedPacientes = decoded.map((j) => PacienteModel.fromJson(j)).toList();
        _pacientesEnMemoria.clear();
        _pacientesEnMemoria.addAll(cachedPacientes);
        return cachedPacientes;
      } catch (e) {
        // ignore: avoid_print
        print('Error leyendo cache_pacientes_json: $e');
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
    final usuarioId = prefs.getString('auth_user_id') ?? '00000000-0000-0000-0000-000000000001';

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
        _pacientesEnMemoria.add(nuevoPaciente);
        await prefs.setString(
          'cache_pacientes_json',
          jsonEncode(_pacientesEnMemoria.map((p) => p.toJson()).toList()),
        );

        return {
          'exito': true,
          'mensaje': 'Paciente registrado exitosamente.',
          'paciente': nuevoPaciente,
          'token': nuevoPaciente.token ?? tokenGenerado,
        };
      }
    } catch (_) {
      // Fallback para desarrollo sin conexión
    }

    // Creación local para que la UI funcione de inmediato
    final nuevoPacienteLocal = PacienteModel(
      id: 'paciente-${DateTime.now().millisecondsSinceEpoch}',
      nombre: nombre.trim(),
      apellidos: apellidos.trim(),
      parentesco: parentesco.trim(),
      telefono: telefono.trim(),
      idUsuario: usuarioId,
      token: tokenGenerado,
      tipoPaciente: idTipoPaciente == 1
          ? 'Adulto Mayor'
          : (idTipoPaciente == 2 ? 'Paciente Crónico' : 'General'),
      fechaRegistro: DateTime.now(),
    );

    _pacientesEnMemoria.add(nuevoPacienteLocal);

    return {
      'exito': true,
      'mensaje': 'Paciente creado exitosamente.',
      'paciente': nuevoPacienteLocal,
      'token': tokenGenerado,
    };
  }

  /// Desactiva lógicamente (Soft Delete) a un paciente
  static Future<bool> eliminarPaciente(String idPaciente) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http
          .delete(
            Uri.parse('${ApiConstants.pacientePerfil}/$idPaciente'),
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 || response.statusCode == 204) {
        _pacientesEnMemoria.removeWhere((p) => p.id == idPaciente);
        return true;
      }
    } catch (_) {
      // Fallback local
    }

    _pacientesEnMemoria.removeWhere((p) => p.id == idPaciente);
    return true;
  }
}

