import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vital_bridge/models/alerta_sos_model.dart';
import 'package:vital_bridge/models/paciente_model.dart';
import 'package:vital_bridge/models/toma_model.dart';
import 'package:vital_bridge/services/alarmas_nativas_service.dart';
import 'package:vital_bridge/services/alertas_service.dart';
import 'package:vital_bridge/services/pacientes_service.dart';
import 'package:vital_bridge/services/tratamientos_service.dart';
import 'package:vital_bridge/theme/app_colors.dart';

class HistorialTomasScreen extends StatefulWidget {
  final bool mostrarBotonVolver;
  final String? pacienteIdInicial;
  final String? nombrePacienteInicial;

  const HistorialTomasScreen({
    super.key,
    this.mostrarBotonVolver = true,
    this.pacienteIdInicial,
    this.nombrePacienteInicial,
  });

  @override
  State<HistorialTomasScreen> createState() => _HistorialTomasScreenState();
}

class _HistorialTomasScreenState extends State<HistorialTomasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Estado de Pacientes
  List<PacienteModel> _pacientes = [];
  PacienteModel? _pacienteSeleccionado;
  // ignore: unused_field — reservado para indicador de carga futura
  bool _cargandoPacientes = false;

  // Estado de Fechas (ordenadas del más nuevo al más viejo)
  List<DateTime> _diasHistorial = [];
  DateTime? _fechaSeleccionada;

  // Caché de tomas y resúmenes por fecha para apertura instantánea
  final Map<String, List<TomaModel>> _cacheTomasPorFecha = {};
  final Map<String, Map<String, dynamic>> _cacheResumenPorFecha = {};
  final Set<String> _fechasCargando = {};

  // Estado del Tab 2: Alertas SOS Atendidas
  List<AlertaSosModel> _alertasAtendidas = [];
  bool _cargandoAlertas = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _generarDiasHistorial();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Genera una lista cronológica desde hoy hacia atrás (del más nuevo al más viejo)
  void _generarDiasHistorial({int cantidadDias = 14}) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    _diasHistorial = List.generate(cantidadDias, (index) {
      return hoy.subtract(Duration(days: index));
    });
    // Por defecto, seleccionar el día más nuevo (Hoy)
    _fechaSeleccionada = _diasHistorial.isNotEmpty ? _diasHistorial.first : hoy;
  }

  String _fechaKey(DateTime f) {
    return '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';
  }

  Future<void> _cargarDatosIniciales() async {
    setState(() => _cargandoPacientes = true);
    final lista = await PacientesService.obtenerPacientes();

    PacienteModel? inicial;
    if (widget.pacienteIdInicial != null) {
      try {
        inicial = lista.firstWhere((p) => p.id == widget.pacienteIdInicial);
      } catch (_) {}
    }

    if (inicial == null) {
      final guardadoId = await PacientesService.obtenerIdPacienteSeleccionado();
      if (guardadoId != null) {
        try {
          inicial = lista.firstWhere((p) => p.id == guardadoId);
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _pacientes = lista;
        _pacienteSeleccionado = inicial ?? (lista.isNotEmpty ? lista.first : null);
        _cargandoPacientes = false;
      });

      // Cargar el cumplimiento de la primera fecha seleccionada (Hoy)
      if (_fechaSeleccionada != null) {
        _cargarTomasDeFecha(_fechaSeleccionada!);
      }
      _cargarAlertasAtendidas();
    }
  }

  Future<void> _cargarTomasDeFecha(DateTime fecha, {bool forzarRecarga = false}) async {
    final key = _fechaKey(fecha);
    if (!forzarRecarga && _cacheTomasPorFecha.containsKey(key)) {
      return;
    }

    setState(() {
      _fechasCargando.add(key);
    });

    final tomas = await TratamientosService.obtenerTomasPorFecha(
      pacienteId: _pacienteSeleccionado?.id,
      fecha: fecha,
    );
    final resumen = TratamientosService.calcularResumenCumplimiento(tomas);

    if (mounted) {
      setState(() {
        _cacheTomasPorFecha[key] = tomas;
        _cacheResumenPorFecha[key] = resumen;
        _fechasCargando.remove(key);
      });
    }
  }

  void _tocarFecha(DateTime fecha) {
    final key = _fechaKey(fecha);
    setState(() {
      if (_fechaSeleccionada != null && _fechaKey(_fechaSeleccionada!) == key) {
        // Si ya está seleccionada, permite colapsar
        _fechaSeleccionada = null;
      } else {
        _fechaSeleccionada = fecha;
      }
    });

    if (_fechaSeleccionada != null) {
      _cargarTomasDeFecha(fecha);
    }
  }

  Future<void> _cargarAlertasAtendidas() async {
    setState(() => _cargandoAlertas = true);
    final alertas = await AlertasService.obtenerHistorialAlertasAtendidas(
      pacienteId: _pacienteSeleccionado?.id,
    );
    if (mounted) {
      setState(() {
        _alertasAtendidas = alertas;
        _cargandoAlertas = false;
      });
    }
  }

  void _cambiarPaciente(PacienteModel nuevoPaciente) {
    setState(() {
      _pacienteSeleccionado = nuevoPaciente;
      _cacheTomasPorFecha.clear();
      _cacheResumenPorFecha.clear();
      _fechasCargando.clear();
    });
    PacientesService.guardarIdPacienteSeleccionado(nuevoPaciente.id);

    if (_fechaSeleccionada != null) {
      _cargarTomasDeFecha(_fechaSeleccionada!, forzarRecarga: true);
    }
    _cargarAlertasAtendidas();
  }

  Future<void> _seleccionarFechaCalendario() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 120)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.moradoOscuro,
              onPrimary: Colors.white,
              onSurface: AppColors.azulOscuro,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final fechaSinHora = DateTime(picked.year, picked.month, picked.day);
      // Si la fecha no está en la lista actual, agregarla al principio o en orden
      if (!_diasHistorial.any((d) => _fechaKey(d) == _fechaKey(fechaSinHora))) {
        setState(() {
          _diasHistorial.insert(0, fechaSinHora);
          _diasHistorial.sort((a, b) => b.compareTo(a)); // Del más nuevo al más viejo
        });
      }
      _tocarFecha(fechaSinHora);
    }
  }

  String _mesAbreviado(DateTime fecha) {
    const meses = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
    ];
    return meses[fecha.month - 1];
  }

  String _etiquetaFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final fechaDia = DateTime(fecha.year, fecha.month, fecha.day);

    final diferencia = hoy.difference(fechaDia).inDays;
    if (diferencia == 0) return 'Hoy';
    if (diferencia == 1) return 'Ayer';
    if (diferencia == 2) return 'Hace 2 días';
    if (diferencia < 7) return 'Hace $diferencia días';

    final meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${fecha.day} ${meses[fecha.month - 1]}';
  }

  String _formatoFechaCompleto(DateTime fecha) {
    final diasSemana = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    final meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final nombreDia = diasSemana[fecha.weekday - 1];
    final nombreMes = meses[fecha.month - 1];
    return '$nombreDia, ${fecha.day} de $nombreMes ${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: widget.mostrarBotonVolver,
        leading: widget.mostrarBotonVolver
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.azulOscuro, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Historial y Cumplimiento',
          style: TextStyle(
            color: AppColors.azulOscuro,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.fondo,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.moradoOscuro,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.medication_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Medicamentos'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.crisis_alert_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Alertas SOS'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // Selector de Paciente (apoyo multi-paciente)
            if (_pacientes.isNotEmpty) _construirSelectorPaciente(),

            // Contenido de las pestañas
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _construirPestanaCumplimientoCronologico(),
                  _construirPestanaAlertasAtendidas(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirSelectorPaciente() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, size: 18, color: AppColors.moradoOscuro),
          const SizedBox(width: 8),
          const Text(
            'Paciente:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.azulOscuro,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pacientes.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final p = _pacientes[index];
                  final esSeleccionado = _pacienteSeleccionado?.id == p.id;
                  return ChoiceChip(
                    label: Text(p.nombre),
                    selected: esSeleccionado,
                    onSelected: (val) {
                      if (val) _cambiarPaciente(p);
                    },
                    selectedColor: AppColors.moradoOscuro,
                    backgroundColor: AppColors.fondo,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: esSeleccionado ? Colors.white : AppColors.azulOscuro,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: esSeleccionado ? AppColors.moradoOscuro : const Color(0xFFCBD5E1),
                      ),
                    ),
                    showCheckmark: false,
                    avatar: (p.foto != null && p.foto!.isNotEmpty)
                        ? CircleAvatar(
                            radius: 10,
                            backgroundImage: p.foto!.startsWith('http')
                                ? NetworkImage(p.foto!)
                                : FileImage(File(p.foto!)) as ImageProvider,
                          )
                        : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PESTAÑA 1: CUMPLIMIENTO CRONOLÓGICO (DEL MÁS NUEVO AL MÁS VIEJO)
  // ==========================================================================
  Widget _construirPestanaCumplimientoCronologico() {
    return RefreshIndicator(
      color: AppColors.moradoOscuro,
      onRefresh: () async {
        _cacheTomasPorFecha.clear();
        _cacheResumenPorFecha.clear();
        if (_fechaSeleccionada != null) {
          await _cargarTomasDeFecha(_fechaSeleccionada!, forzarRecarga: true);
        }
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: 32 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: _diasHistorial.length + 1, // +1 para el botón de calendario al final
        itemBuilder: (context, index) {
          // Último elemento: botón para buscar fechas más antiguas en el calendario
          if (index == _diasHistorial.length) {
            return _construirBotonMasFechas();
          }

          final fecha = _diasHistorial[index];
          final key = _fechaKey(fecha);
          final bool estaSeleccionada =
              _fechaSeleccionada != null && _fechaKey(_fechaSeleccionada!) == key;
          final bool estaCargando = _fechasCargando.contains(key);
          final List<TomaModel>? tomas = _cacheTomasPorFecha[key];
          final Map<String, dynamic>? resumen = _cacheResumenPorFecha[key];

          return _construirTarjetaDia(
            fecha: fecha,
            estaSeleccionada: estaSeleccionada,
            estaCargando: estaCargando,
            tomas: tomas,
            resumen: resumen,
          );
        },
      ),
    );
  }

  /// Tarjeta de cada día ordenado cronológicamente del más nuevo al más viejo
  Widget _construirTarjetaDia({
    required DateTime fecha,
    required bool estaSeleccionada,
    required bool estaCargando,
    required List<TomaModel>? tomas,
    required Map<String, dynamic>? resumen,
  }) {
    final etiqueta = _etiquetaFecha(fecha);
    final fechaCompleta = _formatoFechaCompleto(fecha);

    final int porcentaje = resumen?['porcentaje'] ?? 100;
    final int total = resumen?['total'] ?? 0;
    final int tomadas = resumen?['tomadas'] ?? 0;

    Color colorEstado = AppColors.turquesa;
    if (total == 0) {
      colorEstado = const Color(0xFF94A3B8);
    } else if (porcentaje < 50) {
      colorEstado = AppColors.terracota;
    } else if (porcentaje < 80) {
      colorEstado = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: estaSeleccionada ? AppColors.moradoOscuro : const Color(0xFFE2E8F0),
          width: estaSeleccionada ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: estaSeleccionada
                ? AppColors.moradoOscuro.withValues(alpha: 0.08)
                : AppColors.azulOscuro.withValues(alpha: 0.02),
            blurRadius: estaSeleccionada ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // Encabezado de la tarjeta (Toca para desplegar o colapsar)
            InkWell(
              onTap: () => _tocarFecha(fecha),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Icono de calendario con el día
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: estaSeleccionada
                            ? AppColors.moradoOscuro
                            : AppColors.lilaSuave.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${fecha.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                              color: estaSeleccionada ? Colors.white : AppColors.moradoOscuro,
                            ),
                          ),
                          Text(
                            _mesAbreviado(fecha),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: estaSeleccionada ? Colors.white.withValues(alpha: 0.85) : AppColors.azulOscuro,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Información de la fecha
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  fechaCompleta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.azulOscuro,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: estaSeleccionada
                                      ? AppColors.turquesa.withValues(alpha: 0.25)
                                      : AppColors.lilaSuave.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  etiqueta,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: estaSeleccionada ? const Color(0xFF1E3F38) : AppColors.moradoOscuro,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            resumen != null
                                ? (total == 0
                                    ? 'Sin dosis programadas'
                                    : '$tomadas de $total dosis tomadas')
                                : 'Presiona para ver cumplimiento',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Chip de porcentaje o flecha de expansión
                    if (resumen != null && total > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorEstado.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colorEstado.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '$porcentaje%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorEstado,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),

                    Icon(
                      estaSeleccionada
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: estaSeleccionada ? AppColors.moradoOscuro : Colors.grey[400],
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),

            // Contenido desplegable al presionar: Muestra el cumplimiento del día seleccionado
            if (estaSeleccionada) ...[
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              if (estaCargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.moradoOscuro),
                  ),
                )
              else if (tomas == null || tomas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No hubo medicamentos registrados para esta fecha.',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // Resumen métrico del día seleccionado
                _construirPanelCumplimientoDia(resumen: resumen!, colorEstado: colorEstado),

                // Lista de dosis del día
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medicamentos del Día (${tomas.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.azulOscuro,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...tomas.map(_construirFilaToma),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Panel con porcentaje y barra de progreso al abrir una fecha
  Widget _construirPanelCumplimientoDia({
    required Map<String, dynamic> resumen,
    required Color colorEstado,
  }) {
    final int total = resumen['total'] ?? 0;
    final int tomadas = resumen['tomadas'] ?? 0;
    final int omitidas = resumen['omitidas'] ?? 0;
    final int pendientes = resumen['pendientes'] ?? 0;
    final int porcentaje = resumen['porcentaje'] ?? 100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.fondo.withValues(alpha: 0.6),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$porcentaje%',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: colorEstado,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: total > 0 ? (tomadas / total) : 1.0,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(colorEstado),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$tomadas de $total dosis tomadas',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _construirIndicadorMini('Tomadas', '$tomadas', const Color(0xFF16A34A)),
              _construirIndicadorMini('Omitidas', '$omitidas', AppColors.terracota),
              _construirIndicadorMini('Pendientes', '$pendientes', const Color(0xFFD97706)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirIndicadorMini(String label, String valor, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        Text(
          valor,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  /// Fila de cada medicamento dentro del día expandido
  Widget _construirFilaToma(TomaModel toma) {
    final bool esTomada = toma.esTomada;
    final bool esOmitida = toma.estado.toLowerCase() == 'omitida';

    Color colorEstado = esTomada
        ? const Color(0xFF16A34A)
        : (esOmitida ? AppColors.terracota : const Color(0xFFD97706));

    Color fondoEstado = esTomada
        ? const Color(0xFFDCFCE7)
        : (esOmitida ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7));

    String textoEstado = esTomada
        ? (toma.horaConfirmadaLegible != null
            ? 'Tomada a las ${toma.horaConfirmadaLegible}'
            : 'Tomada')
        : (esOmitida ? 'Omitida' : 'Pendiente');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.lilaSuave.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medication_rounded, size: 18, color: AppColors.moradoOscuro),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  toma.medicamento,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.azulOscuro,
                  ),
                ),
                Text(
                  '${toma.dosis} • Prog: ${toma.horaProgramada}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: fondoEstado,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              textoEstado,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colorEstado,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Botón inferior para seleccionar cualquier otra fecha del calendario
  Widget _construirBotonMasFechas() {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 20),
      child: Center(
        child: TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.moradoOscuro,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          onPressed: _seleccionarFechaCalendario,
          icon: const Icon(Icons.calendar_month_rounded, size: 18),
          label: const Text(
            'Consultar fecha anterior en el calendario',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // PESTAÑA 2: REGISTRO DE ALERTAS SOS ATENDIDAS (DEL MÁS NUEVO AL MÁS VIEJO)
  // ==========================================================================
  Widget _construirPestanaAlertasAtendidas() {
    return RefreshIndicator(
      color: AppColors.moradoOscuro,
      onRefresh: () async {
        await _cargarAlertasAtendidas();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 32 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner informativo de emergencias atendidas
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Historial de Auxilio SOS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF14532D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Alertas atendidas y resueltas ordenadas de la más reciente a la más antigua.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Encabezado de la lista
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Alertas Atendidas (${_alertasAtendidas.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.azulOscuro,
                  ),
                ),
                if (_alertasAtendidas.isNotEmpty)
                  const Text(
                    'Más reciente a más antigua',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (_cargandoAlertas)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.moradoOscuro),
                ),
              )
            else if (_alertasAtendidas.isEmpty)
              _construirEmptyStateAlertas()
            else
              ..._alertasAtendidas.map(_construirTarjetaAlertaAtendida),
          ],
        ),
      ),
    );
  }

  Widget _construirTarjetaAlertaAtendida(AlertaSosModel alerta) {
    final localTime = alerta.fechaCreacion.toLocal();
    final fechaLegible =
        '${localTime.day}/${localTime.month}/${localTime.year} a las ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    final bool tieneGps = alerta.latitud != null && alerta.longitud != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.azulOscuro.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.terracota.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.crisis_alert_rounded, color: AppColors.terracota, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alerta.nombrePaciente ?? 'Paciente',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.azulOscuro,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Emitida: $fechaLegible',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text(
                      'Atendida',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (tieneGps) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.fondo,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: AppColors.terracota),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'GPS: ${alerta.latitud!.toStringAsFixed(4)}, ${alerta.longitud!.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: AppColors.azulOscuro,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      final url = alerta.enlaceGoogleMaps;
                      if (url != null) {
                        AlarmasNativasService.abrirEnlace(url);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.moradoOscuro,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_rounded, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Ver mapa',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirEmptyStateAlertas() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.health_and_safety_rounded, size: 40, color: Color(0xFF16A34A)),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sin emergencias atendidas',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.azulOscuro,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No hay registros de alertas SOS atendidas para este paciente. ¡Todo en orden!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
