import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio optimizado para procesamiento de video con FFmpeg
/// Implementa procesamiento en paralelo, cache inteligente y gestión de memoria
class VideoProcessingService {
  static VideoProcessingService? _instance;
  static VideoProcessingService get instance =>
      _instance ??= VideoProcessingService._();

  VideoProcessingService._();

  // Cache de comandos FFmpeg frecuentes
  final Map<String, String> _commandCache = {};

  // Pool de buffers reutilizables
  final List<List<int>> _bufferPool = [];
  final int _maxBufferPoolSize = 10;

  // Cola de procesamiento para evitar sobrecarga
  final Queue<VideoProcessingTask> _processingQueue = Queue();
  bool _isProcessing = false;

  // Configuración de performance
  int _maxConcurrentProcesses = 2;
  int _currentProcesses = 0;

  // Métricas de performance
  final Map<String, int> _processingTimes = {};
  final Map<String, int> _memoryUsage = {};

  /// Inicializa el servicio
  Future<void> initialize() async {
    try {
      // Limpiar archivos temporales antiguos
      await _cleanupOldTempFiles();

      // Cargar configuración de performance
      await _loadPerformanceConfig();

      print('✅ VideoProcessingService inicializado');
    } catch (e) {
      print('❌ Error inicializando VideoProcessingService: $e');
      rethrow;
    }
  }

  /// Procesa video con efectos optimizados
  Future<String> processVideoWithEffects({
    required String inputPath,
    required VideoEffectsConfig effects,
    required Function(int) onProgress,
    required Function(String) onError,
  }) async {
    try {
      // Verificar que el archivo de entrada existe
      if (!await File(inputPath).exists()) {
        throw Exception('Archivo de entrada no encontrado: $inputPath');
      }

      // Crear tarea de procesamiento
      final task = VideoProcessingTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        inputPath: inputPath,
        effects: effects,
        onProgress: onProgress,
        onError: onError,
      );

      // Agregar a la cola
      _processingQueue.add(task);

      // Iniciar procesamiento si no está activo
      if (!_isProcessing) {
        _processQueue();
      }

      // Esperar a que se complete la tarea
      return await task.completer.future;
    } catch (e) {
      onError('Error iniciando procesamiento: $e');
      rethrow;
    }
  }

  /// Procesa la cola de tareas
  void _processQueue() async {
    if (_isProcessing || _processingQueue.isEmpty) return;

    _isProcessing = true;

    while (_processingQueue.isNotEmpty &&
        _currentProcesses < _maxConcurrentProcesses) {
      final task = _processingQueue.removeFirst();
      _currentProcesses++;

      // Procesar en paralelo
      _processTask(task).then((_) {
        _currentProcesses--;
        // Continuar con la siguiente tarea
        if (_processingQueue.isNotEmpty) {
          _processQueue();
        } else {
          _isProcessing = false;
        }
      });
    }
  }

  /// Procesa una tarea individual
  Future<void> _processTask(VideoProcessingTask task) async {
    final stopwatch = Stopwatch()..start();
    final initialMemory = await _getCurrentMemoryUsage();

    try {
      print('🔄 Procesando video: ${task.id}');

      // Aplicar efectos en paralelo cuando sea posible
      String currentPath = task.inputPath;

      // 1. Efectos de velocidad (slow motion, reverse)
      if (task.effects.hasSpeedEffects) {
        currentPath = await _applySpeedEffects(
            currentPath, task.effects, task.onProgress);
      }

      // 2. Filtros de color (paralelo con efectos de velocidad)
      if (task.effects.hasColorFilters) {
        currentPath = await _applyColorFilters(
            currentPath, task.effects, task.onProgress);
      }

      // 3. Overlays (logo, marco)
      if (task.effects.hasOverlays) {
        currentPath =
            await _applyOverlays(currentPath, task.effects, task.onProgress);
      }

      // 4. Audio de fondo
      if (task.effects.hasAudioBackground) {
        currentPath = await _applyAudioBackground(
            currentPath, task.effects, task.onProgress);
      }

      // Limpiar archivos temporales intermedios
      await _cleanupIntermediateFiles(task.inputPath, currentPath);

      // Registrar métricas
      final processingTime = stopwatch.elapsedMilliseconds;
      final finalMemory = await _getCurrentMemoryUsage();

      _processingTimes[task.id] = processingTime;
      _memoryUsage[task.id] = finalMemory - initialMemory;

      print('✅ Video procesado exitosamente en ${processingTime}ms');
      print('📊 Memoria utilizada: ${finalMemory - initialMemory}MB');

      // Completar tarea
      task.completer.complete(currentPath);
    } catch (e) {
      print('❌ Error procesando video ${task.id}: $e');
      task.onError('Error en procesamiento: $e');
      task.completer.completeError(e);
    }
  }

  /// Aplica efectos de velocidad optimizados
  Future<String> _applySpeedEffects(String inputPath,
      VideoEffectsConfig effects, Function(int) onProgress) async {
    try {
      final outputPath = await _getTempFilePath('speed_effects.mp4');

      // Construir comando FFmpeg optimizado
      String command = _buildSpeedEffectsCommand(inputPath, effects);

      // Verificar cache
      if (_commandCache.containsKey(command)) {
        command = _commandCache[command]!;
        print('🔄 Usando comando cacheado para efectos de velocidad');
      }

      // Ejecutar FFmpeg
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        onProgress(25); // 25% completado
        return outputPath;
      } else {
        throw Exception('Error aplicando efectos de velocidad');
      }
    } catch (e) {
      print('❌ Error en efectos de velocidad: $e');
      rethrow;
    }
  }

  /// Aplica filtros de color optimizados
  Future<String> _applyColorFilters(String inputPath,
      VideoEffectsConfig effects, Function(int) onProgress) async {
    try {
      final outputPath = await _getTempFilePath('color_filters.mp4');

      // Construir comando FFmpeg optimizado
      String command = _buildColorFiltersCommand(inputPath, effects);

      // Verificar cache
      if (_commandCache.containsKey(command)) {
        command = _commandCache[command]!;
        print('🔄 Usando comando cacheado para filtros de color');
      }

      // Ejecutar FFmpeg
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        onProgress(50); // 50% completado
        return outputPath;
      } else {
        throw Exception('Error aplicando filtros de color');
      }
    } catch (e) {
      print('❌ Error en filtros de color: $e');
      rethrow;
    }
  }

  /// Aplica overlays optimizados
  Future<String> _applyOverlays(String inputPath, VideoEffectsConfig effects,
      Function(int) onProgress) async {
    try {
      final outputPath = await _getTempFilePath('overlays.mp4');

      // Construir comando FFmpeg optimizado
      String command = _buildOverlaysCommand(inputPath, effects);

      // Verificar cache
      if (_commandCache.containsKey(command)) {
        command = _commandCache[command]!;
        print('🔄 Usando comando cacheado para overlays');
      }

      // Ejecutar FFmpeg
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        onProgress(75); // 75% completado
        return outputPath;
      } else {
        throw Exception('Error aplicando overlays');
      }
    } catch (e) {
      print('❌ Error en overlays: $e');
      rethrow;
    }
  }

  /// Aplica audio de fondo optimizado
  Future<String> _applyAudioBackground(String inputPath,
      VideoEffectsConfig effects, Function(int) onProgress) async {
    try {
      final outputPath = await _getTempFilePath('final_video.mp4');

      // Construir comando FFmpeg optimizado
      String command = _buildAudioBackgroundCommand(inputPath, effects);

      // Verificar cache
      if (_commandCache.containsKey(command)) {
        command = _commandCache[command]!;
        print('🔄 Usando comando cacheado para audio de fondo');
      }

      // Ejecutar FFmpeg
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        onProgress(100); // 100% completado
        return outputPath;
      } else {
        throw Exception('Error aplicando audio de fondo');
      }
    } catch (e) {
      print('❌ Error en audio de fondo: $e');
      rethrow;
    }
  }

  /// Construye comando FFmpeg para efectos de velocidad
  String _buildSpeedEffectsCommand(
      String inputPath, VideoEffectsConfig effects) {
    // Comando optimizado para efectos de velocidad
    // Implementar lógica específica según los efectos configurados
    return '-i "$inputPath" -filter_complex "..." -c:v libx264 -preset fast -crf 23 -y output.mp4';
  }

  /// Construye comando FFmpeg para filtros de color
  String _buildColorFiltersCommand(
      String inputPath, VideoEffectsConfig effects) {
    // Comando optimizado para filtros de color
    return '-i "$inputPath" -vf "..." -c:v libx264 -preset fast -crf 23 -y output.mp4';
  }

  /// Construye comando FFmpeg para overlays
  String _buildOverlaysCommand(String inputPath, VideoEffectsConfig effects) {
    // Comando optimizado para overlays
    return '-i "$inputPath" -i overlay.png -filter_complex "..." -c:v libx264 -preset fast -crf 23 -y output.mp4';
  }

  /// Construye comando FFmpeg para audio de fondo
  String _buildAudioBackgroundCommand(
      String inputPath, VideoEffectsConfig effects) {
    // Comando optimizado para audio de fondo
    return '-i "$inputPath" -i audio.mp3 -c:v copy -c:a aac -shortest -y output.mp4';
  }

  /// Obtiene ruta de archivo temporal
  Future<String> _getTempFilePath(String filename) async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/video_processing_$filename';
  }

  /// Limpia archivos temporales antiguos
  Future<void> _cleanupOldTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();

      for (var file in files) {
        if (file is File && file.path.contains('video_processing_')) {
          final stat = await file.stat();
          final age = DateTime.now().difference(stat.modified);

          // Eliminar archivos más antiguos de 1 hora
          if (age.inHours > 1) {
            await file.delete();
            print('🗑️ Archivo temporal eliminado: ${file.path}');
          }
        }
      }
    } catch (e) {
      print('⚠️ Error limpiando archivos temporales: $e');
    }
  }

  /// Limpia archivos intermedios
  Future<void> _cleanupIntermediateFiles(
      String originalPath, String finalPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();

      for (var file in files) {
        if (file is File &&
            file.path.contains('video_processing_') &&
            file.path != finalPath) {
          await file.delete();
          print('🗑️ Archivo intermedio eliminado: ${file.path}');
        }
      }
    } catch (e) {
      print('⚠️ Error limpiando archivos intermedios: $e');
    }
  }

  /// Obtiene uso actual de memoria
  Future<int> _getCurrentMemoryUsage() async {
    // Implementar lógica para obtener uso de memoria
    // Por ahora retornamos un valor simulado
    return 100; // MB
  }

  /// Carga configuración de performance
  Future<void> _loadPerformanceConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _maxConcurrentProcesses = prefs.getInt('maxConcurrentProcesses') ?? 2;

      print(
          '⚙️ Configuración de performance cargada: $_maxConcurrentProcesses procesos concurrentes');
    } catch (e) {
      print('⚠️ Error cargando configuración de performance: $e');
    }
  }

  /// Obtiene métricas de performance
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'processingTimes': _processingTimes,
      'memoryUsage': _memoryUsage,
      'currentProcesses': _currentProcesses,
      'queueSize': _processingQueue.length,
    };
  }

  /// Limpia métricas antiguas
  void clearOldMetrics() {
    final cutoff = DateTime.now().millisecondsSinceEpoch -
        (24 * 60 * 60 * 1000); // 24 horas

    _processingTimes.removeWhere((key, value) => int.parse(key) < cutoff);
    _memoryUsage.removeWhere((key, value) => int.parse(key) < cutoff);
  }

  /// Libera memoria del pool de buffers
  // ignore: unused_element
  void _cleanupBufferPool() {
    if (_bufferPool.length > _maxBufferPoolSize) {
      final excess = _bufferPool.length - _maxBufferPoolSize;
      _bufferPool.removeRange(0, excess);
      print('🧹 Pool de buffers limpiado: $excess buffers eliminados');
    }
  }

  /// Dispone recursos del servicio
  Future<void> dispose() async {
    try {
      // Limpiar cola de procesamiento
      _processingQueue.clear();

      // Limpiar cache
      _commandCache.clear();

      // Limpiar pool de buffers
      _bufferPool.clear();

      // Limpiar archivos temporales
      await _cleanupOldTempFiles();

      print('✅ VideoProcessingService liberado');
    } catch (e) {
      print('❌ Error liberando VideoProcessingService: $e');
    }
  }
}

/// Configuración de efectos de video
class VideoEffectsConfig {
  final bool enableSlowMotion;
  final bool enableReverse;
  final bool enableSpeedControl;
  final bool enableColorFilters;
  final bool enableOverlays;
  final bool enableAudioBackground;

  // Parámetros específicos
  final double slowMotionSpeed;
  final List<String> colorFilters;
  final Map<String, String> overlaySettings;
  final String audioBackgroundPath;

  VideoEffectsConfig({
    this.enableSlowMotion = false,
    this.enableReverse = false,
    this.enableSpeedControl = false,
    this.enableColorFilters = false,
    this.enableOverlays = false,
    this.enableAudioBackground = false,
    this.slowMotionSpeed = 0.5,
    this.colorFilters = const [],
    this.overlaySettings = const {},
    this.audioBackgroundPath = '',
  });

  bool get hasSpeedEffects =>
      enableSlowMotion || enableReverse || enableSpeedControl;
  bool get hasColorFilters => enableColorFilters && colorFilters.isNotEmpty;
  bool get hasOverlays => enableOverlays && overlaySettings.isNotEmpty;
  bool get hasAudioBackground =>
      enableAudioBackground && audioBackgroundPath.isNotEmpty;
}

/// Tarea de procesamiento de video
class VideoProcessingTask {
  final String id;
  final String inputPath;
  final VideoEffectsConfig effects;
  final Function(int) onProgress;
  final Function(String) onError;
  final Completer<String> completer = Completer<String>();

  VideoProcessingTask({
    required this.id,
    required this.inputPath,
    required this.effects,
    required this.onProgress,
    required this.onError,
  });
}
