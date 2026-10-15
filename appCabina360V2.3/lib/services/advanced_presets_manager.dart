import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'advanced_video_editing_service.dart';

/// Gestor de presets avanzados para Cabina 360
/// Maneja la carga, guardado y gestión de presets con estructura JSON
class AdvancedPresetsManager {
  static AdvancedPresetsManager? _instance;
  static AdvancedPresetsManager get instance =>
      _instance ??= AdvancedPresetsManager._();

  AdvancedPresetsManager._();

  // Lista de presets cargados
  List<AdvancedPreset> _availablePresets = [];

  // Preset seleccionado actualmente
  AdvancedPreset? _selectedPreset;

  // Cache de presets por categoría
  final Map<String, List<AdvancedPreset>> _presetsByCategory = {};

  // Getters
  List<AdvancedPreset> get availablePresets => _availablePresets;
  AdvancedPreset? get selectedPreset => _selectedPreset;
  bool get hasPresetSelected => _selectedPreset != null;

  /// Inicializa el gestor
  Future<void> initialize() async {
    try {
      await _loadPresetsFromAssets();
      await _loadSelectedPreset();
      await _organizePresetsByCategory();

      print(
          '✅ AdvancedPresetsManager inicializado con ${_availablePresets.length} presets');
    } catch (e) {
      print('❌ Error inicializando AdvancedPresetsManager: $e');
      rethrow;
    }
  }

  /// Carga presets desde el archivo de assets
  Future<void> _loadPresetsFromAssets() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/presets/advanced_presets.json');
      final jsonList = json.decode(jsonString) as List;

      _availablePresets =
          jsonList.map((json) => AdvancedPreset.fromJson(json)).toList();

      print('📁 Cargados ${_availablePresets.length} presets avanzados');
    } catch (e) {
      print('❌ Error cargando presets desde assets: $e');
      // Crear presets por defecto si falla la carga
      _createDefaultPresets();
    }
  }

  /// Crea presets por defecto si falla la carga
  void _createDefaultPresets() {
    _availablePresets = [
      AdvancedPreset(
        name: 'Boomerang Simple',
        description: 'Efecto boomerang básico para todo el video',
        blocks: [
          VideoBlock(
            range: const VideoRange(startPercentage: 0.0, endPercentage: 1.0),
            effects: [
              const BlockEffect(
                type: EffectType.boomerang,
                intensity: 1.0,
              ),
            ],
          ),
        ],
      ),
      AdvancedPreset(
        name: 'VHS Vintage',
        description: 'Efecto VHS vintage para todo el video',
        blocks: [
          VideoBlock(
            range: const VideoRange(startPercentage: 0.0, endPercentage: 1.0),
            effects: [
              const BlockEffect(
                type: EffectType.vhs,
                intensity: 1.0,
              ),
            ],
          ),
        ],
      ),
    ];

    print('🔄 Creados ${_availablePresets.length} presets por defecto');
  }

  /// Organiza presets por categoría
  Future<void> _organizePresetsByCategory() async {
    _presetsByCategory.clear();

    for (final preset in _availablePresets) {
      final category = preset.metadata['category'] ?? 'general';
      _presetsByCategory.putIfAbsent(category, () => []).add(preset);
    }

    print('📂 Presets organizados en ${_presetsByCategory.length} categorías');
  }

  /// Obtiene presets por categoría
  List<AdvancedPreset> getPresetsByCategory(String category) {
    return _presetsByCategory[category] ?? [];
  }

  /// Obtiene todas las categorías disponibles
  List<String> getAvailableCategories() {
    return _presetsByCategory.keys.toList();
  }

  /// Selecciona un preset
  Future<void> selectPreset(AdvancedPreset preset) async {
    _selectedPreset = preset;
    await _saveSelectedPreset();
    print('🎬 Preset avanzado seleccionado: ${preset.name}');
  }

  /// Limpia el preset seleccionado
  Future<void> clearPreset() async {
    _selectedPreset = null;
    await _saveSelectedPreset();
    print('🧹 Preset avanzado limpiado');
  }

  /// Obtiene preset por nombre
  AdvancedPreset? getPresetByName(String name) {
    try {
      return _availablePresets.firstWhere(
        (preset) => preset.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Obtiene presets por dificultad
  List<AdvancedPreset> getPresetsByDifficulty(String difficulty) {
    return _availablePresets.where((preset) {
      final presetDifficulty = preset.metadata['difficulty'] ?? 'medium';
      return presetDifficulty.toLowerCase() == difficulty.toLowerCase();
    }).toList();
  }

  /// Obtiene presets por tiempo estimado
  List<AdvancedPreset> getPresetsByEstimatedTime(String timeRange) {
    return _availablePresets.where((preset) {
      final estimatedTime =
          preset.metadata['estimatedTime'] ?? '2x video duration';
      return estimatedTime.contains(timeRange);
    }).toList();
  }

  /// Busca presets por texto
  List<AdvancedPreset> searchPresets(String query) {
    if (query.isEmpty) return _availablePresets;

    final lowercaseQuery = query.toLowerCase();
    return _availablePresets.where((preset) {
      return preset.name.toLowerCase().contains(lowercaseQuery) ||
          preset.description.toLowerCase().contains(lowercaseQuery) ||
          preset.metadata['category']
                  ?.toString()
                  .toLowerCase()
                  .contains(lowercaseQuery) ==
              true;
    }).toList();
  }

  /// Aplica el preset seleccionado a un video
  Future<String> applySelectedPreset({
    required String inputVideoPath,
    Function(double)? onProgress,
  }) async {
    if (_selectedPreset == null) {
      print(
          '⚠️ No hay preset avanzado seleccionado, retornando video original');
      return inputVideoPath;
    }

    try {
      print('🎬 Aplicando preset avanzado: ${_selectedPreset!.name}');

      final editingService = AdvancedVideoEditingService.instance;
      final outputPath = await editingService.applyAdvancedPreset(
        inputPath: inputVideoPath,
        preset: _selectedPreset!,
        onProgress: onProgress,
      );

      print('✅ Preset avanzado aplicado exitosamente');
      return outputPath;
    } catch (e) {
      print('❌ Error aplicando preset avanzado: $e, retornando video original');
      return inputVideoPath;
    }
  }

  /// Crea un preset personalizado
  Future<AdvancedPreset> createCustomPreset({
    required String name,
    required String description,
    required List<VideoBlock> blocks,
    Map<String, dynamic> metadata = const {},
  }) async {
    final customPreset = AdvancedPreset(
      name: name,
      description: description,
      blocks: blocks,
      metadata: {
        'category': 'custom',
        'difficulty': 'custom',
        'estimatedTime': 'variable',
        'createdAt': DateTime.now().toIso8601String(),
        ...metadata,
      },
    );

    // Agregar a la lista de presets disponibles
    _availablePresets.add(customPreset);

    // Reorganizar por categoría
    await _organizePresetsByCategory();

    // Guardar preset personalizado
    await _saveCustomPreset(customPreset);

    print('✨ Preset personalizado creado: $name');
    return customPreset;
  }

  /// Guarda un preset personalizado
  Future<void> _saveCustomPreset(AdvancedPreset preset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customPresets =
          prefs.getStringList('custom_advanced_presets') ?? [];

      // Convertir preset a JSON y agregar a la lista
      final presetJson = json.encode(preset.toJson());
      customPresets.add(presetJson);

      await prefs.setStringList('custom_advanced_presets', customPresets);
      print('💾 Preset personalizado guardado');
    } catch (e) {
      print('❌ Error guardando preset personalizado: $e');
    }
  }

  /// Carga presets personalizados guardados
  // ignore: unused_element
  Future<void> _loadCustomPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customPresetsJson =
          prefs.getStringList('custom_advanced_presets') ?? [];

      for (final presetJson in customPresetsJson) {
        try {
          final presetData = json.decode(presetJson);
          final customPreset = AdvancedPreset.fromJson(presetData);

          // Verificar que no esté duplicado
          if (!_availablePresets.any((p) => p.name == customPreset.name)) {
            _availablePresets.add(customPreset);
          }
        } catch (e) {
          print('⚠️ Error cargando preset personalizado: $e');
        }
      }

      print('📁 Cargados ${customPresetsJson.length} presets personalizados');
    } catch (e) {
      print('❌ Error cargando presets personalizados: $e');
    }
  }

  /// Elimina un preset personalizado
  Future<void> deleteCustomPreset(AdvancedPreset preset) async {
    try {
      // Solo se pueden eliminar presets personalizados
      if (preset.metadata['category'] != 'custom') {
        throw Exception('Solo se pueden eliminar presets personalizados');
      }

      // Remover de la lista
      _availablePresets.removeWhere((p) => p.name == preset.name);

      // Remover de SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final customPresets =
          prefs.getStringList('custom_advanced_presets') ?? [];

      customPresets.removeWhere((presetJson) {
        try {
          final presetData = json.decode(presetJson);
          return presetData['presetName'] == preset.name;
        } catch (e) {
          return false;
        }
      });

      await prefs.setStringList('custom_advanced_presets', customPresets);

      // Reorganizar por categoría
      await _organizePresetsByCategory();

      print('🗑️ Preset personalizado eliminado: ${preset.name}');
    } catch (e) {
      print('❌ Error eliminando preset personalizado: $e');
      rethrow;
    }
  }

  /// Exporta un preset a JSON
  String exportPresetToJson(AdvancedPreset preset) {
    return json.encode(preset.toJson());
  }

  /// Importa un preset desde JSON
  Future<AdvancedPreset?> importPresetFromJson(String jsonString) async {
    try {
      final presetData = json.decode(jsonString);
      var preset = AdvancedPreset.fromJson(presetData);

      // Verificar que no esté duplicado
      if (_availablePresets.any((p) => p.name == preset.name)) {
        // Agregar sufijo para evitar duplicados
        preset = AdvancedPreset(
          name: '${preset.name} (Importado)',
          description: preset.description,
          blocks: preset.blocks,
          metadata: preset.metadata,
        );
      }

      // Agregar a la lista
      _availablePresets.add(preset);

      // Reorganizar por categoría
      await _organizePresetsByCategory();

      print('📥 Preset importado: ${preset.name}');
      return preset;
    } catch (e) {
      print('❌ Error importando preset: $e');
      return null;
    }
  }

  // Métodos privados

  Future<void> _loadSelectedPreset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final presetName = prefs.getString('selected_advanced_preset');

      if (presetName != null) {
        final preset = getPresetByName(presetName);
        if (preset != null) {
          _selectedPreset = preset;
          print('📁 Preset avanzado cargado: $presetName');
        }
      }
    } catch (e) {
      print('⚠️ Error cargando preset avanzado seleccionado: $e');
    }
  }

  Future<void> _saveSelectedPreset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_selectedPreset != null) {
        await prefs.setString(
            'selected_advanced_preset', _selectedPreset!.name);
      } else {
        await prefs.remove('selected_advanced_preset');
      }
    } catch (e) {
      print('❌ Error guardando preset avanzado seleccionado: $e');
    }
  }

  /// Limpia todos los recursos
  Future<void> cleanup() async {
    try {
      _availablePresets.clear();
      _presetsByCategory.clear();
      _selectedPreset = null;
      print('🧹 AdvancedPresetsManager limpiado');
    } catch (e) {
      print('❌ Error limpiando AdvancedPresetsManager: $e');
    }
  }
}
