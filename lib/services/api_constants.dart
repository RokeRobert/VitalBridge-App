// ============================================================================
// CONFIGURACIÓN DE RUTAS Y CONSTANTES DE RED (api_constants.dart)
// ============================================================================
// Centraliza todas las URLs y endpoints de la API REST para evitar tener
// direcciones "quemadas" (hardcoded) dispersas en el código.
// ============================================================================

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // --------------------------------------------------------------------------
  // URL BASE DINÁMICA
  // --------------------------------------------------------------------------
  // ¿Por qué usamos 10.0.2.2 en Android?
  // El Emulador de Android funciona dentro de una red virtual aislada.
  // Su 'localhost' (127.0.0.1) apunta a sí mismo (al teléfono virtual).
  // La IP '10.0.2.2' es un alias reservado por Google que conecta directamente
  // con el 'localhost' de tu computadora física donde corre el backend en el puerto 5113.
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5113/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:5113/api';
    } catch (_) {}
    return 'http://localhost:5113/api'; // Si corre en Windows Desktop o pruebas locales
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

  // --- Endpoints de Perfiles y Almacenamiento de Fotos (/api/perfiles) ---
  static String get subirFotoPerfil => '$baseUrl/perfiles/foto';
  static String perfilUsuario(String id) => '$baseUrl/perfiles/usuario/$id';
}
