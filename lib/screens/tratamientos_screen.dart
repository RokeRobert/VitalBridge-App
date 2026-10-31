import 'package:flutter/material.dart';
import 'package:vital_bridge/models/tratamiento_model.dart';
import 'package:vital_bridge/screens/agregar_medicamento_screen.dart';
import 'package:vital_bridge/services/auth_service.dart';
import 'package:vital_bridge/services/tratamientos_service.dart';
import 'package:vital_bridge/theme/app_colors.dart';

class TratamientosScreen extends StatefulWidget {
  final bool mostrarBotonVolver;
  final bool esModoCuidador;
  final String? pacienteId;

  const TratamientosScreen({
    super.key,
    this.mostrarBotonVolver = true,
    this.esModoCuidador = true,
    this.pacienteId,
  });

  @override
  State<TratamientosScreen> createState() => _TratamientosScreenState();
}

class _TratamientosScreenState extends State<TratamientosScreen> {
  String _busqueda = '';
  bool _cargando = true;
  List<TratamientoModel> _tratamientos = [];
  String? _idPacienteActual;

  @override
  void initState() {
    super.initState();
    _inicializarYCargar();
  }

  Future<void> _inicializarYCargar() async {
    _idPacienteActual = widget.pacienteId ?? await AuthService.obtenerUsuarioId();
    await _cargarTratamientos();
  }

  Future<void> _cargarTratamientos() async {
    setState(() => _cargando = true);

    try {
      final lista = await TratamientosService.obtenerTratamientos(
        pacienteId: _idPacienteActual,
      );

      // Agrupar para asegurar que cada medicamento se muestre UNA SOLA VEZ
      // (es una lista de medicamentos que toma el paciente, no de alarmas individuales)
      final Map<String, TratamientoModel> medicamentosUnicos = {};

      for (var t in lista) {
        final clave = t.medicamento.trim().toLowerCase();
        if (!medicamentosUnicos.containsKey(clave)) {
          medicamentosUnicos[clave] = t;
        } else {
          final existente = medicamentosUnicos[clave]!;
          // Unir horarios sin duplicados si venían en registros separados
          final horariosUnicos = <String>{...existente.horarios, ...t.horarios}.toList();
          medicamentosUnicos[clave] = TratamientoModel(
            id: existente.id,
            idPaciente: existente.idPaciente,
            idUsuario: existente.idUsuario,
            medicamento: existente.medicamento,
            cantidad: existente.cantidad,
            unidadMedida: existente.unidadMedida,
            idUnidadMedida: existente.idUnidadMedida,
            frecuencia: existente.frecuencia,
            fechaInicio: existente.fechaInicio,
            fechaFinal: existente.fechaFinal,
            indicaciones: (existente.indicaciones != null && existente.indicaciones!.isNotEmpty)
                ? existente.indicaciones
                : t.indicaciones,
            activo: existente.activo,
            horarios: horariosUnicos,
            presentacion: existente.presentacion,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _tratamientos = medicamentosUnicos.values.toList();
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  IconData _obtenerIconoPresentacion(String presentacion) {
    final p = presentacion.toLowerCase();
    if (p.contains('cápsula') || p.contains('capsula')) {
      return Icons.medication_liquid_rounded;
    } else if (p.contains('jarabe') || p.contains('líquido') || p.contains('liquido') || p.contains('gota')) {
      return Icons.water_drop_outlined;
    } else if (p.contains('inyecc') || p.contains('ampolleta')) {
      return Icons.vaccines_rounded;
    }
    return Icons.medication_rounded;
  }

  void _eliminarTratamiento(TratamientoModel item) {
    final String nombre = item.medicamento;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.terracota.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.terracota, size: 24),
            ),
            const SizedBox(width: 10),
            const Text(
              'Eliminar Medicina',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.azulOscuro),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar $nombre del tratamiento? Las alarmas programadas se cancelarán en el teléfono del paciente.',
          style: const TextStyle(fontSize: 14.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracota,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await TratamientosService.eliminarTratamiento(item.id);
              _cargarTratamientos();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🗑️ $nombre ha sido eliminado del tratamiento.'),
                  backgroundColor: AppColors.azulOscuro,
                ),
              );
            },
            child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tratamientosFiltrados = _tratamientos.where((t) {
      final nombre = t.medicamento.toLowerCase();
      return nombre.contains(_busqueda.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.azulOscuro,
        leading: widget.mostrarBotonVolver
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.azulOscuro),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: Text(
          widget.esModoCuidador ? 'Tratamientos Asignados' : 'Mis Medicamentos',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.azulOscuro,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.esModoCuidador)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.moradoOscuro, size: 26),
              tooltip: 'Nuevo Medicamento',
              onPressed: () async {
                final resultado = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AgregarMedicamentoScreen()),
                );
                if (resultado == true) {
                  _cargarTratamientos();
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarTratamientos,
          color: AppColors.moradoOscuro,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.esModoCuidador)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.turquesa.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.turquesa.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Color(0xFF1E3F38), size: 24),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tus medicamentos están protegidos. Solo tu cuidador o médico puede modificarlos.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3F38),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Barra de búsqueda rápida
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _busqueda = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar medicina por nombre...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.moradoOscuro),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.moradoOscuro, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Contador de tratamientos activos
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_tratamientos.length} Medicamentos asignados',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.azulOscuro,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.turquesa.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Activo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3F38),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Lista de Tarjetas de Medicamentos
                if (_cargando)
                  Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.moradoOscuro),
                        SizedBox(height: 14),
                        Text(
                          'Cargando tus medicamentos...',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 14.5),
                        ),
                      ],
                    ),
                  )
                else if (tratamientosFiltrados.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Text(
                        _busqueda.isEmpty
                            ? 'No tienes medicamentos registrados actualmente.'
                            : 'No se encontraron medicamentos con ese nombre.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tratamientosFiltrados.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final item = tratamientosFiltrados[index];
                      final icono = _obtenerIconoPresentacion(item.presentacion);

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.azulOscuro.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cabecera: Ícono + Nombre + Dosis
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.moradoOscuro.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    icono,
                                    color: AppColors.moradoOscuro,
                                    size: 26,
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
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.azulOscuro,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${item.dosisLegible} • ${item.frecuencia}',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                if (widget.esModoCuidador)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 22, color: AppColors.terracota),
                                    tooltip: 'Eliminar medicina',
                                    onPressed: () => _eliminarTratamiento(item),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 12),

                            // Horarios programados para este medicamento
                            if (item.horarios.isNotEmpty) ...[
                              const Text(
                                'Horarios de toma durante el día:',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: item.horarios.map((hora) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.lilaSuave.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.alarm_rounded, size: 14, color: AppColors.moradoOscuro),
                                        const SizedBox(width: 5),
                                        Text(
                                          hora,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.moradoOscuro,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Indicaciones médicas
                            if (item.indicaciones != null && item.indicaciones!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.fondo,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF336C60)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.indicaciones!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF334155),
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
    );
  }
}
