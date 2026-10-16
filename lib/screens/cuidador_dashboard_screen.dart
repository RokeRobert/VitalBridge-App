import 'package:flutter/material.dart';
import 'package:vital_bridge/screens/agregar_medicamento_screen.dart';
import 'package:vital_bridge/screens/alerta_sos_cuidador_screen.dart';
import 'package:vital_bridge/screens/login_screen.dart';
import 'package:vital_bridge/screens/perfil_cuidador_screen.dart';
import 'package:vital_bridge/screens/perfil_paciente_screen.dart';
import 'package:vital_bridge/screens/tratamientos_screen.dart';
import 'package:vital_bridge/theme/app_colors.dart';

class CuidadorDashboardScreen extends StatefulWidget {
  const CuidadorDashboardScreen({super.key});

  @override
  State<CuidadorDashboardScreen> createState() => _CuidadorDashboardScreenState();
}

class _CuidadorDashboardScreenState extends State<CuidadorDashboardScreen> {
  int _tabSeleccionado = 0;

  // Datos simulados del paciente supervisado
  final String _nombrePaciente = 'Roberto Gómez';
  final String _parentesco = 'Familiar a cargo (Padre)';
  final int _bateriaPaciente = 84;
  final String _ultimaConexion = 'Hace 3 minutos';

  // Lista de tratamientos del día supervisados
  final List<Map<String, dynamic>> _seguimientoHoy = [
    {
      'hora': '8:00 AM',
      'medicamento': 'Paracetamol',
      'dosis': '1 tableta (500 mg)',
      'estado': 'Tomada',
      'horaConfirmada': '8:03 AM',
      'esAlerta': false,
    },
    {
      'hora': '2:00 PM',
      'medicamento': 'Omeprazol',
      'dosis': '1 cápsula (20 mg)',
      'estado': 'Próxima',
      'horaConfirmada': null,
      'esAlerta': false,
    },
    {
      'hora': '9:00 PM',
      'medicamento': 'Losartán',
      'dosis': '1 tableta (50 mg)',
      'estado': 'Pendiente',
      'horaConfirmada': null,
      'esAlerta': false,
    },
  ];

  void _confirmarCerrarSesion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.terracota),
            SizedBox(width: 10),
            Text(
              'Cerrar Sesión',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.azulOscuro),
            ),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas salir del panel de cuidador? Regresarás a la pantalla de inicio de sesión.',
          style: TextStyle(fontSize: 14.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracota,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
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

  Widget _construirVistaMonitoreo() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado del Cuidador
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lilaSuave.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'MODO CUIDADOR',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.moradoOscuro,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Panel de Monitoreo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.azulOscuro,
                      ),
                    ),
                  ],
                ),

                
              ],
            ),
            const SizedBox(height: 16),

            
            const SizedBox(height: 16),

            // Tarjeta del Paciente Supervisado
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.azulOscuro.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar iniciales
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.moradoOscuro.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.person_rounded,
                            size: 32,
                            color: AppColors.moradoOscuro,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nombrePaciente,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: AppColors.azulOscuro,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _parentesco,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Botón de acceso directo al Perfil del Paciente (solo para cuidador)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PerfilPacienteScreen(
                                nombreInicial: 'Roberto',
                                apellidosInicial: 'Gómez',
                                parentescoInicial: 'Padre',
                                telefonoInicial: '+34 610 345 872',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.lilaSuave.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.lilaSuave.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.badge_outlined, size: 15, color: AppColors.moradoOscuro),
                              SizedBox(width: 4),
                              Text(
                                'Ver Perfil',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.moradoOscuro,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),

                  // Estado del dispositivo del paciente
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.wifi_rounded, size: 18, color: AppColors.turquesa),
                          const SizedBox(width: 6),
                          Text(
                            _ultimaConexion,
                            style: const TextStyle(fontSize: 13, color: AppColors.azulOscuro),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.battery_charging_full_rounded, size: 18, color: AppColors.turquesa),
                          const SizedBox(width: 4),
                          Text(
                            '$_bateriaPaciente%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.azulOscuro,
                            ),
                          ),
                        ],
                      ),
                      // Botón de llamada rápida
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Llamando a $_nombrePaciente...'),
                              backgroundColor: AppColors.moradoOscuro,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.turquesa.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.call_rounded, size: 16, color: Color(0xFF1E3F38)),
                              SizedBox(width: 4),
                              Text(
                                'Llamar',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3F38),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tarjeta de Resumen de Adherencia / Cumplimiento
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.moradoOscuro,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.moradoOscuro.withValues(alpha: 0.28),
                    blurRadius: 18,
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
                      const Text(
                        'Cumplimiento de Hoy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE2DCF7),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.turquesa.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '1 de 3 completadas',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.turquesa,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '33%',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Barra de progreso
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: const LinearProgressIndicator(
                      value: 0.33,
                      minHeight: 8,
                      backgroundColor: Color(0xFF453E60),
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.turquesa),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Próxima dosis programada para las 2:00 PM',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFD6D0EA),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sección: Seguimiento de Medicamentos de Hoy
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tratamiento de Hoy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.azulOscuro,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AgregarMedicamentoScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.moradoOscuro),
                  label: const Text(
                    'Agregar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.moradoOscuro,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Lista de tomas con su estado en tiempo real
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _seguimientoHoy.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _seguimientoHoy[index];
                final String estado = item['estado'];

                Color colorBadge;
                Color colorTextoBadge;
                String textoBadge;
                IconData iconoEstado;

                if (estado == 'Tomada') {
                  colorBadge = AppColors.turquesa.withValues(alpha: 0.2);
                  colorTextoBadge = const Color(0xFF1E3F38);
                  textoBadge = 'Tomada (${item['horaConfirmada']})';
                  iconoEstado = Icons.check_circle_rounded;
                } else if (estado == 'Próxima') {
                  colorBadge = AppColors.lilaSuave.withValues(alpha: 0.25);
                  colorTextoBadge = AppColors.moradoOscuro;
                  textoBadge = 'Próxima toma';
                  iconoEstado = Icons.access_time_filled_rounded;
                } else {
                  colorBadge = const Color(0xFFF1F5F9);
                  colorTextoBadge = Colors.grey[700]!;
                  textoBadge = 'Pendiente';
                  iconoEstado = Icons.schedule_rounded;
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: estado == 'Próxima' ? AppColors.lilaSuave : const Color(0xFFE2E8F0),
                      width: estado == 'Próxima' ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Columna Hora
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.fondo,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item['hora'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.azulOscuro,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Medicamento y dosis
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['medicamento'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.azulOscuro,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['dosis'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Badge de estatus
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorBadge,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(iconoEstado, size: 14, color: colorTextoBadge),
                            const SizedBox(width: 5),
                            Text(
                              textoBadge,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorTextoBadge,
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

            // Banner informativo SOS / Sistema de Alarma y Llamada de Emergencia
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.terracota.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.terracota.withValues(alpha: 0.35), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.crisis_alert_rounded, color: AppColors.terracota, size: 28),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Alerta SOS y Llamada de Emergencia',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.azulOscuro,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Si tu familiar presiona el botón SOS, tu teléfono sonará como una alarma inmediata a todo volumen. Si no hay conexión a internet, el sistema activará una llamada telefónica automática.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.azulOscuro,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_in_talk_rounded, size: 14, color: Color(0xFF1E3F38)),
                            SizedBox(width: 5),
                            Text(
                              'Respaldo por llamada: Activo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3F38),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.terracota,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AlertaSosCuidadorScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.crisis_alert_rounded, size: 18),
                      label: const Text(
                        'Simular Recepción de Alerta SOS',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget cuerpo;
    if (_tabSeleccionado == 1) {
      cuerpo = const TratamientosScreen(mostrarBotonVolver: false);
    } else if (_tabSeleccionado == 2) {
      // Pestaña 3: Perfil del Cuidador (Reemplaza definitivamente Ajustes)
      cuerpo = PerfilCuidadorScreen(
        onVolverAMonitoreo: () {
          setState(() {
            _tabSeleccionado = 0;
          });
        },
      );
    } else {
      cuerpo = _construirVistaMonitoreo();
    }

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: cuerpo,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabSeleccionado,
        onTap: (index) {
          setState(() {
            _tabSeleccionado = index;
          });
        },
        selectedItemColor: AppColors.moradoOscuro,
        unselectedItemColor: Colors.grey[500],
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Monitoreo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication_rounded),
            label: 'Tratamientos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
