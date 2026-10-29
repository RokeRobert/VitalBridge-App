/// Modelo que representa al Usuario Cuidador en Flutter.
/// Se mapea con la entidad 'Usuario' de C# (tabla 'usuario' en Supabase).
class UsuarioModel {
  final String id;
  final String nombre;
  final String apellidos;
  final String correo;
  final String telefono;
  final String? foto;
  final String? token; // Token de autenticación JWT
  final DateTime? fechaRegistro;

  UsuarioModel({
    required this.id,
    required this.nombre,
    required this.apellidos,
    required this.correo,
    required this.telefono,
    this.foto,
    this.token,
    this.fechaRegistro,
  });

  /// Nombre completo formateado
  String get nombreCompleto => '$nombre $apellidos'.trim();

  /// Crea una instancia desde la respuesta JSON que entrega la API de C#
  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id: (json['idUsuario'] ?? json['id_usuario'] ?? json['id'] ?? '').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      apellidos: (json['apellidos'] ?? '').toString(),
      correo: (json['correo'] ?? json['email'] ?? '').toString(),
      telefono: (json['telefono'] ?? '').toString(),
      foto: json['foto']?.toString(),
      token: (json['token'] ?? json['tokenUsuario'] ?? json['accessToken'])?.toString(),
      fechaRegistro: json['fechaRegistro'] != null
          ? DateTime.tryParse(json['fechaRegistro'].toString())
          : (json['fecha_registro'] != null
              ? DateTime.tryParse(json['fecha_registro'].toString())
              : null),
    );
  }

  /// Convierte la clase a JSON para enviarla al backend de C# (ej: en registro o actualización)
  Map<String, dynamic> toJson() {
    return {
      'idUsuario': id,
      'nombre': nombre,
      'apellidos': apellidos,
      'correo': correo,
      'telefono': telefono,
      if (foto != null) 'foto': foto,
      if (token != null) 'token': token,
    };
  }

  /// Permite crear una copia modificando solo ciertos campos
  UsuarioModel copyWith({
    String? id,
    String? nombre,
    String? apellidos,
    String? correo,
    String? telefono,
    String? foto,
    String? token,
    DateTime? fechaRegistro,
  }) {
    return UsuarioModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellidos: apellidos ?? this.apellidos,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      foto: foto ?? this.foto,
      token: token ?? this.token,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
    );
  }
}

