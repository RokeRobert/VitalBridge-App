// ============================================================================
// MODELO ARQUETIPO DE ENTIDAD (paciente_model.dart)
// ============================================================================
// En Flutter, los modelos representan los datos de negocio en memoria.
// Este modelo sirve como arquetipo para todos los demás (Usuario, Tratamiento, Alerta):
// 1. Inmutabilidad (propiedades 'final').
// 2. Deserialización JSON -> Objeto (factory fromJson).
// 3. Serialización Objeto -> JSON (toJson).
// 4. Copia inmutable (copyWith).
// ============================================================================

class PacienteModel {
  final String id;
  final String nombre;
  final String apellidos;
  final String parentesco;
  final String telefono;
  final String? foto;           // Opcional (nullable): URL pública de Supabase Storage
  final String? idUsuario;      // ID del cuidador asignado
  final String tipoPaciente;    // Ej: "Adulto Mayor", "Discapacidad"
  final String? token;          // Código de vinculación (ej: VB-8492-3KMZ)
  final DateTime? fechaRegistro;

  // Constructor con parámetros nombrados:
  // - required: Obligatorio para instanciar el objeto.
  // - parentesco = 'Familiar': Valor por defecto si no se especifica.
  PacienteModel({
    required this.id,
    required this.nombre,
    required this.apellidos,
    this.parentesco = 'Familiar',
    required this.telefono,
    this.foto,
    this.idUsuario,
    this.tipoPaciente = 'Adulto Mayor',
    this.token,
    this.fechaRegistro,
  });

  // Getter computado: Genera el nombre completo dinámicamente sin duplicar memoria.
  String get nombreCompleto => '$nombre $apellidos'.trim();

  // --------------------------------------------------------------------------
  // 1. DESERIALIZACIÓN (De JSON a Objeto Dart)
  // --------------------------------------------------------------------------
  // 'factory' permite ejecutar lógica de parsing y retornar una nueva instancia.
  // Es defensivo: Acepta tanto camelCase ('idPaciente') como snake_case ('id_paciente')
  // para evitar que la app crashee si cambian las convenciones del backend.
  factory PacienteModel.fromJson(Map<String, dynamic> json) {
    return PacienteModel(
      id: (json['idPaciente'] ?? json['id_paciente'] ?? json['id'] ?? '').toString(),
      nombre: (json['nombrePaciente'] ?? json['nombre_paciente'] ?? json['nombre'] ?? '').toString(),
      apellidos: (json['apellidosPacientes'] ?? json['apellidos_pacientes'] ?? json['apellidos'] ?? '').toString(),
      parentesco: (json['parentesco'] ?? json['relacion'] ?? 'Familiar').toString(),
      telefono: (json['telefono'] ?? '').toString(),
      foto: (json['fotoPaciente'] ?? json['foto_paciente'] ?? json['foto'])?.toString(),
      idUsuario: (json['idUsuario'] ?? json['id_usuario'])?.toString(),
      tipoPaciente: (json['tipoPaciente'] is Map
              ? json['tipoPaciente']['nombreTipo']
              : (json['tipoPaciente'] ??
                  json['nombreTipo'] ??
                  json['tipo_paciente'] ??
                  'Adulto Mayor'))
          .toString(),
      token: (json['token'] ?? json['tokenPaciente'] ?? json['token_paciente'])?.toString(),
      fechaRegistro: json['fechaRegistro'] != null
          ? DateTime.tryParse(json['fechaRegistro'].toString())
          : (json['fecha_registro'] != null
              ? DateTime.tryParse(json['fecha_registro'].toString())
              : null),
    );
  }

  // --------------------------------------------------------------------------
  // 2. SERIALIZACIÓN (De Objeto Dart a JSON)
  // --------------------------------------------------------------------------
  // Convierte el objeto a un Map<String, dynamic> para que 'jsonEncode()'
  // pueda transformarlo en una cadena de texto y enviarlo por HTTP POST/PUT.
  Map<String, dynamic> toJson() {
    return {
      'idPaciente': id,
      'nombrePaciente': nombre,
      'apellidosPacientes': apellidos,
      'parentesco': parentesco,
      'telefono': telefono,
      if (foto != null) 'fotoPaciente': foto,
      if (idUsuario != null) 'idUsuario': idUsuario,
      if (token != null) 'token': token,
      'tipoPaciente': tipoPaciente,
    };
  }

  // --------------------------------------------------------------------------
  // 3. PATRÓN COPYWITH (Modificación Inmutable)
  // --------------------------------------------------------------------------
  // Crea una copia exacta del paciente modificando únicamente los campos deseados.
  // Ejemplo: paciente.copyWith(nombre: 'Carlos');
  PacienteModel copyWith({
    String? id,
    String? nombre,
    String? apellidos,
    String? parentesco,
    String? telefono,
    String? foto,
    String? idUsuario,
    String? tipoPaciente,
    String? token,
    DateTime? fechaRegistro,
  }) {
    return PacienteModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellidos: apellidos ?? this.apellidos,
      parentesco: parentesco ?? this.parentesco,
      telefono: telefono ?? this.telefono,
      foto: foto ?? this.foto,
      idUsuario: idUsuario ?? this.idUsuario,
      tipoPaciente: tipoPaciente ?? this.tipoPaciente,
      token: token ?? this.token,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
    );
  }
}
