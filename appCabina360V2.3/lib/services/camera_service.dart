import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:cabina360_v2_2/services/logging_service.dart';

class CameraService {
  static CameraService? _instance;
  static CameraService get instance => _instance ??= CameraService._();

  CameraService._();

  List<CameraDescription> _cameras = [];
  CameraDescription? _frontCamera;
  CameraDescription? _backCamera;
  CameraDescription? _currentCamera;
  bool _isInitializing = false;

  // Getters
  List<CameraDescription> get cameras => _cameras;
  CameraDescription? get frontCamera => _frontCamera;
  CameraDescription? get backCamera => _backCamera;
  CameraDescription? get currentCamera => _currentCamera;
  bool get hasMultipleCameras => _cameras.length > 1;
  bool get isFrontCamera => _currentCamera == _frontCamera;
  bool get isInitializing => _isInitializing;

  /// Inicializa el servicio de cámaras con timeout y mejor manejo de errores
  Future<void> initialize() async {
    final log = LoggingService.instance;
    if (_isInitializing) {
      log.warning('Camera', 'CameraService ya se está inicializando');
      return;
    }

    _isInitializing = true;

    try {
      log.info('Camera', 'Iniciando CameraService...');

      // Timeout para la obtención de cámaras
      _cameras = await availableCameras().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log.warning('Camera', 'Timeout obteniendo cámaras disponibles');
          throw TimeoutException(
            'Timeout obteniendo cámaras',
            const Duration(seconds: 10),
          );
        },
      );

      if (_cameras.isEmpty) {
        throw Exception('No se encontraron cámaras disponibles');
      }

      _classifyCameras();
      await _loadUserPreference();

      log.info(
        'Camera',
        'CameraService inicializado: ${_cameras.length} cámaras encontradas',
      );
    } catch (e, stack) {
      log.error('Camera', 'Error inicializando CameraService', e, stack);
      _isInitializing = false;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Clasifica las cámaras disponibles
  void _classifyCameras() {
    final log = LoggingService.instance;
    _frontCamera = null;
    _backCamera = null;

    for (var camera in _cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        _frontCamera = camera;
        log.info('Camera', 'Cámara frontal encontrada: ${camera.name}');
      } else if (camera.lensDirection == CameraLensDirection.back) {
        _backCamera = camera;
        log.info('Camera', 'Cámara trasera encontrada: ${camera.name}');
      }
    }

    // Validar que al menos una cámara esté disponible
    if (_frontCamera == null && _backCamera == null) {
      log.warning(
        'Camera',
        'No se pudo clasificar ninguna cámara, usando la primera disponible',
      );
      if (_cameras.isNotEmpty) {
        _backCamera = _cameras.first;
      }
    }
  }

  /// Carga la preferencia del usuario
  Future<void> _loadUserPreference() async {
    final log = LoggingService.instance;
    try {
      final prefs = await SharedPreferences.getInstance();
      final useFrontCamera = prefs.getBool('useFrontCamera') ?? false;

      // Validar que la cámara preferida esté disponible
      if (useFrontCamera && _frontCamera != null) {
        _currentCamera = _frontCamera;
        log.info('Camera', 'Usando cámara frontal (preferencia guardada)');
      } else if (_backCamera != null) {
        _currentCamera = _backCamera;
        log.info('Camera', 'Usando cámara trasera (por defecto)');
      } else if (_cameras.isNotEmpty) {
        _currentCamera = _cameras.first;
        log.info(
          'Camera',
          'Usando primera cámara disponible: ${_cameras.first.name}',
        );
      } else {
        throw Exception('No hay cámaras disponibles');
      }
    } catch (e, stack) {
      log.warning('Camera', 'Error cargando preferencia de cámara', e, stack);
      // Fallback a cámara trasera o primera disponible
      _currentCamera =
          _backCamera ?? (_cameras.isNotEmpty ? _cameras.first : null);
      if (_currentCamera == null) {
        throw Exception('No se pudo establecer una cámara por defecto');
      }
    }
  }

  /// Guarda la preferencia del usuario
  Future<void> saveUserPreference(bool useFrontCamera) async {
    final log = LoggingService.instance;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('useFrontCamera', useFrontCamera);
      log.info(
        'Camera',
        'Preferencia de cámara guardada: ${useFrontCamera ? "frontal" : "trasera"}',
      );
    } catch (e) {
      log.error('Camera', 'Error guardando preferencia de cámara', e);
    }
  }

  /// Cambia entre cámara frontal y trasera con validación
  Future<CameraDescription?> switchCamera() async {
    final log = LoggingService.instance;
    if (!hasMultipleCameras) {
      log.warning('Camera', 'Solo hay una cámara disponible');
      return _currentCamera;
    }

    try {
      if (_currentCamera == _backCamera && _frontCamera != null) {
        _currentCamera = _frontCamera;
        await saveUserPreference(true);
        log.info('Camera', 'Cambiando a cámara frontal');
      } else if (_currentCamera == _frontCamera && _backCamera != null) {
        _currentCamera = _backCamera;
        await saveUserPreference(false);
        log.info('Camera', 'Cambiando a cámara trasera');
      }

      return _currentCamera;
    } catch (e) {
      log.error('Camera', 'Error cambiando cámara', e);
      return _currentCamera;
    }
  }

  /// Obtiene la cámara actual con validación
  CameraDescription getCurrentCamera() {
    if (_currentCamera == null) {
      LoggingService.instance.warning(
        'Camera',
        'No hay cámara seleccionada, usando cámara por defecto',
      );
      _currentCamera = _backCamera ?? _cameras.first;
    }
    return _currentCamera!;
  }

  /// Verifica si se puede cambiar de cámara
  bool canSwitchCamera() {
    return hasMultipleCameras &&
        ((_currentCamera == _backCamera && _frontCamera != null) ||
            (_currentCamera == _frontCamera && _backCamera != null));
  }

  /// Reinicia el servicio de cámaras
  Future<void> reset() async {
    _isInitializing = false;
    _cameras.clear();
    _frontCamera = null;
    _backCamera = null;
    _currentCamera = null;
    LoggingService.instance.info('Camera', 'CameraService reiniciado');
  }

  /// Verifica el estado de las cámaras
  Map<String, dynamic> getCameraStatus() {
    return {
      'totalCameras': _cameras.length,
      'hasFrontCamera': _frontCamera != null,
      'hasBackCamera': _backCamera != null,
      'currentCamera': _currentCamera?.name ?? 'none',
      'isFrontCamera': isFrontCamera,
      'canSwitch': canSwitchCamera(),
      'isInitializing': _isInitializing,
    };
  }
}
