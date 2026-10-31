import 'package:flutter/material.dart';
import 'package:vital_bridge/models/tratamiento_model.dart';
import 'package:vital_bridge/screens/agregar_medicamento_screen.dart';
import 'package:vital_bridge/services/pacientes_service.dart';
import 'package:vital_bridge/services/tratamientos_service.dart';
import 'package:vital_bridge/theme/app_colors.dart';

class TratamientosScreen extends StatefulWidget {
  final bool mostrarBotonVolver;
  final bool esModoCuidador;
  final String? pacienteId;
  final String? nombrePaciente;

  const TratamientosScreen({
    super.key,
    this.mostrarBotonVolver = true,
    this.esModoCuidador = true,
    this.pacienteId,
    this.nombrePaciente,
  });

  @override
  State<TratamientosScreen> createState() => _TratamientosScreenState();
}

class _TratamientosScreenState extends State<TratamientosScreen> {
  String _busqueda = '';
  bool _cargando = true;
  String? _pacienteIdActual;
  String? _nombrePacienteActual;

  List<TratamientoModel> _tratamientos = [];

  @override
  void initState() {
    super.initState();
    _pacienteIdActual = widget.pacienteId;
    _nombrePacienteActual = widget.nombrePaciente;
    _cargarTratamientos();
  }

  @override
  void didUpdateWidget(covariant TratamientosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pacienteId != widget.pacienteId) {
      _pacienteIdActual = widget.pacienteId;
      _nombrePacienteActual = widget.nombrePaciente;
      _cargarTratamientos();
    }
  }

  Future<void> _cargarTratamientos() async {
    setState(() => _cargando = true);

    try {
      // Si no se proporcionó pacienteId, obtener el primer paciente activo del cuidador
      if (_pacienteIdActual == null || _pacienteIdActual!.isEmpty) {
        final pacientes = await PacientesService.obtenerPacientes();
        if (pacientes.isNotEmpty) {
          _pacienteIdActual = pacientes.first.id;
          _nombrePacienteActual = pacientes.first.nombre;
        }
      }

      final lista = await TratamientosService.obtenerTratamientos(
        pacienteId: _pacienteIdActual,
      );

      if (mounted) {
        setState(() {
          _tratamientos = lista;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  IconData _obtenerIcono(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('cápsula') || t.contains('capsula')) return Icons.medication_liquid_rounded;
    if (t.contains('jarabe')) return Icons.vaccines_rounded;
    if (t.contains('gota')) return Icons.water_drop_outlined;
    if (t.contains('inyecc')) return Icons.healing_rounded;
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
              final exito = await TratamientosService.eliminarTratamiento(item.id);
              if (exito) {
                await _cargarTratamientos();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🗑️ $nombre ha sido finalizado del tratamiento.'),
                      backgroundColor: AppColors.azulOscuro,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirEditarTratamiento(TratamientoModel item) async {
    final editado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AgregarMedicamentoScreen(
          idPaciente: _pacienteIdActual ?? item.idPaciente,
          nombrePaciente: _nombrePacienteActual,
          tratamientoParaEditar: item,
        ),
      ),
    );

    if (editado == true) {
      await _cargarTratamientos();
    }
  }

  void _editarIndicacionesRapidas(TratamientoModel item) {
    final TextEditingController dosisCtrl = TextEditingController(text: item.cantidad.toString());
    final TextEditingController indicacionesCtrl = TextEditingController(text: item.indicaciones ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppColors.moradoOscuro, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Editar ${item.medicamento}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.azulOscuro),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dosis / Cantidad:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.azulOscuro)),
              const SizedBox(height: 6),
              TextField(
                controller: dosisCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.fondo,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Indicaciones de toma:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.azulOscuro)),
              const SizedBox(height: 6),
              TextField(
                controller: indicacionesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.fondo,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.moradoOscuro,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final actualizado = item.copyWith(
                cantidad: double.tryParse(dosisCtrl.text.trim()) ?? item.cantidad,
                indicaciones: indicacionesCtrl.text.trim(),
              );

              final res = await TratamientosService.actualizarTratamiento(actualizado);
              if (res['exito'] == true) {
                await _cargarTratamientos();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Indicaciones de ${item.medicamento} actualizadas.'),
                      backgroundColor: const Color(0xFF336C60),
                    ),
                  );
                }
              }
            },
            child: const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: Text(
          widget.esModoCuidador ? 'Tratamientos Asignados' : 'Mis Medicamentos',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.azulOscuro,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: widget.mostrarBotonVolver
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: [
          if (widget.esModoCuidador)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.moradoOscuro, size: 26),
              tooltip: 'Nuevo Medicamento',
              onPressed: () async {
                final agregado = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => AgregarMedicamentoScreen(
                      idPaciente: _pacienteIdActual,
                      nombrePaciente: _nombrePacienteActual,
                    ),
                  ),
                );
                if (agregado == true) {
                  await _cargarTratamientos();
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.moradoOscuro,
          onRefresh: _cargarTratamientos,
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
                      '${_tratamientos.length} Medicamentos configurados',
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
                      child: Text(
                        _cargando ? 'Sincronizando...' : 'Sincronizado',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3F38),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Estado de carga o Lista de Tarjetas
                if (_cargando)
                  Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      color: AppColors.moradoOscuro,
                    ),
                  )
                else if (tratamientosFiltrados.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        _busqueda.isNotEmpty
                            ? 'No se encontraron medicamentos con ese nombre.'
                            : 'No hay medicamentos configurados para este paciente.',
                        style: const TextStyle(color: Colors.grey, fontSize: 15),
                        textAlign: TextAlign.center,
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
                      final icono = _obtenerIcono(item.presentacion);
                      final duracionTexto = item.fechaFinal == null
                          ? 'Continuo'
                          : 'Hasta ${item.fechaFinal!.day}/${item.fechaFinal!.month}/${item.fechaFinal!.year}';

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
                            // Cabecera: Ícono + Nombre + Botones Acción (Editar / Eliminar)
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
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.dosisLegible} • ${item.frecuencia} ($duracionTexto)',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                if (widget.esModoCuidador) ...[
                                  // Botón Editar completo / formulario
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.moradoOscuro),
                                    tooltip: 'Editar medicamento',
                                    onPressed: () => _abrirEditarTratamiento(item),
                                  ),

                                  // Botón Eliminar (Soft Delete)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.terracota),
                                    tooltip: 'Eliminar medicina',
                                    onPressed: () => _eliminarTratamiento(item),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 12),

                            // Fila de Horarios programados
                            const Text(
                              'Horarios de Alarma:',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (item.horarios.isEmpty)
                              const Text(
                                'Sin horarios configurados',
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              )
                            else
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

                            // Indicaciones de consumo
                            if (item.indicaciones != null && item.indicaciones!.isNotEmpty)
                              InkWell(
                                onTap: widget.esModoCuidador ? () => _editarIndicacionesRapidas(item) : null,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
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
                                      if (widget.esModoCuidador)
                                        const Icon(Icons.edit_note_rounded, size: 16, color: AppColors.moradoOscuro),
                                    ],
                                  ),
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
