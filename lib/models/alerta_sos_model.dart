/// Modelo que representa una Alerta SOS generada por el paciente.
/// Se mapea con la entidad 'Alerta' de C# (tabla 'alerta' en Supabase).
class AlertaSosModel {
  final int id;
  final String idPaciente;
  final String? nombrePaciente;
  final DateTime fechaCreacion;
  final int idEstadoAlerta; // 1: Activa, 2: Atendida, 3: Falsa Alarma
  final String estado;

  AlertaSosModel({
    required this.id,
    required this.idPaciente,
    this.nombrePaciente,
    required this.fechaCreacion,
    this.idEstadoAlerta = 1,
    this.estado = 'Activa',
  });

  bool get esActiva => idEstadoAlerta == 1 || estado.toLowerCase() == 'activa';

  String get horaLegible {
    final hora = fechaCreacion.hour.toString().padLeft(2, '0');
    final min = fechaCreacion.minute.toString().padLeft(2, '0');
    return '$hora:$min';
  }

  factory AlertaSosModel.fromJson(Map<String, dynamic> json) {
    return AlertaSosModel(
      id: int.tryParse((json['idAlerta'] ?? json['id_alerta'] ?? json['id'] ?? 0).toString()) ?? 0,
      idPaciente: (json['idPaciente'] ?? json['id_paciente'] ?? '').toString(),
      nombrePaciente: (json['nombrePaciente'] ??
              (json['paciente'] is Map ? json['paciente']['nombrePaciente'] : null))
          ?.toString(),
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.tryParse(json['fechaCreacion'].toString()) ?? DateTime.now()
          : (json['fecha_creacion'] != null
              ? DateTime.tryParse(json['fecha_creacion'].toString()) ?? DateTime.now()
              : DateTime.now()),
      idEstadoAlerta: int.tryParse((json['idEstadoAlerta'] ?? json['id_estado_alerta'] ?? 1).toString()) ?? 1,
      estado: (json['estado'] ??
              (json['estadoAlerta'] is Map ? json['estadoAlerta']['nombreEstado'] : null) ??
              'Activa')
          .toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'idAlerta': id,
      'idPaciente': idPaciente,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'idEstadoAlerta': idEstadoAlerta,
    };
  }
}

