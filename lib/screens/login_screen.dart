import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_bridge/screens/cuidador_dashboard_screen.dart';
import 'package:vital_bridge/screens/paciente_screen.dart';
import 'package:vital_bridge/screens/registro_screen.dart';
import 'package:vital_bridge/services/auth_service.dart';
import 'package:vital_bridge/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController(text: 'VB-8492');
  bool _obscurePassword = true;
  bool _cargandoCuidador = false;

  @override
  void initState() {
    super.initState();
    _cargarCredencialesGuardadas();
  }

  Future<void> _cargarCredencialesGuardadas() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('usuario_correo');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _emailController.text = savedEmail;
    } else {
      _emailController.text = 'maria.cuidadora@vitalbridge.com';
    }
    _passwordController.text = 'VitalBridge2026!';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  // 1. Flujo Cuidador: Iniciar sesión usando AuthService
  Future<void> _iniciarSesionCuidador() async {
    if (_cargandoCuidador) return;

    final correo = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (correo.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa tu correo y contraseña.'),
          backgroundColor: AppColors.terracota,
        ),
      );
      return;
    }

    setState(() => _cargandoCuidador = true);

    final res = await AuthService.loginCuidador(
      correo: correo,
      password: password,
    );

    if (!mounted) return;
    setState(() => _cargandoCuidador = false);

    if (res['exito'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['modoSimulacion'] == true
              ? '✅ Sesión iniciada (Modo desarrollo / offline)'
              : '✅ Bienvenido a VitalBridge'),
          backgroundColor: const Color(0xFF336C60),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const CuidadorDashboardScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['mensaje'] ?? 'Error al iniciar sesión'),
          backgroundColor: AppColors.terracota,
        ),
      );
    }
  }

  // 2. Flujo Paciente: Ventana modal para vincular mediante Token o QR
  void _mostrarModalAccesoPaciente() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        bool cargandoToken = false;

        return StatefulBuilder(
          builder: (sheetContext, setModalState) => Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra de agarre superior
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Ícono de QR / Llave
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.lilaSuave.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 40,
                      color: AppColors.moradoOscuro,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Título
                const Text(
                  'Acceso para Paciente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.azulOscuro,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Escanea el código QR que te comparta tu cuidador o ingresa el código de vinculación.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 22),

                // Campo de Token / Código
                const Text(
                  'Código de Vinculación (Token)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.azulOscuro,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tokenController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3.0,
                    color: AppColors.moradoOscuro,
                  ),
                  decoration: InputDecoration(
                    hintText: 'EJ. VB-8492',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), letterSpacing: 1),
                    filled: true,
                    fillColor: AppColors.fondo,
                    prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppColors.moradoOscuro),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.moradoOscuro, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Opción de escanear QR
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.moradoOscuro, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📷 Cámara lista: QR escaneado con éxito (Simulado)'),
                        backgroundColor: AppColors.moradoOscuro,
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.moradoOscuro, size: 20),
                  label: const Text(
                    'Escanear Código QR con Cámara',
                    style: TextStyle(
                      color: AppColors.moradoOscuro,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Botón Aceptar y Entrar a la Pantalla Principal del Paciente
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.turquesa,
                    foregroundColor: const Color(0xFF1E3F38),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: cargandoToken
                      ? null
                      : () async {
                          final token = _tokenController.text.trim();
                          if (token.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Por favor ingresa un código de vinculación.'),
                                backgroundColor: AppColors.terracota,
                              ),
                            );
                            return;
                          }

                          setModalState(() => cargandoToken = true);
                          final res = await AuthService.loginPacienteConToken(token: token);
                          if (!mounted || !modalContext.mounted) return;
                          setModalState(() => cargandoToken = false);

                          if (res['exito'] == true) {
                            if (Navigator.canPop(modalContext)) {
                              Navigator.pop(modalContext); // Cierra el modal
                            }
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✅ ¡Vinculado exitosamente! Bienvenido, ${res['paciente']?.nombre ?? 'Paciente'}.',
                                ),
                                backgroundColor: const Color(0xFF336C60),
                              ),
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const PacienteScreen()),
                            );
                          } else {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['mensaje'] ?? 'Código de vinculación inválido.'),
                                backgroundColor: AppColors.terracota,
                              ),
                            );
                          }
                        },
                  child: cargandoToken
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Color(0xFF1E3F38),
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Aceptar y Entrar al Modo Paciente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),

                // Icono / Logo central con punto verde menta
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Image.asset(
                              'assets/images/logo_icono.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFF66CCA8),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Título y Subtítulo
                const Text(
                  'VitalBridge',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3352),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'El puente entre tu bienestar y los que te cuidan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6F6593),
                  ),
                ),
                const SizedBox(height: 32),

                // Campo: Correo Electrónico
                const Text(
                  'Correo Electrónico',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'cuidador@correo.com',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      color: Color(0xFF9189AC),
                      size: 22,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF7CD4C2), width: 1.6),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF49BAA5), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Campo: Contraseña
                const Text(
                  'Contraseña',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF9189AC),
                      size: 22,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF9189AC),
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF7CD4C2), width: 1.6),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF49BAA5), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Enlace "¿Olvidaste tu contraseña?"
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recuperar contraseña')),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF988FB6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Botón: Iniciar Sesión (Entra al Dashboard del Cuidador)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E5482),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _cargandoCuidador ? null : _iniciarSesionCuidador,
                  child: _cargandoCuidador
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Iniciar Sesión (Cuidador)',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 12),

                // Botón: Crear cuenta
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7CD4C2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RegistroScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Crear cuenta',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3F38),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Separador visual "O"
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        'O SI ERES PACIENTE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                  ],
                ),
                const SizedBox(height: 20),

                // ===============================================
                // ACCESO PACIENTE: Botón con QR / Token
                // ===============================================
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _mostrarModalAccesoPaciente,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.lilaSuave, width: 1.6),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.moradoOscuro.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, size: 28, color: AppColors.moradoOscuro),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Entrar con Código QR o Token',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.azulOscuro,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Para adultos mayores (sin contraseña)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.moradoOscuro),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Badge inferior: Tus datos de salud están protegidos
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: Color(0xFF336C60),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Tus datos de salud están protegidos',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C5E53),
                          ),
                        ),
                      ],
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
