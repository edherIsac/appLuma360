import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// Servicio de configuración avanzada para la aplicación
/// Maneja presets, importación/exportación y validación de configuraciones
class AdvancedConfigService {
  static AdvancedConfigService? _instance;
  static AdvancedConfigService get instance =>
      _instance ??= AdvancedConfigService._();

  AdvancedConfigService._();

  // Configuraciones predefinidas
  static const Map<String, Map<String, dynamic>> _defaultPresets = {
    'boda_romantica': {
      'name': 'Boda Romántica',
      'description':
          'Configuración optimizada para bodas con tonos cálidos y efectos suaves',
      'videoEffects': {
        'speed': 0.75,
        'colorFilter': 'warm',
        'brightness': 1.1,
        'contrast': 1.05,
        'saturation': 1.2,
        'stabilization': 'medium',
      },
      'audioSettings': {
        'backgroundVolume': 0.3,
        'fadeIn': 1.0,
        'fadeOut': 1.0,
      },
      'outputSettings': {
        'quality': 'high',
        'format': 'mp4',
        'resolution': '720p',
      }
    },
    'xv_años_festivo': {
      'name': 'XV Años Festivo',
      'description':
          'Configuración vibrante para XV años con colores llamativos',
      'videoEffects': {
        'speed': 1.0,
        'colorFilter': 'vibrant',
        'brightness': 1.15,
        'contrast': 1.1,
        'saturation': 1.3,
        'stabilization': 'high',
      },
      'audioSettings': {
        'backgroundVolume': 0.4,
        'fadeIn': 0.5,
        'fadeOut': 0.5,
      },
      'outputSettings': {
        'quality': 'high',
        'format': 'mp4',
        'resolution': '720p',
      }
    },
    'graduacion_elegante': {
      'name': 'Graduación Elegante',
      'description':
          'Configuración profesional para graduaciones con tonos sobrios',
      'videoEffects': {
        'speed': 0.85,
        'colorFilter': 'elegant',
        'brightness': 1.0,
        'contrast': 1.15,
        'saturation': 0.9,
        'stabilization': 'high',
      },
      'audioSettings': {
        'backgroundVolume': 0.25,
        'fadeIn': 1.5,
        'fadeOut': 1.5,
      },
      'outputSettings': {
        'quality': 'ultra',
        'format': 'mp4',
        'resolution': '1080p',
      }
    },
    'evento_corporativo': {
      'name': 'Evento Corporativo',
      'description': 'Configuración profesional para eventos empresariales',
      'videoEffects': {
        'speed': 1.0,
        'colorFilter': 'professional',
        'brightness': 1.05,
        'contrast': 1.1,
        'saturation': 0.95,
        'stabilization': 'ultra',
      },
      'audioSettings': {
        'backgroundVolume': 0.2,
        'fadeIn': 2.0,
        'fadeOut': 2.0,
      },
      'outputSettings': {
        'quality': 'ultra',
        'format': 'mp4',
        'resolution': '1080p',
      }
    }
  };

  // Historial de configuraciones
  final List<ConfigurationHistory> _configHistory = [];
  final int _maxHistorySize = 50;

  // Configuración actual
  Map<String, dynamic>? _currentConfig;

  /// Inicializar el servicio
  Future<void> initialize() async {
    await _loadCurrentConfig();
    await _loadConfigHistory();
  }

  /// Obtener todos los presets disponibles
  Map<String, Map<String, dynamic>> get availablePresets =>
      Map.unmodifiable(_defaultPresets);

  /// Obtener preset por ID
  Map<String, dynamic>? getPreset(String presetId) {
    return _defaultPresets[presetId];
  }

  /// Aplicar preset a la configuración actual
  Future<void> applyPreset(String presetId) async {
    final preset = _defaultPresets[presetId];
    if (preset != null) {
      _currentConfig = Map.from(preset);
      await _saveCurrentConfig();
      await _addToHistory('Preset aplicado: ${preset['name']}', preset);
    }
  }

  /// Obtener configuración actual
  Map<String, dynamic>? get currentConfig =>
      _currentConfig != null ? Map.unmodifiable(_currentConfig!) : null;

  /// Actualizar configuración actual
  Future<void> updateCurrentConfig(Map<String, dynamic> newConfig) async {
    _currentConfig = Map.from(newConfig);
    await _saveCurrentConfig();
    await _addToHistory('Configuración actualizada manualmente', newConfig);
  }

  /// Obtener historial de configuraciones
  List<ConfigurationHistory> get configHistory =>
      List.unmodifiable(_configHistory);

  /// Exportar configuración actual
  Future<String> exportCurrentConfig() async {
    if (_currentConfig == null) {
      throw Exception('No hay configuración actual para exportar');
    }

    final exportData = {
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0.0',
      'config': _currentConfig,
      'metadata': {
        'exportedBy': 'Cabina 360 v21',
        'device': Platform.operatingSystem,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }
    };

    return jsonEncode(exportData);
  }

  /// Exportar configuración a archivo
  Future<File> exportConfigToFile(String filename) async {
    final exportData = await exportCurrentConfig();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename.json');
    await file.writeAsString(exportData);
    return file;
  }

  /// Importar configuración desde JSON
  Future<void> importConfigFromJson(String jsonData) async {
    try {
      final importData = jsonDecode(jsonData) as Map<String, dynamic>;

      // Validar estructura del archivo importado
      if (!_validateImportStructure(importData)) {
        throw Exception('Formato de archivo de configuración inválido');
      }

      final config = importData['config'] as Map<String, dynamic>;

      // Validar configuración importada
      if (!_validateConfiguration(config)) {
        throw Exception(
            'Configuración importada contiene parámetros inválidos');
      }

      _currentConfig = Map.from(config);
      await _saveCurrentConfig();
      await _addToHistory('Configuración importada desde archivo', config);
    } catch (e) {
      throw Exception('Error al importar configuración: $e');
    }
  }

  /// Importar configuración desde archivo
  Future<void> importConfigFromFile(File file) async {
    try {
      final jsonData = await file.readAsString();
      await importConfigFromJson(jsonData);
    } catch (e) {
      throw Exception('Error al leer archivo de configuración: $e');
    }
  }

  /// Validar configuración en tiempo real
  ValidationResult validateConfiguration(Map<String, dynamic> config) {
    final errors = <String>[];
    final warnings = <String>[];

    // Validar efectos de video
    if (config.containsKey('videoEffects')) {
      final videoEffects = config['videoEffects'] as Map<String, dynamic>;

      // Validar velocidad
      if (videoEffects.containsKey('speed')) {
        final speed = videoEffects['speed'] as num;
        if (speed < 0.1 || speed > 5.0) {
          errors.add('La velocidad debe estar entre 0.1x y 5.0x');
        } else if (speed < 0.5) {
          warnings
              .add('Velocidad muy baja puede resultar en videos muy largos');
        }
      }

      // Validar brillo
      if (videoEffects.containsKey('brightness')) {
        final brightness = videoEffects['brightness'] as num;
        if (brightness < 0.1 || brightness > 3.0) {
          errors.add('El brillo debe estar entre 0.1 y 3.0');
        }
      }

      // Validar contraste
      if (videoEffects.containsKey('contrast')) {
        final contrast = videoEffects['contrast'] as num;
        if (contrast < 0.1 || contrast > 3.0) {
          errors.add('El contraste debe estar entre 0.1 y 3.0');
        }
      }

      // Validar saturación
      if (videoEffects.containsKey('saturation')) {
        final saturation = videoEffects['saturation'] as num;
        if (saturation < 0.0 || saturation > 3.0) {
          errors.add('La saturación debe estar entre 0.0 y 3.0');
        }
      }
    }

    // Validar configuración de audio
    if (config.containsKey('audioSettings')) {
      final audioSettings = config['audioSettings'] as Map<String, dynamic>;

      if (audioSettings.containsKey('backgroundVolume')) {
        final volume = audioSettings['backgroundVolume'] as num;
        if (volume < 0.0 || volume > 1.0) {
          errors.add('El volumen de fondo debe estar entre 0.0 y 1.0');
        }
      }
    }

    // Validar configuración de salida
    if (config.containsKey('outputSettings')) {
      final outputSettings = config['outputSettings'] as Map<String, dynamic>;

      if (outputSettings.containsKey('quality')) {
        final quality = outputSettings['quality'] as String;
        if (!['low', 'medium', 'high', 'ultra'].contains(quality)) {
          errors.add('Calidad de salida debe ser: low, medium, high o ultra');
        }
      }

      if (outputSettings.containsKey('resolution')) {
        final resolution = outputSettings['resolution'] as String;
        if (!['480p', '720p', '1080p', '4K'].contains(resolution)) {
          errors.add('Resolución debe ser: 480p, 720p, 1080p o 4K');
        }
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Crear preset personalizado
  Future<void> createCustomPreset(
      String name, String description, Map<String, dynamic> config) async {
    // Validar configuración antes de crear preset
    final validation = validateConfiguration(config);
    if (!validation.isValid) {
      throw Exception(
          'Configuración inválida: ${validation.errors.join(', ')}');
    }

    final customPreset = {
      'name': name,
      'description': description,
      'isCustom': true,
      'createdAt': DateTime.now().toIso8601String(),
      ...config,
    };

    // Guardar preset personalizado
    final prefs = await SharedPreferences.getInstance();
    final customPresets = prefs.getStringList('custom_presets') ?? [];
    customPresets.add(jsonEncode(customPreset));
    await prefs.setStringList('custom_presets', customPresets);

    await _addToHistory('Preset personalizado creado: $name', customPreset);
  }

  /// Obtener presets personalizados
  Future<List<Map<String, dynamic>>> getCustomPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final customPresetsData = prefs.getStringList('custom_presets') ?? [];

    return customPresetsData
        .map((data) => jsonDecode(data) as Map<String, dynamic>)
        .toList();
  }

  /// Eliminar preset personalizado
  Future<void> deleteCustomPreset(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final customPresets = prefs.getStringList('custom_presets') ?? [];

    final updatedPresets = customPresets.where((data) {
      final preset = jsonDecode(data) as Map<String, dynamic>;
      return preset['name'] != name;
    }).toList();

    await prefs.setStringList('custom_presets', updatedPresets);
    await _addToHistory('Preset personalizado eliminado: $name', {});
  }

  /// Limpiar historial
  Future<void> clearHistory() async {
    _configHistory.clear();
    await _saveConfigHistory();
  }

  /// Obtener estadísticas de uso
  Map<String, dynamic> getUsageStats() {
    final totalConfigs = _configHistory.length;
    final customPresetsCount = _configHistory
        .where((entry) => entry.description.contains('personalizado'))
        .length;

    final mostUsedPreset = _getMostUsedPreset();

    return {
      'totalConfigurations': totalConfigs,
      'customPresetsCreated': customPresetsCount,
      'mostUsedPreset': mostUsedPreset,
      'lastConfiguration': _configHistory.isNotEmpty
          ? _configHistory.first.timestamp.toIso8601String()
          : null,
    };
  }

  // Métodos privados

  Future<void> _loadCurrentConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString('current_config');
    if (configJson != null) {
      try {
        _currentConfig = jsonDecode(configJson) as Map<String, dynamic>;
      } catch (e) {
        // Si hay error, usar configuración por defecto
        _currentConfig = Map.from(_defaultPresets['boda_romantica']!);
      }
    } else {
      // Configuración por defecto
      _currentConfig = Map.from(_defaultPresets['boda_romantica']!);
    }
  }

  Future<void> _saveCurrentConfig() async {
    if (_currentConfig != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_config', jsonEncode(_currentConfig));
    }
  }

  Future<void> _loadConfigHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('config_history') ?? [];

    _configHistory.clear();
    for (final entryJson in historyJson) {
      try {
        final entry = jsonDecode(entryJson) as Map<String, dynamic>;
        _configHistory.add(ConfigurationHistory.fromJson(entry));
      } catch (e) {
        // Ignorar entradas corruptas
      }
    }
  }

  Future<void> _saveConfigHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson =
        _configHistory.map((entry) => jsonEncode(entry.toJson())).toList();
    await prefs.setStringList('config_history', historyJson);
  }

  Future<void> _addToHistory(
      String description, Map<String, dynamic> config) async {
    final entry = ConfigurationHistory(
      timestamp: DateTime.now(),
      description: description,
      config: config,
    );

    _configHistory.insert(0, entry);

    // Mantener tamaño máximo del historial
    if (_configHistory.length > _maxHistorySize) {
      _configHistory.removeRange(_maxHistorySize, _configHistory.length);
    }

    await _saveConfigHistory();
  }

  bool _validateImportStructure(Map<String, dynamic> importData) {
    return importData.containsKey('config') &&
        importData.containsKey('version') &&
        importData.containsKey('timestamp');
  }

  bool _validateConfiguration(Map<String, dynamic> config) {
    final validation = validateConfiguration(config);
    return validation.isValid;
  }

  String? _getMostUsedPreset() {
    if (_configHistory.isEmpty) return null;

    final presetCounts = <String, int>{};
    for (final entry in _configHistory) {
      if (entry.description.contains('Preset aplicado:')) {
        final presetName = entry.description.split('Preset aplicado: ')[1];
        presetCounts[presetName] = (presetCounts[presetName] ?? 0) + 1;
      }
    }

    if (presetCounts.isEmpty) return null;

    final mostUsed =
        presetCounts.entries.reduce((a, b) => a.value > b.value ? a : b);

    return mostUsed.key;
  }

  /// Liberar recursos
  Future<void> dispose() async {
    await _saveCurrentConfig();
    await _saveConfigHistory();
  }
}

/// Clase para representar una entrada del historial de configuraciones
class ConfigurationHistory {
  final DateTime timestamp;
  final String description;
  final Map<String, dynamic> config;

  ConfigurationHistory({
    required this.timestamp,
    required this.description,
    required this.config,
  });

  factory ConfigurationHistory.fromJson(Map<String, dynamic> json) {
    return ConfigurationHistory(
      timestamp: DateTime.parse(json['timestamp'] as String),
      description: json['description'] as String,
      config: Map<String, dynamic>.from(json['config'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'config': config,
    };
  }
}

/// Clase para representar el resultado de validación
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}
