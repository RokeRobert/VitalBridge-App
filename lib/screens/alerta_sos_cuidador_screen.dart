import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:vital_bridge/screens/cuidador_dashboard_screen.dart';
import 'package:vital_bridge/services/alarmas_nativas_service.dart';
import 'package:vital_bridge/services/alertas_service.dart';
import 'package:vital_bridge/services/fcm_service.dart';
import 'package:vital_bridge/theme/app_colors.dart';

class AlertaSosCuidadorScreen extends StatefulWidget {
  final String nombrePaciente;
  final String idPaciente;
  final String parentesco;
  final String telefono;
  final String horaAlerta;
  final int? idAlerta;
  final double? latitud;
  final double? longitud;

  const AlertaSosCuidadorScreen({
    super.key,
    this.nombrePaciente = 'Roberto Gómez',
    this.idPaciente = '0045',
    this.parentesco = 'Padre',
    this.telefono = '+34 610 345 872',
    this.horaAlerta = '10:45 AM',
    this.idAlerta,
    this.latitud,
    this.longitud,
  });

  @override
  State<AlertaSosCuidadorScreen> createState() => _AlertaSosCuidadorScreenState();
}

class _AlertaSosCuidadorScreenState extends State<AlertaSosCuidadorScreen> {
  late final AudioPlayer _audioPlayer;
  Timer? _vibracionTimer;
  bool _sirenaActiva = true;

  @override
  void initState() {
    super.initState();
    FcmService.alertaSosAbierta = true;
    AlarmasNativasService.cancelarNotificacionSos();
    _audioPlayer = AudioPlayer();
    _iniciarSirena();
  }

  @override
  void dispose() {
    FcmService.alertaSosAbierta = false;
    _detenerSirena();
    AlarmasNativasService.cancelarNotificacionSos();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _iniciarSirena() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/sos_sirena.wav'));

      _vibracionTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
        if (_sirenaActiva) {
          HapticFeedback.vibrate();
        }
      });
    } catch (_) {}
  }

  void _detenerSirena() {
    _sirenaActiva = false;
    _vibracionTimer?.cancel();
    _vibracionTimer = null;
    try {
      _audioPlayer.stop();
    } catch (_) {}
  }

  void _silenciarSirena() {
    _detenerSirena();
    AlarmasNativasService.cancelarNotificacionSos();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sirena de emergencia silenciada.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _salirDeAlerta({bool resolver = false}) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final puedeHacerPop = navigator.canPop();

    _detenerSirena();
    FcmService.alertaSosAbierta = false;
    await AlarmasNativasService.cancelarNotificacionSos();

    if (resolver && widget.idAlerta != null) {
      AlertasService.resolverAlerta(widget.idAlerta!, resolucion: 'Atendida');
    }

    final estabaBloqueado = await AlarmasNativasService.estaPantallaBloqueada();

    if (!estabaBloqueado && puedeHacerPop) {
      if (!mounted) return;
      navigator.pop();
      if (resolver) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Alerta SOS marcada como atendida exitosamente.'),
            backgroundColor: Color(0xFF2C5E53),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      if (!mounted) return;
      // Reemplazamos la pantalla raíz por el dashboard para asegurar que el stack nunca quede en negro
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const CuidadorDashboardScreen()),
      );
      // Cerramos la actividad de Android y quitamos los flags de pantalla bloqueada
      await AlarmasNativasService.cerrarPantallaAlarma();
    }
  }

  void _llamarPaciente() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.phone_in_talk_rounded, color: Color(0xFFE25C54)),
            SizedBox(width: 10),
            Text('Llamada de Emergencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Llamando a ${widget.nombrePaciente} (${widget.telefono})...\n\nSi no contesta, el sistema mantendrá la alarma activa.',
          style: const TextStyle(fontSize: 14.5, color: Color(0xFF475569)),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE25C54),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Colgar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _verUbicacion() {
    final tieneCoordenadas = widget.latitud != null && widget.longitud != null;
    final latStr = widget.latitud != null ? widget.latitud!.toStringAsFixed(6) : null;
    final lngStr = widget.longitud != null ? widget.longitud!.toStringAsFixed(6) : null;
    final urlMaps = tieneCoordenadas
        ? 'https://www.google.com/maps/search/?api=1&query=${widget.latitud},${widget.longitud}'
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E5482).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Color(0xFF5E5482), size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ubicación en Tiempo Real',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.azulOscuro),
                    ),
                    Text(
                      tieneCoordenadas ? 'GPS Satelital Activo' : 'GPS no disponible',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF2F7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pin_drop_rounded, size: 40, color: Color(0xFFE25C54)),
                  const SizedBox(height: 10),
                  if (tieneCoordenadas) ...[
                    Text(
                      'Coordenadas: $latStr, $lngStr',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.azulOscuro),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Transmitido en vivo por el teléfono del paciente',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ] else ...[
                    const Text(
                      'Sin señal GPS del paciente al emitir la alerta',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.azulOscuro),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Comunícate por llamada telefónica de inmediato',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (tieneCoordenadas && urlMaps != null) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF336C60),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.map_rounded, size: 20),
                label: const Text('Abrir en Google Maps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () {
                  AlarmasNativasService.abrirEnlace(urlMaps);
                },
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5E5482),
                side: const BorderSide(color: Color(0xFF5E5482)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar Mapa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  void _marcarAtendida() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF52C4A8), size: 26),
            SizedBox(width: 10),
            Text('Finalizar Alerta SOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          '¿Deseas marcar esta alerta como atendida o falsa alarma? Esto detendrá las notificaciones y restablecerá el estado normal.',
          style: TextStyle(fontSize: 14.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF52C4A8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _salirDeAlerta(resolver: true);
            },
            child: const Text('Sí, finalizar alerta', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _llamar911() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.emergency_rounded, color: Color(0xFFE25C54), size: 28),
            SizedBox(width: 10),
            Text('Llamar al 911', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          '¿Deseas conectar inmediatamente con la línea de emergencias médicas 911?',
          style: TextStyle(fontSize: 14.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE25C54),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conectando con Servicios de Emergencia 911...'),
                  backgroundColor: Color(0xFFE25C54),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            child: const Text('Llamar al 911', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonAccion({
    required Color color,
    required IconData icono,
    required String texto,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _salirDeAlerta(resolver: false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFBFD),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra Superior: Silenciar sirena y Botón Cerrar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        _sirenaActiva ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        color: _sirenaActiva ? const Color(0xFFE25C54) : Colors.grey,
                      ),
                      tooltip: 'Silenciar sirena',
                      onPressed: _silenciarSirena,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      tooltip: 'Cerrar alerta',
                      onPressed: () => _salirDeAlerta(resolver: false),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Ícono de Sirena Central con resplandor suave
                Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E7),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF9C8C5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE25C54).withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.warning_amber_rounded, color: Color(0xFFE25C54), size: 30),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Título Principal
                const Text(
                  '¡ALERTA SOS ACTIVADA!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: AppColors.azulOscuro,
                  ),
                ),
                const SizedBox(height: 4),

                // Subtítulo
                const Text(
                  'ATENCIÓN INMEDIATA REQUERIDA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: Color(0xFF7E8B9B),
                  ),
                ),
                const SizedBox(height: 16),

                // Avatar del paciente con badge de pulso vital rojo
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFD8ECE4),
                          border: Border.all(color: Colors.white, width: 3.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const ClipOval(
                          child: Icon(
                            Icons.person_rounded,
                            size: 60,
                            color: Color(0xFF4A7C6D),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE25C54),
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
                            Icons.monitor_heart_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Nombre del paciente
                Text(
                  widget.nombrePaciente,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.azulOscuro,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Chip de rol y código ID
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'Adulto Mayor • ID: ${widget.idPaciente}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Tarjeta 1: EMERGENCIA ACTIVA / ALERTA DEL PACIENTE
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EMERGENCIA ACTIVA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: Color(0xFFE25C54),
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'ALERTA DEL PACIENTE',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.azulOscuro,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE8E7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(Icons.warning_amber_rounded, color: Color(0xFFE25C54), size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE25C54),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE25C54).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                'ACCIÓN URGENTE',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: Color(0xFFE25C54),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '¡El paciente ha presionado el botón SOS!',
                              style: TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 15,
                                  color: Color(0xFFFFD4D1),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Hace 1 min • ${widget.horaAlerta}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFFFD4D1),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Tarjeta 2: RESPUESTA INMEDIATA / ¿QUÉ DESEAS HACER?
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RESPUESTA INMEDIATA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '¿QUÉ DESEAS HACER?',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.azulOscuro,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Botón 1: Llamar inmediatamente (Rojo Coral)
                      _buildBotonAccion(
                        color: const Color(0xFFE25C54),
                        icono: Icons.phone_rounded,
                        texto: 'Llamar inmediatamente',
                        onTap: _llamarPaciente,
                      ),
                      const SizedBox(height: 12),

                      // Botón 2: Ver ubicación en tiempo real (Morado)
                      _buildBotonAccion(
                        color: const Color(0xFF5E5482),
                        icono: Icons.location_on_outlined,
                        texto: 'Ver ubicación en tiempo real',
                        onTap: _verUbicacion,
                      ),
                      const SizedBox(height: 12),

                      // Botón 3: Marcar como atendida / Falsa alarma (Turquesa / Menta)
                      _buildBotonAccion(
                        color: const Color(0xFF52C4A8),
                        icono: Icons.check_rounded,
                        texto: 'Marcar como atendida / Falsa alarma',
                        onTap: _marcarAtendida,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Enlace directo al 911
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFE25C54)),
                    const SizedBox(width: 6),
                    const Text(
                      'Enlace directo: ',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    InkWell(
                      onTap: _llamar911,
                      child: const Text(
                        'Llamar al 911 (Emergencias)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE25C54),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Footer
                const Text(
                  '© VitalBridge • Cuidamos contigo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
