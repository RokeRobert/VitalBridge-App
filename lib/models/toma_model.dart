/// Modelo que representa la toma programada o realizada de un medicamento.
/// Se mapea con las entidades 'Horario' y 'Toma' de C#.
class TomaModel {
  final int idHorario;
  final int? idTratamiento;
  final String medicamento;
  final String dosis;
  final String horaProgramada;
  final DateTime? horaTomada;
  final String estado; // 'Tomada', 'Próxima', 'Pendiente', 'Omitida'
  final String? observaciones;
  final String? indicaciones;

  TomaModel({
    required this.idHorario,
    this.idTratamiento,
    required this.medicamento,
    required this.dosis,
    required this.horaProgramada,
    this.horaTomada,
    this.estado = 'Pendiente',
    this.observaciones,
    this.indicaciones,
  });

  /// Determina si ya fue registrada como tomada
  bool get esTomada => estado.toLowerCase() == 'tomada';

  /// Hora confirmada legible
  String? get horaConfirmadaLegible {
    if (horaTomada == null) return null;
    final local = horaTomada!.toLocal();
    final hora = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$hora:$min';
  }

  TomaModel copyWith({
    int? idHorario,
    int? idTratamiento,
    String? medicamento,
    String? dosis,
    String? horaProgramada,
    DateTime? horaTomada,
    String? estado,
    String? observaciones,
    String? indicaciones,
  }) {
    return TomaModel(
      idHorario: idHorario ?? this.idHorario,
      idTratamiento: idTratamiento ?? this.idTratamiento,
      medicamento: medicamento ?? this.medicamento,
      dosis: dosis ?? this.dosis,
      horaProgramada: horaProgramada ?? this.horaProgramada,
      horaTomada: horaTomada ?? this.horaTomada,
      estado: estado ?? this.estado,
      observaciones: observaciones ?? this.observaciones,
      indicaciones: indicaciones ?? this.indicaciones,
    );
  }

  factory TomaModel.fromJson(Map<String, dynamic> json) {
    return TomaModel(
      idHorario: int.tryParse((json['idHorario'] ?? json['id_horario'] ?? 0).toString()) ?? 0,
      idTratamiento: int.tryParse((json['idTratamiento'] ?? json['id_tratamiento'])?.toString() ?? ''),
      medicamento: (json['medicamento'] ?? json['nombre'] ?? '').toString(),
      dosis: (json['dosis'] ?? json['cantidad'] ?? '1 tableta').toString(),
      horaProgramada: (json['horaProgramada'] ?? json['hora'] ?? '8:00 AM').toString(),
      horaTomada: json['horaTomada'] != null
          ? DateTime.tryParse(json['horaTomada'].toString())
          : (json['hora_tomada'] != null
              ? DateTime.tryParse(json['hora_tomada'].toString())
              : null),
      estado: (json['estado'] ?? json['nombreEstado'] ?? 'Pendiente').toString(),
      observaciones: json['observaciones']?.toString(),
      indicaciones: json['indicaciones']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idHorario': idHorario,
      if (idTratamiento != null) 'idTratamiento': idTratamiento,
      'medicamento': medicamento,
      'dosis': dosis,
      'horaProgramada': horaProgramada,
      if (horaTomada != null) 'horaTomada': horaTomada!.toIso8601String(),
      'estado': estado,
      if (observaciones != null) 'observaciones': observaciones,
      if (indicaciones != null) 'indicaciones': indicaciones,
    };
  }
}
