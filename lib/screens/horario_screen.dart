import 'package:flutter/material.dart';
import 'package:vital_bridge/models/toma_model.dart';
import 'package:vital_bridge/screens/paciente_screen.dart';
import 'package:vital_bridge/services/auth_service.dart';
import 'package:vital_bridge/services/tratamientos_service.dart';

class HorarioMedicamentosScreen extends StatefulWidget {
  final String? pacienteId;

  const HorarioMedicamentosScreen({
    super.key,
    this.pacienteId,
  });

  @override
  State<HorarioMedicamentosScreen> createState() => _HorarioMedicamentosScreenState();
}

class _HorarioMedicamentosScreenState extends State<HorarioMedicamentosScreen>
    with WidgetsBindingObserver {
  List<TomaModel> _tomas = [];
  bool _cargando = true;
  String? _idPacienteActual;
  final Set<int> _tomasEnProceso = {};
  int _diaSeleccionado = 1; // 1 = Hoy

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inicializarYCargar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarTomas();
    }
  }

  Future<void> _inicializarYCargar() async {
    _idPacienteActual = widget.pacienteId ?? await AuthService.obtenerUsuarioId();
    await _cargarTomas();
  }

  Future<void> _cargarTomas() async {
    setState(() => _cargando = true);

    try {
      final lista = await TratamientosService.obtenerTomasHoy(
        pacienteId: _idPacienteActual,
      );

      if (!mounted) return;
      setState(() {
        _tomas = lista;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _confirmarToma(TomaModel med) async {
    if (_tomasEnProceso.contains(med.idHorario)) return;

    setState(() {
      _tomasEnProceso.add(med.idHorario);
    });

    final exito = await TratamientosService.confirmarToma(med.idHorario);

    if (!mounted) return;

    setState(() {
      _tomasEnProceso.remove(med.idHorario);
      if (exito) {
        final index = _tomas.indexWhere((t) => t.idHorario == med.idHorario);
        if (index != -1) {
          _tomas[index] = _tomas[index].copyWith(
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
              ? '✅ ${med.medicamento} marcado como tomado exitosamente.'
              : '⚠️ Error al confirmar la toma.',
          style: const TextStyle(fontSize: 15),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: exito ? const Color(0xFF336C60) : const Color(0xFFE25C54),
      ),
    );
  }

  String _formatearFechaHoy() {
    final ahora = DateTime.now();
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final diaSemana = dias[ahora.weekday - 1];
    final mes = meses[ahora.month - 1];
    return '$diaSemana, ${ahora.day} de $mes';
  }

  List<String> _generarDiasSemana() {
    final ahora = DateTime.now();
    const nombresDias = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    final ayer = ahora.subtract(const Duration(days: 1));
    final manana = ahora.add(const Duration(days: 1));
    final masDos = ahora.add(const Duration(days: 2));
    final masTres = ahora.add(const Duration(days: 3));

    return [
      'Ayer\n${nombresDias[ayer.weekday]} ${ayer.day}',
      'HOY\n${nombresDias[ahora.weekday]} ${ahora.day}',
      'Mañana\n${nombresDias[manana.weekday]} ${manana.day}',
      '${nombresDias[masDos.weekday]} ${masDos.day}',
      '${nombresDias[masTres.weekday]} ${masTres.day}',
    ];
  }

  String _obtenerMomentoDelDia(String horaStr) {
    try {
      final match = RegExp(r'(\d+):(\d+)\s*(AM|PM)?', caseSensitive: false).firstMatch(horaStr.trim());
      if (match != null) {
        int hora = int.parse(match.group(1)!);
        final periodo = match.group(3)?.toUpperCase();
        if (periodo == 'PM' && hora < 12) hora += 12;
        if (periodo == 'AM' && hora == 12) hora = 0;

        if (hora < 12) return 'Mañana (Desayuno)';
        if (hora < 18) return 'Tarde (Comida)';
        return 'Noche (Cena / Dormir)';
      }
    } catch (_) {}
    return 'Día';
  }

  TomaModel? _obtenerProximaPendiente() {
    final pendientes = _tomas.where((t) => !t.esTomada).toList();
    if (pendientes.isNotEmpty) {
      return pendientes.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final int totalTomas = _tomas.length;
    final int tomasCompletadas = _tomas.where((m) => m.esTomada).length;
    final diasSemana = _generarDiasSemana();
    final proximaPendiente = _obtenerProximaPendiente();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2), // Fondo suave crema
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior accesible con botón de regreso
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop(true);
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const PacienteScreen(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E0D8)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF2C324E)),
                          SizedBox(width: 6),
                          Text(
                            'Volver',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C324E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'VitalBridge',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5E5482),
                    ),
                  ),
                ],
              ),
            ),

            // Contenido dinámico con scroll y pull-to-refresh
            Expanded(
              child: RefreshIndicator(
                onRefresh: _cargarTomas,
                color: const Color(0xFF453E60),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Título grande y comprensible
                      const Text(
                        'Mis Medicinas de Hoy',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF222845),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatearFechaHoy(),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Selector de días dinámico
                      SizedBox(
                        height: 65,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: diasSemana.length,
                          itemBuilder: (context, index) {
                            bool esSeleccionado = index == _diaSeleccionado;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10.0),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  setState(() {
                                    _diaSeleccionado = index;
                                  });
                                  if (index == 1) {
                                    _cargarTomas();
                                  }
                                },
                                child: Container(
                                  width: 85,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: esSeleccionado
                                        ? const Color(0xFF5E5482)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: esSeleccionado
                                          ? const Color(0xFF5E5482)
                                          : const Color(0xFFE2E0D8),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      diasSemana[index],
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: esSeleccionado
                                            ? Colors.white
                                            : const Color(0xFF475569),
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tarjeta resumen del progreso del día
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: totalTomas > 0 && tomasCompletadas == totalTomas
                              ? const Color(0xFFE8F7F3)
                              : const Color(0xFFF3F0FA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: totalTomas > 0 && tomasCompletadas == totalTomas
                                ? const Color(0xFF7CD4C2)
                                : const Color(0xFFD6D0EA),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: totalTomas > 0 && tomasCompletadas == totalTomas
                                    ? const Color(0xFF7CD4C2)
                                    : const Color(0xFF5E5482),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                totalTomas > 0 && tomasCompletadas == totalTomas
                                    ? Icons.check_circle_rounded
                                    : Icons.fact_check_rounded,
                                color: totalTomas > 0 && tomasCompletadas == totalTomas
                                    ? const Color(0xFF1E3F38)
                                    : Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    totalTomas > 0
                                        ? 'Progreso: $tomasCompletadas de $totalTomas tomas realizadas'
                                        : 'Sin tomas programadas para hoy',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: totalTomas > 0 && tomasCompletadas == totalTomas
                                          ? const Color(0xFF1E3F38)
                                          : const Color(0xFF2C324E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    totalTomas == 0
                                        ? 'No tienes medicamentos pendientes hoy'
                                        : (tomasCompletadas == totalTomas
                                            ? '¡Excelente! Terminaste todas tus tomas de hoy 🎉'
                                            : (proximaPendiente != null
                                                ? 'Tu próxima medicina es a las ${proximaPendiente.horaProgramada}'
                                                : 'Sigue tus tomas según el horario')),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: totalTomas > 0 && tomasCompletadas == totalTomas
                                          ? const Color(0xFF2C5E53)
                                          : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Título de la lista
                      const Text(
                        'Horario por horas:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Estado de Carga / Empty State / Lista Real Dinámica
                      if (_cargando)
                        Container(
                          height: 200,
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Color(0xFF5E5482)),
                              SizedBox(height: 14),
                              Text(
                                'Cargando tu horario de tomas...',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 14.5),
                              ),
                            ],
                          ),
                        )
                      else if (_tomas.isEmpty)
                        // EMPTY STATE: Cuando no hay ningún medicamento asignado
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE2E0D8)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7CD4C2).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 48,
                                  color: Color(0xFF2C5E53),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No tienes medicinas programadas para hoy',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF222845),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Si tu cuidador asigna un tratamiento, aparecerá en esta lista automáticamente con sus alarmas.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // LISTA DE TARJETAS DE MEDICAMENTOS REALES Y DINÁMICAS
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _tomas.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final med = _tomas[index];
                            final bool tomada = med.esTomada;
                            final bool esProxima =
                                proximaPendiente != null && proximaPendiente.idHorario == med.idHorario;
                            final bool enProceso = _tomasEnProceso.contains(med.idHorario);
                            final momento = _obtenerMomentoDelDia(med.horaProgramada);

                            return Container(
                              decoration: BoxDecoration(
                                color: esProxima
                                    ? const Color(0xFF453E60) // Morado destacado para la próxima pendiente
                                    : (tomada ? const Color(0xFFF7FCFA) : Colors.white),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: tomada
                                      ? const Color(0xFF7CD4C2)
                                      : (esProxima
                                          ? const Color(0xFF5E5482)
                                          : const Color(0xFFE2E0D8)),
                                  width: esProxima ? 2 : 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Fila 1: Hora en grande y botón de estado
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time_filled_rounded,
                                            size: 22,
                                            color: esProxima
                                                ? const Color(0xFF7CD4C2)
                                                : (tomada
                                                    ? const Color(0xFF336C60)
                                                    : const Color(0xFF5E5482)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            med.horaProgramada,
                                            style: TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                              color: esProxima
                                                  ? Colors.white
                                                  : const Color(0xFF222845),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Botón interactivo para marcar/confirmar toma
                                      InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: (tomada || enProceso) ? null : () => _confirmarToma(med),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: tomada
                                                ? const Color(0xFF7CD4C2)
                                                : (esProxima
                                                    ? const Color(0xFF7CD4C2)
                                                    : const Color(0xFFF1F5F9)),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: tomada
                                                  ? const Color(0xFF336C60)
                                                  : (esProxima
                                                      ? const Color(0xFF1E3F38)
                                                      : const Color(0xFFCBD5E1)),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (enProceso)
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Color(0xFF1E3F38),
                                                  ),
                                                )
                                              else
                                                Icon(
                                                  tomada
                                                      ? Icons.check_circle_rounded
                                                      : Icons.radio_button_unchecked_rounded,
                                                  size: 18,
                                                  color: tomada || esProxima
                                                      ? const Color(0xFF1E3F38)
                                                      : const Color(0xFF475569),
                                                ),
                                              const SizedBox(width: 6),
                                              Text(
                                                tomada
                                                    ? 'Tomada'
                                                    : (enProceso ? 'Guardando...' : 'Confirmar'),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: tomada || esProxima
                                                      ? const Color(0xFF1E3F38)
                                                      : const Color(0xFF475569),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Momento del día (Mañana, Tarde, Noche)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: esProxima
                                          ? Colors.white.withValues(alpha: 0.15)
                                          : const Color(0xFFF4F6F8),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      momento,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: esProxima
                                            ? const Color(0xFFE2DCF7)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Nombre de la medicina y Dosis
                                  Text(
                                    med.medicamento,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: esProxima ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    med.dosis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: esProxima
                                          ? const Color(0xFFB5ADC8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                  if (med.indicaciones != null && med.indicaciones!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 16,
                                          color: esProxima
                                              ? const Color(0xFF7CD4C2)
                                              : const Color(0xFF336C60),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            med.indicaciones!,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: esProxima
                                                  ? const Color(0xFFD6D0EA)
                                                  : const Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
