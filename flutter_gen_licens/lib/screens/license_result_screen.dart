import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/license_generator_service.dart';

/// Screen 3: Display the generated license result.
///
/// Shows:
/// - License summary (device ID, expiration date)
/// - Base64-encoded license string (selectable/copyable)
/// - Pretty-printed JSON
/// - Actions: Copy, Save file, Share
class LicenseResultScreen extends StatefulWidget {
  final String deviceId;
  final String expires;

  const LicenseResultScreen({
    super.key,
    required this.deviceId,
    required this.expires,
  });

  @override
  State<LicenseResultScreen> createState() => _LicenseResultScreenState();
}

class _LicenseResultScreenState extends State<LicenseResultScreen> {
  late final String _licenseBase64;
  late final String _licenseJson;
  late final String _fileName;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _licenseBase64 = LicenseGeneratorService.generateLicenseBase64(
      widget.deviceId,
      widget.expires,
    );
    _licenseJson = LicenseGeneratorService.generateLicenseJson(
      widget.deviceId,
      widget.expires,
    );
    _fileName = LicenseGeneratorService.generateFileName(widget.deviceId);
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _licenseBase64));
    setState(() => _copied = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Licencia copiada al portapapeles'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    // Reset the copied indicator after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _saveToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      await file.writeAsString(_licenseBase64);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Licencia guardada en: ${file.path}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareFile() async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$_fileName');
      await file.writeAsString(_licenseBase64);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Licencia para ${widget.deviceId}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetFlow() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Licencia Generada'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success icon
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              '¡Licencia generada exitosamente!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.devices, color: Colors.deepPurple),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ID del dispositivo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                widget.deviceId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.event, color: Colors.deepPurple),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Fecha de expiración',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                widget.expires,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Base64 license
            Text(
              'Licencia (Base64, para la app):',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                _licenseBase64,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),

            // JSON license
            Text(
              'Licencia (JSON):',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                _licenseJson,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 32),

            // Action buttons
            FilledButton.icon(
              onPressed: _copyToClipboard,
              icon: Icon(_copied ? Icons.check : Icons.copy),
              label: Text(_copied ? 'Copiado' : 'Copiar Base64'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saveToFile,
              icon: const Icon(Icons.save),
              label: const Text('Guardar archivo'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _shareFile,
              icon: const Icon(Icons.share),
              label: const Text('Compartir'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _resetFlow,
              icon: const Icon(Icons.refresh),
              label: const Text('Nueva licencia'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
