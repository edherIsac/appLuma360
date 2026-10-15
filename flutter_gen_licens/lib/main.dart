import 'package:flutter/material.dart';
import 'screens/device_id_input_screen.dart';

void main() {
  runApp(const GenLicensApp());
}

class GenLicensApp extends StatelessWidget {
  const GenLicensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Generador de Licencias',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const DeviceIdInputScreen(),
    );
  }
}
