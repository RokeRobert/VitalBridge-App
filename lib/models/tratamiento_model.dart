/// Modelo que representa un Tratamiento / Medicamento en Flutter.
/// Se mapea con la entidad 'Tratamiento' de C# (tabla 'tratamiento' en Supabase).
class TratamientoModel {
  final int id;
  final String? idPaciente;
  final String? idUsuario;
  final String medicamento;
  final double cantidad;
  final String unidadMedida; // Ej: "mg", "tableta", "ml"
  final int? idUnidadMedida;
  final String frecuencia; // Ej: "Cada 8 horas", "08:00:00"
  final DateTime fechaInicio;
  final DateTime? fechaFinal;
  final String? indicaciones;
  final bool activo;
  final List<String> horarios; // Ej: ["08:00 AM", "08:00 PM"]
  final String presentacion; // Ej: "Tableta", "Cápsula", "Jarabe"

  TratamientoModel({
    required this.id,
    this.idPaciente,
    this.idUsuario,
    required this.medicamento,
    this.cantidad = 1.0,
    this.unidadMedida = 'tableta',
    this.idUnidadMedida,
    this.frecuencia = 'Cada 8 horas',
    required this.fechaInicio,
    this.fechaFinal,
    this.indicaciones,
    this.activo = true,
    this.horarios = const [],
    this.presentacion = 'Tableta',
  });

  /// Texto legible de dosis (ej: "500 mg" o "1 tableta")
  String get dosisLegible {
    final cantidadStr = cantidad % 1 == 0 ? cantidad.toInt().toString() : cantidad.toString();
    return '$cantidadStr $unidadMedida';
  }

  /// Próxima toma sugerida (toma el primer horario disponible)
  String get proximaToma {
    if (horarios.isNotEmpty) {
      return horarios.first;
    }
    return '8:00 AM';
  }

  /// Crea una instancia desde el JSON que entrega la API de C#
  factory TratamientoModel.fromJson(Map<String, dynamic> json) {
    // Manejo flexible de horarios
    List<String> listaHorarios = [];
    if (json['horarios'] is List) {
      listaHorarios = (json['horarios'] as List)
          .map((h) => h is Map ? (h['dia'] ?? '').toString() : h.toString())
          .toList();
    }

    return TratamientoModel(
      id: int.tryParse((json['idTratamiento'] ?? json['id_tratamiento'] ?? json['id'] ?? 0).toString()) ?? 0,
      idPaciente: (json['idPaciente'] ?? json['id_paciente'])?.toString(),
      idUsuario: (json['idUsuario'] ?? json['id_usuario'])?.toString(),
      medicamento: (json['medicamento'] ?? json['nombre'] ?? '').toString(),
      cantidad: double.tryParse((json['cantidad'] ?? 1.0).toString()) ?? 1.0,
      unidadMedida: (json['unidadMedida'] is Map
              ? (json['unidadMedida']['abreviacion'] ?? json['unidadMedida']['nombreUnidad'])
              : (json['unidadMedida'] ??
                  json['unidad_medida'] ??
                  json['dosis'] ??
                  'tableta'))
          .toString(),
      idUnidadMedida: int.tryParse((json['idUnidadMedida'] ?? json['id_unidad_medida'])?.toString() ?? ''),
      frecuencia: (json['frecuencia'] ?? 'Cada 8 horas').toString(),
      fechaInicio: json['fechaInicio'] != null
          ? DateTime.tryParse(json['fechaInicio'].toString()) ?? DateTime.now()
          : (json['fecha_inicio'] != null
              ? DateTime.tryParse(json['fecha_inicio'].toString()) ?? DateTime.now()
              : DateTime.now()),
      fechaFinal: json['fechaFinal'] != null
          ? DateTime.tryParse(json['fechaFinal'].toString())
          : (json['fecha_final'] != null
              ? DateTime.tryParse(json['fecha_final'].toString())
              : null),
      indicaciones: json['indicaciones']?.toString(),
      activo: json['activo'] ?? (json['idEstadoTratamiento'] == 1 || json['id_estado_tratamiento'] == 1),
      horarios: listaHorarios,
      presentacion: (json['presentacion'] ?? json['tipo'] ?? 'Tableta').toString(),
    );
  }

  /// Convierte la clase a JSON para enviarlo al backend de C#
  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'idTratamiento': id,
      if (idPaciente != null) 'idPaciente': idPaciente,
      if (idUsuario != null) 'idUsuario': idUsuario,
      'medicamento': medicamento,
      'cantidad': cantidad,
      'unidadMedida': unidadMedida,
      if (idUnidadMedida != null) 'idUnidadMedida': idUnidadMedida,
      'frecuencia': frecuencia,
      'fechaInicio': fechaInicio.toIso8601String().split('T').first,
      if (fechaFinal != null) 'fechaFinal': fechaFinal!.toIso8601String().split('T').first,
      'indicaciones': indicaciones,
      'activo': activo,
      'horarios': horarios,
      'presentacion': presentacion,
    };
  }

  /// Permite crear una copia modificada
  TratamientoModel copyWith({
    int? id,
    String? idPaciente,
    String? idUsuario,
    String? medicamento,
    double? cantidad,
    String? unidadMedida,
    int? idUnidadMedida,
    String? frecuencia,
    DateTime? fechaInicio,
    DateTime? fechaFinal,
    String? indicaciones,
    bool? activo,
    List<String>? horarios,
    String? presentacion,
  }) {
    return TratamientoModel(
      id: id ?? this.id,
      idPaciente: idPaciente ?? this.idPaciente,
      idUsuario: idUsuario ?? this.idUsuario,
      medicamento: medicamento ?? this.medicamento,
      cantidad: cantidad ?? this.cantidad,
      unidadMedida: unidadMedida ?? this.unidadMedida,
      idUnidadMedida: idUnidadMedida ?? this.idUnidadMedida,
      frecuencia: frecuencia ?? this.frecuencia,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFinal: fechaFinal ?? this.fechaFinal,
      indicaciones: indicaciones ?? this.indicaciones,
      activo: activo ?? this.activo,
      horarios: horarios ?? this.horarios,
      presentacion: presentacion ?? this.presentacion,
    );
  }
}
