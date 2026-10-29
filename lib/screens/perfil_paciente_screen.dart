import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vital_bridge/services/perfiles_service.dart';
import 'package:vital_bridge/theme/app_colors.dart';

class PerfilPacienteScreen extends StatefulWidget {
  final String? idPaciente;
  final String? fotoInicial;
  final String nombreInicial;
  final String apellidosInicial;
  final String parentescoInicial;
  final String telefonoInicial;
  final String tipoPacienteInicial;
  final String tokenInicial;

  const PerfilPacienteScreen({
    super.key,
    this.idPaciente,
    this.fotoInicial,
    this.nombreInicial = '',
    this.apellidosInicial = '',
    this.parentescoInicial = 'Familiar',
    this.telefonoInicial = '',
    this.tipoPacienteInicial = 'Adulto Mayor',
    this.tokenInicial = '',
  });

  @override
  State<PerfilPacienteScreen> createState() => _PerfilPacienteScreenState();
}

class _PerfilPacienteScreenState extends State<PerfilPacienteScreen> {
  static const List<String> _opcionesParentesco = [
    'Padre / Madre',
    'Abuelo / Abuela',
    'Esposo / Esposa',
    'Tío / Tía',
    'Hijo / Hija',
    'Paciente a cargo',
    'Otro familiar',
  ];

  bool _editando = false;
  String? _fotoUrl;
  String? _savedFoto;
  XFile? _nuevaFotoArchivo;
  bool _subiendoFoto = false;

  late String _savedNombre;
  late String _savedApellidos;
  late String _savedParentesco;
  late String _savedTelefono;
  late String _tipoPaciente;
  late String _token;
  late String _parentescoSeleccionado;

  late final TextEditingController _nombreController;
  late final TextEditingController _apellidosController;
  late final TextEditingController _parentescoController;
  late final TextEditingController _telefonoController;

  List<String> get _opcionesParentescoValidas {
    final list = List<String>.from(_opcionesParentesco);
    if (!list.contains(_parentescoSeleccionado) && _parentescoSeleccionado.isNotEmpty) {
      list.insert(0, _parentescoSeleccionado);
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _fotoUrl = widget.fotoInicial;
    _savedFoto = widget.fotoInicial;
    _savedNombre = widget.nombreInicial;
    _savedApellidos = widget.apellidosInicial;
    _savedParentesco = widget.parentescoInicial.isNotEmpty ? widget.parentescoInicial : 'Padre / Madre';
    _parentescoSeleccionado = _savedParentesco;
    _savedTelefono = widget.telefonoInicial;
    _tipoPaciente = widget.tipoPacienteInicial;
    _token = widget.tokenInicial;

    _nombreController = TextEditingController(text: _savedNombre);
    _apellidosController = TextEditingController(text: _savedApellidos);
    _parentescoController = TextEditingController(text: _savedParentesco);
    _telefonoController = TextEditingController(text: _savedTelefono);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _parentescoController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  void _cancelarEdicionPaciente() {
    setState(() {
      _nombreController.text = _savedNombre;
      _apellidosController.text = _savedApellidos;
      _parentescoSeleccionado = _savedParentesco;
      _parentescoController.text = _savedParentesco;
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

  void _mostrarConfirmacionSobrescribirPaciente() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          '¿Estás seguro de que deseas sobrescribir los datos del paciente con la nueva información ingresada?',
          style: TextStyle(fontSize: 14.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C5E53),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              _savedNombre = _nombreController.text.trim();
              _savedApellidos = _apellidosController.text.trim();
              _savedParentesco = _parentescoSeleccionado.trim();
              _savedTelefono = _telefonoController.text.trim();
              _guardarCambios();
            },
            child: const Text('Sí, sobrescribir', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _cambiarFotoPaciente() async {
    if (!_editando) return;

    final archivo = await PerfilesService.seleccionarFotoDeGaleria();
    if (archivo == null) return;

    setState(() {
      _nuevaFotoArchivo = archivo;
      _fotoUrl = archivo.path; // Previsualización local inmediata
    });
  }

  Future<void> _guardarCambios() async {
    setState(() => _subiendoFoto = true);

    String? urlFinalFoto = _savedFoto;

    // 1. Si seleccionó una nueva foto, subirla a Supabase Storage y a la BD
    if (_nuevaFotoArchivo != null && widget.idPaciente != null && widget.idPaciente!.isNotEmpty) {
      final resFoto = await PerfilesService.subirFoto(
        archivo: _nuevaFotoArchivo!,
        tipo: 'paciente',
        id: widget.idPaciente!,
      );
      if (resFoto['exito'] == true && resFoto['urlFoto'] != null) {
        urlFinalFoto = resFoto['urlFoto'];
        _savedFoto = urlFinalFoto;
        _fotoUrl = urlFinalFoto;
      }
    }

    // 2. Actualizar paciente en backend
    if (widget.idPaciente != null && widget.idPaciente!.isNotEmpty) {
      final res = await PerfilesService.actualizarPaciente(
        widget.idPaciente!,
        nombre: _nombreController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        telefono: _telefonoController.text.trim(),
        parentesco: _parentescoSeleccionado.trim(),
        foto: urlFinalFoto,
      );

      if (!mounted) return;
      setState(() {
        _nuevaFotoArchivo = null;
        _subiendoFoto = false;
      });

      if (res['exito'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['mensaje'] ?? 'Error al actualizar el paciente'),
            backgroundColor: AppColors.terracota,
          ),
        );
        return;
      }
    } else {
      if (mounted) {
        setState(() {
          _nuevaFotoArchivo = null;
          _subiendoFoto = false;
        });
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Datos de ${_nombreController.text} ${_apellidosController.text} actualizados correctamente.',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2C5E53),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Navigator.pop(context, {
      'nombre': _nombreController.text.trim(),
      'apellidos': _apellidosController.text.trim(),
      'parentesco': _parentescoSeleccionado.trim(),
      'telefono': _telefonoController.text.trim(),
      'foto': _fotoUrl,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Cabecera curva en verde menta con círculos decorativos
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
                      // Barra superior con botón volver y título
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: AppColors.azulOscuro,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'PERFIL DEL PACIENTE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: AppColors.azulOscuro,
                              ),
                            ),
                          ),
                          const SizedBox(width: 42), // Balance simétrico
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Avatar del paciente con badge de cámara
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            onTap: (_editando && !_subiendoFoto) ? _cambiarFotoPaciente : null,
                            child: Container(
                              width: 96,
                              height: 96,
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
                                                child: Icon(Icons.person_rounded, size: 68, color: Color(0xFF558273)),
                                              ),
                                            )
                                          : Image.file(
                                              File(_fotoUrl!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const Center(
                                                child: Icon(Icons.person_rounded, size: 68, color: Color(0xFF558273)),
                                              ),
                                            ))
                                      : const Center(
                                          child: Icon(
                                            Icons.person_rounded,
                                            size: 68,
                                            color: Color(0xFF558273),
                                          ),
                                        ),
                            ),
                          ),
                          // Badge pequeño inferior derecho (Cámara - solo visible al editar)
                          if (_editando)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _subiendoFoto ? null : _cambiarFotoPaciente,
                              child: Container(
                                width: 30,
                                height: 30,
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
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Nombre del paciente
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

                      // Badge de rol dinámico
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCDEFE3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_tipoPaciente${_token.isNotEmpty ? " · Código: $_token" : ""}',
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

                // Círculos decorativos translúcidos
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

            // Contenedor blanco con información personal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 26.0),
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
                  const SizedBox(height: 20),

                  // Campo Nombre
                  const Text(
                    'Nombre',
                    style: TextStyle(
                      fontSize: 13.5,
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
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                      filled: true,
                      fillColor: _editando ? Colors.white : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  const SizedBox(height: 16),

                  // Campo Apellidos
                  const Text(
                    'Apellidos',
                    style: TextStyle(
                      fontSize: 13.5,
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
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                      filled: true,
                      fillColor: _editando ? Colors.white : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  const SizedBox(height: 16),

                  // Campo Parentesco / Relación con el Cuidador (Requerimiento solicitado)
                  const Text(
                    'Parentesco / Relación con el cuidador',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!_editando)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.family_restroom_rounded, color: AppColors.moradoOscuro, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _parentescoSeleccionado,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _opcionesParentescoValidas.contains(_parentescoSeleccionado)
                              ? _parentescoSeleccionado
                              : _opcionesParentescoValidas.first,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.moradoOscuro),
                          items: _opcionesParentescoValidas.map((opc) {
                            return DropdownMenuItem<String>(
                              value: opc,
                              child: Row(
                                children: [
                                  const Icon(Icons.family_restroom_rounded, color: AppColors.moradoOscuro, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    opc,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.azulOscuro,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _parentescoSeleccionado = val;
                                _parentescoController.text = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Campo Teléfono
                  const Text(
                    'Teléfono',
                    style: TextStyle(
                      fontSize: 13.5,
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
                      prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF94A3B8), size: 20),
                      filled: true,
                      fillColor: _editando ? Colors.white : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  const SizedBox(height: 32),

                  // Botón grande de edición que se divide en Cancelar y Guardar
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
                        'Editar Información del Paciente',
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
                            onPressed: _cancelarEdicionPaciente,
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
                            onPressed: _mostrarConfirmacionSobrescribirPaciente,
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
