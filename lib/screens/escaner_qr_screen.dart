import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vital_bridge/theme/app_colors.dart';

/// Pantalla con cámara física para escanear el código QR del paciente
class EscanerQrScreen extends StatefulWidget {
  const EscanerQrScreen({super.key});

  @override
  State<EscanerQrScreen> createState() => _EscanerQrScreenState();
}

class _EscanerQrScreenState extends State<EscanerQrScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _detectado = false;
  bool _linternaActiva = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _procesarCodigo(String rawValue) {
    if (_detectado) return;
    _detectado = true;

    // Vibración háptica de confirmación al escanear
    HapticFeedback.mediumImpact();

    // Limpiar el código (en caso de que venga con espacios o prefijos)
    final codigoLimpio = rawValue.trim();

    Navigator.of(context).pop(codigoLimpio);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Escanear Código QR',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _linternaActiva ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _linternaActiva ? Colors.amber : Colors.white,
            ),
            tooltip: 'Linterna',
            onPressed: () {
              setState(() => _linternaActiva = !_linternaActiva);
              _controller.toggleTorch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            tooltip: 'Cambiar cámara',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Visor de la cámara
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final valor = barcode.rawValue;
                if (valor != null && valor.isNotEmpty) {
                  _procesarCodigo(valor);
                  break;
                }
              }
            },
          ),

          // 2. Máscara oscura con ventana transparente central (Marco de escaneo)
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.turquesa, width: 3.5),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),

          // 3. Indicaciones para el usuario
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: AppColors.turquesa, size: 28),
                  SizedBox(height: 8),
                  Text(
                    'Apunta la cámara al código QR que te muestra tu cuidador',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

