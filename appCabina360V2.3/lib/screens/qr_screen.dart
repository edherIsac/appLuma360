import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/config.dart';
import '../screens/config_screen.dart';
import '../services/logging_service.dart';
import '../services/wifi_server_service.dart';

class QRScreen extends StatefulWidget {
  const QRScreen({Key? key}) : super(key: key);

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  final WifiServerService _wifiService = WifiServerService.instance;
  final NetworkInfo _networkInfo = NetworkInfo();
  final GlobalKey _qrKey = GlobalKey();
  final GlobalKey _modalQrKey = GlobalKey();
  String? _serverUrl;
  String? _wifiName;
  String? _wifiIP;
  String? _logoPath;
  bool _isLoading = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadServerInfo();
    _loadLogoPath();
  }

  Future<void> _loadLogoPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('logoPath');
      if (path != null && File(path).existsSync()) {
        setState(() {
          _logoPath = path;
        });
      }
    } catch (_) {}
  }

  /// Construye el widget del logo: usa el personalizado si existe, si no el default
  Widget _buildLogoImage({double? width, double? height, BoxFit? fit}) {
    if (_logoPath != null && File(_logoPath!).existsSync()) {
      return Image.file(
        File(_logoPath!),
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/logos/logo.png',
          width: width,
          height: height,
          fit: fit ?? BoxFit.cover,
        ),
      );
    }
    return Image.asset(
      'assets/logos/logo.png',
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
    );
  }

  Future<void> _loadServerInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('=== CARGANDO INFORMACIÓN DEL SERVIDOR ===');

      // Obtener información del servidor
      _serverUrl = _wifiService.serverUrl;
      _wifiName = _wifiService.wifiName;

      print('URL del servidor: $_serverUrl');
      print('Nombre WiFi del servicio: $_wifiName');

      // Obtener información de red (solo la IP, no el nombre)
      _wifiIP = await _networkInfo.getWifiIP();
      print('IP WiFi: $_wifiIP');

      setState(() {
        _isLoading = false;
      });

      // Si no hay nombre de red válido, mostrar AlertDialog y redirigir
      if (_wifiName == null ||
          _wifiName!.isEmpty ||
          _wifiName == 'null' ||
          _wifiName == 'Red WiFi no detectada') {
        Future.delayed(Duration.zero, () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Configurar Red WiFi'),
              content: const Text(
                'No se pudo detectar el nombre de la red WiFi. Por favor, configúralo manualmente en la pantalla de configuración.',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    // Obtener configuración actual desde SharedPreferences
                    final prefs = await SharedPreferences.getInstance();
                    final configString = prefs.getString('config');
                    ConfigCabina? config;
                    if (configString != null) {
                      config = ConfigCabina.fromJson(jsonDecode(configString));
                    } else {
                      config = ConfigCabina(
                        duration: 5,
                        enabledVideoFilter: true,
                        enabledContornoVideo: true,
                        enabledLogo: true,
                        enabledAudioFondo: true,
                        contornoVideo: '1',
                        audioFondo: '1',
                        logoPosition: 'rb',
                        whatsApp: '',
                        enabledINTERNET: false,
                        useFrontCamera: false,
                        wifiName: '',
                        videoResolution: 'medium',
                      );
                    }
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => ConfigScreen(
                          initialConfig: config!,
                          onConfigChanged: (_) {
                            // Al volver de config, recargar info
                            _loadServerInfo();
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Ir a Configuración'),
                ),
              ],
            ),
          );
        });
      }
    } catch (e) {
      print('❌ Error cargando información del servidor: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ignore: unused_element
  String _generateWiFiQRData() {
    print(
      'Generando QR WiFi con nombre:  [1m$_wifiName\u001b[0m (sin contraseña)',
    );
    if (_wifiName != null &&
        _wifiName!.isNotEmpty &&
        _wifiName != 'Red WiFi Actual' &&
        _wifiName != 'null') {
      String cleanWifiName = _wifiName!.replaceAll('"', '');
      String qrData = 'WIFI:S:$cleanWifiName;T:WPA;;';
      print('✅ QR WiFi generado (sin contraseña): $qrData');
      return qrData;
    } else {
      print('❌ No se puede generar QR WiFi - nombre inválido: $_wifiName');
      return '';
    }
  }

  String _generateServerQRData() {
    return _serverUrl ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Código QR - Compartir Videos'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando información del servidor...'),
                ],
              ),
            )
          : _serverUrl == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Servidor no disponible',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Asegúrate de que el servidor WiFi esté iniciado',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Información de conexión
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2196F3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.wifi, color: const Color(0xFF1976D2)),
                            const SizedBox(width: 8),
                            Text(
                              'Información de Conexión',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Red WiFi:',
                          _wifiName ?? 'No disponible',
                        ),
                        if (_wifiIP != null)
                          _buildInfoRow('IP del dispositivo:', _wifiIP!),
                        _buildInfoRow('URL del servidor:', _serverUrl!),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFF9800)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: const Color(0xFFE65100),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Los dispositivos deben estar conectados a la misma red WiFi',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFE65100),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Código QR para WiFi - COMENTADO TEMPORALMENTE
                  /*
                      if (_wifiName != null &&
                          _wifiName!.isNotEmpty &&
                          _wifiName != 'Red WiFi Actual' &&
                          _wifiName != 'null')
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.3),
                                spreadRadius: 2,
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.wifi,
                                      color: const Color(0xFF1976D2)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Conectar a WiFi',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1976D2),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Campo de contraseña WiFi
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFE0E0E0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '🔐 Contraseña WiFi (opcional):',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1976D2),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: TextEditingController(
                                                text: _wifiPassword),
                                            obscureText: true, // Always obscure
                                            decoration: const InputDecoration(
                                              hintText: 'Contraseña de WiFi',
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                            ),
                                            onChanged: (value) {
                                              setState(
                                                  () {}); // Reconstruir para actualizar el QR
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.visibility_off,
                                            color: Color(0xFF1976D2),
                                          ),
                                          onPressed: () {
                                            // No action needed, always obscured
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Si ingresas la contraseña, el QR permitirá conectarse automáticamente',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF666666),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              QrImageView(
                                data: _generateWiFiQRData(),
                                version: QrVersions.auto,
                                size: 200.0,
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF000000),
                              ),
                              const SizedBox(height: 16),

                              Text(
                                'Escanea para obtener información de la red WiFi',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF424242),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Red: $_wifiName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1976D2),
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              if (_wifiPassword == null || _wifiPassword!.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFFF9800)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          color: const Color(0xFFE65100),
                                          size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Necesitarás ingresar la contraseña manualmente',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFE65100),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                      if (_wifiName != null &&
                          _wifiName!.isNotEmpty &&
                          _wifiName != 'Red WiFi Actual' &&
                          _wifiName != 'null')
                        const SizedBox(height: 20),
                      */

                  // Mensaje cuando no se puede obtener el nombre de WiFi - COMENTADO TEMPORALMENTE
                  /*
                      if (_wifiName == null ||
                          _wifiName!.isEmpty ||
                          _wifiName == 'Red WiFi Actual' ||
                          _wifiName == 'null' ||
                          _wifiName!.startsWith('Red_WiFi_') ||
                          _wifiName!.startsWith('WiFi_'))
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFF9800)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: const Color(0xFFE65100)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Nombre de WiFi no detectado correctamente',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFE65100),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'La app no pudo obtener el nombre real de tu red WiFi. Para generar códigos QR correctos:',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFE65100),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF2196F3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '📱 Configurar nombre de WiFi:',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1976D2),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '1. Ve a Configuración → Configuración de WiFi',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1976D2),
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      '2. Ingresa el nombre real de tu red WiFi',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1976D2),
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      '3. Guarda y reinicia el servidor WiFi',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1976D2),
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '💡 Por ahora, los usuarios deberán conectarse manualmente a la misma red WiFi que este dispositivo.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFE65100),
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_wifiName == null ||
                          _wifiName!.isEmpty ||
                          _wifiName == 'Red WiFi Actual')
                        const SizedBox(height: 20),
                      */

                  // Código QR para servidor
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.web, color: const Color(0xFF2E7D32)),
                            const SizedBox(width: 8),
                            Text(
                              'Acceder a Videos',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        RepaintBoundary(
                          key: _qrKey,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              QrImageView(
                                data: _generateServerQRData(),
                                version: QrVersions.auto,
                                size: 200.0,
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF000000),
                              ),
                              Container(
                                width: 66,
                                height: 66,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: _buildLogoImage(fit: BoxFit.cover),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Botón de descarga del QR
                        _isDownloading
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: _downloadQR,
                                icon: const Icon(Icons.download, size: 18),
                                label: const Text('Descargar QR'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2E7D32),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                        const SizedBox(height: 16),
                        Text(
                          'Escanea para acceder a los videos',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF424242),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Instrucciones
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4CAF50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.help_outline,
                              color: const Color(0xFF2E7D32),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Instrucciones',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInstructionStep(
                          1,
                          'Conecta tu dispositivo a la red WiFi: $_wifiName',
                        ),
                        _buildInstructionStep(
                          2,
                          'Ingresa la contraseña de la red WiFi manualmente',
                        ),
                        _buildInstructionStep(
                          3,
                          'Una vez conectado, escanea el código QR (Videos)',
                        ),
                        _buildInstructionStep(
                          4,
                          'Se abrirá automáticamente la página web con los videos',
                        ),
                        _buildInstructionStep(
                          5,
                          'Descarga o visualiza tus videos favoritos',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showUrlModal,
                          icon: const Icon(Icons.qr_code_2),
                          label: const Text('Ver QR Web'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _copyUrlToClipboard,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copiar URL'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _downloadQR() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final log = LoggingService.instance;
      log.info('QRScreen', 'Descargando código QR...');

      final renderObject =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (renderObject == null) {
        log.error('QRScreen', 'No se pudo obtener el boundary del QR');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al generar la imagen del QR')),
          );
        }
        return;
      }

      final image = await renderObject.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        log.error('QRScreen', 'No se pudieron obtener los bytes de la imagen');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al generar la imagen del QR')),
          );
        }
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Guardar en directorio temporal
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      const fileName = 'cabina360_qr.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      // Compartir el archivo
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'QR Cabina 360 - Acceder a Videos',
        text: 'Escanea este código QR para acceder a los videos de Cabina 360',
      );

      log.info('QRScreen', 'QR descargado exitosamente');
    } catch (e, stack) {
      final log = LoggingService.instance;
      log.error('QRScreen', 'Error descargando QR', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  void _showUrlModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.qr_code_2,
                    color: const Color(0xFF2E7D32),
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'URL del Servidor Web',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // URL correcta para QR web
              const Text(
                'URL para acceder a la página de Videos:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4CAF50)),
                ),
                child: SelectableText(
                  _getWebQrUrl(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2E7D32),
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // QR Code grande con Stack para fondo blanco del logo
              RepaintBoundary(
                key: _modalQrKey,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(
                      data: _getWebQrUrl(),
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF000000),
                    ),
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildLogoImage(fit: BoxFit.cover),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Escanea este QR para acceder directamente a la página de videos',
                style: TextStyle(fontSize: 12, color: Color(0xFF424242)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _copyUrlToClipboard();
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar URL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getWebQrUrl() {
    if (_serverUrl == null) return '';
    // Asegurar que la URL termine con /qr
    final base = _serverUrl!.replaceAll(RegExp(r'/+$'), '');
    return '$base/qr';
  }

  Future<void> _copyUrlToClipboard() async {
    final url = _getWebQrUrl();
    if (url.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('URL copiada al portapapeles'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al copiar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF616161),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF212121),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(int step, String instruction) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF424242),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
