import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/license_service.dart';
import '../services/logging_service.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class LicenseScreen extends StatefulWidget {
  final VoidCallback onLicenseValidated;
  const LicenseScreen({Key? key, required this.onLicenseValidated})
    : super(key: key);

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _loading = false;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final id = await _getDeviceId();
    setState(() {
      _deviceId = id;
    });
  }

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown';
    } else {
      return 'unknown';
    }
  }

  Future<void> _copyDeviceId() async {
    if (_deviceId != null) {
      await Clipboard.setData(ClipboardData(text: _deviceId ?? ''));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ID copiado al portapapeles')));
    }
  }

  Future<void> _validateAndSave() async {
    final log = LoggingService.instance;
    setState(() {
      _loading = true;
      _error = null;
    });
    final license = _controller.text.trim();
    log.info('LicenseScreen', 'Intentando validar licencia...');
    try {
      final deviceId = await _getDeviceId();
      final result = await LicenseService.validateLicense(license, deviceId);
      if (result.isValid) {
        log.info('LicenseScreen', 'Licencia validada exitosamente ✓');
        await LicenseService.saveLicense(license);
        widget.onLicenseValidated();
      } else {
        log.warning('LicenseScreen', 'Licencia rechazada: ${result.error}');
        setState(() {
          _error = result.error;
        });
      }
    } catch (e, stack) {
      log.error('LicenseScreen', 'Error validando licencia', e, stack);
      setState(() {
        _error = 'Error inesperado: $e';
      });
    }
    setState(() {
      _loading = false;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      _controller.text = content.trim();
    }
  }

  Future<void> _exportLogs() async {
    final log = LoggingService.instance;
    try {
      log.info('LicenseScreen', 'Exportando logs de diagnóstico...');
      final exportFile = await LoggingService.instance
          .exportLogsWithDiagnostics();
      await Share.shareXFiles([
        XFile(exportFile.path),
      ], subject: 'Logs Cabina 360 - Diagnóstico');
    } catch (e, stack) {
      log.error('LicenseScreen', 'Error exportando logs', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exportando logs: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activar Licencia')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_deviceId != null) ...[
              Row(
                children: [
                  const Text(
                    'ID del dispositivo:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      _deviceId ?? '',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copiar ID',
                    onPressed: _copyDeviceId,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            const Text(
              'Pega tu licencia o cárgala desde un archivo:',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Licencia',
                errorText: _error,
              ),
              enabled: !_loading,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loading ? null : _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Cargar archivo'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _validateAndSave,
                    icon: const Icon(Icons.verified_user),
                    label: _loading
                        ? const Text('Validando...')
                        : const Text('Validar y Activar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Si tienes problemas, contacta al proveedor.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _exportLogs,
              icon: const Icon(Icons.bug_report),
              label: const Text('Exportar Logs de Diagnóstico'),
            ),
          ],
        ),
      ),
    );
  }
}
