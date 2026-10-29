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

  TomaModel({
    required this.idHorario,
    this.idTratamiento,
    required this.medicamento,
    required this.dosis,
    required this.horaProgramada,
    this.horaTomada,
    this.estado = 'Pendiente',
    this.observaciones,
  });

  /// Determina si ya fue registrada como tomada
  bool get esTomada => estado == 'Tomada';

  /// Hora confirmada legible
  String? get horaConfirmadaLegible {
    if (horaTomada == null) return null;
    final hora = horaTomada!.hour.toString().padLeft(2, '0');
    final min = horaTomada!.minute.toString().padLeft(2, '0');
    return '$hora:$min';
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
    };
  }
}

