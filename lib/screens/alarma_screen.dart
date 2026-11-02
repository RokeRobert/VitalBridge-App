import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_bridge/screens/paciente_screen.dart';
import 'package:vital_bridge/services/alarmas_nativas_service.dart';
import 'package:vital_bridge/services/tratamientos_service.dart';

class AlarmaMedicamentoScreen extends StatefulWidget {
  final int? idHorario;
  final String nombreMedicamento;
  final String dosis;
  final String hora;
  final String indicaciones;

  const AlarmaMedicamentoScreen({
    super.key,
    this.idHorario,
    this.nombreMedicamento = 'Paracetamol (Medicina A)',
    this.dosis = '1 tableta',
    this.hora = '8:00 AM',
    this.indicaciones = 'Después del desayuno • Con agua',
  });

  @override
  State<AlarmaMedicamentoScreen> createState() => _AlarmaMedicamentoScreenState();
}

class _AlarmaMedicamentoScreenState extends State<AlarmaMedicamentoScreen> {
  bool _alarmaSonando = true;
  bool _tomaConfirmada = false;
  bool _confirmando = false;

  late final AudioPlayer _audioPlayer;
  Timer? _vibracionTimer;

  @override
  void initState() {
    super.initState();
    AlarmasNativasService.alarmaAbierta = true;
    if (widget.idHorario != null) {
      AlarmasNativasService.cancelarAlarma(widget.idHorario!);
    }
    AlarmasNativasService.cancelarTodasLasNotificacionesActivas();
    _audioPlayer = AudioPlayer();
    _iniciarAlarmaSonido();
  }

  @override
  void dispose() {
    AlarmasNativasService.alarmaAbierta = false;
    _detenerAlarmaSonido();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _iniciarAlarmaSonido() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/alarma.wav'));

      // Vibración pulsante constante mientras la alarma esté activa
      HapticFeedback.heavyImpact();
      _vibracionTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
        if (_alarmaSonando) {
          HapticFeedback.heavyImpact();
        }
      });
    } catch (_) {}
  }

  void _detenerAlarmaSonido() {
    _vibracionTimer?.cancel();
    _vibracionTimer = null;
    try {
      _audioPlayer.stop();
    } catch (_) {}
    // Cancelar la notificación del sistema Android para apagar de inmediato su sonido
    if (widget.idHorario != null) {
      AlarmasNativasService.cancelarAlarma(widget.idHorario!);
    }
    AlarmasNativasService.cancelarTodasLasNotificacionesActivas();
  }

  void _silenciarAlarma() {
    _detenerAlarmaSonido();
    setState(() {
      _alarmaSonando = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sonido de alarma silenciado.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmarToma() async {
    if (_confirmando) return;

    setState(() {
      _confirmando = true;
    });

    bool exito = true;
    if (widget.idHorario != null) {
      exito = await TratamientosService.confirmarToma(widget.idHorario!);
    }

    if (!mounted) return;

    setState(() {
      _confirmando = false;
      _tomaConfirmada = exito;
      if (exito) {
        _detenerAlarmaSonido();
        _alarmaSonando = false;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          exito
              ? 'Toma registrada exitosamente en VitalBridge.'
              : 'No se pudo confirmar la toma en el servidor.',
        ),
        backgroundColor: exito ? const Color(0xFF336C60) : const Color(0xFFE25C54),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _cerrarAplicacion() async {
    AlarmasNativasService.alarmaAbierta = false;
    _detenerAlarmaSonido();
    final navigator = Navigator.of(context);
    final puedeHacerPop = navigator.canPop();

    await AlarmasNativasService.cancelarTodasLasNotificacionesActivas();
    final estabaBloqueado = await AlarmasNativasService.estaPantallaBloqueada();

    if (!estabaBloqueado && puedeHacerPop) {
      if (!mounted) return;
      navigator.pop(_tomaConfirmada);
    } else {
      if (!mounted) return;
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const PacienteScreen()),
      );
      await AlarmasNativasService.cerrarPantallaAlarma();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cerrarAplicacion();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF7F2),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),

                // Indicador visual de campana de alarma
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: _alarmaSonando
                          ? const Color(0xFFFDE8E7)
                          : const Color(0xFFE8F7F3),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_alarmaSonando
                                  ? const Color(0xFFE25C54)
                                  : const Color(0xFF7CD4C2))
                              .withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      _alarmaSonando
                          ? Icons.notifications_active_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 46,
                      color: _alarmaSonando
                          ? const Color(0xFFE25C54)
                          : const Color(0xFF2C5E53),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Título de Alarma Activa
                Text(
                  _alarmaSonando ? '¡Hora de tu medicina!' : 'Alarma Silenciada',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222845),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _alarmaSonando
                      ? 'La alarma está sonando actualmente'
                      : (_tomaConfirmada
                          ? 'Dosis registrada correctamente'
                          : 'Recuerda tomar tu medicamento'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: _alarmaSonando ? const Color(0xFFE25C54) : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),

                // Recuadro morado informativo de la medicina
                Container(
                  padding: const EdgeInsets.all(22.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF453E60),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF453E60).withValues(alpha: 0.25),
                        blurRadius: 16,
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5A527A),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.medication_rounded,
                                  size: 15,
                                  color: Color(0xFFE2DCF7),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'DOSIS ACTUAL',
                                  style: TextStyle(
                                    color: Color(0xFFE2DCF7),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            widget.dosis,
                            style: const TextStyle(
                              color: Color(0xFFB5ADC8),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.nombreMedicamento,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.hora,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.8,
                        ),
                      ),
                      if (widget.indicaciones.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.indicaciones,
                          style: const TextStyle(
                            color: Color(0xFFB5ADC8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Botón 1: Apagar / Silenciar Sonido de Alarma
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _alarmaSonando
                        ? const Color(0xFFE25C54)
                        : const Color(0xFFE5E7EB),
                    foregroundColor: _alarmaSonando ? Colors.white : const Color(0xFF6B7280),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _alarmaSonando ? _silenciarAlarma : null,
                  icon: Icon(
                    _alarmaSonando ? Icons.volume_off_rounded : Icons.check_rounded,
                    size: 22,
                  ),
                  label: Text(
                    _alarmaSonando ? 'Apagar sonido de alarma' : 'Alarma apagada',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Botón 2: Confirmar Toma de Medicamento
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tomaConfirmada
                        ? const Color(0xFF336C60)
                        : const Color(0xFF7CD4C2),
                    foregroundColor: _tomaConfirmada ? Colors.white : const Color(0xFF1E3F38),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: (_tomaConfirmada || _confirmando) ? null : _confirmarToma,
                  icon: _confirmando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF1E3F38)),
                        )
                      : Icon(
                          _tomaConfirmada ? Icons.check_circle_rounded : Icons.medication_rounded,
                          size: 22,
                        ),
                  label: Text(
                    _confirmando
                        ? 'Registrando toma...'
                        : (_tomaConfirmada ? '¡Medicamento tomado!' : 'Confirmar toma de medicina'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Botón 3: Listo (Cierra la aplicación automáticamente)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E5482),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _cerrarAplicacion,
                  icon: const Icon(Icons.exit_to_app_rounded, size: 22),
                  label: const Text(
                    'Listo (Cerrar Alarma y Salir)',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
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
