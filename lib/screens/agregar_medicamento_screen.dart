import 'package:flutter/material.dart';
import 'package:vital_bridge/theme/app_colors.dart';

class AgregarMedicamentoScreen extends StatefulWidget {
  const AgregarMedicamentoScreen({super.key});

  @override
  State<AgregarMedicamentoScreen> createState() => _AgregarMedicamentoScreenState();
}

class _AgregarMedicamentoScreenState extends State<AgregarMedicamentoScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _dosisController = TextEditingController();
  final TextEditingController _indicacionesController = TextEditingController();

  // Tipo de presentación seleccionada
  String _tipoSeleccionado = 'Tableta';
  final List<Map<String, dynamic>> _tipos = [
    {'nombre': 'Tableta', 'icono': Icons.medication_rounded},
    {'nombre': 'Cápsula', 'icono': Icons.medication_liquid_rounded},
    {'nombre': 'Jarabe', 'icono': Icons.vaccines_rounded},
    {'nombre': 'Gotas', 'icono': Icons.water_drop_outlined},
    {'nombre': 'Inyección', 'icono': Icons.healing_rounded},
  ];

  // Horarios de toma programados
  final List<TimeOfDay> _horarios = [
    const TimeOfDay(hour: 8, minute: 0),
    const TimeOfDay(hour: 20, minute: 0),
  ];

  // Días de la semana en que se toma
  bool _todosLosDias = true;
  final Map<String, bool> _diasSemana = {
    'Lun': true,
    'Mar': true,
    'Mié': true,
    'Jue': true,
    'Vie': true,
    'Sáb': true,
    'Dom': true,
  };

  // Duración del tratamiento
  bool _esDePorVida = true;
  String _duracionSeleccionada = '7 días';
  DateTime? _fechaFinPersonalizada;

  final List<String> _opcionesDuracion = [
    '7 días',
    '14 días',
    '1 mes',
    'Fecha específica',
  ];

  // Indicaciones rápidas seleccionables
  String _momentoComida = 'Después de comer';
  final List<String> _opcionesComida = [
    'Con el desayuno',
    'Antes de comer',
    'Después de comer',
    'En ayunas',
    'Antes de dormir',
  ];

  @override
  void dispose() {
    _nombreController.dispose();
    _dosisController.dispose();
    _indicacionesController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarHora(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _horarios[index],
    );
    if (picked != null) {
      setState(() {
        _horarios[index] = picked;
      });
    }
  }

  Future<void> _agregarHora() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 14, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _horarios.add(picked);
      });
    }
  }

  void _eliminarHora(int index) {
    if (_horarios.length > 1) {
      setState(() {
        _horarios.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe haber al menos un horario de toma.')),
      );
    }
  }

  Future<void> _seleccionarFechaFin() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _fechaFinPersonalizada = picked;
        _duracionSeleccionada = 'Fecha específica';
      });
    }
  }

  String _formatearHora(TimeOfDay time) {
    final int hora = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final String minuto = time.minute.toString().padLeft(2, '0');
    final String periodo = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hora:$minuto $periodo';
  }

  String _resumenDias() {
    if (_todosLosDias) return 'Todos los días';
    final activos = _diasSemana.entries.where((e) => e.value).map((e) => e.key).toList();
    if (activos.isEmpty) return 'Ningún día seleccionado';
    if (activos.length == 7) return 'Todos los días';
    return activos.join(', ');
  }

  void _guardarMedicamento() {
    if (_formKey.currentState!.validate()) {
      if (!_todosLosDias && !_diasSemana.containsValue(true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Por favor selecciona al menos un día de la semana para la toma.'),
            backgroundColor: AppColors.terracota,
          ),
        );
        return;
      }

      final String dias = _resumenDias();
      final String vigencia = _esDePorVida
          ? 'Tratamiento continuo'
          : (_duracionSeleccionada == 'Fecha específica' && _fechaFinPersonalizada != null
              ? 'Hasta ${_fechaFinPersonalizada!.day}/${_fechaFinPersonalizada!.month}/${_fechaFinPersonalizada!.year}'
              : 'Por $_duracionSeleccionada');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ¡${_nombreController.text} guardado!\nProgramado: $dias ($vigencia)',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF336C60),
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.of(context).maybePop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.azulOscuro,
        title: const Text(
          'Nuevo Medicamento',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.azulOscuro,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner superior de contexto
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lilaSuave.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.lilaSuave.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.person_pin_rounded, color: AppColors.moradoOscuro, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asignar a: Miguel Angel Ramos',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.azulOscuro,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Los horarios se sincronizarán de inmediato en el teléfono de tu familiar.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.azulOscuro,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sección 1: Nombre del Medicamento
                const Text(
                  'Nombre del Medicamento *',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.azulOscuro,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nombreController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa el nombre de la medicina';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Ej. Paracetamol, Losartán, Omeprazol',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                const SizedBox(height: 22),

                // Sección 2: Presentación
                const Text(
                  'Tipo de Presentación',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.azulOscuro,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tipos.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final tipo = _tipos[index];
                      final bool esSeleccionado = tipo['nombre'] == _tipoSeleccionado;

                      return ChoiceChip(
                        selected: esSeleccionado,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _tipoSeleccionado = tipo['nombre'];
                            });
                          }
                        },
                        avatar: Icon(
                          tipo['icono'],
                          size: 18,
                          color: esSeleccionado ? Colors.white : AppColors.moradoOscuro,
                        ),
                        label: Text(tipo['nombre']),
                        selectedColor: AppColors.moradoOscuro,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: esSeleccionado ? Colors.white : AppColors.azulOscuro,
                          fontWeight: esSeleccionado ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: esSeleccionado ? AppColors.moradoOscuro : const Color(0xFFE2E8F0),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 22),

                // Sección 3: Dosis por toma
                const Text(
                  'Dosis por Toma *',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.azulOscuro,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dosisController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor especifica la dosis (ej. 1 tableta, 500 mg)';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Ej. 1 tableta (500 mg), 10 ml, 2 gotas',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                const SizedBox(height: 24),

                // Sección 4: Horarios de Alarma
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Horarios de Alarma',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.azulOscuro,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _agregarHora,
                      icon: const Icon(Icons.add_alarm_rounded, size: 18, color: AppColors.moradoOscuro),
                      label: const Text(
                        'Añadir Hora',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.moradoOscuro),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(_horarios.length, (index) {
                    final time = _horarios[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.moradoOscuro.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 18, color: AppColors.moradoOscuro),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _seleccionarHora(index),
                            child: Text(
                              _formatearHora(time),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.azulOscuro,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _eliminarHora(index),
                            child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 26),

                // ==========================================
                // NUEVA SECCIÓN: Días en que le toca la toma
                // ==========================================
                const Text(
                  '¿Qué días le toca la toma? *',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.azulOscuro,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ChoiceChip(
                      selected: _todosLosDias,
                      onSelected: (val) {
                        setState(() {
                          _todosLosDias = true;
                          _diasSemana.updateAll((key, value) => true);
                        });
                      },
                      label: const Text('Todos los días'),
                      selectedColor: AppColors.moradoOscuro,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: _todosLosDias ? Colors.white : AppColors.azulOscuro,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: _todosLosDias ? AppColors.moradoOscuro : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      selected: !_todosLosDias,
                      onSelected: (val) {
                        setState(() {
                          _todosLosDias = false;
                        });
                      },
                      label: const Text('Días específicos'),
                      selectedColor: AppColors.moradoOscuro,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: !_todosLosDias ? Colors.white : AppColors.azulOscuro,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: !_todosLosDias ? AppColors.moradoOscuro : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Círculos interactivos de los 7 días de la semana
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _diasSemana.keys.map((dia) {
                      final bool activo = _diasSemana[dia]!;
                      return InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          setState(() {
                            _diasSemana[dia] = !_diasSemana[dia]!;
                            // Si se desmarca alguno, ya no son "todos los días"
                            if (_diasSemana.containsValue(false)) {
                              _todosLosDias = false;
                            } else {
                              _todosLosDias = true;
                            }
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: activo ? AppColors.turquesa : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: activo ? const Color(0xFF336C60) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              dia,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: activo ? const Color(0xFF1E3F38) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 26),

                // ==========================================
                // NUEVA SECCIÓN: Duración del tratamiento
                // ==========================================
                const Text(
                  'Duración del Tratamiento *',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.azulOscuro,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ChoiceChip(
                      selected: _esDePorVida,
                      onSelected: (val) {
                        setState(() {
                          _esDePorVida = true;
                        });
                      },
                      label: const Text('De por vida / Continuo'),
                      selectedColor: AppColors.moradoOscuro,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: _esDePorVida ? Colors.white : AppColors.azulOscuro,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: _esDePorVida ? AppColors.moradoOscuro : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      selected: !_esDePorVida,
                      onSelected: (val) {
                        setState(() {
                          _esDePorVida = false;
                        });
                      },
                      label: const Text('Periodo definido'),
                      selectedColor: AppColors.moradoOscuro,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: !_esDePorVida ? Colors.white : AppColors.azulOscuro,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: !_esDePorVida ? AppColors.moradoOscuro : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ],
                ),

                // Si es por periodo definido, muestra las opciones de duración
                if (!_esDePorVida) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _opcionesDuracion.map((duracion) {
                      final bool seleccionada = duracion == _duracionSeleccionada;
                      return ChoiceChip(
                        selected: seleccionada,
                        onSelected: (val) {
                          if (duracion == 'Fecha específica') {
                            _seleccionarFechaFin();
                          } else {
                            setState(() {
                              _duracionSeleccionada = duracion;
                              _fechaFinPersonalizada = null;
                            });
                          }
                        },
                        label: Text(
                          duracion == 'Fecha específica' && _fechaFinPersonalizada != null
                              ? 'Hasta ${_fechaFinPersonalizada!.day}/${_fechaFinPersonalizada!.month}/${_fechaFinPersonalizada!.year}'
                              : duracion,
                        ),
                        selectedColor: AppColors.lilaSuave,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: seleccionada ? AppColors.azulOscuro : const Color(0xFF475569),
                          fontWeight: seleccionada ? FontWeight.bold : FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: seleccionada ? AppColors.moradoOscuro : const Color(0xFFE2E8F0),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 26),

                // Sección 5: Indicación con la comida
                const Text(
                  'Instrucciones de Consumo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.azulOscuro,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _opcionesComida.map((opcion) {
                    final bool seleccionada = opcion == _momentoComida;
                    return ChoiceChip(
                      selected: seleccionada,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _momentoComida = opcion;
                          });
                        }
                      },
                      label: Text(opcion),
                      selectedColor: AppColors.turquesa,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: seleccionada ? const Color(0xFF1E3F38) : AppColors.azulOscuro,
                        fontWeight: seleccionada ? FontWeight.bold : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: seleccionada ? AppColors.turquesa : const Color(0xFFE2E8F0),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Notas adicionales
                TextFormField(
                  controller: _indicacionesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Notas adicionales (ej. Con medio vaso de agua, no tomar leche)',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                const SizedBox(height: 34),

                // Botón Guardar Tratamiento
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.turquesa,
                    foregroundColor: const Color(0xFF1E3F38),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _guardarMedicamento,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 22, color: Color(0xFF1E3F38)),
                      SizedBox(width: 8),
                      Text(
                        'Guardar Medicamento',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Botón Cancelar
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
