import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de usabilidad avanzada para la aplicación
/// Maneja modo oscuro/claro, gestos táctiles, tutorial y accesibilidad
class UsabilityService {
  static UsabilityService? _instance;
  static UsabilityService get instance => _instance ??= UsabilityService._();

  UsabilityService._();

  // Stream controllers para notificar cambios
  final StreamController<ThemeMode> _themeModeController =
      StreamController<ThemeMode>.broadcast();
  final StreamController<bool> _tutorialController =
      StreamController<bool>.broadcast();
  final StreamController<AccessibilitySettings> _accessibilityController =
      StreamController<AccessibilitySettings>.broadcast();

  // Configuración actual
  ThemeMode _currentThemeMode = ThemeMode.system;
  bool _isTutorialActive = false;
  AccessibilitySettings _accessibilitySettings = AccessibilitySettings();
  bool _isFirstTimeUser = true;

  // Streams públicos
  Stream<ThemeMode> get themeModeStream => _themeModeController.stream;
  Stream<bool> get tutorialStream => _tutorialController.stream;
  Stream<AccessibilitySettings> get accessibilityStream =>
      _accessibilityController.stream;

  // Getters
  ThemeMode get currentThemeMode => _currentThemeMode;
  bool get isTutorialActive => _isTutorialActive;
  AccessibilitySettings get accessibilitySettings => _accessibilitySettings;
  bool get isFirstTimeUser => _isFirstTimeUser;

  /// Inicializar el servicio
  Future<void> initialize() async {
    await _loadSettings();
    await _checkFirstTimeUser();
    _startThemeAutoDetection();
  }

  /// Cambiar modo de tema
  Future<void> setThemeMode(ThemeMode themeMode) async {
    _currentThemeMode = themeMode;
    _themeModeController.add(themeMode);
    await _saveSettings();
  }

  /// Cambiar a modo oscuro
  Future<void> enableDarkMode() async {
    await setThemeMode(ThemeMode.dark);
  }

  /// Cambiar a modo claro
  Future<void> enableLightMode() async {
    await setThemeMode(ThemeMode.light);
  }

  /// Cambiar a modo automático
  Future<void> enableAutoTheme() async {
    await setThemeMode(ThemeMode.system);
  }

  /// Obtener tema actual basado en configuración
  ThemeData getCurrentTheme(BuildContext context) {
    switch (_currentThemeMode) {
      case ThemeMode.light:
        return _getLightTheme(context);
      case ThemeMode.dark:
        return _getDarkTheme(context);
      case ThemeMode.system:
        final brightness = MediaQuery.of(context).platformBrightness;
        return brightness == Brightness.dark
            ? _getDarkTheme(context)
            : _getLightTheme(context);
    }
  }

  /// Obtener tema claro personalizado
  ThemeData _getLightTheme(BuildContext context) {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      primaryColor: Colors.blue[600],
      scaffoldBackgroundColor: Colors.grey[50],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
      ),
      colorScheme: ColorScheme.light(
        primary: Colors.blue[600]!,
        secondary: Colors.orange[600]!,
        surface: Colors.grey[50]!,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.grey[800]!,
      ),
    );
  }

  /// Obtener tema oscuro personalizado
  ThemeData _getDarkTheme(BuildContext context) {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      primaryColor: Colors.blue[400],
      scaffoldBackgroundColor: Colors.grey[900],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.grey[850],
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[800],
      ),
      colorScheme: ColorScheme.dark(
        primary: Colors.blue[400]!,
        secondary: Colors.orange[400]!,
        surface: Colors.grey[900]!,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
    );
  }

  /// Activar/desactivar tutorial
  Future<void> setTutorialActive(bool active) async {
    _isTutorialActive = active;
    _tutorialController.add(active);
    await _saveSettings();
  }

  /// Marcar tutorial como completado
  Future<void> completeTutorial() async {
    _isFirstTimeUser = false;
    await _saveSettings();
  }

  /// Obtener paso actual del tutorial
  int getCurrentTutorialStep() {
    // Implementar lógica de pasos del tutorial
    return 0;
  }

  /// Actualizar configuración de accesibilidad
  Future<void> updateAccessibilitySettings(
      AccessibilitySettings settings) async {
    _accessibilitySettings = settings;
    _accessibilityController.add(settings);
    await _saveSettings();
  }

  /// Habilitar/deshabilitar VoiceOver/TalkBack
  Future<void> setScreenReaderEnabled(bool enabled) async {
    _accessibilitySettings.screenReaderEnabled = enabled;
    await updateAccessibilitySettings(_accessibilitySettings);
  }

  /// Habilitar/deshabilitar alto contraste
  Future<void> setHighContrastEnabled(bool enabled) async {
    _accessibilitySettings.highContrastEnabled = enabled;
    await updateAccessibilitySettings(_accessibilitySettings);
  }

  /// Habilitar/deshabilitar texto grande
  Future<void> setLargeTextEnabled(bool enabled) async {
    _accessibilitySettings.largeTextEnabled = enabled;
    await updateAccessibilitySettings(_accessibilitySettings);
  }

  /// Habilitar/deshabilitar reducción de movimiento
  Future<void> setReduceMotionEnabled(bool enabled) async {
    _accessibilitySettings.reduceMotionEnabled = enabled;
    await updateAccessibilitySettings(_accessibilitySettings);
  }

  /// Obtener configuración de gestos táctiles
  TouchGestureSettings getTouchGestureSettings() {
    return TouchGestureSettings(
      doubleTapEnabled: true,
      longPressEnabled: true,
      pinchToZoomEnabled: true,
      swipeEnabled: true,
      rotationEnabled: true,
    );
  }

  /// Procesar gesto táctil
  void processTouchGesture(TouchGesture gesture) {
    switch (gesture.type) {
      case TouchGestureType.doubleTap:
        _handleDoubleTap(gesture);
        break;
      case TouchGestureType.longPress:
        _handleLongPress(gesture);
        break;
      case TouchGestureType.pinch:
        _handlePinch(gesture);
        break;
      case TouchGestureType.swipe:
        _handleSwipe(gesture);
        break;
      case TouchGestureType.rotation:
        _handleRotation(gesture);
        break;
    }
  }

  /// Manejar doble tap
  void _handleDoubleTap(TouchGesture gesture) {
    // Implementar lógica de doble tap
    // Por ejemplo: zoom in/out, reset de vista, etc.
  }

  /// Manejar presión larga
  void _handleLongPress(TouchGesture gesture) {
    // Implementar lógica de presión larga
    // Por ejemplo: menú contextual, preview, etc.
  }

  /// Manejar pinch
  void _handlePinch(TouchGesture gesture) {
    // Implementar lógica de pinch
    // Por ejemplo: zoom in/out, ajuste de escala, etc.
  }

  /// Manejar swipe
  void _handleSwipe(TouchGesture gesture) {
    // Implementar lógica de swipe
    // Por ejemplo: navegación entre pantallas, cambio de modo, etc.
  }

  /// Manejar rotación
  void _handleRotation(TouchGesture gesture) {
    // Implementar lógica de rotación
    // Por ejemplo: rotación de vista, ajuste de orientación, etc.
  }

  /// Iniciar detección automática de tema
  void _startThemeAutoDetection() {
    // Implementar detección automática basada en hora del día
    // Por ejemplo: modo oscuro automático después de las 6 PM
    Timer.periodic(const Duration(minutes: 30), (timer) {
      _checkTimeBasedTheme();
    });
  }

  /// Verificar tema basado en hora del día
  void _checkTimeBasedTheme() {
    if (_currentThemeMode == ThemeMode.system) {
      final now = DateTime.now();
      final hour = now.hour;

      // Cambiar a modo oscuro entre 6 PM y 6 AM
      if (hour >= 18 || hour < 6) {
        if (_currentThemeMode != ThemeMode.dark) {
          _themeModeController.add(ThemeMode.dark);
        }
      } else {
        if (_currentThemeMode != ThemeMode.light) {
          _themeModeController.add(ThemeMode.light);
        }
      }
    }
  }

  /// Verificar si es la primera vez del usuario
  Future<void> _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    _isFirstTimeUser = prefs.getBool('is_first_time_user') ?? true;
  }

  /// Cargar configuración guardada
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Cargar tema
    final themeIndex = prefs.getInt('theme_mode') ?? 0;
    _currentThemeMode = ThemeMode.values[themeIndex];

    // Cargar tutorial
    _isTutorialActive = prefs.getBool('tutorial_active') ?? false;

    // Cargar accesibilidad
    final screenReader = prefs.getBool('screen_reader_enabled') ?? false;
    final highContrast = prefs.getBool('high_contrast_enabled') ?? false;
    final largeText = prefs.getBool('large_text_enabled') ?? false;
    final reduceMotion = prefs.getBool('reduce_motion_enabled') ?? false;

    _accessibilitySettings = AccessibilitySettings(
      screenReaderEnabled: screenReader,
      highContrastEnabled: highContrast,
      largeTextEnabled: largeText,
      reduceMotionEnabled: reduceMotion,
    );
  }

  /// Guardar configuración
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Guardar tema
    await prefs.setInt('theme_mode', _currentThemeMode.index);

    // Guardar tutorial
    await prefs.setBool('tutorial_active', _isTutorialActive);
    await prefs.setBool('is_first_time_user', _isFirstTimeUser);

    // Guardar accesibilidad
    await prefs.setBool(
        'screen_reader_enabled', _accessibilitySettings.screenReaderEnabled);
    await prefs.setBool(
        'high_contrast_enabled', _accessibilitySettings.highContrastEnabled);
    await prefs.setBool(
        'large_text_enabled', _accessibilitySettings.largeTextEnabled);
    await prefs.setBool(
        'reduce_motion_enabled', _accessibilitySettings.reduceMotionEnabled);
  }

  /// Obtener estadísticas de usabilidad
  Map<String, dynamic> getUsabilityStats() {
    return {
      'currentTheme': _currentThemeMode.name,
      'tutorialActive': _isTutorialActive,
      'isFirstTimeUser': _isFirstTimeUser,
      'accessibilitySettings': _accessibilitySettings.toJson(),
      'touchGesturesEnabled': getTouchGestureSettings().toJson(),
    };
  }

  /// Liberar recursos
  Future<void> dispose() async {
    await _saveSettings();
    _themeModeController.close();
    _tutorialController.close();
    _accessibilityController.close();
  }
}

/// Configuración de accesibilidad
class AccessibilitySettings {
  bool screenReaderEnabled;
  bool highContrastEnabled;
  bool largeTextEnabled;
  bool reduceMotionEnabled;

  AccessibilitySettings({
    this.screenReaderEnabled = false,
    this.highContrastEnabled = false,
    this.largeTextEnabled = false,
    this.reduceMotionEnabled = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'screenReaderEnabled': screenReaderEnabled,
      'highContrastEnabled': highContrastEnabled,
      'largeTextEnabled': largeTextEnabled,
      'reduceMotionEnabled': reduceMotionEnabled,
    };
  }

  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) {
    return AccessibilitySettings(
      screenReaderEnabled: json['screenReaderEnabled'] ?? false,
      highContrastEnabled: json['highContrastEnabled'] ?? false,
      largeTextEnabled: json['largeTextEnabled'] ?? false,
      reduceMotionEnabled: json['reduceMotionEnabled'] ?? false,
    );
  }
}

/// Configuración de gestos táctiles
class TouchGestureSettings {
  final bool doubleTapEnabled;
  final bool longPressEnabled;
  final bool pinchToZoomEnabled;
  final bool swipeEnabled;
  final bool rotationEnabled;

  TouchGestureSettings({
    required this.doubleTapEnabled,
    required this.longPressEnabled,
    required this.pinchToZoomEnabled,
    required this.swipeEnabled,
    required this.rotationEnabled,
  });

  Map<String, dynamic> toJson() {
    return {
      'doubleTapEnabled': doubleTapEnabled,
      'longPressEnabled': longPressEnabled,
      'pinchToZoomEnabled': pinchToZoomEnabled,
      'swipeEnabled': swipeEnabled,
      'rotationEnabled': rotationEnabled,
    };
  }
}

/// Representación de un gesto táctil
class TouchGesture {
  final TouchGestureType type;
  final Offset position;
  final double? scale;
  final double? rotation;
  final Offset? delta;

  TouchGesture({
    required this.type,
    required this.position,
    this.scale,
    this.rotation,
    this.delta,
  });
}

/// Tipos de gestos táctiles
enum TouchGestureType {
  doubleTap,
  longPress,
  pinch,
  swipe,
  rotation,
}
