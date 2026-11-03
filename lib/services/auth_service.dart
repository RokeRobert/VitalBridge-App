import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_bridge/models/paciente_model.dart';
import 'package:vital_bridge/models/usuario_model.dart';
import 'package:vital_bridge/services/api_constants.dart';
import 'package:vital_bridge/services/pacientes_service.dart';
import 'package:vital_bridge/services/tratamientos_service.dart';

class AuthService {
  static const String _keyToken = 'auth_token';
  static const String _keyUsuarioId = 'auth_user_id';
  static const String _keyRol = 'auth_rol'; // 'cuidador' o 'paciente'

  /// Inicia sesión como Cuidador usando Correo y Contraseña
  static Future<Map<String, dynamic>> loginCuidador({
    required String correo,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.loginCuidador),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'correo': correo.trim(),
              'contrasena': password.trim(),
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final Map<String, dynamic> data = (decoded is Map)
            ? decoded.cast<String, dynamic>()
            : <String, dynamic>{};

        final dynamic userRaw = data['usuario'] ?? data;
        final Map<String, dynamic> userMap = (userRaw is Map)
            ? userRaw.cast<String, dynamic>()
            : <String, dynamic>{};

        final usuario = UsuarioModel.fromJson(userMap);

        // Guardar sesión en el teléfono
        final prefs = await SharedPreferences.getInstance();
        final usuarioIdAnterior = prefs.getString(_keyUsuarioId);
        if (usuarioIdAnterior != usuario.id) {
          await _limpiarCachesLocales(prefs);
        }

        await prefs.setString(_keyToken, usuario.token ?? 'token_simulado');
        await prefs.setString(_keyUsuarioId, usuario.id);
        await prefs.setString(_keyRol, 'cuidador');
        await prefs.setString('usuario_nombre', usuario.nombre);
        await prefs.setString('usuario_apellidos', usuario.apellidos);
        await prefs.setString('usuario_correo', usuario.correo);
        await prefs.setString('usuario_telefono', usuario.telefono);
        if (usuario.foto != null && usuario.foto!.isNotEmpty) {
          await prefs.setString('usuario_foto', usuario.foto!);
        }

        return {'exito': true, 'usuario': usuario};
      } else {
        String mensajeError = 'Credenciales incorrectas.';
        try {
          final error = jsonDecode(response.body);
          if (error is Map && error['mensaje'] != null) {
            mensajeError = error['mensaje'].toString();
          }
        } catch (_) {}
        return {
          'exito': false,
          'mensaje': mensajeError,
        };
      }
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Fallo al conectar con el servidor: $e',
      };
    }
  }

  /// Registra un nuevo Cuidador en la API
  static Future<Map<String, dynamic>> registrarCuidador({
    required String nombre,
    required String apellidos,
    required String correo,
    required String telefono,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.registroCuidador),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'nombre': nombre.trim(),
              'apellidos': apellidos.trim(),
              'correo': correo.trim(),
              'telefono': telefono.trim(),
              'contrasena': password.trim(),
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dynamic userRaw = data['usuario'] ?? data;
        final Map<String, dynamic> userMap = (userRaw is Map)
            ? userRaw.cast<String, dynamic>()
            : <String, dynamic>{};

        final usuario = UsuarioModel.fromJson(userMap);

        // Limpiar cachés de cualquier cuenta previa en el dispositivo
        final prefs = await SharedPreferences.getInstance();
        await _limpiarCachesLocales(prefs);

        // Guardar sesión activa del nuevo cuidador registrado
        await prefs.setString(_keyToken, usuario.token ?? '');
        await prefs.setString(_keyUsuarioId, usuario.id);
        await prefs.setString(_keyRol, 'cuidador');
        await prefs.setString('usuario_nombre', usuario.nombre.isNotEmpty ? usuario.nombre : nombre.trim());
        await prefs.setString('usuario_apellidos', usuario.apellidos.isNotEmpty ? usuario.apellidos : apellidos.trim());
        await prefs.setString('usuario_correo', usuario.correo.isNotEmpty ? usuario.correo : correo.trim());
        await prefs.setString('usuario_telefono', usuario.telefono.isNotEmpty ? usuario.telefono : telefono.trim());
        if (usuario.foto != null && usuario.foto!.isNotEmpty) {
          await prefs.setString('usuario_foto', usuario.foto!);
        }

        return {'exito': true, 'data': data, 'usuario': usuario};
      } else {
        final error = jsonDecode(response.body);
        return {
          'exito': false,
          'mensaje': error['mensaje'] ?? 'No se pudo completar el registro.',
        };
      }
    } catch (e) {
      // Modo desarrollo si el backend aún no está encendido
      return {
        'exito': true,
        'modoSimulacion': true,
        'mensaje': 'Cuenta creada en modo local/desarrollo.',
      };
    }
  }

  /// Inicia sesión del Paciente mediante Token único o código QR
  static Future<Map<String, dynamic>> loginPacienteConToken({
    required String token,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.loginPacienteToken),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token.trim()}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final paciente = PacienteModel.fromJson(data['paciente'] ?? data);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyToken, token);
        await prefs.setString(_keyUsuarioId, paciente.id);
        await prefs.setString(_keyRol, 'paciente');
        await prefs.setString('usuario_nombre', paciente.nombre);
        await prefs.setString('usuario_apellidos', paciente.apellidos);

        return {'exito': true, 'paciente': paciente};
      } else {
        return {'exito': false, 'mensaje': 'Código de token inválido o expirado.'};
      }
    } catch (e) {
      // Modo desarrollo / respaldo si no hay conexión al backend
      return {
        'exito': true,
        'modoSimulacion': true,
        'paciente': PacienteModel(
          id: '00000000-0000-0000-0000-000000000045',
          nombre: 'Roberto',
          apellidos: 'Gómez',
          parentesco: 'Padre',
          telefono: '+34 610 345 872',
          token: token,
        ),
      };
    }
  }

  /// Cierra la sesión activa en el dispositivo
  static Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUsuarioId);
    await prefs.remove(_keyRol);
    await prefs.remove('usuario_nombre');
    await prefs.remove('usuario_apellidos');
    await prefs.remove('usuario_correo');
    await prefs.remove('usuario_telefono');
    await prefs.remove('usuario_foto');
    await _limpiarCachesLocales(prefs);
  }

  /// Limpia cachés en disco y memoria volátil
  static Future<void> _limpiarCachesLocales(SharedPreferences prefs) async {
    final keys = prefs.getKeys().toList();
    for (var k in keys) {
      if (k.startsWith('cache_') || k.startsWith('cola_')) {
        await prefs.remove(k);
      }
    }
    PacientesService.limpiarCache();
    TratamientosService.limpiarCache();
  }

  /// Obtiene el ID del usuario actual en sesión
  static Future<String?> obtenerUsuarioId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsuarioId);
  }

  /// Obtiene el token guardado en el teléfono
  static Future<String?> obtenerTokenGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }
}

