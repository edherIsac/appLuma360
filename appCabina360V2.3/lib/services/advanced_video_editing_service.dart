import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';

/// Servicio avanzado de edición de video para Cabina 360
/// Implementa pipeline básico de edición, trim, efectos básicos y presets avanzados
class AdvancedVideoEditingService {
  static AdvancedVideoEditingService? _instance;
  static AdvancedVideoEditingService get instance =>
      _instance ??= AdvancedVideoEditingService._();

  AdvancedVideoEditingService._();

  // Cache de comandos FFmpeg frecuentes
  // ignore: unused_field
  final Map<String, String> _commandCache = {};

  // Pool de archivos temporales
  final List<String> _tempFiles = [];
  final int _maxTempFiles = 20;

  // Cola de procesamiento
  // ignore: unused_field
  final Queue<EditingTask> _editingQueue = Queue();
  // ignore: unused_field
  bool _isProcessing = false;

  // Configuración de performance
  // ignore: unused_field
  int _maxConcurrentProcesses = 2;
  // ignore: unused_field
  int _currentProcesses = 0;

  /// Inicializa el servicio
  Future<void> initialize() async {
    try {
      await _cleanupOldTempFiles();
      print('✅ AdvancedVideoEditingService inicializado');
    } catch (e) {
      print('❌ Error inicializando AdvancedVideoEditingService: $e');
      rethrow;
    }
  }

  /// Trim de video (cortar inicio/fin)
  Future<String> trimVideo({
    required String inputPath,
    required Duration startTime,
    required Duration endTime,
    Function(double)? onProgress,
  }) async {
    try {
      final outputPath = await _getTempFilePath('trim');

      // Convertir duraciones a formato FFmpeg (HH:MM:SS.mmm)
      final startStr = _durationToFFmpeg(startTime);
      final durationStr = _durationToFFmpeg(endTime - startTime);

      final command =
          '-i "$inputPath" -ss $startStr -t $durationStr -c copy -avoid_negative_ts make_zero -y "$outputPath"';

      print('✂️ Comando trim: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        onProgress?.call(100.0);
        _addTempFile(outputPath);
        return outputPath;
      } else {
        throw Exception('Error en trim de video');
      }
    } catch (e) {
      print('❌ Error en trim: $e');
      rethrow;
    }
  }

  /// Aplica efectos básicos: boomerang, VHS, zoom
  Future<String> applyBasicEffects({
    required String inputPath,
    required List<BasicEffect> effects,
    Function(double)? onProgress,
  }) async {
    try {
      final outputPath = await _getTempFilePath('basic_effects');
      final filters = <String>[];

      // Construir filtros según los efectos seleccionados
      for (final effect in effects) {
        switch (effect) {
          case BasicEffect.boomerang:
            filters.add(_buildBoomerangFilter());
            break;
          case BasicEffect.vhs:
            filters.add(_buildVHSFilter());
            break;
          case BasicEffect.zoom:
            filters.add(_buildZoomFilter());
            break;
        }
      }

      if (filters.isEmpty) {
        return inputPath; // Sin efectos
      }

      final filterString = filters.join(',');
      final command =
          '-i "$inputPath" -vf "$filterString" -c:a copy -c:v libx264 -preset medium -crf 23 -y "$outputPath"';

      print('🎬 Comando efectos básicos: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        onProgress?.call(100.0);
        _addTempFile(outputPath);
        return outputPath;
      } else {
        throw Exception('Error aplicando efectos básicos');
      }
    } catch (e) {
      print('❌ Error en efectos básicos: $e');
      rethrow;
    }
  }

  /// Aplica preset avanzado con estructura JSON
  Future<String> applyAdvancedPreset({
    required String inputPath,
    required AdvancedPreset preset,
    Function(double)? onProgress,
  }) async {
    try {
      print('🎬 Aplicando preset avanzado: ${preset.name}');

      String currentVideoPath = inputPath;
      int totalBlocks = preset.blocks.length;

      // Procesar cada bloque del preset
      for (int i = 0; i < preset.blocks.length; i++) {
        final block = preset.blocks[i];
        final progress = (i / totalBlocks) * 100;
        onProgress?.call(progress);

        // Extraer segmento del video según el rango
        final segmentPath = await _extractVideoSegment(
          inputPath: currentVideoPath,
          range: block.range,
        );

        // Aplicar efectos del bloque
        final processedPath = await _applyBlockEffects(
          inputPath: segmentPath,
          effects: block.effects,
        );

        // Limpiar archivo temporal del segmento
        await _cleanupTempFile(segmentPath);

        currentVideoPath = processedPath;
      }

      // Concatenar todos los bloques procesados
      final finalOutputPath = await _getTempFilePath('advanced_preset');
      final concatenatedPath = await _concatenateVideoBlocks(
        blockPaths: preset.blocks
            .map((b) => b.processedPath ?? '')
            .where((p) => p.isNotEmpty)
            .toList(),
        outputPath: finalOutputPath,
      );

      onProgress?.call(100.0);
      _addTempFile(finalOutputPath);

      return concatenatedPath;
    } catch (e) {
      print('❌ Error aplicando preset avanzado: $e');
      rethrow;
    }
  }

  /// Extrae un segmento de video según el rango especificado
  Future<String> _extractVideoSegment({
    required String inputPath,
    required VideoRange range,
  }) async {
    try {
      final outputPath = await _getTempFilePath('segment');

      // Obtener duración total del video
      final duration = await _getVideoDuration(inputPath);
      if (duration == null) {
        throw Exception('No se pudo obtener la duración del video');
      }

      // Calcular tiempos de inicio y fin
      final startTime = duration * range.startPercentage;
      final endTime = duration * range.endPercentage;

      final startStr =
          _durationToFFmpeg(Duration(milliseconds: (startTime * 1000).round()));
      final durationStr = _durationToFFmpeg(
          Duration(milliseconds: ((endTime - startTime) * 1000).round()));

      final command =
          '-i "$inputPath" -ss $startStr -t $durationStr -c copy -avoid_negative_ts make_zero -y "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return outputPath;
      } else {
        throw Exception('Error extrayendo segmento de video');
      }
    } catch (e) {
      print('❌ Error extrayendo segmento: $e');
      rethrow;
    }
  }

  /// Aplica efectos a un bloque específico
  Future<String> _applyBlockEffects({
    required String inputPath,
    required List<BlockEffect> effects,
  }) async {
    try {
      String currentPath = inputPath;

      for (final effect in effects) {
        final outputPath = await _getTempFilePath('block_effect');

        String command;
        switch (effect.type) {
          case EffectType.boomerang:
            command = _buildBoomerangCommand(currentPath, outputPath);
            break;
          case EffectType.vhs:
            command = _buildVHSCommand(currentPath, outputPath);
            break;
          case EffectType.zoom:
            command = _buildZoomCommand(currentPath, outputPath);
            break;
          case EffectType.slowMotion:
            command = _buildSlowMotionCommand(
                currentPath, outputPath, effect.intensity);
            break;
          case EffectType.reverse:
            command = _buildReverseCommand(currentPath, outputPath);
            break;
          case EffectType.colorFilter:
            command = _buildColorFilterCommand(
                currentPath, outputPath, effect.colorParams);
            break;
        }

        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          // Limpiar archivo anterior si no es el original
          if (currentPath != inputPath) {
            await _cleanupTempFile(currentPath);
          }
          currentPath = outputPath;
        } else {
          throw Exception('Error aplicando efecto: ${effect.type}');
        }
      }

      return currentPath;
    } catch (e) {
      print('❌ Error aplicando efectos de bloque: $e');
      rethrow;
    }
  }

  /// Concatena múltiples bloques de video
  Future<String> _concatenateVideoBlocks({
    required List<String> blockPaths,
    required String outputPath,
  }) async {
    try {
      if (blockPaths.isEmpty) {
        throw Exception('No hay bloques para concatenar');
      }

      if (blockPaths.length == 1) {
        // Solo un bloque, solo copiar
        final command = '-i "${blockPaths[0]}" -c copy -y "$outputPath"';
        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          return outputPath;
        } else {
          throw Exception('Error copiando bloque único');
        }
      }

      // Crear archivo de lista para concatenación
      final listFile = await _createConcatListFile(blockPaths);

      final command =
          '-f concat -safe 0 -i "$listFile" -c copy -y "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Limpiar archivo de lista
      await _cleanupTempFile(listFile);

      if (ReturnCode.isSuccess(returnCode)) {
        return outputPath;
      } else {
        throw Exception('Error concatenando bloques de video');
      }
    } catch (e) {
      print('❌ Error concatenando bloques: $e');
      rethrow;
    }
  }

  /// Crea archivo de lista para concatenación FFmpeg
  Future<String> _createConcatListFile(List<String> blockPaths) async {
    final listFile = await _getTempFilePath('concat_list');
    final content = blockPaths.map((path) => "file '$path'").join('\n');

    await File(listFile).writeAsString(content);
    return listFile;
  }

  /// Obtiene la duración del video en segundos
  Future<double?> _getVideoDuration(String videoPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final information = session.getMediaInformation();
      final duration = information?.getDuration();

      if (duration != null) {
        return double.tryParse(duration);
      }
      return null;
    } catch (e) {
      print('⚠️ Error obteniendo duración: $e');
      return null;
    }
  }

  // Métodos de construcción de filtros y comandos

  String _buildBoomerangFilter() {
    return 'reverse,setpts=PTS-STARTPTS';
  }

  String _buildVHSFilter() {
    return 'noise=alls=20:allf=t,colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131';
  }

  String _buildZoomFilter() {
    return 'scale=iw*1.2:ih*1.2,crop=iw/1.2:ih/1.2';
  }

  String _buildBoomerangCommand(String inputPath, String outputPath) {
    return '-i "$inputPath" -vf "reverse,setpts=PTS-STARTPTS" -c:a copy -c:v libx264 -preset medium -crf 23 -y "$outputPath"';
  }

  String _buildVHSCommand(String inputPath, String outputPath) {
    return '-i "$inputPath" -vf "noise=alls=20:allf=t,colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131" -c:a copy -c:v libx264 -preset medium -crf 23 -y "$outputPath"';
  }

  String _buildZoomCommand(String inputPath, String outputPath) {
    return '-i "$inputPath" -vf "scale=iw*1.2:ih*1.2,crop=iw/1.2:ih/1.2" -c:a copy -c:v libx264 -preset medium -crf 23 -y "$outputPath"';
  }

  String _buildSlowMotionCommand(
      String inputPath, String outputPath, double intensity) {
    final speedFactor = 1.0 / intensity;
    return '-i "$inputPath" -filter:v "setpts=${speedFactor}*PTS" -c:a copy -c:v libx264 -preset medium -crf 23 -y "$outputPath"';
  }

  String _buildReverseCommand(String inputPath, String outputPath) {
    return '-i "$inputPath" -vf "reverse" -c:a copy -c:v libx264 -preset medium -crf 23 -y "$outputPath"';
  }

  String _buildColorFilterCommand(
      String inputPath, String outputPath, Map<String, dynamic>? colorParams) {
    if (colorParams == null) return '-i "$inputPath" -c copy -y "$outputPath"';

    final filters = <String>[];

    if (colorParams['brightness'] != null) {
      filters.add('eq=brightness=${colorParams['brightness']}');
    }
    if (colorParams['contrast'] != null) {
      filters.add('eq=contrast=${colorParams['contrast']}');
    }
    if (colorParams['saturation'] != null) {
      filters.add('eq=saturation=${colorParams['saturation']}');
    }
    if (colorParams['hue'] != null) {
      filters.add('hue=h=${colorParams['hue']}');
    }

    if (filters.isEmpty) {
      return '-i "$inputPath" -c copy -y "$outputPath"';
    }

    final filterString = filters.join(',');
    return '-i "$inputPath" -vf "$filterString" -c:a copy -c:v libx264 -preset medium -crf 23 -y "$outputPath"';
  }

  // Utilidades

  String _durationToFFmpeg(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds =
        (duration.inMilliseconds % 1000).toString().padLeft(3, '0');

    return '$hours:$minutes:$seconds.$milliseconds';
  }

  Future<String> _getTempFilePath(String prefix) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempDir = Directory.systemTemp;
    final editingDir = Directory('${tempDir.path}/advanced_editing');

    if (!await editingDir.exists()) {
      await editingDir.create(recursive: true);
    }

    return '${editingDir.path}/${prefix}_$timestamp.mp4';
  }

  void _addTempFile(String path) {
    _tempFiles.add(path);
    if (_tempFiles.length > _maxTempFiles) {
      _cleanupOldTempFiles();
    }
  }

  Future<void> _cleanupTempFile(String path) async {
    try {
      if (await File(path).exists()) {
        await File(path).delete();
      }
      _tempFiles.remove(path);
    } catch (e) {
      print('⚠️ Error limpiando archivo temporal: $e');
    }
  }

  Future<void> _cleanupOldTempFiles() async {
    try {
      for (final path in _tempFiles) {
        if (await File(path).exists()) {
          await File(path).delete();
        }
      }
      _tempFiles.clear();
    } catch (e) {
      print('⚠️ Error limpiando archivos temporales: $e');
    }
  }

  /// Limpia todos los archivos temporales
  Future<void> cleanup() async {
    await _cleanupOldTempFiles();
  }
}

// Modelos de datos para presets avanzados

/// Preset avanzado con estructura JSON
class AdvancedPreset {
  final String name;
  final String description;
  final List<VideoBlock> blocks;
  final Map<String, dynamic> metadata;

  const AdvancedPreset({
    required this.name,
    required this.description,
    required this.blocks,
    this.metadata = const {},
  });

  factory AdvancedPreset.fromJson(Map<String, dynamic> json) {
    return AdvancedPreset(
      name: json['presetName'] ?? '',
      description: json['description'] ?? '',
      blocks: (json['blocks'] as List?)
              ?.map((b) => VideoBlock.fromJson(b))
              .toList() ??
          [],
      metadata: json['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'presetName': name,
      'description': description,
      'blocks': blocks.map((b) => b.toJson()).toList(),
      'metadata': metadata,
    };
  }
}

/// Bloque de video con rango y efectos
class VideoBlock {
  final VideoRange range;
  final List<BlockEffect> effects;
  String? processedPath; // Ruta del archivo procesado

  VideoBlock({
    required this.range,
    required this.effects,
    this.processedPath,
  });

  factory VideoBlock.fromJson(Map<String, dynamic> json) {
    return VideoBlock(
      range: VideoRange.fromJson(json['range'] ?? {}),
      effects: _parseEffectsList(json['effects']),
    );
  }

  static List<BlockEffect> _parseEffectsList(dynamic effectsJson) {
    if (effectsJson == null) return [];
    if (effectsJson is! List) return [];

    return effectsJson
        .where((e) => e is Map<String, dynamic>)
        .map((e) => BlockEffect.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'range': range.toJson(),
      'effects': effects.map((e) => e.toJson()).toList(),
    };
  }
}

/// Rango de video (porcentajes)
class VideoRange {
  final double startPercentage;
  final double endPercentage;

  const VideoRange({
    required this.startPercentage,
    required this.endPercentage,
  });

  factory VideoRange.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      return const VideoRange(startPercentage: 0.0, endPercentage: 1.0);
    }

    final rangeStr = json['range'] ?? '0-100';
    if (rangeStr is! String) {
      return const VideoRange(startPercentage: 0.0, endPercentage: 1.0);
    }

    final parts = rangeStr.split('-');

    if (parts.length == 2) {
      final start = double.tryParse(parts[0]) ?? 0.0;
      final end = double.tryParse(parts[1]) ?? 100.0;
      return VideoRange(
        startPercentage: start / 100.0,
        endPercentage: end / 100.0,
      );
    }

    return const VideoRange(startPercentage: 0.0, endPercentage: 1.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'range':
          '${(startPercentage * 100).round()}-${(endPercentage * 100).round()}',
    };
  }
}

/// Efecto aplicable a un bloque
class BlockEffect {
  final EffectType type;
  final double intensity;
  final Map<String, dynamic>? colorParams;

  const BlockEffect({
    required this.type,
    this.intensity = 1.0,
    this.colorParams,
  });

  factory BlockEffect.fromJson(Map<String, dynamic> json) {
    return BlockEffect(
      type: EffectType.values.firstWhere(
        (e) => e.toString() == json['effect'],
        orElse: () => EffectType.boomerang,
      ),
      intensity: _parseDouble(json['intensity']) ?? 1.0,
      colorParams: json['colorParams'],
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'effect': type.toString(),
      'intensity': intensity,
      if (colorParams != null) 'colorParams': colorParams,
    };
  }
}

/// Tipos de efectos disponibles
enum EffectType {
  boomerang,
  vhs,
  zoom,
  slowMotion,
  reverse,
  colorFilter,
}

/// Efectos básicos para compatibilidad
enum BasicEffect {
  boomerang,
  vhs,
  zoom,
}

/// Tarea de edición
class EditingTask {
  final String id;
  final String inputPath;
  final List<BasicEffect> effects;
  final Function(double)? onProgress;
  final Function(String)? onError;
  final Completer<String> completer;

  EditingTask({
    required this.id,
    required this.inputPath,
    required this.effects,
    this.onProgress,
    this.onError,
  }) : completer = Completer<String>();
}
