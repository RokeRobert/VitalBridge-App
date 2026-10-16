import 'package:flutter/material.dart';
import 'package:vital_bridge/theme/app_colors.dart';

class PerfilPacienteScreen extends StatefulWidget {
  final String nombreInicial;
  final String apellidosInicial;
  final String parentescoInicial;
  final String telefonoInicial;

  const PerfilPacienteScreen({
    super.key,
    this.nombreInicial = 'Roberto',
    this.apellidosInicial = 'Gómez',
    this.parentescoInicial = 'Padre',
    this.telefonoInicial = '+34 610 345 872',
  });

  @override
  State<PerfilPacienteScreen> createState() => _PerfilPacienteScreenState();
}

class _PerfilPacienteScreenState extends State<PerfilPacienteScreen> {
  bool _editando = false;

  late String _savedNombre;
  late String _savedApellidos;
  late String _savedParentesco;
  late String _savedTelefono;

  late final TextEditingController _nombreController;
  late final TextEditingController _apellidosController;
  late final TextEditingController _parentescoController;
  late final TextEditingController _telefonoController;

  @override
  void initState() {
    super.initState();
    _savedNombre = widget.nombreInicial;
    _savedApellidos = widget.apellidosInicial;
    _savedParentesco = widget.parentescoInicial;
    _savedTelefono = widget.telefonoInicial;

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
      _parentescoController.text = _savedParentesco;
      _telefonoController.text = _savedTelefono;
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
              _savedParentesco = _parentescoController.text.trim();
              _savedTelefono = _telefonoController.text.trim();
              _guardarCambios();
            },
            child: const Text('Sí, sobrescribir', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _guardarCambios() {
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
      'parentesco': _parentescoController.text.trim(),
      'telefono': _telefonoController.text.trim(),
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

                      // Avatar del paciente con badge de destello / estrella
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
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
                            child: const ClipOval(
                              child: Icon(
                                Icons.person_rounded,
                                size: 68,
                                color: Color(0xFF558273),
                              ),
                            ),
                          ),
                          // Badge pequeño inferior derecho
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: AppColors.moradoOscuro,
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

                      // Badge de rol: Adulto Mayor · ID: 0045
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCDEFE3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Adulto Mayor · ID: 0045',
                          style: TextStyle(
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
                  TextField(
                    controller: _parentescoController,
                    readOnly: !_editando,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.family_restroom_rounded, color: AppColors.moradoOscuro, size: 20),
                      hintText: 'Ej. Padre, Madre, Abuelo, Tío...',
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
