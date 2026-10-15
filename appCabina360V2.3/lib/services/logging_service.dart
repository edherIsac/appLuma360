import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Niveles de log ordenados por severidad
enum LogLevel { debug, info, warning, error, critical }

/// Extensión para convertir LogLevel a string corto
extension LogLevelExtension on LogLevel {
  String get shortName {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO ';
      case LogLevel.warning:
        return 'WARN ';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.critical:
        return 'CRIT ';
    }
  }
}

/// Servicio central de logging para producción.
///
/// Escribe logs estructurados en archivo local con rotación automática.
/// Formato: `TIMESTAMP | LEVEL | TAG | MESSAGE | CONTEXT_JSON`
class LoggingService {
  static LoggingService? _instance;
  static LoggingService get instance => _instance ??= LoggingService._();

  LoggingService._();

  // Configuración
  static const int _maxFileSizeBytes = 1 * 1024 * 1024; // 1MB por archivo
  static const int _maxRotatedFiles = 2; // cabina360.log.1, cabina360.log.2
  static const String _logFileName = 'cabina360.log';
  static const Duration _flushInterval = Duration(seconds: 5);

  // Estado interno
  File? _logFile;
  IOSink? _sink;
  bool _initialized = false;
  final List<String> _buffer = []; // Buffer en memoria antes de flush
  Timer? _flushTimer;
  int _currentFileSize = 0;

  // Getters
  bool get isInitialized => _initialized;

  /// Inicializa el servicio de logging.
  ///
  /// Debe llamarse lo antes posible en main() antes de runApp().
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/$_logFileName');

      // Calcular tamaño actual del archivo
      if (await _logFile!.exists()) {
        _currentFileSize = await _logFile!.length();
      }

      // Abrir sink en modo append
      _sink = _logFile!.openWrite(mode: FileMode.append);

      // Iniciar timer de flush periódico
      _flushTimer = Timer.periodic(_flushInterval, (_) => _flush());

      // Rotar si el archivo es muy grande
      if (_currentFileSize > _maxFileSizeBytes) {
        await _rotateLogFiles();
      }

      _initialized = true;

      // Log de inicialización
      _writeLog(
        LogLevel.info,
        'LoggingService',
        'Sistema de logging inicializado',
        null,
        null,
        null,
      );
      _flush();
    } catch (e) {
      // Si falla la inicialización, no crashear la app
      print('❌ Error inicializando LoggingService: $e');
    }
  }

  /// Log nivel DEBUG — Información detallada para desarrollo
  void debug(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ]) {
    _writeLog(LogLevel.debug, tag, message, error, stackTrace, context);
  }

  /// Log nivel INFO — Información general de operación
  void info(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ]) {
    _writeLog(LogLevel.info, tag, message, error, stackTrace, context);
  }

  /// Log nivel WARNING — Situaciones inesperadas pero recuperables
  void warning(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ]) {
    _writeLog(LogLevel.warning, tag, message, error, stackTrace, context);
  }

  /// Log nivel ERROR — Errores que afectan funcionalidad pero la app puede continuar
  void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ]) {
    _writeLog(LogLevel.error, tag, message, error, stackTrace, context);
    // Flush inmediato en errores para no perder información si la app crashea
    _flush();
  }

  /// Log nivel CRITICAL — Errores que pueden causar que la app sea inutilizable
  void critical(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ]) {
    _writeLog(LogLevel.critical, tag, message, error, stackTrace, context);
    // Flush inmediato en errores críticos
    _flush();
  }

  /// Escribe una línea de log en el buffer
  void _writeLog(
    LogLevel level,
    String tag,
    String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ) {
    if (!_initialized) {
      // Si no está inicializado, usar print como fallback
      print('${level.shortName} | $tag | $message');
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final buffer = StringBuffer();
    buffer.write('$timestamp | ${level.shortName} | $tag | $message');

    // Agregar contexto JSON si existe
    if (context != null && context.isNotEmpty) {
      buffer.write(' | ${_mapToString(context)}');
    }

    // Agregar error si existe
    if (error != null) {
      buffer.write(' | ERROR_DETAIL: $error');
    }

    // Agregar stack trace si existe (solo para error y critical)
    if (stackTrace != null &&
        (level == LogLevel.error || level == LogLevel.critical)) {
      buffer.write(
        ' | STACK: ${stackTrace.toString().replaceAll('\n', ' | ')}',
      );
    }

    final line = buffer.toString();
    _buffer.add(line);

    // También imprimir en consola para desarrollo
    print(line);

    // Si el buffer crece mucho, flush inmediato
    if (_buffer.length >= 50) {
      _flush();
    }
  }

  /// Convierte un Map a string JSON simple
  String _mapToString(Map<String, dynamic> map) {
    final entries = map.entries
        .map((e) => '"${e.key}":${_valueToString(e.value)}')
        .join(',');
    return '{$entries}';
  }

  String _valueToString(dynamic value) {
    if (value is String) return '"${value.replaceAll('"', '\\"')}"';
    if (value is num || value is bool) return value.toString();
    if (value is List) return '[${value.map(_valueToString).join(',')}]';
    return '"$value"';
  }

  /// Flush del buffer al archivo
  void _flush() {
    if (_buffer.isEmpty || _sink == null) return;

    try {
      for (final line in _buffer) {
        _sink!.writeln(line);
        _currentFileSize += line.length + 1; // +1 por newline
      }
      _sink!.flush();
      _buffer.clear();

      // Verificar si necesita rotación
      if (_currentFileSize > _maxFileSizeBytes) {
        _rotateLogFiles();
      }
    } catch (e) {
      print('❌ Error haciendo flush de logs: $e');
    }
  }

  /// Rota los archivos de log
  Future<void> _rotateLogFiles() async {
    try {
      if (_sink != null) {
        await _sink!.close();
        _sink = null;
      }

      final dir = await getApplicationDocumentsDirectory();

      // Eliminar el archivo rotado más viejo
      final oldestFile = File('${dir.path}/$_logFileName.$_maxRotatedFiles');
      if (await oldestFile.exists()) {
        await oldestFile.delete();
      }

      // Rotar archivos existentes
      for (int i = _maxRotatedFiles - 1; i >= 1; i--) {
        final source = File('${dir.path}/$_logFileName.$i');
        if (await source.exists()) {
          await source.rename('${dir.path}/$_logFileName.${i + 1}');
        }
      }

      // Rotar el archivo actual
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.rename('${dir.path}/$_logFileName.1');
      }

      // Crear nuevo archivo
      _logFile = File('${dir.path}/$_logFileName');
      _sink = _logFile!.openWrite(mode: FileMode.append);
      _currentFileSize = 0;
    } catch (e) {
      print('❌ Error rotando archivos de log: $e');
    }
  }

  /// Lee el contenido completo de todos los archivos de log
  Future<String> getLogContents() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final buffer = StringBuffer();

      // Leer archivo actual
      final currentFile = File('${dir.path}/$_logFileName');
      if (await currentFile.exists()) {
        buffer.writeln('=== LOG ACTUAL ===');
        buffer.write(await currentFile.readAsString());
        buffer.writeln();
      }

      // Leer archivos rotados (del más reciente al más viejo)
      for (int i = 1; i <= _maxRotatedFiles; i++) {
        final rotatedFile = File('${dir.path}/$_logFileName.$i');
        if (await rotatedFile.exists()) {
          buffer.writeln('=== LOG ANTERIOR $i ===');
          buffer.write(await rotatedFile.readAsString());
          buffer.writeln();
        }
      }

      return buffer.toString();
    } catch (e) {
      return 'Error leyendo logs: $e';
    }
  }

  /// Genera un archivo de texto completo con diagnóstico + logs para exportar
  Future<File> exportLogsWithDiagnostics() async {
    try {
      // Flush antes de exportar
      _flush();

      final diagnostics = await DeviceDiagnosticsService.generateReport();
      final logs = await getLogContents();

      final buffer = StringBuffer();
      buffer.write(diagnostics);
      buffer.writeln();
      buffer.write(logs);

      // Guardar en archivo temporal para compartir
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final exportFile = File('${tempDir.path}/cabina360_log_$timestamp.txt');
      await exportFile.writeAsString(buffer.toString());

      return exportFile;
    } catch (e) {
      print('❌ Error exportando logs: $e');
      rethrow;
    }
  }

  /// Libera recursos del servicio
  Future<void> dispose() async {
    _flushTimer?.cancel();
    _flush();
    await _sink?.close();
    _sink = null;
    _initialized = false;
  }
}

/// Servicio de diagnóstico del dispositivo.
///
/// Captura información del hardware y software para correlacionar con errores.
/// Incluye envío directo por WhatsApp al número del equipo de desarrollo.
class DeviceDiagnosticsService {
  /// Número de WhatsApp del equipo de desarrollo (hardcodeado)
  static const String _whatsappNumber = '524361072060';

  /// Número de WhatsApp accesible desde fuera
  static String get whatsappNumber => _whatsappNumber;

  /// Genera reporte de diagnóstico del dispositivo
  static Future<String> generateReport() async {
    final buffer = StringBuffer();

    buffer.writeln(
      '============================================================',
    );
    buffer.writeln('DIAGNÓSTICO CABINA 360');
    buffer.writeln('Fecha: ${DateTime.now().toIso8601String()}');
    buffer.writeln(
      '============================================================',
    );
    buffer.writeln();

    try {
      // Información del dispositivo
      buffer.writeln('--- DISPOSITIVO ---');
      if (Platform.isAndroid) {
        try {
          final deviceInfo = DeviceInfoPlugin();
          final androidInfo = await deviceInfo.androidInfo;
          buffer.writeln('Modelo: ${androidInfo.model}');
          buffer.writeln('Fabricante: ${androidInfo.manufacturer}');
          buffer.writeln(
            'Android: ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})',
          );
          buffer.writeln('Dispositivo físico: ${androidInfo.isPhysicalDevice}');
          buffer.writeln('Hardware: ${androidInfo.hardware}');
          buffer.writeln('Procesadores: ${Platform.numberOfProcessors}');
          buffer.writeln('ID dispositivo: ${androidInfo.id}');
        } catch (e) {
          buffer.writeln('Error obteniendo info de dispositivo: $e');
        }
      } else if (Platform.isIOS) {
        try {
          final deviceInfo = DeviceInfoPlugin();
          final iosInfo = await deviceInfo.iosInfo;
          buffer.writeln('Modelo: ${iosInfo.model}');
          buffer.writeln(
            'Sistema: ${iosInfo.systemName} ${iosInfo.systemVersion}',
          );
          buffer.writeln('Dispositivo físico: ${iosInfo.isPhysicalDevice}');
          buffer.writeln('Procesadores: ${Platform.numberOfProcessors}');
        } catch (e) {
          buffer.writeln('Error obteniendo info de dispositivo: $e');
        }
      }
      buffer.writeln();

      // Almacenamiento disponible
      buffer.writeln('--- ALMACENAMIENTO ---');
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final stat = await appDir.stat();
        buffer.writeln('Directorio app: ${appDir.path}');
        buffer.writeln('Modificado: ${stat.modified.toIso8601String()}');

        // Verificar espacio en directorio de videos
        try {
          final exportDir = await getExternalStorageDirectory();
          if (exportDir != null) {
            buffer.writeln('Directorio videos: ${exportDir.path}');
            List<FileSystemEntity> files = [];
            try {
              files = await exportDir.list().toList();
            } catch (_) {}
            buffer.writeln('Archivos en directorio: ${files.length}');
          }
        } catch (e) {
          buffer.writeln('Error obteniendo directorio de videos: $e');
        }
      } catch (e) {
        buffer.writeln('Error obteniendo info de almacenamiento: $e');
      }
      buffer.writeln();

      // Memoria
      buffer.writeln('--- MEMORIA ---');
      buffer.writeln(
        'Procesadores disponibles: ${Platform.numberOfProcessors}',
      );
      buffer.writeln();

      // Versión de la app
      buffer.writeln('--- APP ---');
      buffer.writeln('Versión: 1.0.0+1');
      buffer.writeln(
        'Plataforma: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      );
      buffer.writeln();
    } catch (e) {
      buffer.writeln('Error general generando diagnóstico: $e');
      buffer.writeln();
    }

    buffer.writeln(
      '============================================================',
    );
    buffer.writeln('LOGS DE SESIÓN');
    buffer.writeln(
      '============================================================',
    );
    buffer.writeln();

    return buffer.toString();
  }
}
