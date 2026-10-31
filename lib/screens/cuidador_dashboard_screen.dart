import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vital_bridge/models/paciente_model.dart';
import 'package:vital_bridge/models/toma_model.dart';
import 'package:vital_bridge/screens/agregar_medicamento_screen.dart';
import 'package:vital_bridge/screens/alerta_sos_cuidador_screen.dart';
import 'package:vital_bridge/screens/login_screen.dart';
import 'package:vital_bridge/screens/perfil_cuidador_screen.dart';
import 'package:vital_bridge/screens/perfil_paciente_screen.dart';
import 'package:vital_bridge/screens/registro_paciente_screen.dart';
import 'package:vital_bridge/screens/tratamientos_screen.dart';
import 'package:vital_bridge/services/pacientes_service.dart';
import 'package:vital_bridge/services/tratamientos_service.dart';
import 'package:vital_bridge/theme/app_colors.dart';

class CuidadorDashboardScreen extends StatefulWidget {
  const CuidadorDashboardScreen({super.key});

  @override
  State<CuidadorDashboardScreen> createState() => _CuidadorDashboardScreenState();
}

class _CuidadorDashboardScreenState extends State<CuidadorDashboardScreen> {
  int _tabSeleccionado = 0;

  // Estado dinámico de Pacientes
  bool _cargando = true;
  List<PacienteModel> _pacientes = [];
  PacienteModel? _pacienteSeleccionado;

  // Lista dinámica de tomas del día para el paciente supervisado
  List<TomaModel> _tomasHoy = [];
  bool _cargandoTomas = false;

  @override
  void initState() {
    super.initState();
    _cargarPacientes();
  }

  Future<void> _cargarPacientes() async {
    setState(() => _cargando = true);
    final lista = await PacientesService.obtenerPacientes();

    if (!mounted) return;

    setState(() {
      _pacientes = lista;
      if (_pacientes.isNotEmpty) {
        _pacienteSeleccionado = _pacientes.first;
      } else {
        _pacienteSeleccionado = null;
      }
      _cargando = false;
    });

    if (_pacienteSeleccionado != null) {
      _cargarTomasHoy();
    }
  }

  Future<void> _cargarTomasHoy() async {
    if (_pacienteSeleccionado == null) {
      if (mounted) setState(() => _tomasHoy = []);
      return;
    }
    setState(() => _cargandoTomas = true);
    final tomas = await TratamientosService.obtenerTomasHoy(pacienteId: _pacienteSeleccionado!.id);
    if (!mounted) return;
    setState(() {
      _tomasHoy = tomas;
      _cargandoTomas = false;
    });
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
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Sí, salir', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Despliega el modal interactivo con el Código QR y Token de vinculación de un paciente
  void _mostrarModalQR(PacienteModel paciente) {
    final token = paciente.token ?? 'VB-1000';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              const SizedBox(height: 18),
              Text(
                'Código QR de ${paciente.nombre}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.azulOscuro,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Escanea este código con la cámara de la app en el dispositivo de ${paciente.nombre} para vincularlo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),

              // Contenedor visual del QR
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.lilaSuave.withValues(alpha: 0.6), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.azulOscuro.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: token,
                  version: QrVersions.auto,
                  size: 180.0,
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
              const SizedBox(height: 16),

              // Chip con el Token manual
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.fondo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.vpn_key_rounded, size: 16, color: AppColors.moradoOscuro),
                    const SizedBox(width: 8),
                    Text(
                      'Token: $token',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: AppColors.azulOscuro,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: token));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            duration: Duration(seconds: 2),
                            content: Text('Token copiado al portapapeles.'),
                          ),
                        );
                      },
                      child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.moradoOscuro),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.moradoOscuro,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido / Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Construye el encabezado superior con el modo, estado y botón de salida
  Widget _construirEncabezado() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.lilaSuave.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'MODO CUIDADOR',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.moradoOscuro,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Panel de Monitoreo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.azulOscuro,
              ),
            ),
          ],
        ),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, size: 15, color: AppColors.turquesa),
                  SizedBox(width: 5),
                  Text(
                    'Activo',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.azulOscuro,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _confirmarCerrarSesion,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Tooltip(
                    message: 'Cerrar Sesión',
                    child: Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: AppColors.terracota,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// EMPTY STATE: Vista cuando el cuidador recién ingresa y NO tiene pacientes registrados
  Widget _construirVistaEmptyState() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _construirEncabezado(),
            const SizedBox(height: 24),

            // Tarjeta Heroica de Bienvenida y Estado Vacío
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.azulOscuro.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  // Icono ilustrativo grande
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.lilaSuave.withValues(alpha: 0.35),
                          AppColors.turquesa.withValues(alpha: 0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 44,
                        color: AppColors.moradoOscuro,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    '¡Bienvenido a VitalBridge!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.azulOscuro,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aún no tienes ningún paciente asignado a tu supervisión. Registra a tu primer familiar para programar sus tratamientos, generar su código QR de vinculación y recibir alertas de emergencia.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Botón Principal de Acción
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.moradoOscuro,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        final resultado = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegistroPacienteScreen(),
                          ),
                        );
                        if (resultado != null) {
                          _cargarPacientes();
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 22),
                      label: const Text(
                        'Registrar a mi primer paciente',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tarjeta de Guía Rápida de Inicio
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: AppColors.turquesa, size: 22),
                      SizedBox(width: 8),
                      Text(
                        '¿Cómo funciona el sistema?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.azulOscuro,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _construirPasoGuia(
                    numero: '1',
                    titulo: 'Registras al paciente',
                    descripcion: 'Ingresas sus datos básicos como nombre, teléfono y parentesco.',
                  ),
                  const SizedBox(height: 12),
                  _construirPasoGuia(
                    numero: '2',
                    titulo: 'Generas su código QR',
                    descripcion: 'El sistema genera una credencial segura para que el adulto mayor ingrese sin escribir contraseñas.',
                  ),
                  const SizedBox(height: 12),
                  _construirPasoGuia(
                    numero: '3',
                    titulo: 'Monitoreas sus dosis y alertas',
                    descripcion: 'Supervisas cada medicamento tomado y recibes avisos inmediatos en caso de emergencia SOS.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _construirPasoGuia({
    required String numero,
    required String titulo,
    required String descripcion,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.moradoOscuro.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              numero,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: AppColors.moradoOscuro,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.azulOscuro,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                descripcion,
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600], height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// VISTA ACTIVA: Cuando el cuidador ya tiene 1 o más pacientes registrados
  Widget _construirVistaMonitoreoActivo() {
    final paciente = _pacienteSeleccionado!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _construirEncabezado(),
            const SizedBox(height: 16),

            // Selector de Paciente (si tiene más de 1 paciente)
            if (_pacientes.length > 1) ...[
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pacientes.length + 1,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == _pacientes.length) {
                      return OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.moradoOscuro,
                          side: const BorderSide(color: AppColors.lilaSuave),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () async {
                          final nuevo = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegistroPacienteScreen(),
                            ),
                          );
                          if (nuevo != null) _cargarPacientes();
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Nuevo', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      );
                    }

                    final p = _pacientes[index];
                    final esActivo = p.id == paciente.id;

                    return FilterChip(
                      selected: esActivo,
                      showCheckmark: false,
                      avatar: (p.foto != null && p.foto!.isNotEmpty)
                          ? CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.transparent,
                              backgroundImage: p.foto!.startsWith('http')
                                  ? NetworkImage(p.foto!)
                                  : FileImage(File(p.foto!)) as ImageProvider,
                            )
                          : null,
                      label: Text(p.nombre),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: esActivo ? Colors.white : AppColors.azulOscuro,
                      ),
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.moradoOscuro,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: esActivo ? AppColors.moradoOscuro : const Color(0xFFE2E8F0),
                        ),
                      ),
                      onSelected: (_) {
                        setState(() => _pacienteSeleccionado = p);
                        _cargarTomasHoy();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Banner Provisional de Alerta SOS Entrante
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AlertaSosCuidadorScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE25C54), Color(0xFFC7433B)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE25C54).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🚨', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Alerta SOS del Paciente',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '• EN VIVO',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFFD4D1),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Toca para ver pantalla de emergencia (Provisional)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFEE2E8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tarjeta del Paciente Supervisado
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.azulOscuro.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.moradoOscuro.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (paciente.foto != null && paciente.foto!.isNotEmpty)
                            ? (paciente.foto!.startsWith('http')
                                ? Image.network(
                                    paciente.foto!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Center(
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 32,
                                        color: AppColors.moradoOscuro,
                                      ),
                                    ),
                                  )
                                : Image.file(
                                    File(paciente.foto!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Center(
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 32,
                                        color: AppColors.moradoOscuro,
                                      ),
                                    ),
                                  ))
                            : const Center(
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 32,
                                  color: AppColors.moradoOscuro,
                                ),
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
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.azulOscuro,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${paciente.parentesco} • ${paciente.tipoPaciente}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Botón de acceso directo al Perfil
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final modificado = await Navigator.of(context).push<Map<String, dynamic>>(
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
                          if (modificado != null) {
                            await _cargarPacientes();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.lilaSuave.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.lilaSuave.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.badge_outlined, size: 15, color: AppColors.moradoOscuro),
                              SizedBox(width: 4),
                              Text(
                                'Perfil',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.moradoOscuro,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),

                  // Barra de acción rápida: Ver QR y Conexión
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.wifi_rounded, size: 17, color: AppColors.turquesa),
                          const SizedBox(width: 6),
                          Text(
                            'Activo',
                            style: const TextStyle(fontSize: 13, color: AppColors.azulOscuro),
                          ),
                        ],
                      ),

                      // Botón para desplegar el QR en cualquier momento
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _mostrarModalQR(paciente),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 18, color: AppColors.moradoOscuro),
                        label: const Text(
                          'Ver Código QR',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.moradoOscuro,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Card Resumen del Día: Barra de Progreso Dinámica
            Builder(
              builder: (context) {
                final int totalTomas = _tomasHoy.length;
                final int tomasTomadas = _tomasHoy.where((t) => t.esTomada).length;
                final double porcentaje = totalTomas == 0 ? 0.0 : (tomasTomadas / totalTomas);
                final String porcentajeTexto = totalTomas == 0 ? '0%' : '${(porcentaje * 100).toInt()}%';

                String subtituloProgreso;
                if (totalTomas == 0) {
                  subtituloProgreso = 'No hay medicamentos programados para hoy';
                } else if (tomasTomadas == totalTomas) {
                  subtituloProgreso = '¡Todas las dosis de hoy fueron completadas!';
                } else {
                  final proxima = _tomasHoy.firstWhere((t) => !t.esTomada, orElse: () => _tomasHoy.first);
                  subtituloProgreso = 'Próxima dosis programada para las ${proxima.horaProgramada}';
                }

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.azulOscuro,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.azulOscuro.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Progreso del Día',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              totalTomas == 0 ? 'Sin dosis hoy' : '$tomasTomadas de $totalTomas dosis',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        porcentajeTexto,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: porcentaje,
                          minHeight: 8,
                          backgroundColor: const Color(0xFF453E60),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.turquesa),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subtituloProgreso,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFFD6D0EA)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Sección: Seguimiento de Medicamentos de Hoy
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tratamiento de Hoy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.azulOscuro,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final agregado = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AgregarMedicamentoScreen(
                          idPaciente: paciente.id,
                          nombrePaciente: paciente.nombre,
                        ),
                      ),
                    );
                    if (agregado == true) {
                      _cargarTomasHoy();
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.moradoOscuro),
                  label: const Text(
                    'Agregar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.moradoOscuro,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Lista de tomas de hoy o Empty State de Medicamentos
            if (_cargandoTomas) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: CircularProgressIndicator(color: AppColors.moradoOscuro),
                ),
              ),
            ] else if (_tomasHoy.isEmpty) ...[
              // EMPTY STATE DE MEDICAMENTOS PARA EL PACIENTE
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.lilaSuave.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medication_outlined,
                        size: 34,
                        color: AppColors.moradoOscuro,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sin medicamentos programados para hoy',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.azulOscuro,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${paciente.nombre} aún no tiene dosis registradas para hoy. Pulsa en el botón para programar su primer tratamiento.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.35),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.moradoOscuro,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      onPressed: () async {
                        final agregado = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AgregarMedicamentoScreen(
                              idPaciente: paciente.id,
                              nombrePaciente: paciente.nombre,
                            ),
                          ),
                        );
                        if (agregado == true) {
                          _cargarTomasHoy();
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Programar Tratamiento',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tomasHoy.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _tomasHoy[index];
                  final bool tomada = item.esTomada;

                  Color colorBadge;
                  Color colorTextoBadge;
                  String textoBadge;
                  IconData iconoEstado;

                  if (tomada) {
                    colorBadge = AppColors.turquesa.withValues(alpha: 0.2);
                    colorTextoBadge = const Color(0xFF1E3F38);
                    textoBadge = 'Tomada (${item.horaConfirmadaLegible ?? item.horaProgramada})';
                    iconoEstado = Icons.check_circle_rounded;
                  } else {
                    colorBadge = const Color(0xFFF1F5F9);
                    colorTextoBadge = Colors.grey[700]!;
                    textoBadge = 'Pendiente';
                    iconoEstado = Icons.schedule_rounded;
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      if (!tomada) {
                        final confirmar = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Confirmar Toma', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.azulOscuro)),
                            content: Text('¿Deseas marcar como tomada la dosis de ${item.medicamento} (${item.dosis})?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.turquesa, foregroundColor: const Color(0xFF1E3F38)),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Sí, tomada', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );

                        if (confirmar == true) {
                          await TratamientosService.confirmarToma(item.idHorario);
                          _cargarTomasHoy();
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.fondo,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.horaProgramada,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.azulOscuro,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.medicamento,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.azulOscuro,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.dosis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorBadge,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(iconoEstado, size: 14, color: colorTextoBadge),
                                const SizedBox(width: 5),
                                Text(
                                  textoBadge,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colorTextoBadge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 24),

            // Banner informativo SOS
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.terracota.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.terracota.withValues(alpha: 0.35), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.crisis_alert_rounded, color: AppColors.terracota, size: 28),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Alerta SOS y Llamada de Emergencia',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.azulOscuro,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Si tu familiar presiona el botón SOS, tu teléfono sonará como una alarma inmediata a todo volumen.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.azulOscuro,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.terracota,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AlertaSosCuidadorScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.crisis_alert_rounded, size: 18),
                      label: const Text(
                        'Simular Recepción de Alerta SOS',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget cuerpo;

    if (_cargando) {
      cuerpo = const Scaffold(
        backgroundColor: AppColors.fondo,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.moradoOscuro),
              SizedBox(height: 16),
              Text(
                'Cargando panel de monitoreo...',
                style: TextStyle(color: AppColors.azulOscuro, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    } else if (_tabSeleccionado == 1) {
      cuerpo = TratamientosScreen(
        mostrarBotonVolver: false,
        pacienteId: _pacienteSeleccionado?.id,
      );
    } else if (_tabSeleccionado == 2) {
      cuerpo = PerfilCuidadorScreen(
        onVolverAMonitoreo: () {
          setState(() => _tabSeleccionado = 0);
        },
      );
    } else {
      cuerpo = _pacientes.isEmpty
          ? _construirVistaEmptyState()
          : _construirVistaMonitoreoActivo();
    }

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: cuerpo,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabSeleccionado,
        onTap: (index) {
          setState(() => _tabSeleccionado = index);
        },
        selectedItemColor: AppColors.moradoOscuro,
        unselectedItemColor: Colors.grey[500],
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Monitoreo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication_rounded),
            label: 'Tratamientos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
