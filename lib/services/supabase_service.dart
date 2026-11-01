import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio centralizado para la conexión con Supabase y escucha de eventos Realtime
class SupabaseService {
  static const String supabaseUrl = 'https://gbhdsmsmxschbxtrmzpk.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdiaGRzbXNteHNjaGJ4dHJtenBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA5NTA5NTIsImV4cCI6MjEwNjUyNjk1Mn0.SUXrtvJJs0qAMNN7NX_hPOWnhs9W6Cp9COX74e19CMU';

  static bool _inicializado = false;
  static bool get estaInicializado => _inicializado;

  /// Inicializa la conexión con Supabase al arranque de la aplicación
  static Future<void> inicializar() async {
    if (_inicializado) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
      _inicializado = true;
      if (kDebugMode) {
        // ignore: avoid_print
        print('✅ Supabase Realtime inicializado correctamente.');
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('⚠️ Aviso: Supabase inicialización diferida o sin red: $e');
      }
    }
  }

  /// Instancia del cliente de Supabase
  static SupabaseClient? get client {
    if (!_inicializado) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Suscribe un listener a cualquier cambio (INSERT, UPDATE, DELETE) en una tabla de PostgreSQL
  static RealtimeChannel? escucharTabla({
    required String canalNombre,
    required String tabla,
    required void Function() onCambio,
  }) {
    final c = client;
    if (c == null) return null;

    try {
      final channel = c.channel(canalNombre);
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: tabla,
        callback: (payload) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('🔔 Evento Realtime en tabla $tabla: ${payload.eventType}');
          }
          onCambio();
        },
      ).subscribe();

      return channel;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Error al suscribir canal Realtime para $tabla: $e');
      }
      return null;
    }
  }
}

