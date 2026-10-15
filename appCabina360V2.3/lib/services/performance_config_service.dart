import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de configuración de performance para optimizar FFmpeg
/// Ajusta parámetros según las capacidades del dispositivo
class PerformanceConfigService {
  static PerformanceConfigService? _instance;
  static PerformanceConfigService get instance =>
      _instance ??= PerformanceConfigService._();

  PerformanceConfigService._();

  // Configuración de performance
  late PerformanceProfile _currentProfile;
  late DeviceCapabilities _deviceCapabilities;

  // Configuración FFmpeg optimizada
  late FFmpegConfig _ffmpegConfig;

  // Cache de configuraciones
  final Map<String, FFmpegConfig> _configCache = {};

  /// Inicializa el servicio
  Future<void> initialize() async {
    try {
      // Detectar capacidades del dispositivo
      await _detectDeviceCapabilities();

      // Seleccionar perfil de performance apropiado
      _selectPerformanceProfile();

      // Generar configuración FFmpeg optimizada
      _generateFFmpegConfig();

      // Cargar configuración guardada
      await _loadSavedConfiguration();

      print('✅ PerformanceConfigService inicializado');
      print('📱 Dispositivo: ${_deviceCapabilities.model}');
      print('⚡ Perfil: ${_currentProfile.name}');
    } catch (e) {
      print('❌ Error inicializando PerformanceConfigService: $e');
      rethrow;
    }
  }

  /// Detecta las capacidades del dispositivo
  Future<void> _detectDeviceCapabilities() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceCapabilities = DeviceCapabilities(
          platform: 'Android',
          model: androidInfo.model,
          manufacturer: androidInfo.manufacturer,
          sdkVersion: androidInfo.version.sdkInt,
          cpuCores: androidInfo.hardware.contains('qcom') ? 8 : 4, // Estimación
          ramGB: _estimateRAM(androidInfo.version.sdkInt),
          isHighEnd: androidInfo.version.sdkInt >= 30 &&
              androidInfo.hardware.contains('qcom'),
        );
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceCapabilities = DeviceCapabilities(
          platform: 'iOS',
          model: iosInfo.model,
          manufacturer: 'Apple',
          sdkVersion: int.parse(iosInfo.systemVersion.split('.').first),
          cpuCores: 6, // Estimación para iOS moderno
          ramGB: _estimateRAMiOS(iosInfo.systemVersion),
          isHighEnd: iosInfo.systemVersion.compareTo('15.0') >= 0,
        );
      } else {
        // Fallback para otras plataformas
        _deviceCapabilities = DeviceCapabilities(
          platform: 'Unknown',
          model: 'Unknown',
          manufacturer: 'Unknown',
          sdkVersion: 0,
          cpuCores: 4,
          ramGB: 4,
          isHighEnd: false,
        );
      }

      print('📱 Capacidades del dispositivo detectadas:');
      print('   - Plataforma: ${_deviceCapabilities.platform}');
      print('   - Modelo: ${_deviceCapabilities.model}');
      print('   - SDK: ${_deviceCapabilities.sdkVersion}');
      print('   - CPU: ${_deviceCapabilities.cpuCores} cores');
      print('   - RAM: ${_deviceCapabilities.ramGB}GB');
      print('   - High-end: ${_deviceCapabilities.isHighEnd}');
    } catch (e) {
      print('❌ Error detectando capacidades del dispositivo: $e');
      rethrow;
    }
  }

  /// Estima RAM para Android basado en SDK
  int _estimateRAM(int sdkVersion) {
    if (sdkVersion >= 30) return 8; // Android 11+
    if (sdkVersion >= 28) return 6; // Android 9+
    if (sdkVersion >= 24) return 4; // Android 7+
    return 2; // Android 6 y anteriores
  }

  /// Estima RAM para iOS basado en versión
  int _estimateRAMiOS(String systemVersion) {
    final majorVersion = int.parse(systemVersion.split('.').first);
    if (majorVersion >= 15) return 6; // iOS 15+
    if (majorVersion >= 13) return 4; // iOS 13+
    return 2; // iOS 12 y anteriores
  }

  /// Selecciona perfil de performance apropiado
  void _selectPerformanceProfile() {
    if (_deviceCapabilities.isHighEnd && _deviceCapabilities.ramGB >= 6) {
      _currentProfile = PerformanceProfile.high;
    } else if (_deviceCapabilities.ramGB >= 4) {
      _currentProfile = PerformanceProfile.medium;
    } else {
      _currentProfile = PerformanceProfile.low;
    }

    print('⚡ Perfil de performance seleccionado: ${_currentProfile.name}');
  }

  /// Genera configuración FFmpeg optimizada
  void _generateFFmpegConfig() {
    switch (_currentProfile) {
      case PerformanceProfile.high:
        _ffmpegConfig = FFmpegConfig(
          videoCodec: 'libx264',
          audioCodec: 'aac',
          videoPreset: 'fast',
          crf: 20, // Alta calidad
          bitrate: '4000k',
          maxConcurrentProcesses: 3,
          enableHardwareAcceleration: true,
          bufferSize: 1024 * 1024, // 1MB
          threadCount: _deviceCapabilities.cpuCores,
        );
        break;

      case PerformanceProfile.medium:
        _ffmpegConfig = FFmpegConfig(
          videoCodec: 'libx264',
          audioCodec: 'aac',
          videoPreset: 'medium',
          crf: 23, // Calidad media
          bitrate: '3000k',
          maxConcurrentProcesses: 2,
          enableHardwareAcceleration: false,
          bufferSize: 512 * 1024, // 512KB
          threadCount: (_deviceCapabilities.cpuCores / 2).round(),
        );
        break;

      case PerformanceProfile.low:
        _ffmpegConfig = FFmpegConfig(
          videoCodec: 'libx264',
          audioCodec: 'aac',
          videoPreset: 'ultrafast',
          crf: 28, // Calidad baja pero rápida
          bitrate: '2000k',
          maxConcurrentProcesses: 1,
          enableHardwareAcceleration: false,
          bufferSize: 256 * 1024, // 256KB
          threadCount: 1,
        );
        break;
    }

    print('⚙️ Configuración FFmpeg generada:');
    print('   - Codec: ${_ffmpegConfig.videoCodec}');
    print('   - Preset: ${_ffmpegConfig.videoPreset}');
    print('   - CRF: ${_ffmpegConfig.crf}');
    print('   - Bitrate: ${_ffmpegConfig.bitrate}');
    print('   - Procesos: ${_ffmpegConfig.maxConcurrentProcesses}');
    print('   - Threads: ${_ffmpegConfig.threadCount}');
  }

  /// Carga configuración guardada
  Future<void> _loadSavedConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cargar configuración personalizada si existe
      final customCRF = prefs.getInt('customCRF');
      final customBitrate = prefs.getString('customBitrate');
      final customPreset = prefs.getString('customPreset');

      if (customCRF != null) {
        _ffmpegConfig = _ffmpegConfig.copyWith(crf: customCRF);
        print('⚙️ CRF personalizado cargado: $customCRF');
      }

      if (customBitrate != null) {
        _ffmpegConfig = _ffmpegConfig.copyWith(bitrate: customBitrate);
        print('⚙️ Bitrate personalizado cargado: $customBitrate');
      }

      if (customPreset != null) {
        _ffmpegConfig = _ffmpegConfig.copyWith(videoPreset: customPreset);
        print('⚙️ Preset personalizado cargado: $customPreset');
      }
    } catch (e) {
      print('⚠️ Error cargando configuración guardada: $e');
    }
  }

  /// Obtiene configuración FFmpeg para un tipo de efecto específico
  FFmpegConfig getFFmpegConfigForEffect(VideoEffectType effectType) {
    final cacheKey = '${_currentProfile.name}_${effectType.name}';

    if (_configCache.containsKey(cacheKey)) {
      return _configCache[cacheKey]!;
    }

    // Generar configuración específica para el efecto
    FFmpegConfig effectConfig;

    switch (effectType) {
      case VideoEffectType.slowMotion:
        effectConfig = _ffmpegConfig.copyWith(
          videoPreset: 'fast', // Priorizar velocidad
          crf: _ffmpegConfig.crf + 2, // Calidad ligeramente menor
        );
        break;

      case VideoEffectType.reverse:
        effectConfig = _ffmpegConfig.copyWith(
          videoPreset: 'medium', // Balance entre velocidad y calidad
        );
        break;

      case VideoEffectType.colorFilter:
        effectConfig = _ffmpegConfig.copyWith(
          videoPreset: 'medium', // Balance entre velocidad y calidad
        );
        break;

      case VideoEffectType.overlay:
        effectConfig = _ffmpegConfig.copyWith(
          videoPreset: 'fast', // Priorizar velocidad para overlays
        );
        break;

      case VideoEffectType.audioBackground:
        effectConfig = _ffmpegConfig.copyWith(
          videoPreset: 'ultrafast', // Solo audio, máxima velocidad
        );
        break;
    }

    // Cachear configuración
    _configCache[cacheKey] = effectConfig;

    return effectConfig;
  }

  /// Genera comando FFmpeg optimizado
  String generateFFmpegCommand({
    required String inputPath,
    required String outputPath,
    required VideoEffectType effectType,
    Map<String, String>? additionalParams,
  }) {
    final config = getFFmpegConfigForEffect(effectType);

    // Comando base optimizado
    String command = '-i "$inputPath"';

    // Parámetros de video
    command += ' -c:v ${config.videoCodec}';
    command += ' -preset ${config.videoPreset}';
    command += ' -crf ${config.crf}';
    command += ' -b:v ${config.bitrate}';

    // Parámetros de audio
    command += ' -c:a ${config.audioCodec}';

    // Optimizaciones de performance
    command += ' -threads ${config.threadCount}';
    command += ' -bufsize ${config.bufferSize}';

    // Hardware acceleration si está disponible
    if (config.enableHardwareAcceleration && _deviceCapabilities.isHighEnd) {
      command += ' -hwaccel auto';
    }

    // Parámetros adicionales específicos del efecto
    if (additionalParams != null) {
      additionalParams.forEach((key, value) {
        command += ' $key $value';
      });
    }

    // Archivo de salida
    command += ' -y "$outputPath"';

    return command;
  }

  /// Obtiene configuración actual
  FFmpegConfig get currentFFmpegConfig => _ffmpegConfig;

  /// Obtiene perfil de performance actual
  PerformanceProfile get currentProfile => _currentProfile;

  /// Obtiene capacidades del dispositivo
  DeviceCapabilities get deviceCapabilities => _deviceCapabilities;

  /// Actualiza configuración personalizada
  Future<void> updateCustomConfiguration({
    int? crf,
    String? bitrate,
    String? preset,
  }) async {
    try {
      if (crf != null) _ffmpegConfig = _ffmpegConfig.copyWith(crf: crf);
      if (bitrate != null)
        _ffmpegConfig = _ffmpegConfig.copyWith(bitrate: bitrate);
      if (preset != null)
        _ffmpegConfig = _ffmpegConfig.copyWith(videoPreset: preset);

      // Guardar configuración
      final prefs = await SharedPreferences.getInstance();
      if (crf != null) await prefs.setInt('customCRF', crf);
      if (bitrate != null) await prefs.setString('customBitrate', bitrate);
      if (preset != null) await prefs.setString('customPreset', preset);

      // Limpiar cache
      _configCache.clear();

      print('✅ Configuración personalizada actualizada');
    } catch (e) {
      print('❌ Error actualizando configuración personalizada: $e');
    }
  }

  /// Obtiene métricas de performance
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'profile': _currentProfile.name,
      'deviceCapabilities': _deviceCapabilities.toJson(),
      'ffmpegConfig': _ffmpegConfig.toJson(),
      'configCacheSize': _configCache.length,
    };
  }

  /// Dispone recursos del servicio
  void dispose() {
    _configCache.clear();
    print('✅ PerformanceConfigService liberado');
  }
}

/// Perfiles de performance
enum PerformanceProfile {
  low('Baja'),
  medium('Media'),
  high('Alta');

  const PerformanceProfile(this.name);
  final String name;
}

/// Tipos de efectos de video
enum VideoEffectType {
  slowMotion('Cámara Lenta'),
  reverse('Reversa'),
  colorFilter('Filtro de Color'),
  overlay('Overlay'),
  audioBackground('Audio de Fondo');

  const VideoEffectType(this.name);
  final String name;
}

/// Capacidades del dispositivo
class DeviceCapabilities {
  final String platform;
  final String model;
  final String manufacturer;
  final int sdkVersion;
  final int cpuCores;
  final int ramGB;
  final bool isHighEnd;

  DeviceCapabilities({
    required this.platform,
    required this.model,
    required this.manufacturer,
    required this.sdkVersion,
    required this.cpuCores,
    required this.ramGB,
    required this.isHighEnd,
  });

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'model': model,
      'manufacturer': manufacturer,
      'sdkVersion': sdkVersion,
      'cpuCores': cpuCores,
      'ramGB': ramGB,
      'isHighEnd': isHighEnd,
    };
  }
}

/// Configuración FFmpeg optimizada
class FFmpegConfig {
  final String videoCodec;
  final String audioCodec;
  final String videoPreset;
  final int crf;
  final String bitrate;
  final int maxConcurrentProcesses;
  final bool enableHardwareAcceleration;
  final int bufferSize;
  final int threadCount;

  FFmpegConfig({
    required this.videoCodec,
    required this.audioCodec,
    required this.videoPreset,
    required this.crf,
    required this.bitrate,
    required this.maxConcurrentProcesses,
    required this.enableHardwareAcceleration,
    required this.bufferSize,
    required this.threadCount,
  });

  FFmpegConfig copyWith({
    String? videoCodec,
    String? audioCodec,
    String? videoPreset,
    int? crf,
    String? bitrate,
    int? maxConcurrentProcesses,
    bool? enableHardwareAcceleration,
    int? bufferSize,
    int? threadCount,
  }) {
    return FFmpegConfig(
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      videoPreset: videoPreset ?? this.videoPreset,
      crf: crf ?? this.crf,
      bitrate: bitrate ?? this.bitrate,
      maxConcurrentProcesses:
          maxConcurrentProcesses ?? this.maxConcurrentProcesses,
      enableHardwareAcceleration:
          enableHardwareAcceleration ?? this.enableHardwareAcceleration,
      bufferSize: bufferSize ?? this.bufferSize,
      threadCount: threadCount ?? this.threadCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoCodec': videoCodec,
      'audioCodec': audioCodec,
      'videoPreset': videoPreset,
      'crf': crf,
      'bitrate': bitrate,
      'maxConcurrentProcesses': maxConcurrentProcesses,
      'enableHardwareAcceleration': enableHardwareAcceleration,
      'bufferSize': bufferSize,
      'threadCount': threadCount,
    };
  }
}
