import 'package:flutter/material.dart';
import '../services/usability_service.dart';

/// Pantalla de configuración de usabilidad
/// Permite gestionar temas, accesibilidad, gestos táctiles y tutorial
class UsabilityConfigScreen extends StatefulWidget {
  const UsabilityConfigScreen({super.key});

  @override
  State<UsabilityConfigScreen> createState() => _UsabilityConfigScreenState();
}

class _UsabilityConfigScreenState extends State<UsabilityConfigScreen> {
  final UsabilityService _usabilityService = UsabilityService.instance;

  ThemeMode _currentThemeMode = ThemeMode.system;
  bool _isTutorialActive = false;
  AccessibilitySettings _accessibilitySettings = AccessibilitySettings();
  TouchGestureSettings _touchGestureSettings = TouchGestureSettings(
    doubleTapEnabled: true,
    longPressEnabled: true,
    pinchToZoomEnabled: true,
    swipeEnabled: true,
    rotationEnabled: true,
  );

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Cargar configuración actual
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _usabilityService.initialize();

      _currentThemeMode = _usabilityService.currentThemeMode;
      _isTutorialActive = _usabilityService.isTutorialActive;
      _accessibilitySettings = _usabilityService.accessibilitySettings;
      _touchGestureSettings = _usabilityService.getTouchGestureSettings();

      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar configuración: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Cambiar modo de tema
  Future<void> _changeThemeMode(ThemeMode themeMode) async {
    try {
      await _usabilityService.setThemeMode(themeMode);
      setState(() {
        _currentThemeMode = themeMode;
        _successMessage = 'Tema cambiado exitosamente';
      });

      // Limpiar mensaje después de 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cambiar tema: $e';
      });
    }
  }

  /// Cambiar estado del tutorial
  Future<void> _toggleTutorial(bool value) async {
    try {
      await _usabilityService.setTutorialActive(value);
      setState(() {
        _isTutorialActive = value;
        _successMessage = value ? 'Tutorial activado' : 'Tutorial desactivado';
      });

      // Limpiar mensaje después de 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cambiar tutorial: $e';
      });
    }
  }

  /// Cambiar configuración de accesibilidad
  Future<void> _updateAccessibility(AccessibilitySettings settings) async {
    try {
      await _usabilityService.updateAccessibilitySettings(settings);
      setState(() {
        _accessibilitySettings = settings;
        _successMessage = 'Configuración de accesibilidad actualizada';
      });

      // Limpiar mensaje después de 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al actualizar accesibilidad: $e';
      });
    }
  }

  /// Completar tutorial
  Future<void> _completeTutorial() async {
    try {
      await _usabilityService.completeTutorial();
      setState(() {
        _successMessage = 'Tutorial completado exitosamente';
      });

      // Limpiar mensaje después de 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al completar tutorial: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Usabilidad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSettings,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mensajes de estado
                  if (_errorMessage != null)
                    _buildMessageCard(_errorMessage!, Colors.red, Icons.error),
                  if (_successMessage != null)
                    _buildMessageCard(
                        _successMessage!, Colors.green, Icons.check_circle),

                  // Configuración de tema
                  _buildThemeSection(),

                  const SizedBox(height: 24),

                  // Configuración de tutorial
                  _buildTutorialSection(),

                  const SizedBox(height: 24),

                  // Configuración de accesibilidad
                  _buildAccessibilitySection(),

                  const SizedBox(height: 24),

                  // Configuración de gestos táctiles
                  _buildTouchGesturesSection(),

                  const SizedBox(height: 24),

                  // Estadísticas de usabilidad
                  _buildUsabilityStatsSection(),
                ],
              ),
            ),
    );
  }

  /// Construir tarjeta de mensaje
  Widget _buildMessageCard(String message, Color color, IconData icon) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          message,
          style: TextStyle(color: color),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              _errorMessage = null;
              _successMessage = null;
            });
          },
        ),
      ),
    );
  }

  /// Construir sección de tema
  Widget _buildThemeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.palette, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Configuración de Tema',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RadioListTile<ThemeMode>(
              title: const Text('Tema Claro'),
              subtitle: const Text('Colores claros y brillantes'),
              value: ThemeMode.light,
              groupValue: _currentThemeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  _changeThemeMode(value);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Tema Oscuro'),
              subtitle: const Text('Colores oscuros y suaves'),
              value: ThemeMode.dark,
              groupValue: _currentThemeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  _changeThemeMode(value);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Tema Automático'),
              subtitle: const Text('Cambia según la hora del día'),
              value: ThemeMode.system,
              groupValue: _currentThemeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  _changeThemeMode(value);
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'El tema automático cambia a modo oscuro entre las 6 PM y 6 AM',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construir sección de tutorial
  Widget _buildTutorialSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Tutorial Interactivo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Activar Tutorial'),
              subtitle: const Text('Muestra guías para nuevos usuarios'),
              value: _isTutorialActive,
              onChanged: _toggleTutorial,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTutorialActive ? null : _completeTutorial,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Marcar como Completado'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Implementar reinicio del tutorial
                      setState(() {
                        _successMessage = 'Tutorial reiniciado';
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reiniciar Tutorial'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Construir sección de accesibilidad
  Widget _buildAccessibilitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.accessibility, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Configuración de Accesibilidad',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Lector de Pantalla'),
              subtitle: const Text('Habilita VoiceOver/TalkBack'),
              value: _accessibilitySettings.screenReaderEnabled,
              onChanged: (bool value) {
                final newSettings = AccessibilitySettings(
                  screenReaderEnabled: value,
                  highContrastEnabled:
                      _accessibilitySettings.highContrastEnabled,
                  largeTextEnabled: _accessibilitySettings.largeTextEnabled,
                  reduceMotionEnabled:
                      _accessibilitySettings.reduceMotionEnabled,
                );
                _updateAccessibility(newSettings);
              },
            ),
            SwitchListTile(
              title: const Text('Alto Contraste'),
              subtitle: const Text('Mejora la visibilidad del texto'),
              value: _accessibilitySettings.highContrastEnabled,
              onChanged: (bool value) {
                final newSettings = AccessibilitySettings(
                  screenReaderEnabled:
                      _accessibilitySettings.screenReaderEnabled,
                  highContrastEnabled: value,
                  largeTextEnabled: _accessibilitySettings.largeTextEnabled,
                  reduceMotionEnabled:
                      _accessibilitySettings.reduceMotionEnabled,
                );
                _updateAccessibility(newSettings);
              },
            ),
            SwitchListTile(
              title: const Text('Texto Grande'),
              subtitle: const Text('Aumenta el tamaño de la fuente'),
              value: _accessibilitySettings.largeTextEnabled,
              onChanged: (bool value) {
                final newSettings = AccessibilitySettings(
                  screenReaderEnabled:
                      _accessibilitySettings.screenReaderEnabled,
                  highContrastEnabled:
                      _accessibilitySettings.highContrastEnabled,
                  largeTextEnabled: value,
                  reduceMotionEnabled:
                      _accessibilitySettings.reduceMotionEnabled,
                );
                _updateAccessibility(newSettings);
              },
            ),
            SwitchListTile(
              title: const Text('Reducir Movimiento'),
              subtitle: const Text('Minimiza animaciones y transiciones'),
              value: _accessibilitySettings.reduceMotionEnabled,
              onChanged: (bool value) {
                final newSettings = AccessibilitySettings(
                  screenReaderEnabled:
                      _accessibilitySettings.screenReaderEnabled,
                  highContrastEnabled:
                      _accessibilitySettings.highContrastEnabled,
                  largeTextEnabled: _accessibilitySettings.largeTextEnabled,
                  reduceMotionEnabled: value,
                );
                _updateAccessibility(newSettings);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Construir sección de gestos táctiles
  Widget _buildTouchGesturesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.touch_app, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Gestos Táctiles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Doble Tap'),
              subtitle: const Text('Zoom in/out, reset de vista'),
              value: _touchGestureSettings.doubleTapEnabled,
              onChanged: (bool value) {
                setState(() {
                  _touchGestureSettings = TouchGestureSettings(
                    doubleTapEnabled: value,
                    longPressEnabled: _touchGestureSettings.longPressEnabled,
                    pinchToZoomEnabled:
                        _touchGestureSettings.pinchToZoomEnabled,
                    swipeEnabled: _touchGestureSettings.swipeEnabled,
                    rotationEnabled: _touchGestureSettings.rotationEnabled,
                  );
                });
              },
            ),
            SwitchListTile(
              title: const Text('Presión Larga'),
              subtitle: const Text('Menú contextual, preview'),
              value: _touchGestureSettings.longPressEnabled,
              onChanged: (bool value) {
                setState(() {
                  _touchGestureSettings = TouchGestureSettings(
                    doubleTapEnabled: _touchGestureSettings.doubleTapEnabled,
                    longPressEnabled: value,
                    pinchToZoomEnabled:
                        _touchGestureSettings.pinchToZoomEnabled,
                    swipeEnabled: _touchGestureSettings.swipeEnabled,
                    rotationEnabled: _touchGestureSettings.rotationEnabled,
                  );
                });
              },
            ),
            SwitchListTile(
              title: const Text('Pinch to Zoom'),
              subtitle: const Text('Zoom in/out, ajuste de escala'),
              value: _touchGestureSettings.pinchToZoomEnabled,
              onChanged: (bool value) {
                setState(() {
                  _touchGestureSettings = TouchGestureSettings(
                    doubleTapEnabled: _touchGestureSettings.doubleTapEnabled,
                    longPressEnabled: _touchGestureSettings.longPressEnabled,
                    pinchToZoomEnabled: value,
                    swipeEnabled: _touchGestureSettings.swipeEnabled,
                    rotationEnabled: _touchGestureSettings.rotationEnabled,
                  );
                });
              },
            ),
            SwitchListTile(
              title: const Text('Swipe'),
              subtitle: const Text('Navegación entre pantallas'),
              value: _touchGestureSettings.swipeEnabled,
              onChanged: (bool value) {
                setState(() {
                  _touchGestureSettings = TouchGestureSettings(
                    doubleTapEnabled: _touchGestureSettings.doubleTapEnabled,
                    longPressEnabled: _touchGestureSettings.longPressEnabled,
                    pinchToZoomEnabled:
                        _touchGestureSettings.pinchToZoomEnabled,
                    swipeEnabled: value,
                    rotationEnabled: _touchGestureSettings.rotationEnabled,
                  );
                });
              },
            ),
            SwitchListTile(
              title: const Text('Rotación'),
              subtitle: const Text('Rotación de vista, orientación'),
              value: _touchGestureSettings.rotationEnabled,
              onChanged: (bool value) {
                setState(() {
                  _touchGestureSettings = TouchGestureSettings(
                    doubleTapEnabled: _touchGestureSettings.doubleTapEnabled,
                    longPressEnabled: _touchGestureSettings.longPressEnabled,
                    pinchToZoomEnabled:
                        _touchGestureSettings.pinchToZoomEnabled,
                    swipeEnabled: _touchGestureSettings.swipeEnabled,
                    rotationEnabled: value,
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Construir sección de estadísticas de usabilidad
  Widget _buildUsabilityStatsSection() {
    final stats = _usabilityService.getUsabilityStats();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text(
                  'Estadísticas de Usabilidad',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatItem(
                'Tema Actual', stats['currentTheme']?.toString() ?? 'N/A'),
            _buildStatItem('Tutorial Activo',
                stats['tutorialActive']?.toString() ?? 'false'),
            _buildStatItem(
                'Primera Vez', stats['isFirstTimeUser']?.toString() ?? 'true'),
            _buildStatItem(
                'Lector de Pantalla',
                stats['accessibilitySettings']['screenReaderEnabled']
                        ?.toString() ??
                    'false'),
            _buildStatItem(
                'Alto Contraste',
                stats['accessibilitySettings']['highContrastEnabled']
                        ?.toString() ??
                    'false'),
            _buildStatItem(
                'Texto Grande',
                stats['accessibilitySettings']['largeTextEnabled']
                        ?.toString() ??
                    'false'),
            _buildStatItem(
                'Reducir Movimiento',
                stats['accessibilitySettings']['reduceMotionEnabled']
                        ?.toString() ??
                    'false'),
          ],
        ),
      ),
    );
  }

  /// Construir item de estadística
  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
