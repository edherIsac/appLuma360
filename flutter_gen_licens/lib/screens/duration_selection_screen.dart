import 'package:flutter/material.dart';
import 'license_result_screen.dart';
import '../services/license_generator_service.dart';

/// Duration type options matching the Node.js inquirer choices.
enum DurationType { months, days, exact }

/// Screen 2: Select the license duration.
///
/// Replaces the inquirer prompts for duration type selection:
/// - Por meses → input number of months
/// - Por días → input number of days
/// - Fecha exacta → input YYYY-MM-DD
class DurationSelectionScreen extends StatefulWidget {
  final String deviceId;

  const DurationSelectionScreen({super.key, required this.deviceId});

  @override
  State<DurationSelectionScreen> createState() =>
      _DurationSelectionScreenState();
}

class _DurationSelectionScreenState extends State<DurationSelectionScreen> {
  DurationType _durationType = DurationType.months;
  final _numberController = TextEditingController();
  final _dateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _numberController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String _calculateExpiry() {
    final today = DateTime.now();
    switch (_durationType) {
      case DurationType.months:
        final months = int.parse(_numberController.text);
        return LicenseGeneratorService.formatDate(
          LicenseGeneratorService.addMonths(today, months),
        );
      case DurationType.days:
        final days = int.parse(_numberController.text);
        return LicenseGeneratorService.formatDate(
          LicenseGeneratorService.addDays(today, days),
        );
      case DurationType.exact:
        return _dateController.text;
    }
  }

  void _showConfirmationDialog() {
    if (!_formKey.currentState!.validate()) return;

    final expires = _calculateExpiry();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar licencia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID del dispositivo: ${widget.deviceId}'),
            const SizedBox(height: 8),
            Text('Fecha de expiración: $expires'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _generateAndNavigate(expires);
            },
            child: const Text('Generar'),
          ),
        ],
      ),
    );
  }

  void _generateAndNavigate(String expires) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            LicenseResultScreen(deviceId: widget.deviceId, expires: expires),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = LicenseGeneratorService.formatDate(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duración de Licencia'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Device ID summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.devices, color: Colors.deepPurple),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dispositivo',
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
                ),
              ),
              const SizedBox(height: 24),

              // Duration type selection
              Text(
                '¿Cómo quieres definir la duración?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SegmentedButton<DurationType>(
                segments: const [
                  ButtonSegment(
                    value: DurationType.months,
                    label: Text('Meses'),
                    icon: Icon(Icons.calendar_month),
                  ),
                  ButtonSegment(
                    value: DurationType.days,
                    label: Text('Días'),
                    icon: Icon(Icons.calendar_today),
                  ),
                  ButtonSegment(
                    value: DurationType.exact,
                    label: Text('Fecha exacta'),
                    icon: Icon(Icons.event),
                  ),
                ],
                selected: {_durationType},
                onSelectionChanged: (selection) {
                  setState(() {
                    _durationType = selection.first;
                    _numberController.clear();
                    _dateController.clear();
                  });
                },
              ),
              const SizedBox(height: 24),

              // Conditional input based on duration type
              if (_durationType == DurationType.months) ...[
                TextFormField(
                  controller: _numberController,
                  decoration: const InputDecoration(
                    labelText: '¿Cuántos meses de duración?',
                    prefixIcon: Icon(Icons.calendar_month),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa un número';
                    }
                    final n = int.tryParse(value);
                    if (n == null || n <= 0) return 'Debe ser mayor que 0';
                    return null;
                  },
                ),
              ] else if (_durationType == DurationType.days) ...[
                TextFormField(
                  controller: _numberController,
                  decoration: const InputDecoration(
                    labelText: '¿Cuántos días de duración?',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa un número';
                    }
                    final n = int.tryParse(value);
                    if (n == null || n <= 0) return 'Debe ser mayor que 0';
                    return null;
                  },
                ),
              ] else ...[
                TextFormField(
                  controller: _dateController,
                  decoration: InputDecoration(
                    labelText: 'Fecha de expiración',
                    prefixIcon: const Icon(Icons.event),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: () => _selectDate(context),
                    ),
                  ),
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Selecciona una fecha';
                    }
                    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
                      return 'Formato inválido. Usa YYYY-MM-DD.';
                    }
                    return null;
                  },
                ),
              ],

              const Spacer(),
              FilledButton.icon(
                onPressed: _showConfirmationDialog,
                icon: const Icon(Icons.check),
                label: const Text('Generar Licencia'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
