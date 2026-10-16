import 'package:flutter/material.dart';
import 'package:vital_bridge/screens/paciente_screen.dart';

class HorarioMedicamentosScreen extends StatefulWidget {
  const HorarioMedicamentosScreen({super.key});

  @override
  State<HorarioMedicamentosScreen> createState() => _HorarioMedicamentosScreenState();
}

class _HorarioMedicamentosScreenState extends State<HorarioMedicamentosScreen> {
  // Lista de tomas del día para el adulto mayor
  final List<Map<String, dynamic>> _medicamentos = [
    {
      'hora': '8:00 AM',
      'momento': 'Mañana (Desayuno)',
      'nombre': 'Paracetamol',
      'dosis': '1 tableta (500 mg)',
      'indicacion': 'Tomar con el desayuno y agua',
      'tomada': true,
      'esProxima': false,
      'colorIcono': const Color(0xFF7CD4C2),
    },
    {
      'hora': '2:00 PM',
      'momento': 'Tarde (Comida)',
      'nombre': 'Omeprazol',
      'dosis': '1 cápsula (20 mg)',
      'indicacion': '30 minutos antes de almorzar',
      'tomada': false,
      'esProxima': true,
      'colorIcono': const Color(0xFF5E5482),
    },
    {
      'hora': '9:00 PM',
      'momento': 'Noche (Cena / Dormir)',
      'nombre': 'Losartán',
      'dosis': '1 tableta (50 mg)',
      'indicacion': 'Antes de acostarse con un vaso de agua',
      'tomada': false,
      'esProxima': false,
      'colorIcono': const Color(0xFFD27A7A),
    },
  ];

  int _diaSeleccionado = 1; // 1 = Hoy (Lunes)

  final List<String> _diasSemana = [
    'Ayer\nDom 21',
    'HOY\nLun 22',
    'Mañana\nMar 23',
    'Mié 24',
    'Jue 25',
  ];

  void _cambiarEstadoToma(int index) {
    setState(() {
      _medicamentos[index]['tomada'] = !_medicamentos[index]['tomada'];
    });

    final bool estadoActual = _medicamentos[index]['tomada'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          estadoActual
              ? '✅ ${datos['nombre']} marcado como tomado.'
              : '↩️ ${_medicamentos[index]['nombre']} marcado como pendiente.',
          style: const TextStyle(fontSize: 16),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: estadoActual ? const Color(0xFF336C60) : const Color(0xFF5E5482),
      ),
    );
  }

  Map<String, dynamic> get datos => _medicamentos[0];

  @override
  Widget build(BuildContext context) {
    int totalTomas = _medicamentos.length;
    int tomasCompletadas = _medicamentos.where((m) => m['tomada'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2), // Fondo suave crema
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior accesible con botón de regreso grande
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
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
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 22, color: Color(0xFF2C324E)),
                          SizedBox(width: 6),
                          Text(
                            'Volver',
                            style: TextStyle(
                              fontSize: 16,
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

            // Contenido con scroll
            Expanded(
              child: SingleChildScrollView(
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
                    const Text(
                      'Lunes, 22 de Septiembre',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Selector de días grande y claro
                    SizedBox(
                      height: 65,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _diasSemana.length,
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
                                    _diasSemana[index],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
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
                        color: const Color(0xFFE8F7F3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF7CD4C2), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFF7CD4C2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.fact_check_rounded,
                              color: Color(0xFF1E3F38),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Progreso: $tomasCompletadas de $totalTomas pastillas tomadas',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3F38),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tomasCompletadas == totalTomas
                                      ? '¡Excelente! Terminaste tus tomas de hoy'
                                      : 'Tu próxima medicina es a las 2:00 PM',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF2C5E53),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Horario por horas:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Lista de tarjetas de medicamentos
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _medicamentos.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final med = _medicamentos[index];
                        final bool tomada = med['tomada'];
                        final bool esProxima = med['esProxima'];

                        return Container(
                          decoration: BoxDecoration(
                            color: esProxima
                                ? const Color(0xFF453E60) // Morado destacado para la próxima
                                : Colors.white,
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
                              // Fila 1: Hora en muy grande y etiqueta de estado
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
                                            : const Color(0xFF5E5482),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        med['hora'],
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

                                  // Botón grande interactivo para marcar como tomada
                                  InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => _cambiarEstadoToma(index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: tomada
                                            ? const Color(0xFF7CD4C2)
                                            : (esProxima
                                                ? const Color(0xFF5A527A)
                                                : const Color(0xFFF1F5F9)),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: tomada
                                              ? const Color(0xFF336C60)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            tomada
                                                ? Icons.check_circle_rounded
                                                : Icons.radio_button_unchecked_rounded,
                                            size: 18,
                                            color: tomada
                                                ? const Color(0xFF1E3F38)
                                                : (esProxima
                                                    ? Colors.white
                                                    : const Color(0xFF475569)),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            tomada ? 'Tomada' : 'Marcar',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: tomada
                                                  ? const Color(0xFF1E3F38)
                                                  : (esProxima
                                                      ? Colors.white
                                                      : const Color(0xFF475569)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Momento del día (ej. Mañana / Desayuno)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: esProxima
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : const Color(0xFFF4F6F8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  med['momento'],
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
                                med['nombre'],
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: esProxima ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                med['dosis'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: esProxima
                                      ? const Color(0xFFB5ADC8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Indicaciones claras (con qué tomarla)
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
                                      med['indicacion'],
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
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
