import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_bridge/models/paciente_model.dart';
import 'package:vital_bridge/screens/login_screen.dart';
import 'package:vital_bridge/screens/perfil_paciente_screen.dart';
import 'package:vital_bridge/screens/registro_paciente_screen.dart';
import 'package:vital_bridge/services/auth_service.dart';
import 'package:vital_bridge/services/pacientes_service.dart';
import 'package:vital_bridge/services/perfiles_service.dart';
import 'package:vital_bridge/theme/app_colors.dart';

class PerfilCuidadorScreen extends StatefulWidget {
  final VoidCallback? onVolverAMonitoreo;

  const PerfilCuidadorScreen({
    super.key,
    this.onVolverAMonitoreo,
  });

  @override
  State<PerfilCuidadorScreen> createState() => _PerfilCuidadorScreenState();
}

class _PerfilCuidadorScreenState extends State<PerfilCuidadorScreen> {
  bool _editando = false;
  bool _cargando = true;
  bool _subiendoFoto = false;

  String? _usuarioId;
  String? _fotoUrl;
  String? _savedFoto;
  XFile? _nuevaFotoArchivo;

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidosController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();

  // Valores guardados del cuidador para revertir en caso de cancelar
  String _savedNombre = 'María';
  String _savedApellidos = 'García';
  String _savedEmail = 'maria@vitalbridge.es';
  String _savedTelefono = '+34 601 234 567';

  // Lista de pacientes asignados al cuidador
  List<PacienteModel> _pacientes = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosPerfil() async {
    setState(() => _cargando = true);
    final prefs = await SharedPreferences.getInstance();
    final usuarioId = prefs.getString('auth_user_id') ?? '';
    _usuarioId = usuarioId;

    // Cargar pacientes reales asignados al cuidador
    final listaPacientes = await PacientesService.obtenerPacientes();

    // Obtener datos del perfil desde backend o caché
    if (usuarioId.isNotEmpty) {
      final res = await PerfilesService.obtenerPerfilUsuario(usuarioId);
      if (res['exito'] == true && res['data'] != null) {
        final d = res['data'];
        _savedNombre = d['nombre'] ?? prefs.getString('usuario_nombre') ?? 'María';
        _savedApellidos = d['apellidos'] ?? prefs.getString('usuario_apellidos') ?? 'García';
        _savedEmail = d['correo'] ?? prefs.getString('usuario_correo') ?? 'maria@vitalbridge.es';
        _savedTelefono = d['telefono'] ?? prefs.getString('usuario_telefono') ?? '+34 601 234 567';
        _fotoUrl = d['foto'] ?? prefs.getString('usuario_foto');
      }
    } else {
      _savedNombre = prefs.getString('usuario_nombre') ?? 'María';
      _savedApellidos = prefs.getString('usuario_apellidos') ?? 'García';
      _savedEmail = prefs.getString('usuario_correo') ?? 'maria@vitalbridge.es';
      _savedTelefono = prefs.getString('usuario_telefono') ?? '+34 601 234 567';
      _fotoUrl = prefs.getString('usuario_foto');
    }

    _savedFoto = _fotoUrl;

    if (!mounted) return;
    setState(() {
      _nombreController.text = _savedNombre;
      _apellidosController.text = _savedApellidos;
      _emailController.text = _savedEmail;
      _telefonoController.text = _savedTelefono;
      _pacientes = listaPacientes;
      _cargando = false;
    });
  }

  Future<void> _cambiarFotoPerfil() async {
    if (!_editando) return;

    final archivo = await PerfilesService.seleccionarFotoDeGaleria();
    if (archivo == null) return;

    setState(() {
      _nuevaFotoArchivo = archivo;
      _fotoUrl = archivo.path; // Previsualización local inmediata
    });
  }

  void _cancelarEdicionCuidador() {
    setState(() {
      _nombreController.text = _savedNombre;
      _apellidosController.text = _savedApellidos;
      _emailController.text = _savedEmail;
      _telefonoController.text = _savedTelefono;
      _nuevaFotoArchivo = null;
      _fotoUrl = _savedFoto;
      _editando = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edición cancelada. Los cambios fueron descartados.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _mostrarConfirmacionSobrescribirCuidador() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.turquesa, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Confirmar sobreescritura',
                style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.bold, color: AppColors.azulOscuro),
              ),
            ),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas sobrescribir tus datos personales con la nueva información?',
          style: TextStyle(fontSize: 14.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C5E53),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final nuevoNombre = _nombreController.text.trim();
              final nuevosApellidos = _apellidosController.text.trim();
              final nuevoTelefono = _telefonoController.text.trim();

              setState(() {
                _cargando = true;
                _subiendoFoto = true;
              });

              // 1. Si seleccionó una nueva foto, subirla a Supabase Storage y guardar en BD
              if (_nuevaFotoArchivo != null && _usuarioId != null && _usuarioId!.isNotEmpty) {
                final resFoto = await PerfilesService.subirFoto(
                  archivo: _nuevaFotoArchivo!,
                  tipo: 'usuario',
                  id: _usuarioId!,
                );
                if (resFoto['exito'] == true && resFoto['urlFoto'] != null) {
                  _savedFoto = resFoto['urlFoto'];
                  _fotoUrl = _savedFoto;
                }
              }

              // 2. Guardar datos de texto en el backend
              if (_usuarioId != null && _usuarioId!.isNotEmpty) {
                await PerfilesService.actualizarPerfilUsuario(
                  _usuarioId!,
                  nombre: nuevoNombre,
                  apellidos: nuevosApellidos,
                  telefono: nuevoTelefono,
                );
              }

              if (!mounted) return;
              setState(() {
                _savedNombre = nuevoNombre;
                _savedApellidos = nuevosApellidos;
                _savedEmail = _emailController.text.trim();
                _savedTelefono = nuevoTelefono;
                _nuevaFotoArchivo = null;
                _cargando = false;
                _subiendoFoto = false;
                _editando = false;
              });

              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white),
                      SizedBox(width: 10),
                      Text('✅ Datos guardados y sincronizados con éxito.'),
                    ],
                  ),
                  backgroundColor: Color(0xFF2C5E53),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Sí, sobrescribir', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  void _abrirPerfilPaciente(PacienteModel paciente) async {
    final resultado = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => PerfilPacienteScreen(
          idPaciente: paciente.id,
          fotoInicial: paciente.foto,
          nombreInicial: paciente.nombre,
          apellidosInicial: paciente.apellidos,
          parentescoInicial: paciente.parentesco,
          telefonoInicial: paciente.telefono,
          tipoPacienteInicial: paciente.tipoPaciente,
          tokenInicial: paciente.token ?? '',
        ),
      ),
    );

    if (resultado != null && mounted) {
      await _cargarDatosPerfil();
    }
  }

  void _confirmarCerrarSesion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.terracota),
            SizedBox(width: 10),
            Text(
              'Cerrar Sesión',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.azulOscuro),
            ),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas salir del panel de cuidador? Regresarás a la pantalla de inicio de sesión.',
          style: TextStyle(fontSize: 14.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracota,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.pop(context);
              await AuthService.cerrarSesion();
              if (!mounted) return;
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Sí, salir', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.moradoOscuro),
              SizedBox(height: 16),
              Text(
                'Cargando perfil...',
                style: TextStyle(color: AppColors.azulOscuro, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Cabecera curva en gradiente menta suave
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 48, bottom: 44, left: 20, right: 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFD6F2E8),
                        Color(0xFFEAF8F3),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(36),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Barra superior: Título centrado
                      const Center(
                        child: Text(
                          'PERFIL DEL CUIDADOR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppColors.azulOscuro,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Avatar del cuidador con foto dinámica y botón de cámara
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            onTap: (_editando && !_subiendoFoto) ? _cambiarFotoPerfil : null,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3.5),
                                color: const Color(0xFFC7EADB),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _subiendoFoto
                                  ? const Center(
                                      child: CircularProgressIndicator(color: AppColors.turquesa),
                                    )
                                  : (_fotoUrl != null && _fotoUrl!.isNotEmpty)
                                      ? (_fotoUrl!.startsWith('http')
                                          ? Image.network(
                                              _fotoUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const Center(
                                                child: Icon(Icons.face_3_rounded, size: 68, color: Color(0xFF558273)),
                                              ),
                                            )
                                          : Image.file(
                                              File(_fotoUrl!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const Center(
                                                child: Icon(Icons.face_3_rounded, size: 68, color: Color(0xFF558273)),
                                              ),
                                            ))
                                      : const Center(
                                          child: Icon(
                                            Icons.face_3_rounded,
                                            size: 68,
                                            color: Color(0xFF558273),
                                          ),
                                        ),
                            ),
                          ),
                          // Badge inferior derecho para editar foto (solo visible al editar)
                          if (_editando)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _subiendoFoto ? null : _cambiarFotoPerfil,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.moradoOscuro,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Nombre del cuidador
                      Text(
                        '${_nombreController.text} ${_apellidosController.text}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.azulOscuro,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Badge de rol: Cuidador
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCDEFE3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _usuarioId != null && _usuarioId!.length >= 4
                              ? 'Cuidador · ID: ${_usuarioId!.substring(0, 4).toUpperCase()}'
                              : 'Cuidador · Registrado',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E5246),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Círculo decorativo
                Positioned(
                  top: 20,
                  right: -25,
                  child: IgnorePointer(
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Contenedor blanco con información personal y pacientes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Título Sección: Información Personal
                  const Text(
                    'INFORMACIÓN PERSONAL',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.azulOscuro,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Fila con Nombre y Apellidos en dos columnas
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nombre',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _nombreController,
                              readOnly: !_editando,
                              onChanged: (val) => setState(() {}),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8), size: 19),
                                filled: true,
                                fillColor: _editando ? Colors.white : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: _editando ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                                    width: 1.4,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.turquesa, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Apellidos',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _apellidosController,
                              readOnly: !_editando,
                              onChanged: (val) => setState(() {}),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8), size: 19),
                                filled: true,
                                fillColor: _editando ? Colors.white : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: _editando ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                                    width: 1.4,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.turquesa, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Correo electrónico
                  const Text(
                    'Correo electrónico',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    readOnly: true, // Correo protegido de Auth
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF94A3B8), size: 19),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1.4,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.turquesa, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Teléfono
                  const Text(
                    'Teléfono',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _telefonoController,
                    readOnly: !_editando,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF94A3B8), size: 19),
                      filled: true,
                      fillColor: _editando ? Colors.white : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: _editando ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                          width: 1.4,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.turquesa, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botón de edición que se divide en Cancelar y Guardar
                  if (!_editando)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.moradoOscuro,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _editando = true;
                        });
                      },
                      icon: const Icon(Icons.edit_note_rounded, size: 22),
                      label: const Text(
                        'Editar Información Personal',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: const Color(0xFFF1F5F9),
                            ),
                            onPressed: _cancelarEdicionCuidador,
                            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                            label: const Text(
                              'Cancelar',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2C5E53),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _mostrarConfirmacionSobrescribirCuidador,
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: const Text(
                              'Guardar',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 28),

                  // Sección: MIS PACIENTES ASIGNADOS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'MIS PACIENTES ASIGNADOS',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.azulOscuro,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final nuevo = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegistroPacienteScreen(),
                            ),
                          );
                          if (nuevo != null) {
                            _cargarDatosPerfil();
                          }
                        },
                        icon: const Icon(Icons.add, size: 16, color: AppColors.moradoOscuro),
                        label: const Text(
                          'Agregar',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.moradoOscuro),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Lista dinámica de Pacientes
                  if (_pacientes.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.people_outline_rounded, size: 40, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 8),
                          const Text(
                            'Aún no tienes pacientes asignados',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.azulOscuro,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Registra a un adulto mayor para comenzar a monitorear su medicación.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.moradoOscuro,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final nuevo = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegistroPacienteScreen(),
                                ),
                              );
                              if (nuevo != null) {
                                _cargarDatosPerfil();
                              }
                            },
                            icon: const Icon(Icons.person_add_rounded, size: 18),
                            label: const Text('Registrar Paciente', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._pacientes.map((paciente) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.azulOscuro.withValues(alpha: 0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Cabecera paciente: Foto, Nombre, Parentesco y Badge
                              Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFD6F2E8),
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: (paciente.foto != null && paciente.foto!.isNotEmpty)
                                        ? (paciente.foto!.startsWith('http')
                                            ? Image.network(
                                                paciente.foto!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => const Icon(
                                                  Icons.person_rounded,
                                                  size: 34,
                                                  color: Color(0xFF558273),
                                                ),
                                              )
                                            : Image.file(
                                                File(paciente.foto!),
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => const Icon(
                                                  Icons.person_rounded,
                                                  size: 34,
                                                  color: Color(0xFF558273),
                                                ),
                                              ))
                                        : const Icon(
                                            Icons.person_rounded,
                                            size: 34,
                                            color: Color(0xFF558273),
                                          ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          paciente.nombreCompleto,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.azulOscuro,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${paciente.parentesco} • ${paciente.tipoPaciente}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Badge Activo
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2F7F0),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.circle, size: 7, color: Color(0xFF339F80)),
                                        SizedBox(width: 5),
                                        Text(
                                          'Activo',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF287D65),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Botón Ver detalles del paciente
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.moradoOscuro,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => _abrirPerfilPaciente(paciente),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Ver detalles y editar perfil',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 20),

                  // Tarjeta para cerrar sesión
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.terracota.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.logout_rounded, color: AppColors.terracota, size: 20),
                      ),
                      title: const Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: AppColors.terracota,
                        ),
                      ),
                      subtitle: const Text(
                        'Salir de la cuenta de cuidador',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                      onTap: _confirmarCerrarSesion,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
