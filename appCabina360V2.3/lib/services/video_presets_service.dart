import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de presets de video para Cabina 360
/// Maneja presets predefinidos que se aplican automáticamente al finalizar la grabación
class VideoPresetsService {
  static VideoPresetsService? _instance;
  static VideoPresetsService get instance =>
      _instance ??= VideoPresetsService._();

  VideoPresetsService._();

  // Preset seleccionado actualmente
  VideoPreset? _selectedPreset;

  // Getters
  VideoPreset? get selectedPreset => _selectedPreset;
  bool get hasPresetSelected => _selectedPreset != null;

  /// Inicializar el servicio
  Future<void> initialize() async {
    try {
      await _loadSelectedPreset();
      print('✅ VideoPresetsService inicializado');
    } catch (e) {
      print('❌ Error inicializando VideoPresetsService: $e');
    }
  }

  /// Seleccionar un preset
  Future<void> selectPreset(VideoPreset preset) async {
    _selectedPreset = preset;
    await _saveSelectedPreset();
    print('🎬 Preset seleccionado: ${preset.name}');
  }

  /// Limpiar preset seleccionado
  Future<void> clearPreset() async {
    _selectedPreset = null;
    await _saveSelectedPreset();
    print('🧹 Preset limpiado');
  }

  /// Aplicar preset al video finalizado
  Future<String> applyPresetToVideo({
    required String inputVideoPath,
    Function(double)? onProgress,
  }) async {
    if (_selectedPreset == null) {
      print('⚠️ No hay preset seleccionado, retornando video original');
      return inputVideoPath;
    }

    try {
      print('🎬 Aplicando preset: ${_selectedPreset!.name}');

      final outputPath =
          await _generateOutputPath('preset_${_selectedPreset!.key}');
      final command = _buildPresetCommand(inputVideoPath, outputPath);

      print('📝 Comando FFmpeg: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('✅ Preset aplicado exitosamente');
        return outputPath;
      } else {
        print('❌ Error aplicando preset, retornando video original');
        return inputVideoPath;
      }
    } catch (e) {
      print('❌ Error aplicando preset: $e, retornando video original');
      return inputVideoPath;
    }
  }

  /// Obtener todos los presets disponibles
  List<VideoPreset> getAvailablePresets() {
    return [
      VideoPreset(
        key: 'boda_romantica',
        name: 'Boda Romántica',
        description: 'Efectos románticos soñadores con tonos dorados y suaves',
        type: EventType.boda,
        effects: [
          PresetEffect.slowMotion,
          PresetEffect.romanticDreamy,
          PresetEffect.goldenHour,
          PresetEffect.softGlow,
        ],
      ),
      VideoPreset(
        key: 'boda_vintage',
        name: 'Boda Vintage',
        description: 'Estilo vintage clásico con sepia y viñeta',
        type: EventType.boda,
        effects: [
          PresetEffect.vintageWedding,
          PresetEffect.elegantSepia,
          PresetEffect.warmFilter,
        ],
      ),
      VideoPreset(
        key: 'xv_años_festivo',
        name: 'XV Años Festivo',
        description: 'Efectos dinámicos y festivos para celebraciones',
        type: EventType.xvAnos,
        effects: [
          PresetEffect.variableSpeed,
          PresetEffect.celebrationFilter,
          PresetEffect.sparkleEffect,
        ],
      ),
      VideoPreset(
        key: 'graduacion_elegante',
        name: 'Graduación Elegante',
        description: 'Efectos académicos distintivos en sepia y alto contraste',
        type: EventType.graduacion,
        effects: [
          PresetEffect.elegantSepia,
          PresetEffect.formalBlackWhite,
          PresetEffect.academicGlow,
          PresetEffect.cinematicStyle,
        ],
      ),
      VideoPreset(
        key: 'evento_corporativo',
        name: 'Evento Corporativo',
        description: 'Efectos corporativos y formales',
        type: EventType.corporativo,
        effects: [
          PresetEffect.professionalFilter,
          PresetEffect.sharpness,
          PresetEffect.clarity,
        ],
      ),
      VideoPreset(
        key: 'cuadrantes_multiples',
        name: 'Cuadrantes Múltiples',
        description:
            '4 efectos en pantalla dividida: cámara lenta, vintage, B&W, triple reverse',
        type: EventType.none,
        effects: [
          PresetEffect.quadrantSplit,
        ],
      ),
      VideoPreset(
        key: 'sin_efectos',
        name: 'Sin Efectos',
        description: 'Video original sin modificaciones',
        type: EventType.none,
        effects: [],
      ),
    ];
  }

  /// Obtener preset por tipo de evento
  VideoPreset? getPresetByEventType(EventType eventType) {
    final presets = getAvailablePresets();
    try {
      return presets.firstWhere(
        (preset) => preset.type == eventType,
      );
    } catch (e) {
      return null;
    }
  }

  // Métodos privados

  String _buildPresetCommand(String inputPath, String outputPath) {
    if (_selectedPreset == null) {
      return '-i "$inputPath" -c copy -y "$outputPath"';
    }

    final effects = _selectedPreset!.effects;
    final filters = <String>[];

    // Aplicar efectos según el preset
    for (final effect in effects) {
      switch (effect) {
        case PresetEffect.slowMotion:
          filters.add('setpts=2.0*PTS'); // Cámara lenta 0.5x
          break;
        case PresetEffect.warmFilter:
          filters.add('colortemperature=6500'); // Tonos cálidos
          filters.add('eq=brightness=0.02:contrast=1.05');
          break;
        case PresetEffect.softGlow:
          filters.add('gblur=sigma=0.3'); // Glow suave
          break;
        case PresetEffect.variableSpeed:
          // Velocidad variable: lenta al inicio, rápida al final
          filters
              .add('setpts=\'if(lt(T,5),1.5*PTS,if(lt(T,10),0.75*PTS,PTS))\'');
          break;
        case PresetEffect.celebrationFilter:
          filters.add('eq=saturation=1.3:contrast=1.2'); // Colores vibrantes
          break;
        case PresetEffect.sparkleEffect:
          filters.add('unsharp=3:3:1.5:3:3:0.5'); // Efecto sparkle
          break;
        case PresetEffect.eleganceFilter:
          filters.add('eq=contrast=1.15:brightness=0.01'); // Elegancia
          break;
        case PresetEffect.blackWhiteBalance:
          filters.add('hue=s=0'); // Blanco y negro
          break;
        case PresetEffect.cinematicStyle:
          filters.add(
              'colorbalance=rs=0.05:gs=0:bs=-0.05'); // Estilo cinematográfico
          break;
        case PresetEffect.professionalFilter:
          filters.add('unsharp=5:5:1.2:5:5:0.0'); // Nitidez profesional
          break;
        case PresetEffect.sharpness:
          filters.add('eq=contrast=1.1:brightness=0.02'); // Nitidez
          break;
        case PresetEffect.clarity:
          filters.add('eq=contrast=1.2:brightness=0.01'); // Claridad
          break;
        case PresetEffect.quadrantSplit:
          // Efecto especial: dividir pantalla en 4 cuadrantes con efectos diferentes
          return _buildQuadrantSplitCommand(inputPath, outputPath);
        // NUEVOS EFECTOS DISTINTIVOS
        case PresetEffect.romanticDreamy:
          // Efecto romántico soñador: desenfoque suave + tonos rosados + brillo
          filters.add('gblur=sigma=0.8'); // Desenfoque soñador
          filters.add(
              'colorbalance=rs=0.15:gs=0.05:bs=-0.05'); // Tonos rosados cálidos
          filters.add(
              'eq=brightness=0.05:contrast=1.1:saturation=1.1'); // Brillo romántico
          break;
        case PresetEffect.vintageWedding:
          // Efecto vintage de boda: sepia + viñeta + grano
          filters.add(
              'colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131'); // Sepia
          filters.add('vignette=PI/4'); // Viñeta oscura
          filters.add('noise=alls=20:allf=t'); // Grano vintage
          break;
        case PresetEffect.goldenHour:
          // Efecto hora dorada: tonos dorados cálidos + contraste suave
          filters.add('colortemperature=3200'); // Temperatura cálida
          filters.add('colorbalance=rs=0.2:gs=0.1:bs=-0.1'); // Tonos dorados
          filters.add(
              'eq=brightness=0.03:contrast=1.15:saturation=1.2'); // Calidez dorada
          break;
        case PresetEffect.elegantSepia:
          // Sepia elegante: sepia profesional + contraste elegante
          filters.add(
              'colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131'); // Sepia
          filters.add('eq=contrast=1.25:brightness=0.02'); // Contraste elegante
          break;
        case PresetEffect.formalBlackWhite:
          // Blanco y negro formal: alto contraste + nitidez
          filters.add('hue=s=0'); // Blanco y negro
          filters
              .add('eq=contrast=1.4:brightness=-0.01'); // Alto contraste formal
          filters.add('unsharp=5:5:1.0:5:5:0.0'); // Nitidez profesional
          break;
        case PresetEffect.academicGlow:
          // Brillo académico: glow sutil + claridad + tonos neutros
          filters.add('gblur=sigma=0.4'); // Glow académico sutil
          filters.add('eq=contrast=1.2:brightness=0.04'); // Claridad
          filters.add(
              'colorbalance=rs=0.02:gs=0.01:bs=0.02'); // Tonos neutros académicos
          break;
      }
    }

    if (filters.isEmpty) {
      // Sin efectos, solo copiar
      return '-i "$inputPath" -c copy -y "$outputPath"';
    }

    // Aplicar filtros
    final filterString = filters.join(',');
    return '-i "$inputPath" -vf "$filterString" -c:a copy -c:v libx264 -preset medium -crf 23 -y "$outputPath"';
  }

  /// Comando especial para dividir pantalla en 4 cuadrantes con efectos mejorados
  String _buildQuadrantSplitCommand(String inputPath, String outputPath) {
    // Obtener dimensiones del video (asumimos 480x720 basado en los logs)
    final width = 480;
    final height = 720;
    final halfWidth = width ~/ 2;
    final halfHeight = height ~/ 2;

    // Crear 4 versiones del video con efectos diferentes
    // Cuadrante 1: Cámara lenta (esquina superior izquierda) - 2x más lento
    // Cuadrante 2: Efecto vintage (esquina superior derecha) - sepia + viñeta + grano
    // Cuadrante 3: Blanco y negro (esquina inferior izquierda) - B&W + alto contraste + nitidez
    // Cuadrante 4: 3x reverse alternando (esquina inferior derecha) - efecto de rebobinado triple

    return '''
      -i "$inputPath" -i "$inputPath" -i "$inputPath" -i "$inputPath" 
      -filter_complex "
        [0:v]setpts=2.0*PTS,scale=$halfWidth:$halfHeight[slow];
        [1:v]colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131,vignette=PI/4,noise=alls=20:allf=t,scale=$halfWidth:$halfHeight[vintage];
        [2:v]hue=s=0,eq=contrast=1.4:brightness=-0.01,unsharp=5:5:1.0:5:5:0.0,scale=$halfWidth:$halfHeight[bw];
        [3:v]reverse,reverse,reverse,scale=$halfWidth:$halfHeight[triple_reverse];
        [slow][vintage]hstack=inputs=2[top];
        [bw][triple_reverse]hstack=inputs=2[bottom];
        [top][bottom]vstack=inputs=2[out]
      "
      -map "[out]" -map 0:a -c:v libx264 -preset medium -crf 23 -c:a copy -y "$outputPath"
    '''
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<String> _generateOutputPath(String prefix) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempDir = Directory.systemTemp;
    final effectsDir = Directory('${tempDir.path}/video_presets');

    if (!await effectsDir.exists()) {
      await effectsDir.create(recursive: true);
    }

    return '${effectsDir.path}/${prefix}_$timestamp.mp4';
  }

  Future<void> _loadSelectedPreset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final presetKey = prefs.getString('selected_video_preset');

      if (presetKey != null) {
        final presets = getAvailablePresets();
        try {
          _selectedPreset = presets.firstWhere(
            (preset) => preset.key == presetKey,
          );
        } catch (e) {
          _selectedPreset = null;
        }
      }
    } catch (e) {
      print('⚠️ Error cargando preset seleccionado: $e');
    }
  }

  Future<void> _saveSelectedPreset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_selectedPreset != null) {
        await prefs.setString('selected_video_preset', _selectedPreset!.key);
      } else {
        await prefs.remove('selected_video_preset');
      }
    } catch (e) {
      print('❌ Error guardando preset seleccionado: $e');
    }
  }
}

/// Tipos de eventos
enum EventType {
  boda,
  xvAnos,
  graduacion,
  corporativo,
  none,
}

/// Efectos disponibles en presets
enum PresetEffect {
  slowMotion, // Cámara lenta
  warmFilter, // Filtro cálido
  softGlow, // Glow suave
  variableSpeed, // Velocidad variable
  celebrationFilter, // Filtro de celebración
  sparkleEffect, // Efecto sparkle
  eleganceFilter, // Filtro elegante
  blackWhiteBalance, // Balance B&W
  cinematicStyle, // Estilo cinematográfico
  professionalFilter, // Filtro profesional
  sharpness, // Nitidez
  clarity, // Claridad
  quadrantSplit, // Efecto de división de pantalla
  // NUEVOS EFECTOS DISTINTIVOS
  romanticDreamy, // Efecto romántico soñador con desenfoque y tonos rosados
  vintageWedding, // Efecto vintage de boda con sepia y viñeta
  goldenHour, // Efecto hora dorada para bodas
  elegantSepia, // Sepia elegante para graduaciones
  formalBlackWhite, // Blanco y negro formal con alto contraste
  academicGlow, // Brillo académico para graduaciones
}

/// Preset de video
class VideoPreset {
  final String key;
  final String name;
  final String description;
  final EventType type;
  final List<PresetEffect> effects;

  const VideoPreset({
    required this.key,
    required this.name,
    required this.description,
    required this.type,
    required this.effects,
  });

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      'description': description,
      'type': type.toString(),
      'effects': effects.map((e) => e.toString()).toList(),
    };
  }

  factory VideoPreset.fromJson(Map<String, dynamic> json) {
    return VideoPreset(
      key: json['key'],
      name: json['name'],
      description: json['description'],
      type: EventType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => EventType.none,
      ),
      effects: (json['effects'] as List)
          .map((e) => PresetEffect.values.firstWhere(
                (p) => p.toString() == e,
                orElse: () => PresetEffect.clarity,
              ))
          .toList(),
    );
  }
}
