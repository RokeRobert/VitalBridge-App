import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_bridge/models/toma_model.dart';
import 'package:vital_bridge/screens/alarma_screen.dart';
import 'package:vital_bridge/screens/horario_screen.dart';
import 'package:vital_bridge/screens/login_screen.dart';
import 'package:vital_bridge/screens/tratamientos_screen.dart';
import 'package:vital_bridge/services/alertas_service.dart';
import 'package:vital_bridge/services/auth_service.dart';
import 'package:vital_bridge/services/tratamientos_service.dart';

import 'package:vital_bridge/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class PacienteScreen extends StatefulWidget {
  const PacienteScreen({super.key});

  @override
  State<PacienteScreen> createState() => _PacienteScreenState();
}

class _PacienteScreenState extends State<PacienteScreen> with WidgetsBindingObserver {
  List<TomaModel> _tomasHoy = [];
  bool _cargando = true;
  String _nombrePaciente = 'Paciente';
  String? _idPaciente;
  final Set<int> _tomasEnProceso = {};

  // Canales en tiempo real de Supabase
  RealtimeChannel? _canalTratamientos;
  RealtimeChannel? _canalHorarios;
  RealtimeChannel? _canalTomas;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarDatosIniciales();
    _iniciarRealtime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _canalTratamientos?.unsubscribe();
    _canalHorarios?.unsubscribe();
    _canalTomas?.unsubscribe();
    super.dispose();
  }

  void _iniciarRealtime() {
    _canalTratamientos = SupabaseService.escucharTabla(
      canalNombre: 'realtime-paciente-tratamientos',
      tabla: 'tratamiento',
      onCambio: () {
        if (mounted) {
          _cargarTomasHoy();
        }
      },
    );

    _canalHorarios = SupabaseService.escucharTabla(
      canalNombre: 'realtime-paciente-horarios',
      tabla: 'horario',
      onCambio: () {
        if (mounted) {
          _cargarTomasHoy();
        }
      },
    );

    _canalTomas = SupabaseService.escucharTabla(
      canalNombre: 'realtime-paciente-tomas',
      tabla: 'toma',
      onCambio: () {
        if (mounted) {
          _cargarTomasHoy();
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarTomasHoy();
    }
  }

  Future<void> _cargarDatosIniciales() async {
    final prefs = await SharedPreferences.getInstance();
    final nombreGuardado = prefs.getString('usuario_nombre');
    final idGuardado = await AuthService.obtenerUsuarioId();

    if (mounted) {
      setState(() {
        if (nombreGuardado != null && nombreGuardado.isNotEmpty && nombreGuardado != 'Miguel Angel') {
          _nombrePaciente = nombreGuardado;
        }
        _idPaciente = idGuardado;
      });
    }

    // Consulta de respaldo a Supabase para recuperar el nombre real si no estaba en caché
    if (_idPaciente != null && (_nombrePaciente == 'Paciente' || _nombrePaciente == 'Miguel Angel')) {
      try {
        final client = SupabaseService.client;
        if (client != null) {
          final res = await client
              .from('paciente')
              .select('nombre_paciente')
              .eq('id_paciente', _idPaciente!)
              .maybeSingle();

          if (res != null) {
            final nombreReal = res['nombre_paciente']?.toString().trim();
            if (nombreReal != null && nombreReal.isNotEmpty && mounted) {
              setState(() {
                _nombrePaciente = nombreReal;
              });
              await prefs.setString('usuario_nombre', nombreReal);
            }
          }
        }
      } catch (_) {}
    }

    await _cargarTomasHoy();
  }

  Future<void> _cargarTomasHoy() async {
    setState(() => _cargando = true);

    final tomas = await TratamientosService.obtenerTomasHoy(pacienteId: _idPaciente);

    if (!mounted) return;
    setState(() {
      _tomasHoy = tomas;
      _cargando = false;
    });
  }

  DateTime _parsearHora(String horaStr, DateTime base) {
    try {
      final match = RegExp(r'(\d+):(\d+)\s*(AM|PM)?', caseSensitive: false).firstMatch(horaStr.trim());
      if (match != null) {
        int hora = int.parse(match.group(1)!);
        int minuto = int.parse(match.group(2)!);
        final periodo = match.group(3)?.toUpperCase();
        if (periodo == 'PM' && hora < 12) hora += 12;
        if (periodo == 'AM' && hora == 12) hora = 0;
        return DateTime(base.year, base.month, base.day, hora, minuto);
      }
    } catch (_) {}
    return base;
  }

  /// Encuentra la alarma / toma más próxima a la hora actual:
  /// - Si hay tomas pendientes: selecciona la que corresponde tomar a continuación.
  /// - Si ya se tomaron todas: muestra la última tomada en verde.
  TomaModel? _obtenerTomaMasProxima() {
    if (_tomasHoy.isEmpty) return null;

    final pendientes = _tomasHoy.where((t) => !t.esTomada).toList();

    if (pendientes.isNotEmpty) {
      final ahora = DateTime.now();

      // Ordenar cronológicamente por la hora de la toma
      pendientes.sort((a, b) {
        final fa = _parsearHora(a.horaProgramada, ahora);
        final fb = _parsearHora(b.horaProgramada, ahora);
        return fa.compareTo(fb);
      });

      // La primera toma pendiente en orden de horario es la próxima o más urgente
      return pendientes.first;
    }

    // Si todas ya fueron tomadas, mostramos la última realizada hoy
    return _tomasHoy.last;
  }

  Future<void> _confirmarToma(TomaModel toma) async {
    if (_tomasEnProceso.contains(toma.idHorario)) return;

    setState(() {
      _tomasEnProceso.add(toma.idHorario);
    });

    final exito = await TratamientosService.confirmarToma(toma.idHorario);

    if (!mounted) return;

    setState(() {
      _tomasEnProceso.remove(toma.idHorario);
      if (exito) {
        final index = _tomasHoy.indexWhere((t) => t.idHorario == toma.idHorario);
        if (index != -1) {
          _tomasHoy[index] = _tomasHoy[index].copyWith(
            estado: 'Tomada',
            horaTomada: DateTime.now(),
          );
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          exito
              ? '✅ ¡Toma de ${toma.medicamento} confirmada!'
              : '⚠️ Error al confirmar la toma.',
        ),
        backgroundColor: exito ? const Color(0xFF336C60) : const Color(0xFFE25C54),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ignore: unused_element
  void _abrirAlarmaParaToma(TomaModel toma) async {
    final confirmada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AlarmaMedicamentoScreen(
          idHorario: toma.idHorario,
          nombreMedicamento: toma.medicamento,
          dosis: toma.dosis,
          hora: toma.horaProgramada,
          indicaciones: toma.indicaciones ?? 'Seguir indicaciones médicas',
        ),
      ),
    );

    if (confirmada == true) {
      _cargarTomasHoy();
    }
  }

  String _formatearFechaHoy() {
    final ahora = DateTime.now();
    const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final diaSemana = dias[ahora.weekday - 1];
    final mes = meses[ahora.month - 1];
    return '$diaSemana, ${ahora.day} de $mes';
  }

  void _mostrarDialogoSOS(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE25C54), size: 28),
            SizedBox(width: 10),
            Text('Confirmar Alerta SOS', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas enviar una alerta de emergencia a tus cuidadores y familiares?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE25C54),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              AlertasService.emitirAlertaSos(
                idPaciente: _idPaciente ?? '00000000-0000-0000-0000-000000000045',
                motivo: 'Botón SOS presionado por $_nombrePaciente',
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 ¡Alerta SOS enviada con éxito a tus contactos de emergencia!'),
                  backgroundColor: Color(0xFFE25C54),
                  duration: Duration(seconds: 4),
                ),
              );
            },
            child: const Text('Enviar SOS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmarCerrarSesion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFE25C54)),
            SizedBox(width: 10),
            Text(
              'Cerrar Sesión',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C324E)),
            ),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas salir? Para volver a ingresar necesitarás tu código de vinculación.',
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
              elevation: 0,
            ),
            onPressed: () async {
              final navigator = Navigator.of(context);
              Navigator.pop(context);
              await AuthService.cerrarSesion();
              if (!mounted) return;
              navigator.pushAndRemoveUntil(
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

  void _mostrarMenuOpciones() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
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
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF5E5482), size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nombrePaciente,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C324E),
                      ),
                    ),
                    const Text(
                      'Menú del Paciente',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF453E60), size: 22),
              ),
              title: const Text(
                'Tomas de Hoy',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF2C324E)),
              ),
              subtitle: const Text(
                'Revisa los horarios y medicamentos de hoy',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF94A3B8)),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => HorarioMedicamentosScreen(pacienteId: _idPaciente),
                  ),
                );
                _cargarTomasHoy();
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication_rounded, color: Color(0xFF453E60), size: 22),
              ),
              title: const Text(
                'Mis Medicamentos',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF2C324E)),
              ),
              subtitle: const Text(
                'Consulta todos tus tratamientos activos',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF94A3B8)),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TratamientosScreen(
                      esModoCuidador: false,
                      pacienteId: _idPaciente,
                    ),
                  ),
                );
                _cargarTomasHoy();
              },
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE2E8F0), thickness: 1),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout_rounded, color: Color(0xFFE25C54), size: 22),
              ),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFFE25C54)),
              ),
              subtitle: const Text(
                'Desconectar este dispositivo',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFFE25C54)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmarCerrarSesion();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tomasTomadas = _tomasHoy.where((t) => t.esTomada).length;
    final totalTomas = _tomasHoy.length;
    final tomaMasProxima = _obtenerTomaMasProxima();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmarCerrarSesion();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF7F2), // Fondo suave crema
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _cargarTomasHoy,
            color: const Color(0xFF453E60),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Encabezado superior: Saludo, Fecha y Botón de Menú
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¡Hola, $_nombrePaciente!',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C324E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatearFechaHoy(),
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Botón de menú de 3 puntos
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEAE7E0), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          tooltip: 'Menú de opciones',
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: Color(0xFF453E60),
                            size: 24,
                          ),
                          onPressed: _mostrarMenuOpciones,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                // Pregunta principal central
                const Text(
                  '¿Ya tomaste tus\nmedicinas?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222845),
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Resumen del progreso diario
                if (totalTomas > 0)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: tomasTomadas == totalTomas
                            ? const Color(0xFFE8F7F3)
                            : const Color(0xFFEBE8F4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tomasTomadas == totalTomas
                            ? '🎉 ¡Completaste todas tus tomas de hoy! ($tomasTomadas/$totalTomas)'
                            : 'Progreso del día: $tomasTomadas de $totalTomas tomas realizadas',
                        style: TextStyle(
                          color: tomasTomadas == totalTomas
                              ? const Color(0xFF2C5E53)
                              : const Color(0xFF453E60),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 22),

                // TARJETA ÚNICA: LA ALARMA / TOMA MÁS PRÓXIMA A LA HORA ACTUAL
                if (_cargando)
                  Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF453E60)),
                        SizedBox(height: 14),
                        Text(
                          'Buscando tu próxima pastilla...',
                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
                        ),
                      ],
                    ),
                  )
                else if (tomaMasProxima == null)
                  Container(
                    padding: const EdgeInsets.all(28.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFEAE7E0)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: Color(0xFF7CD4C2), size: 52),
                        SizedBox(height: 12),
                        Text(
                          'No hay tomas programadas para hoy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C324E),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Tu cuidador te asignará medicamentos cuando sea necesario.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  )
                else
                  _buildTarjetaToma(tomaMasProxima),

                const SizedBox(height: 18),

                // Tarjeta 2: Alerta SOS (Roja Coral / Terracota) - BOTÓN DE ACCIÓN
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _mostrarDialogoSOS(context),
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE25C54),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE25C54).withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.crisis_alert_rounded,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Alerta SOS',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  // CONSTRUCCIÓN DE LA TARJETA DE LA PASTILLA / TOMA MÁS PRÓXIMA
  Widget _buildTarjetaToma(TomaModel toma) {
    final esTomada = toma.esTomada;
    final enProceso = _tomasEnProceso.contains(toma.idHorario);

    if (esTomada) {
      // ESTADO VERDE CON PALOMITA (✅ TOMADA)
      return Container(
        padding: const EdgeInsets.all(22.0),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F7F3), // Verde menta pastel suave
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF7CD4C2), width: 1.8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7CD4C2).withValues(alpha: 0.2),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: Chip "✅ TOMADA" y Dosis
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C5E53),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF7CD4C2)),
                      SizedBox(width: 6),
                      Text(
                        '✅ TOMADA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  toma.dosis,
                  style: const TextStyle(
                    color: Color(0xFF2C5E53),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Nombre del medicamento
            Text(
              toma.medicamento,
              style: const TextStyle(
                color: Color(0xFF1E3F38),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // Horario programado vs Hora confirmada
            Row(
              children: [
                Text(
                  'Programada: ${toma.horaProgramada}',
                  style: const TextStyle(
                    color: Color(0xFF5A7972),
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF5A7972),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  toma.horaConfirmadaLegible != null
                      ? 'Tomada a las ${toma.horaConfirmadaLegible}'
                      : 'Confirmada',
                  style: const TextStyle(
                    color: Color(0xFF2C5E53),
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (toma.indicaciones != null && toma.indicaciones!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                toma.indicaciones!,
                style: const TextStyle(
                  color: Color(0xFF5A7972),
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // ESTADO PENDIENTE (TARJETA MORADA CON BOTÓN DE CONFIRMAR TOMA)
    return Container(
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
          // Fila superior: Chip "PRÓXIMA ALARMA" y Dosis
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
                      'PRÓXIMA ALARMA',
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
                toma.dosis,
                style: const TextStyle(
                  color: Color(0xFFB5ADC8),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Nombre de la medicina
          Text(
            toma.medicamento,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),

          // Hora en grande
          Text(
            toma.horaProgramada,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.8,
            ),
          ),

          if (toma.indicaciones != null && toma.indicaciones!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              toma.indicaciones!,
              style: const TextStyle(
                color: Color(0xFFB5ADC8),
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Botón principal "Confirmar Toma"
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7CD4C2),
                foregroundColor: const Color(0xFF1E3F38),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: enProceso ? null : () => _confirmarToma(toma),
              icon: enProceso
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1E3F38),
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(
                enProceso ? 'Confirmando...' : 'Confirmar Toma',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
