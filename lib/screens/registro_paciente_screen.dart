import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vital_bridge/models/paciente_model.dart';
import 'package:vital_bridge/services/pacientes_service.dart';
import 'package:vital_bridge/services/perfiles_service.dart';
import 'package:vital_bridge/theme/app_colors.dart';

class RegistroPacienteScreen extends StatefulWidget {
  const RegistroPacienteScreen({super.key});

  @override
  State<RegistroPacienteScreen> createState() => _RegistroPacienteScreenState();
}

class _RegistroPacienteScreenState extends State<RegistroPacienteScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  String _parentescoSeleccionado = 'Padre / Madre';
  int _tipoPacienteSeleccionado = 1; // 1: Adulto Mayor, 2: Crónico, 3: General
  bool _guardando = false;
  XFile? _fotoArchivo;

  Future<void> _seleccionarFoto() async {
    final foto = await PerfilesService.seleccionarFotoDeGaleria();
    if (foto != null) {
      setState(() => _fotoArchivo = foto);
    }
  }

  final List<String> _opcionesParentesco = [
    'Padre / Madre',
    'Abuelo / Abuela',
    'Esposo / Esposa',
    'Tío / Tía',
    'Hijo / Hija',
    'Paciente a cargo',
    'Otro familiar',
  ];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidosCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarPaciente() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final resultado = await PacientesService.registrarPaciente(
        nombre: _nombreCtrl.text,
        apellidos: _apellidosCtrl.text,
        telefono: _telefonoCtrl.text,
        parentesco: _parentescoSeleccionado,
        idTipoPaciente: _tipoPacienteSeleccionado,
      );

      if (!mounted) return;

      setState(() => _guardando = false);

      if (resultado['exito'] == true) {
        PacienteModel paciente = resultado['paciente'];
        final String token = resultado['token'] ?? paciente.token ?? 'VB-1000';

        // Si se seleccionó una foto, subirla a Supabase Storage
        if (_fotoArchivo != null) {
          final resFoto = await PerfilesService.subirFoto(
            archivo: _fotoArchivo!,
            tipo: 'paciente',
            id: paciente.id,
          );
          if (resFoto['exito'] == true && resFoto['urlFoto'] != null) {
            paciente = paciente.copyWith(foto: resFoto['urlFoto']);
          }
        }

        // Mostrar el modal con el Código QR y Token de vinculación generado
        _mostrarModalExitoConQR(paciente, token);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.terracota,
            content: Text(resultado['mensaje'] ?? 'No se pudo registrar el paciente.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.terracota,
          content: Text('Error de conexión: $e'),
        ),
      );
    }
  }

  void _mostrarModalExitoConQR(PacienteModel paciente, String token) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),

              // Icono de éxito
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.turquesa.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.turquesa,
                  size: 38,
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                '¡Paciente Registrado!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.azulOscuro,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Escanea este código QR en el dispositivo de ${paciente.nombre} para vincularlo al instante.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),

              // Contenedor del Código QR generado
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.lilaSuave.withValues(alpha: 0.6), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.azulOscuro.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: token,
                  version: QrVersions.auto,
                  size: 190.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.moradoOscuro,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.azulOscuro,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Tarjeta del Token Alfanumérico
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.fondo,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.vpn_key_rounded, size: 18, color: AppColors.moradoOscuro),
                    const SizedBox(width: 8),
                    Text(
                      'Código: $token',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: AppColors.azulOscuro,
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: token));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            duration: Duration(seconds: 2),
                            content: Text('Código copiado al portapapeles.'),
                          ),
                        );
                      },
                      child: const Tooltip(
                        message: 'Copiar código',
                        child: Icon(Icons.copy_rounded, size: 18, color: AppColors.moradoOscuro),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botón para continuar al Dashboard
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.moradoOscuro,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Cierra bottom sheet
                    Navigator.pop(context, paciente); // Regresa al Dashboard con el nuevo paciente
                  },
                  icon: const Icon(Icons.dashboard_rounded, size: 20),
                  label: const Text(
                    'Ir al Panel de Monitoreo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text(
          'Registrar Paciente',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.azulOscuro,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.azulOscuro, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado descriptivo
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.moradoOscuro.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        color: AppColors.moradoOscuro,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Datos del Familiar o Paciente',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.azulOscuro,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Al guardar se generará un código QR único para que el paciente entre sin contraseñas.',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Selector de Foto de Perfil del Paciente (Opcional)
              Center(
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: _seleccionarFoto,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: AppColors.lilaSuave.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.lilaSuave, width: 2.5),
                            ),
                            child: _fotoArchivo != null
                                ? ClipOval(
                                    child: Image.file(
                                      File(_fotoArchivo!.path),
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person_rounded,
                                    size: 52,
                                    color: AppColors.moradoOscuro,
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _seleccionarFoto,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: AppColors.moradoOscuro,
                                shape: BoxShape.circle,
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
                    const SizedBox(height: 8),
                    Text(
                      _fotoArchivo != null ? 'Foto lista para guardar' : 'Agregar foto de perfil (Opcional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _fotoArchivo != null ? FontWeight.bold : FontWeight.normal,
                        color: _fotoArchivo != null ? AppColors.moradoOscuro : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Campo: Nombre
              const Text('Nombre(s)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.azulOscuro)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Ej. Roberto',
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.moradoOscuro),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresa el nombre del paciente' : null,
              ),
              const SizedBox(height: 16),

              // Campo: Apellidos
              const Text('Apellidos', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.azulOscuro)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _apellidosCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Ej. Gómez Morales',
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.moradoOscuro),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresa los apellidos' : null,
              ),
              const SizedBox(height: 16),

              // Campo: Parentesco / Relación
              const Text('Parentesco o Relación', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.azulOscuro)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _parentescoSeleccionado,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.moradoOscuro),
                    items: _opcionesParentesco.map((opc) {
                      return DropdownMenuItem(value: opc, child: Text(opc));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _parentescoSeleccionado = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Campo: Tipo de Paciente
              const Text('Condición del Paciente', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.azulOscuro)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _tipoPacienteSeleccionado,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.moradoOscuro),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Adulto Mayor')),
                      DropdownMenuItem(value: 2, child: Text('Paciente Crónico')),
                      DropdownMenuItem(value: 3, child: Text('General')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _tipoPacienteSeleccionado = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Campo: Teléfono del Paciente
              const Text('Teléfono de Contacto (Para emergencias)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.azulOscuro)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Ej. +34 610 345 872',
                  prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.moradoOscuro),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresa el teléfono' : null,
              ),
              const SizedBox(height: 32),

              // Botón de Envío
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.moradoOscuro,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _guardando ? null : _guardarPaciente,
                  icon: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_2_rounded, size: 22),
                  label: Text(
                    _guardando ? 'Guardando...' : 'Guardar y Generar Código QR',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

