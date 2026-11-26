import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_bridge/screens/cuidador_dashboard_screen.dart';
import 'package:vital_bridge/screens/paciente_screen.dart';
import 'package:vital_bridge/screens/registro_screen.dart';
import 'package:vital_bridge/services/auth_service.dart';
import 'package:vital_bridge/services/fcm_service.dart';
import 'package:vital_bridge/theme/app_colors.dart';
import 'package:vital_bridge/screens/escaner_qr_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  bool _obscurePassword = true;
  bool _cargandoCuidador = false;
  bool _cargandoGoogle = false;

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
    }
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

    try {
      final res = await AuthService.loginCuidador(
        correo: correo,
        password: password,
      );

      if (!mounted) return;

      if (res['exito'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bienvenido a VitalBridge'),
            backgroundColor: Color(0xFF336C60),
            duration: Duration(seconds: 2),
          ),
        );
        FcmService.sincronizarTokenCuidador();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const CuidadorDashboardScreen()),
        );
      } else {
        final mensaje = res['mensaje'] ?? 'Error al iniciar sesión';
        if (mensaje.toString().toLowerCase().contains('confirmad')) {
          _mostrarDialogoReenviarConfirmacion(correo);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensaje),
              backgroundColor: AppColors.terracota,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.terracota,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cargandoCuidador = false);
      }
    }
  }

  // Flujo Cuidador: Iniciar sesión o registrarse con Google
  Future<void> _iniciarSesionConGoogle() async {
    if (_cargandoGoogle) return;

    setState(() => _cargandoGoogle = true);

    try {
      final res = await AuthService.iniciarSesionConGoogle();
      if (!mounted) return;

      if (res['exito'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión iniciada con Google exitosamente.'),
            backgroundColor: Color(0xFF336C60),
            duration: Duration(seconds: 2),
          ),
        );
        FcmService.sincronizarTokenCuidador();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const CuidadorDashboardScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['mensaje'] ?? 'Error al iniciar con Google.'),
            backgroundColor: AppColors.terracota,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al conectar con Google: $e'),
          backgroundColor: AppColors.terracota,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cargandoGoogle = false);
      }
    }
  }

  // Cuidador: Diálogo para reenviar correo de confirmación de cuenta
  void _mostrarDialogoReenviarConfirmacion(String correo) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool reenviando = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Confirmación pendiente',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.moradoOscuro),
              ),
              content: Text(
                'Tu cuenta aún no ha sido confirmada. Revisa la bandeja de entrada o spam de $correo.\n\n¿Deseas que te reenviemos el enlace de confirmación?',
                style: const TextStyle(fontSize: 14.5, color: Color(0xFF4A5568)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar', style: TextStyle(color: Color(0xFF718096))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.moradoOscuro,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: reenviando
                      ? null
                      : () async {
                          setDialogState(() => reenviando = true);
                          final res = await AuthService.reenviarConfirmacion(correo);
                          if (!mounted || !dialogCtx.mounted) return;
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['mensaje'] ?? 'Solicitud procesada'),
                              backgroundColor: res['exito'] == true
                                  ? const Color(0xFF336C60)
                                  : AppColors.terracota,
                            ),
                          );
                        },
                  child: reenviando
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Reenviar enlace', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Cuidador: Modal para recuperar y restablecer contraseña mediante código OTP
  void _mostrarModalRecuperarPassword() {
    final correoRecuperarController = TextEditingController(text: _emailController.text.trim());
    final codigoController = TextEditingController();
    final nuevaPasswordController = TextEditingController();
    final confirmarPasswordController = TextEditingController();

    int paso = 1;
    bool cargando = false;
    bool obscureNueva = true;
    bool obscureConfirmar = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 28,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    const SizedBox(height: 18),
                    Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: paso == 1
                              ? const Color(0xFFEFEBF6)
                              : const Color(0xFFE6F4F1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          paso == 1
                              ? Icons.lock_reset_rounded
                              : Icons.mark_email_read_rounded,
                          color: paso == 1
                              ? AppColors.moradoOscuro
                              : const Color(0xFF336C60),
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      paso == 1
                          ? 'Recuperar Contraseña'
                          : 'Restablecer Contraseña',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.moradoOscuro,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      paso == 1
                          ? 'Ingresa tu correo electrónico registrado. Te enviaremos un código de seguridad para restablecer tu contraseña.'
                          : 'Ingresa el código recibido en ${correoRecuperarController.text.trim()} y define tu nueva contraseña.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (paso == 1) ...[
                      TextField(
                        controller: correoRecuperarController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'ejemplo@correo.com',
                          labelText: 'Correo electrónico',
                          prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.moradoOscuro),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
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
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.moradoOscuro,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: cargando
                            ? null
                            : () async {
                                final correo = correoRecuperarController.text.trim();
                                if (correo.isEmpty || !correo.contains('@')) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Por favor ingresa un correo electrónico válido.'),
                                      backgroundColor: AppColors.terracota,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => cargando = true);
                                final res = await AuthService.solicitarRecuperacionPassword(correo);
                                if (!mounted || !modalCtx.mounted) return;
                                setModalState(() => cargando = false);

                                if (res['exito'] == true) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res['mensaje'] ?? 'Código enviado a tu correo.'),
                                      backgroundColor: const Color(0xFF336C60),
                                    ),
                                  );
                                  setModalState(() => paso = 2);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res['mensaje'] ?? 'No se pudo enviar el código.'),
                                      backgroundColor: AppColors.terracota,
                                    ),
                                  );
                                }
                              },
                        child: cargando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text(
                                'Enviar Código de Seguridad',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ] else ...[
                      TextField(
                        controller: codigoController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4.0,
                          color: AppColors.moradoOscuro,
                        ),
                        decoration: InputDecoration(
                          hintText: 'CÓDIGO (EJ. 123456)',
                          labelText: 'Código de seguridad',
                          prefixIcon: const Icon(Icons.key_rounded, color: AppColors.moradoOscuro),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
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
                      TextField(
                        controller: nuevaPasswordController,
                        obscureText: obscureNueva,
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          hintText: 'Mínimo 6 caracteres',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.moradoOscuro),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNueva ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: const Color(0xFF988FB6),
                            ),
                            onPressed: () => setModalState(() => obscureNueva = !obscureNueva),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
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
                      TextField(
                        controller: confirmarPasswordController,
                        obscureText: obscureConfirmar,
                        decoration: InputDecoration(
                          labelText: 'Confirmar nueva contraseña',
                          hintText: 'Repite la contraseña',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.moradoOscuro),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirmar ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: const Color(0xFF988FB6),
                            ),
                            onPressed: () => setModalState(() => obscureConfirmar = !obscureConfirmar),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
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
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF336C60),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: cargando
                            ? null
                            : () async {
                                final codigo = codigoController.text.trim();
                                final nueva = nuevaPasswordController.text.trim();
                                final confirmar = confirmarPasswordController.text.trim();

                                if (codigo.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ingresa el código recibido en tu correo.'),
                                      backgroundColor: AppColors.terracota,
                                    ),
                                  );
                                  return;
                                }
                                if (nueva.length < 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('La contraseña debe tener al menos 6 caracteres.'),
                                      backgroundColor: AppColors.terracota,
                                    ),
                                  );
                                  return;
                                }
                                if (nueva != confirmar) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Las contraseñas no coinciden.'),
                                      backgroundColor: AppColors.terracota,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => cargando = true);
                                final res = await AuthService.restablecerPassword(
                                  correo: correoRecuperarController.text.trim(),
                                  codigo: codigo,
                                  nuevaContrasena: nueva,
                                );
                                if (!mounted || !modalCtx.mounted) return;
                                setModalState(() => cargando = false);

                                if (res['exito'] == true) {
                                  Navigator.pop(modalCtx);
                                  _emailController.text = correoRecuperarController.text.trim();
                                  _passwordController.text = nueva;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res['mensaje'] ?? 'Contraseña restablecida exitosamente.'),
                                      backgroundColor: const Color(0xFF336C60),
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res['mensaje'] ?? 'Error al restablecer la contraseña.'),
                                      backgroundColor: AppColors.terracota,
                                    ),
                                  );
                                }
                              },
                        child: cargando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text(
                                'Restablecer Contraseña',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setModalState(() => paso = 1),
                        child: const Text(
                          '¿No recibiste el código? Volver a intentar',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.moradoOscuro,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                  inputFormatters: [
                    TokenInputFormatter(),
                    LengthLimitingTextInputFormatter(14),
                  ],
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
                  onPressed: () async {
                    final codigo = await Navigator.of(context).push<String>(
                      MaterialPageRoute(builder: (context) => const EscanerQrScreen()),
                    );

                    if (codigo != null && codigo.isNotEmpty) {
                      _tokenController.text = codigo;
                      setModalState(() => cargandoToken = true);

                      final res = await AuthService.loginPacienteConToken(token: codigo);
                      if (!mounted || !modalContext.mounted) return;
                      setModalState(() => cargandoToken = false);

                      if (res['exito'] == true) {
                        if (Navigator.canPop(modalContext)) {
                          Navigator.pop(modalContext);
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Código QR escaneado con éxito. Bienvenido, ${res['paciente']?.nombre ?? 'Paciente'}.',
                            ),
                            backgroundColor: const Color(0xFF336C60),
                          ),
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const PacienteScreen()),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['mensaje'] ?? 'Código QR inválido o expirado.'),
                            backgroundColor: AppColors.terracota,
                          ),
                        );
                      }
                    }
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
                                  'Vinculado exitosamente. Bienvenido, ${res['paciente']?.nombre ?? 'Paciente'}.',
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
                    onPressed: _mostrarModalRecuperarPassword,
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
                const SizedBox(height: 16),

                // Separador "O CONTINUAR CON"
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Text(
                        'O CONTINUAR CON',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                  ],
                ),
                const SizedBox(height: 14),

                // Botón Continuar con Google
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _cargandoGoogle ? null : _iniciarSesionConGoogle,
                  child: _cargandoGoogle
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Color(0xFF5E5482),
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4285F4),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  'G',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    fontFamily: 'sans-serif',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Continuar con Google',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
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

class TokenInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    String text = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (text.length > 10) {
      text = text.substring(0, 10);
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) {
        buffer.write('-');
      } else if (i == 5 && text.length > 6) {
        buffer.write('-');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
