/// Modelo que representa una Alerta SOS generada por el paciente.
/// Se mapea con la entidad 'Alerta' de C# (tabla 'alerta' en Supabase).
class AlertaSosModel {
  final int id;
  final String idPaciente;
  final String? nombrePaciente;
  final DateTime fechaCreacion;
  final int idEstadoAlerta; // 1: Activa, 2: Atendida, 3: Falsa Alarma
  final String estado;
  final double? latitud;
  final double? longitud;

  AlertaSosModel({
    required this.id,
    required this.idPaciente,
    this.nombrePaciente,
    required this.fechaCreacion,
    this.idEstadoAlerta = 1,
    this.estado = 'Activa',
    this.latitud,
    this.longitud,
  });

  bool get esActiva => idEstadoAlerta == 1 || estado.toLowerCase() == 'activa';

  static DateTime _parseUtc(dynamic val) {
    if (val == null) return DateTime.now();
    var s = val.toString().trim();
    if (s.isEmpty) return DateTime.now();
    if (!s.endsWith('Z') && !s.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
      s += 'Z';
    }
    return DateTime.tryParse(s)?.toLocal() ?? DateTime.now();
  }

  String get horaLegible {
    final local = fechaCreacion.toLocal();
    final hora = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$hora:$min';
  }

  /// Genera un enlace directo a Google Maps con las coordenadas del paciente
  String? get enlaceGoogleMaps {
    if (latitud != null && longitud != null) {
      return 'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud';
    }
    return null;
  }

  factory AlertaSosModel.fromJson(Map<String, dynamic> json) {
    return AlertaSosModel(
      id: int.tryParse((json['idAlerta'] ?? json['id_alerta'] ?? json['id'] ?? 0).toString()) ?? 0,
      idPaciente: (json['idPaciente'] ?? json['id_paciente'] ?? '').toString(),
      nombrePaciente: (json['nombrePaciente'] ??
              (json['paciente'] is Map ? json['paciente']['nombrePaciente'] : null))
          ?.toString(),
      fechaCreacion: _parseUtc(json['fechaCreacion'] ?? json['fecha_creacion']),
      idEstadoAlerta: int.tryParse((json['idEstadoAlerta'] ?? json['id_estado_alerta'] ?? 1).toString()) ?? 1,
      estado: (json['estado'] ??
              (json['estadoAlerta'] is Map ? json['estadoAlerta']['nombreEstado'] : null) ??
              'Activa')
          .toString(),
      latitud: double.tryParse((json['latitud'] ?? json['latitude'] ?? '').toString()),
      longitud: double.tryParse((json['longitud'] ?? json['longitude'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'idAlerta': id,
      'idPaciente': idPaciente,
      if (nombrePaciente != null) 'nombrePaciente': nombrePaciente,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'idEstadoAlerta': idEstadoAlerta,
      'estado': estado,
      if (latitud != null) 'latitud': latitud,
      if (longitud != null) 'longitud': longitud,
    };
  }
}
