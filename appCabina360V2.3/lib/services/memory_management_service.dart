import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio optimizado para gestión de memoria
/// Implementa limpieza automática, pool de buffers y monitoreo
class MemoryManagementService {
  static MemoryManagementService? _instance;
  static MemoryManagementService get instance => _instance ??= MemoryManagementService._();

  MemoryManagementService._();

  // Pool de buffers reutilizables
  final List<List<int>> _bufferPool = [];
  final int _maxBufferPoolSize = 20;
  final int _maxBufferSize = 1024 * 1024; // 1MB por buffer
  
  // Cache de archivos temporales
  final Map<String, DateTime> _tempFileCache = {};
  final int _maxTempFileAge = 3600; // 1 hora en segundos
  
  // Monitoreo de memoria
  Timer? _memoryMonitorTimer;
  final List<MemorySnapshot> _memorySnapshots = [];
  final int _maxSnapshots = 100;
  
  // Configuración
  bool _autoCleanupEnabled = true;
  int _cleanupInterval = 300; // 5 minutos en segundos
  double _memoryThreshold = 0.8; // 80% de uso de memoria

  /// Inicializa el servicio
  Future<void> initialize() async {
    try {
      // Cargar configuración
      await _loadConfiguration();
      
      // Iniciar monitoreo automático
      _startMemoryMonitoring();
      
      // Limpieza inicial
      await _performCleanup();
      
      print('✅ MemoryManagementService inicializado');
    } catch (e) {
      print('❌ Error inicializando MemoryManagementService: $e');
      rethrow;
    }
  }

  /// Obtiene un buffer del pool
  List<int> getBuffer(int size) {
    // Buscar buffer existente del tamaño correcto
    for (int i = 0; i < _bufferPool.length; i++) {
      if (_bufferPool[i].length >= size) {
        final buffer = _bufferPool.removeAt(i);
        print('🔄 Buffer reutilizado del pool: ${buffer.length} bytes');
        return buffer;
      }
    }
    
    // Crear nuevo buffer si no hay uno disponible
    final newBuffer = List<int>.filled(size, 0);
    print('🆕 Nuevo buffer creado: $size bytes');
    return newBuffer;
  }

  /// Retorna un buffer al pool
  void returnBuffer(List<int> buffer) {
    if (buffer.length <= _maxBufferSize && _bufferPool.length < _maxBufferPoolSize) {
      // Limpiar buffer antes de retornarlo
      buffer.fillRange(0, buffer.length, 0);
      _bufferPool.add(buffer);
      print('🔄 Buffer retornado al pool: ${buffer.length} bytes');
    } else {
      print('🗑️ Buffer descartado (muy grande o pool lleno): ${buffer.length} bytes');
    }
  }

  /// Registra un archivo temporal para limpieza automática
  void registerTempFile(String filePath) {
    _tempFileCache[filePath] = DateTime.now();
    print('📁 Archivo temporal registrado: $filePath');
  }

  /// Limpia archivos temporales antiguos
  Future<void> cleanupTempFiles() async {
    try {
      final now = DateTime.now();
      final filesToDelete = <String>[];
      
      // Identificar archivos antiguos
      _tempFileCache.forEach((filePath, timestamp) {
        final age = now.difference(timestamp).inSeconds;
        if (age > _maxTempFileAge) {
          filesToDelete.add(filePath);
        }
      });
      
      // Eliminar archivos antiguos
      for (final filePath in filesToDelete) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
            print('🗑️ Archivo temporal eliminado: $filePath');
          }
          _tempFileCache.remove(filePath);
        } catch (e) {
          print('⚠️ Error eliminando archivo temporal $filePath: $e');
        }
      }
      
      print('🧹 Limpieza de archivos temporales completada: ${filesToDelete.length} archivos eliminados');
    } catch (e) {
      print('❌ Error en limpieza de archivos temporales: $e');
    }
  }

  /// Limpia directorios temporales del sistema
  Future<void> cleanupSystemTempDirs() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final appTempDir = Directory('${tempDir.path}/cabina360');
      
      if (await appTempDir.exists()) {
        final files = appTempDir.listSync();
        int deletedCount = 0;
        
        for (final entity in files) {
          if (entity is File) {
            try {
              final stat = await entity.stat();
              final age = DateTime.now().difference(stat.modified).inHours;
              
              // Eliminar archivos más antiguos de 2 horas
              if (age > 2) {
                await entity.delete();
                deletedCount++;
              }
            } catch (e) {
              print('⚠️ Error procesando archivo ${entity.path}: $e');
            }
          }
        }
        
        print('🧹 Directorio temporal del sistema limpiado: $deletedCount archivos eliminados');
      }
    } catch (e) {
      print('❌ Error limpiando directorio temporal del sistema: $e');
    }
  }

  /// Limpia el pool de buffers
  void cleanupBufferPool() {
    if (_bufferPool.length > _maxBufferPoolSize) {
      final excess = _bufferPool.length - _maxBufferPoolSize;
      _bufferPool.removeRange(0, excess);
      print('🧹 Pool de buffers limpiado: $excess buffers eliminados');
    }
  }

  /// Realiza limpieza completa
  Future<void> _performCleanup() async {
    try {
      print('🧹 Iniciando limpieza automática...');
      
      // Limpiar archivos temporales
      await cleanupTempFiles();
      
      // Limpiar directorios del sistema
      await cleanupSystemTempDirs();
      
      // Limpiar pool de buffers
      cleanupBufferPool();
      
      // Limpiar snapshots antiguos
      _cleanupOldSnapshots();
      
      print('✅ Limpieza automática completada');
    } catch (e) {
      print('❌ Error en limpieza automática: $e');
    }
  }

  /// Inicia monitoreo automático de memoria
  void _startMemoryMonitoring() {
    _memoryMonitorTimer = Timer.periodic(Duration(seconds: _cleanupInterval), (timer) async {
      try {
        // Tomar snapshot de memoria
        await _takeMemorySnapshot();
        
        // Verificar si se necesita limpieza
        if (_shouldPerformCleanup()) {
          await _performCleanup();
        }
      } catch (e) {
        print('❌ Error en monitoreo de memoria: $e');
      }
    });
    
    print('📊 Monitoreo de memoria iniciado (intervalo: ${_cleanupInterval}s)');
  }

  /// Toma un snapshot de memoria
  Future<void> _takeMemorySnapshot() async {
    try {
      final snapshot = MemorySnapshot(
        timestamp: DateTime.now(),
        bufferPoolSize: _bufferPool.length,
        tempFileCount: _tempFileCache.length,
        totalTempFileSize: await _calculateTotalTempFileSize(),
        memoryUsage: await _getCurrentMemoryUsage(),
      );
      
      _memorySnapshots.add(snapshot);
      
      // Mantener solo los snapshots más recientes
      if (_memorySnapshots.length > _maxSnapshots) {
        _memorySnapshots.removeAt(0);
      }
      
      print('📊 Snapshot de memoria tomado: ${snapshot.memoryUsage}MB');
    } catch (e) {
      print('⚠️ Error tomando snapshot de memoria: $e');
    }
  }

  /// Calcula el tamaño total de archivos temporales
  Future<int> _calculateTotalTempFileSize() async {
    int totalSize = 0;
    
    for (final filePath in _tempFileCache.keys) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      } catch (e) {
        // Ignorar errores en archivos individuales
      }
    }
    
    return totalSize;
  }

  /// Obtiene el uso actual de memoria
  Future<double> _getCurrentMemoryUsage() async {
    try {
      // En Flutter, no hay una API directa para obtener uso de memoria
      // Por ahora, calculamos basándonos en el pool de buffers y archivos temporales
      final bufferMemory = _bufferPool.fold<int>(0, (sum, buffer) => sum + buffer.length);
      final tempFileMemory = await _calculateTotalTempFileSize();
      
      // Convertir a MB
      return (bufferMemory + tempFileMemory) / (1024 * 1024);
    } catch (e) {
      print('⚠️ Error calculando uso de memoria: $e');
      return 0.0;
    }
  }

  /// Verifica si se debe realizar limpieza
  bool _shouldPerformCleanup() {
    if (!_autoCleanupEnabled) return false;
    
    // Limpiar si hay muchos archivos temporales
    if (_tempFileCache.length > 50) return true;
    
    // Limpiar si el pool de buffers está muy lleno
    if (_bufferPool.length > _maxBufferPoolSize * 0.8) return true;
    
    // Limpiar si hay snapshots antiguos
    if (_memorySnapshots.length > _maxSnapshots * 0.8) return true;
    
    return false;
  }

  /// Limpia snapshots antiguos
  void _cleanupOldSnapshots() {
    if (_memorySnapshots.length > _maxSnapshots) {
      final cutoff = DateTime.now().subtract(Duration(hours: 24));
      _memorySnapshots.removeWhere((snapshot) => snapshot.timestamp.isBefore(cutoff));
      print('🧹 Snapshots antiguos limpiados');
    }
  }

  /// Carga configuración
  Future<void> _loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoCleanupEnabled = prefs.getBool('autoCleanupEnabled') ?? true;
      _cleanupInterval = prefs.getInt('cleanupInterval') ?? 300;
      _memoryThreshold = prefs.getDouble('memoryThreshold') ?? 0.8;
      
      print('⚙️ Configuración de memoria cargada');
    } catch (e) {
      print('⚠️ Error cargando configuración de memoria: $e');
    }
  }

  /// Obtiene métricas de memoria
  Map<String, dynamic> getMemoryMetrics() {
    return {
      'bufferPoolSize': _bufferPool.length,
      'maxBufferPoolSize': _maxBufferPoolSize,
      'tempFileCount': _tempFileCache.length,
      'snapshotCount': _memorySnapshots.length,
      'autoCleanupEnabled': _autoCleanupEnabled,
      'cleanupInterval': _cleanupInterval,
      'memoryThreshold': _memoryThreshold,
    };
  }

  /// Obtiene historial de snapshots
  List<MemorySnapshot> getMemoryHistory() {
    return List.unmodifiable(_memorySnapshots);
  }

  /// Configura parámetros de limpieza
  Future<void> configureCleanup({
    bool? autoCleanupEnabled,
    int? cleanupInterval,
    double? memoryThreshold,
  }) async {
    try {
      if (autoCleanupEnabled != null) _autoCleanupEnabled = autoCleanupEnabled;
      if (cleanupInterval != null) _cleanupInterval = cleanupInterval;
      if (memoryThreshold != null) _memoryThreshold = memoryThreshold;
      
      // Guardar configuración
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('autoCleanupEnabled', _autoCleanupEnabled);
      await prefs.setInt('cleanupInterval', _cleanupInterval);
      await prefs.setDouble('memoryThreshold', _memoryThreshold);
      
      print('⚙️ Configuración de limpieza actualizada');
    } catch (e) {
      print('❌ Error configurando limpieza: $e');
    }
  }

  /// Fuerza una limpieza manual
  Future<void> forceCleanup() async {
    print('🧹 Limpieza manual iniciada...');
    await _performCleanup();
    print('✅ Limpieza manual completada');
  }

  /// Dispone recursos del servicio
  Future<void> dispose() async {
    try {
      // Detener monitoreo
      _memoryMonitorTimer?.cancel();
      
      // Limpiar pool de buffers
      _bufferPool.clear();
      
      // Limpiar cache de archivos
      _tempFileCache.clear();
      
      // Limpiar snapshots
      _memorySnapshots.clear();
      
      print('✅ MemoryManagementService liberado');
    } catch (e) {
      print('❌ Error liberando MemoryManagementService: $e');
    }
  }
}

/// Snapshot de memoria para monitoreo
class MemorySnapshot {
  final DateTime timestamp;
  final int bufferPoolSize;
  final int tempFileCount;
  final int totalTempFileSize;
  final double memoryUsage;

  MemorySnapshot({
    required this.timestamp,
    required this.bufferPoolSize,
    required this.tempFileCount,
    required this.totalTempFileSize,
    required this.memoryUsage,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'bufferPoolSize': bufferPoolSize,
      'tempFileCount': tempFileCount,
      'totalTempFileSize': totalTempFileSize,
      'memoryUsage': memoryUsage,
    };
  }

  factory MemorySnapshot.fromJson(Map<String, dynamic> json) {
    return MemorySnapshot(
      timestamp: DateTime.parse(json['timestamp']),
      bufferPoolSize: json['bufferPoolSize'],
      tempFileCount: json['tempFileCount'],
      totalTempFileSize: json['totalTempFileSize'],
      memoryUsage: json['memoryUsage'].toDouble(),
    );
  }
}
