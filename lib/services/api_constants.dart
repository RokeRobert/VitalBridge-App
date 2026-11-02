// ============================================================================
// CONFIGURACIÓN DE RUTAS Y CONSTANTES DE RED (api_constants.dart)
// ============================================================================
// Centraliza todas las URLs y endpoints de la API REST para conectar la app
// móvil con el backend en la nube o en desarrollo local.
// ============================================================================

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // --------------------------------------------------------------------------
  // URL PÚBLICA EN LA NUBE (Render con HTTPS)
  // --------------------------------------------------------------------------
  static const String nubeUrl = 'https://vitalbridge-backend-vl2w.onrender.com/api';

  // Cambiar a 'true' solo si se desea probar con backend local en localhost:5113
  static const bool usarServidorLocal = false;

  /// Retorna la URL base correspondiente (por defecto en la nube pública)
  static String get baseUrl {
    if (usarServidorLocal) {
      if (kIsWeb) return 'http://localhost:5113/api';
      try {
        if (Platform.isAndroid) return 'http://10.0.2.2:5113/api';
      } catch (_) {}
      return 'http://localhost:5113/api';
    }
    return nubeUrl;
  }

  // --- Endpoints de Autenticación (/api/auth) ---
  static String get loginCuidador => '$baseUrl/auth/login';
  static String get registroCuidador => '$baseUrl/auth/registro';
  static String get loginPacienteToken => '$baseUrl/auth/paciente/token';

  // --- Endpoints de Pacientes (/api/pacientes) ---
  static String get pacientePerfil => '$baseUrl/pacientes';
  static String get generarTokenPaciente => '$baseUrl/pacientes/token';

  // --- Endpoints de Tratamientos y Medicamentos (/api/tratamientos) ---
  static String get tratamientos => '$baseUrl/tratamientos';

  // --- Endpoints de Horarios y Tomas de Medicamentos (/api/tomas) ---
  static String get tomasHoy => '$baseUrl/tomas/hoy';
  static String get confirmarToma => '$baseUrl/tomas/confirmar';

  // --- Endpoints de Emergencias y Alertas SOS (/api/alertas) ---
  static String get emitirAlertaSOS => '$baseUrl/alertas/sos';
  static String get alertasActivas => '$baseUrl/alertas/activas';
  static String get resolverAlerta => '$baseUrl/alertas/resolver';
  static String get registrarFcmToken => '$baseUrl/alertas/fcm-token';

  // --- Endpoints de Perfiles y Almacenamiento de Fotos (/api/perfiles) ---
  static String get subirFotoPerfil => '$baseUrl/perfiles/foto';
  static String perfilUsuario(String id) => '$baseUrl/perfiles/usuario/$id';
}
