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

        await prefs.setString(_keyToken, usuario.token ?? '');
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
        final bool requiereConfirmacion = data['requiereConfirmacion'] == true ||
            (usuario.token == null || usuario.token!.isEmpty);

        // Limpiar cachés de cualquier cuenta previa en el dispositivo
        final prefs = await SharedPreferences.getInstance();
        await _limpiarCachesLocales(prefs);

        // Guardar sesión activa del nuevo cuidador registrado solo si ya tiene token
        if (!requiereConfirmacion && usuario.token != null && usuario.token!.isNotEmpty) {
          await prefs.setString(_keyToken, usuario.token!);
          await prefs.setString(_keyUsuarioId, usuario.id);
          await prefs.setString(_keyRol, 'cuidador');
          await prefs.setString('usuario_nombre', usuario.nombre.isNotEmpty ? usuario.nombre : nombre.trim());
          await prefs.setString('usuario_apellidos', usuario.apellidos.isNotEmpty ? usuario.apellidos : apellidos.trim());
          await prefs.setString('usuario_correo', usuario.correo.isNotEmpty ? usuario.correo : correo.trim());
          await prefs.setString('usuario_telefono', usuario.telefono.isNotEmpty ? usuario.telefono : telefono.trim());
          if (usuario.foto != null && usuario.foto!.isNotEmpty) {
            await prefs.setString('usuario_foto', usuario.foto!);
          }
        }

        return {
          'exito': true,
          'data': data,
          'usuario': usuario,
          'requiereConfirmacion': requiereConfirmacion,
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'exito': false,
          'mensaje': error['mensaje'] ?? 'No se pudo completar el registro.',
        };
      }
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error al conectar con el servidor: $e',
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
      return {
        'exito': false,
        'mensaje': 'Error de conexión al validar código con el servidor: $e',
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

  /// Solicita el restablecimiento de contraseña enviando un código OTP al correo
  static Future<Map<String, dynamic>> solicitarRecuperacionPassword(String correo) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.recuperarPassword),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'correo': correo.trim()}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['exito'] == true) {
        return {
          'exito': true,
          'mensaje': data['mensaje'] ?? 'Código de recuperación enviado.',
        };
      } else {
        return {
          'exito': false,
          'mensaje': data['mensaje'] ?? 'No se pudo enviar el correo de recuperación.',
        };
      }
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error de conexión al solicitar recuperación: $e',
      };
    }
  }

  /// Restablece la contraseña utilizando el código OTP recibido por correo
  static Future<Map<String, dynamic>> restablecerPassword({
    required String correo,
    required String codigo,
    required String nuevaContrasena,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.restablecerPassword),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'correo': correo.trim(),
              'codigo': codigo.trim(),
              'nuevaContrasena': nuevaContrasena.trim(),
            }),
          )
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['exito'] == true) {
        return {
          'exito': true,
          'mensaje': data['mensaje'] ?? 'Contraseña restablecida exitosamente.',
        };
      } else {
        return {
          'exito': false,
          'mensaje': data['mensaje'] ?? 'No se pudo restablecer la contraseña.',
        };
      }
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error de conexión al restablecer contraseña: $e',
      };
    }
  }

  /// Solicita el reenvío del correo de activación / confirmación de cuenta
  static Future<Map<String, dynamic>> reenviarConfirmacion(String correo) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.reenviarConfirmacion),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'correo': correo.trim()}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['exito'] == true) {
        return {
          'exito': true,
          'mensaje': data['mensaje'] ?? 'Correo de activación reenviado.',
        };
      } else {
        return {
          'exito': false,
          'mensaje': data['mensaje'] ?? 'No se pudo reenviar la confirmación.',
        };
      }
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error de conexión al reenviar confirmación: $e',
      };
    }
  }
}

