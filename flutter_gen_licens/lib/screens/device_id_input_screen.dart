import 'package:flutter/material.dart';
import 'duration_selection_screen.dart';

/// Screen 1: Input the Device ID.
///
/// Replaces the inquirer prompt:
/// ```js
/// const { deviceId } = await inquirer.prompt([{
///   type: 'input', name: 'deviceId', message: 'ID del dispositivo:',
///   validate: input => isValidDeviceId(input) ? true : 'El ID no puede estar vacío.'
/// }]);
/// ```
class DeviceIdInputScreen extends StatefulWidget {
  const DeviceIdInputScreen({super.key});

  @override
  State<DeviceIdInputScreen> createState() => _DeviceIdInputScreenState();
}

class _DeviceIdInputScreenState extends State<DeviceIdInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdController = TextEditingController();

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }

  void _navigateToDuration() {
    if (_formKey.currentState!.validate()) {
      final deviceId = _deviceIdController.text.trim();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DurationSelectionScreen(deviceId: deviceId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generador de Licencias'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.vpn_key, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 32),
              Text(
                'Generador de Licencias',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ingresa el ID del dispositivo para generar una licencia',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _deviceIdController,
                decoration: const InputDecoration(
                  labelText: 'ID del dispositivo',
                  hintText: 'Ej: V1UGS35H.75-14-3-7',
                  prefixIcon: Icon(Icons.devices),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El ID del dispositivo no puede estar vacío';
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _navigateToDuration(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _navigateToDuration,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Siguiente'),
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
