import 'package:flutter/material.dart';
import 'package:vital_bridge/screens/alarma_screen.dart';
import 'package:vital_bridge/screens/alerta_sos_cuidador_screen.dart';
import 'package:vital_bridge/screens/horario_screen.dart';
import 'package:vital_bridge/screens/tratamientos_screen.dart';

class PacienteScreen extends StatelessWidget {
  const PacienteScreen({super.key});

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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('🚨 ¡Alerta SOS enviada con éxito a tus contactos de emergencia!'),
                  backgroundColor: const Color(0xFFE25C54),
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'Ver alerta cuidador',
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AlertaSosCuidadorScreen(),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            child: const Text('Enviar SOS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2), // Fondo suave crema
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado superior: Saludo, Fecha y Botón de Calendario
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                            color: const Color(0xFF2C324E),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '¡Buenos días, Miguel Angel!',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C324E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Padding(
                        padding: EdgeInsets.only(left: 26.0),
                        child: Text(
                          'lunes, 22 de septiembre',
                          style: TextStyle(
                            fontSize: 14.5,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Botón de calendario
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
                      icon: const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF453E60),
                        size: 22,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const HorarioMedicamentosScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Pregunta principal central
              const Text(
                '¿Ya tomaste tus\nmedicinas?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222845),
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 28),

              // Tarjeta 1: Próxima Alarma (Morada oscura) - SOLO INFORMATIVA / VISUAL
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
                        const Text(
                          '1 tableta',
                          style: TextStyle(
                            color: Color(0xFFB5ADC8),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Nombre de la medicina
                    const Text(
                      'Paracetamol (Medicina A)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Hora en grande
                    const Text(
                      '8:00 AM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Indicaciones
                    const Text(
                      'Después del desayuno • Con agua',
                      style: TextStyle(
                        color: Color(0xFFB5ADC8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Tarjeta 2: Alerta SOS (Roja Coral / Terracota) - BOTÓN DE ACCIÓN
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _mostrarDialogoSOS(context),
                  child: Container(
                    height: 250,
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
                          // Ícono de sirena / luz de emergencia
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.crisis_alert_rounded,
                              size: 56,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Texto Alerta SOS
                          const Text(
                            'Alerta SOS',
                            style: TextStyle(
                              fontSize: 34,
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

              // Botón para que el paciente visualice sus medicamentos (solo lectura)
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TratamientosScreen(
                        esModoCuidador: false, // Modo paciente: sin botones de editar ni eliminar
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.medication_liquid_rounded, color: Color(0xFF5E5482)),
                label: const Text(
                  '📋 Ver mis medicamentos asignados',
                  style: TextStyle(
                    color: Color(0xFF5E5482),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Botón de prueba para simular la llegada de la alarma
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AlarmaMedicamentoScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.alarm_on_rounded, color: Color(0xFF5E5482)),
                label: const Text(
                  '🔔 Probar pantalla de Alarma (8:00 AM)',
                  style: TextStyle(
                    color: Color(0xFF5E5482),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
