import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:cabina360_v2_2/models/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:cabina360_v2_2/screens/config_screen.dart';
import 'package:cabina360_v2_2/screens/qr_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cabina360_v2_2/services/wifi_server_service.dart';
import 'package:cabina360_v2_2/screens/license_screen.dart';
import 'package:cabina360_v2_2/screens/onboarding/onboarding_screen.dart';

import 'package:cabina360_v2_2/services/license_service.dart';
import 'package:cabina360_v2_2/services/permission_service.dart';
import 'package:cabina360_v2_2/services/storage_service.dart';
import 'package:cabina360_v2_2/services/camera_service.dart'; // NUEVO: Importar CameraService
import 'package:cabina360_v2_2/services/usability_service.dart'; // NUEVO: Importar UsabilityService
import 'package:cabina360_v2_2/services/advanced_config_service.dart'; // NUEVO: Importar AdvancedConfigService
import 'package:cabina360_v2_2/services/video_presets_service.dart'; // NUEVO: Importar VideoPresetsService
import 'package:cabina360_v2_2/services/media_store_service.dart'; // NUEVO: Importar MediaStoreService
import 'package:cabina360_v2_2/services/logging_service.dart'; // NUEVO: Importar LoggingService
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:share_plus/share_plus.dart';

late List<CameraDescription> _cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar logging ANTES que nada
  await LoggingService.instance.initialize();
  final log = LoggingService.instance;
  log.info('App', 'Iniciando Cabina 360...');

  // 1. Capturar errores de Flutter framework
  FlutterError.onError = (details) {
    log.critical(
      'FlutterError',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
  };

  // 2. Capturar errores de plataforma
  PlatformDispatcher.instance.onError = (error, stack) {
    log.critical('PlatformError', error.toString(), error, stack);
    return true; // Manejado — no crashear
  };

  // 3. Timeout para availableCameras
  try {
    _cameras = await availableCameras().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        log.warning('Camera', 'Timeout obteniendo cámaras disponibles');
        return [];
      },
    );
    log.info('App', 'Cámaras encontradas: ${_cameras.length}');
  } catch (e, stack) {
    log.error('Camera', 'Error obteniendo cámaras', e, stack);
    _cameras = [];
  }

  // 4. Errores async no manejados via Zone
  runZonedGuarded(
    () {
      runApp(const LicenseGateApp());
    },
    (error, stack) {
      log.critical('UnhandledAsync', error.toString(), error, stack);
    },
  );
}

class LicenseGateApp extends StatefulWidget {
  const LicenseGateApp({super.key});

  @override
  State<LicenseGateApp> createState() => _LicenseGateAppState();
}

class _LicenseGateAppState extends State<LicenseGateApp> {
  bool _checking = true;
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    final log = LoggingService.instance;
    log.info('LicenseGate', 'Iniciando verificación de licencia...');

    String deviceId = 'unknown';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
      }
      log.info('LicenseGate', 'Device ID obtenido: $deviceId');
    } catch (e, stack) {
      log.warning('LicenseGate', 'Error obteniendo device ID', e, stack);
    }

    try {
      final license = await LicenseService.getSavedLicense();
      if (license != null) {
        log.info('LicenseGate', 'Licencia encontrada, validando...');
        final result = await LicenseService.validateLicense(license, deviceId);
        if (result.isValid) {
          log.info('LicenseGate', 'Licencia válida ✓');
        } else {
          log.warning('LicenseGate', 'Licencia inválida: ${result.error}');
        }
        if (mounted) {
          setState(() {
            _valid = result.isValid;
            _checking = false;
          });
        }
      } else {
        log.info(
          'LicenseGate',
          'No hay licencia guardada, mostrando pantalla de activación',
        );
        if (mounted) {
          setState(() {
            _valid = false;
            _checking = false;
          });
        }
      }
    } catch (e, stack) {
      log.error('LicenseGate', 'Error crítico verificando licencia', e, stack);
      if (mounted) {
        setState(() {
          _valid = false;
          _checking = false;
        });
      }
    }
  }

  void _onLicenseValidated() {
    setState(() {
      _valid = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (!_valid) {
      return MaterialApp(
        home: LicenseScreen(onLicenseValidated: _onLicenseValidated),
      );
    }
    return const MyApp();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final UsabilityService _usabilityService = UsabilityService.instance;
  final AdvancedConfigService _advancedConfigService =
      AdvancedConfigService.instance;
  bool _seenOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOnboarding();
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permissions when the user returns from system settings
    if (state == AppLifecycleState.resumed) {
      PermissionService.instance.recheckOnResume();
    }
  }

  Future<void> _checkOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seenOnboarding') ?? false;
      setState(() {
        _seenOnboarding = seen;
      });
    } catch (e) {
      // ignorar errores y mostrar onboarding por defecto
      setState(() {
        _seenOnboarding = false;
      });
    }
  }

  Future<void> _initializeServices() async {
    try {
      await PermissionService.instance.initialize();
      await _usabilityService.initialize();
      await _advancedConfigService.initialize();
    } catch (e) {
      print('Error inicializando servicios: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ThemeMode>(
      stream: _usabilityService.themeModeStream,
      builder: (context, snapshot) {
        final themeMode = snapshot.data ?? ThemeMode.system;

        return MaterialApp(
          title: 'Cabina 360 Luma',
          themeMode: themeMode,
          theme: _usabilityService.getCurrentTheme(context),
          darkTheme: _usabilityService.getCurrentTheme(context),
          home: _seenOnboarding
              ? const MyHomePage(title: 'Cabina 360')
              : OnboardingScreen(
                  onFinished: () {
                    setState(() {
                      _seenOnboarding = true;
                    });
                  },
                ),
        );
      },
    );
  }
}

var initMins = 15;
var initCount = 48;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CameraController? cameraController;
  int recordMins = initMins;
  int recordCount = initCount;
  ResolutionPreset resolutionPreset = ResolutionPreset.medium;
  DateTime currentClipStart = DateTime.now();
  String? ip;
  bool saving = false;
  bool moving = false;
  bool ffmpegRunning = false;
  bool working = false;
  bool socketConected = false;
  var lenController = TextEditingController(text: initMins.toString());
  var countController = TextEditingController(text: initCount.toString());
  var ipController = TextEditingController(text: '192.168.1.105');
  bool _permissionsChecked = false;
  int _countdownSeconds = 3;
  Timer? _countdownTimer;

  late ConfigCabina config;
  int tipoVideoResolution = 2;
  var totalDurationGlobal = 0;
  var noProccess = 0;
  var porcentGlobal = 0.0;
  var progressGlobal = 0.0;
  var procesCompleted = 0;
  var progressOlder = 0.0;

  IO.Socket? socket;

  // Services
  final WifiServerService _wifiServer = WifiServerService.instance;
  final StorageService _storageService = StorageService();
  bool _wifiServerRunning = false;

  // NUEVAS variables para gestión de cámara
  late CameraService _cameraService;
  bool _isSwitchingCamera = false;
  bool _isInitializingCamera = false; // NUEVO: bandera para inicialización

  // NUEVO: Servicio de presets de video
  final VideoPresetsService _videoPresetsService = VideoPresetsService.instance;
  final MediaStoreService _mediaStoreService = MediaStoreService(); // NUEVO

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Mantiene la pantalla encendida
    _cameraService = CameraService.instance; // NUEVO: Inicializar CameraService
    _loadConfig();
    _initializeServices();
    _initializeCamera(); // NUEVO: Inicializar cámara con el servicio
    FFmpegKitConfig.enableStatisticsCallback(statisticsCallback);
    // Reemplazar disableLogs por log callback filtrado para capturar errores de FFmpeg
    FFmpegKitConfig.enableLogCallback((log) {
      final message = log.getMessage();
      if (message.contains('Error') ||
          message.contains('error') ||
          message.contains('Warning') ||
          message.contains('failed') ||
          message.contains('Invalid') ||
          message.contains('Cannot')) {
        LoggingService.instance.warning('FFmpeg', message);
      }
    });
  }

  Future<void> _initializeServices() async {
    final log = LoggingService.instance;
    try {
      await _storageService.init();
      await _videoPresetsService.initialize();
      log.info('App', 'Servicios inicializados correctamente');
    } catch (e, stack) {
      log.error('App', 'Error inicializando servicios', e, stack);
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only check if required permissions are granted — do NOT re-request.
    // Permissions are handled in the onboarding screen.
    if (!_permissionsChecked && mounted) {
      _permissionsChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!PermissionService.instance.areAllRequiredGranted()) {
          LoggingService.instance.warning(
            'App',
            'Algunos permisos requeridos no están concedidos. '
                'El usuario puede concederlos desde la pantalla de configuración.',
          );
        }
      });
    }
  }

  void statisticsCallback(Statistics statistics) {
    if (noProccess == 0) {
      return;
    }

    var time = statistics.getTime() / 1000;
    var nowPorcent = (time * 100) / (totalDurationGlobal);
    var totalProcent = nowPorcent / noProccess;
    var progressGlobal = procesCompleted == 0
        ? 0
        : (100 / noProccess * procesCompleted);
    var progressTmp = totalProcent + progressGlobal;
    var tmp = progressTmp.toStringAsFixed(0);

    setState(() {
      porcentGlobal = progressTmp;
    });

    if (progressTmp > progressOlder) {
      var difProgressOld = progressTmp - progressOlder;
      LoggingService.instance.debug('FFmpeg', "progress diff: $difProgressOld");
      if (difProgressOld < 10 && socket != null && socketConected) {
        socket!.emit("serverProgress", tmp);
        progressOlder = progressTmp;
      }
    }
  }

  late Timer _timer;
  int _start = 10;

  void startTimer() {
    setState(() {
      _start = recordMins; // Cambiar de recordMins + 1 a recordMins
      runTimer();
    });
  }

  void connect() {
    String ip = "http://${ipController.text}:3000";

    socket = IO.io(
      ip,
      IO.OptionBuilder().setTransports(['websocket']).setQuery({
        'app': 'flutter',
      }).build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      setState(() {
        socketConected = true;
      });

      socket!.emit("appInitServer", "app conectada");
    });

    socket!.onDisconnect((data) {
      setState(() {
        socketConected = false;
      });
    });

    socket!.on('appInitRecord', (data) {
      try {
        config = ConfigCabina.fromJson(data);
        setState(() async {
          recordMins = config.duration;
          lenController.text = config.duration.toString();
          recordRecursively();
        });
      } catch (e) {
        LoggingService.instance.error('Socket', 'Error en appInitRecord', e);
      }
    });

    socket!.on('appChangeQuality', (data) {
      var q = QualityChange.fromJson(data);
      setState(() {
        try {
          switch (q.quality) {
            case 1:
              resolutionPreset = ResolutionPreset.low;
              break;
            case 2:
              resolutionPreset = ResolutionPreset.medium;
              break;
            case 3:
              resolutionPreset = ResolutionPreset.high;
              break;
            case 4:
              resolutionPreset = ResolutionPreset.veryHigh;
              break;
          }

          tipoVideoResolution = q.quality;

          initCam();
        } catch (e) {
          LoggingService.instance.error(
            'Socket',
            'Error en appChangeQuality',
            e,
          );
        }
      });
    });
  }

  void runTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer timer) {
      if (_start <= 0) {
        // Cambiar de _start == 0 a _start <= 0
        setState(() {
          _timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable(); // Permite que la pantalla se apague al salir
    _countdownTimer?.cancel();
    try {
      cameraController?.removeListener(() {});
      if (cameraController?.value.isInitialized ?? false) {
        cameraController?.dispose(); // No await aquí, dispose sync
      }
    } catch (e) {
      LoggingService.instance.error('Camera', 'Error al liberar la cámara', e);
    }
    super.dispose();
  }

  // NUEVO: Función para inicializar cámara con el servicio
  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initialize();
      await initCam();
    } catch (e) {
      LoggingService.instance.error('Camera', 'Error inicializando cámara', e);
      showInSnackBar('Error al inicializar la cámara: $e');
    }
  }

  // NUEVO: Función para cambiar de cámara
  Future<void> _switchCamera() async {
    if (_isSwitchingCamera || !_cameraService.canSwitchCamera()) {
      return;
    }

    setState(() {
      _isSwitchingCamera = true;
    });

    try {
      final newCamera = await _cameraService.switchCamera();
      if (newCamera != null) {
        await initCam();
        showInSnackBar(
          'Cámara cambiada a ${_cameraService.isFrontCamera ? "frontal" : "trasera"}',
        );
      }
    } catch (e) {
      LoggingService.instance.error('Camera', 'Error cambiando cámara', e);
      showInSnackBar('Error al cambiar cámara: $e');
    } finally {
      setState(() {
        _isSwitchingCamera = false;
      });
    }
  }

  Future<void> initCam() async {
    if (_isInitializingCamera) {
      LoggingService.instance.debug(
        'Camera',
        '[initCam] Ya se está inicializando la cámara, salgo',
      );
      return;
    }
    LoggingService.instance.info(
      'Camera',
      '[initCam] Iniciando inicialización de cámara',
    );
    _isInitializingCamera = true;
    try {
      if (cameraController?.value.isInitialized ?? false) {
        LoggingService.instance.debug(
          'Camera',
          '[initCam] Omitiendo dispose del CameraController anterior (workaround)',
        );
        // NO se hace dispose aquí
        // cameraController?.removeListener(() {});
        // try {
        //   await cameraController?.dispose().timeout(
        //     const Duration(seconds: 2),
        //     onTimeout: () {
        //       print('[initCam] WARNING: Dispose de CameraController tardó demasiado, continúo el flujo');
        //       showInSnackBar('Advertencia: la cámara tardó en liberar recursos, pero se continuará.');
        //       return null;
        //     },
        //   );
        // } catch (e) {
        //   print('[initCam] ERROR en dispose: $e');
        // }
        // print('[initCam] Dispose completado (o forzado por timeout)');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final selectedCamera = _cameraService.getCurrentCamera();
      LoggingService.instance.info(
        'Camera',
        '[initCam] Creando CameraController con resolución: $resolutionPreset',
      );
      cameraController = CameraController(selectedCamera, resolutionPreset);

      cameraController?.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

      LoggingService.instance.info(
        'Camera',
        '[initCam] Inicializando CameraController...',
      );
      await cameraController?.initialize();
      LoggingService.instance.info(
        'Camera',
        '[initCam] CameraController inicializado',
      );

      if (!mounted) {
        LoggingService.instance.debug(
          'Camera',
          '[initCam] Widget desmontado tras inicializar cámara',
        );
        _isInitializingCamera = false;
        return;
      }

      setState(() {});
      LoggingService.instance.debug(
        'Camera',
        '[initCam] setState ejecutado tras inicializar cámara',
      );
    } catch (e) {
      LoggingService.instance.error(
        'Camera',
        '[initCam] Error durante inicialización',
        e,
      );
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            showInSnackBar('Acceso a la cámara denegado');
            break;
          default:
            showInSnackBar('Error desconocido: ${e.code}');
            break;
        }
      } else {
        showInSnackBar('Error al inicializar la cámara: $e');
      }
    } finally {
      LoggingService.instance.info(
        'Camera',
        '[initCam] Inicialización de cámara finalizada',
      );
      _isInitializingCamera = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar removida para full screen
      body: Builder(
        builder: (context) {
          final double topSafe = MediaQuery.of(context).padding.top;
          return Stack(
            children: [
              // Preview de cámara ocupa todo el fondo, recortando el exceso (BoxFit.cover)
              if (!ffmpegRunning) // Solo mostrar preview si no está procesando FFmpeg
                _buildCameraPreview(),
              // Fondo negro durante procesamiento FFmpeg
              if (ffmpegRunning)
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black,
                ),
              // NUEVA BARRA SUPERIOR: Solo botones a la derecha
              Positioned(
                top: 16 + topSafe,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(),
                      // Botón wifi
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _wifiServerRunning ? Icons.wifi : Icons.wifi_off,
                            color: _wifiServerRunning
                                ? Colors.green
                                : Colors.white,
                            size: 22,
                          ),
                          iconSize: 32,
                          onPressed: () => _toggleWifiServer(),
                          tooltip: _wifiServerRunning
                              ? 'Detener WiFi'
                              : 'Iniciar WiFi',
                        ),
                      ),
                      // Botón QR
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.qr_code,
                            color: _wifiServerRunning
                                ? Colors.blue
                                : Colors.white,
                            size: 22,
                          ),
                          iconSize: 32,
                          onPressed: _wifiServerRunning
                              ? () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const QRScreen(),
                                    ),
                                  );
                                }
                              : null,
                          tooltip: _wifiServerRunning
                              ? 'Mostrar código QR para compartir videos'
                              : 'Activa el servidor WiFi primero',
                        ),
                      ),
                      // Botón eliminar videos
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete_forever,
                            color: Colors.white,
                            size: 22,
                          ),
                          iconSize: 32,
                          onPressed: !working && !ffmpegRunning
                              ? clearAllRecordings
                              : null,
                          tooltip: 'Borrar todos los videos',
                        ),
                      ),
                      // Botón de presets de video
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.movie_filter,
                            color: _videoPresetsService.hasPresetSelected
                                ? Colors.orange
                                : Colors.white,
                            size: 22,
                          ),
                          iconSize: 32,
                          onPressed: () => _showPresetSelector(),
                          tooltip: _videoPresetsService.hasPresetSelected
                              ? 'Preset: ${_videoPresetsService.selectedPreset?.name}'
                              : 'Seleccionar preset de video',
                        ),
                      ),
                      // Botón configuración (al final)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.settings,
                            color: Colors.white,
                            size: 22,
                          ),
                          iconSize: 32,
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ConfigScreen(
                                  initialConfig: config,
                                  onConfigChanged: (newConfig) {
                                    setState(() {
                                      config = newConfig;
                                      recordMins = newConfig.duration;
                                      lenController.text = newConfig.duration
                                          .toString();
                                    });
                                    _wifiServer.setWifiName(
                                      newConfig.wifiName.isNotEmpty
                                          ? newConfig.wifiName
                                          : null,
                                    );
                                  },
                                ),
                              ),
                            );
                            await _loadConfig();
                          },
                          tooltip: 'Configuración',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Imagen flotante independiente en la esquina superior izquierda (sin fondo, más grande)
              Positioned(
                top: 16 + topSafe,
                left: 16,
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  height: 56,
                  width: 56,
                  fit: BoxFit.contain,
                ),
              ),
              // Icono de duración (izquierda del botón de grabar)
              Positioned(
                bottom: 60,
                left: 32,
                child: GestureDetector(
                  onTapDown: (details) async {
                    final selected = await showMenu<int>(
                      context: context,
                      position: RelativeRect.fromLTRB(
                        details.globalPosition.dx,
                        details.globalPosition.dy,
                        details.globalPosition.dx + 1,
                        details.globalPosition.dy + 1,
                      ),
                      items: List.generate(60, (i) => i + 1)
                          .map(
                            (v) => PopupMenuItem<int>(
                              value: v,
                              child: Text('$v s'),
                            ),
                          )
                          .toList(),
                    );
                    if (selected != null) {
                      setState(() {
                        recordMins = selected;
                        lenController.text = selected.toString();
                      });
                    }
                  },
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.timer,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$recordMins',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Icono de resolución (abajo derecha) y botón de cambiar de cámara (más arriba, alineado a la derecha)
              // Botón de resolución
              Positioned(
                bottom: 60,
                right: 32,
                child: GestureDetector(
                  onTapDown: (details) async {
                    final selected = await showMenu<ResolutionPreset>(
                      context: context,
                      position: RelativeRect.fromLTRB(
                        details.globalPosition.dx,
                        details.globalPosition.dy,
                        details.globalPosition.dx + 1,
                        details.globalPosition.dy + 1,
                      ),
                      items: ResolutionPreset.values
                          .where(
                            (e) =>
                                e.name == 'low' ||
                                e.name == 'medium' ||
                                e.name == 'high' ||
                                e.name == 'veryHigh',
                          )
                          .map(
                            (e) => PopupMenuItem<ResolutionPreset>(
                              value: e,
                              child: Text(e.name),
                            ),
                          )
                          .toList(),
                    );
                    if (selected != null) {
                      setState(() {
                        resolutionPreset = selected;
                      });
                      initCam();
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.high_quality,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          resolutionPreset.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Botón de cambiar de cámara (más arriba, alineado a la derecha)
              if (CameraService.instance.hasMultipleCameras)
                Positioned(
                  bottom: 146,
                  right: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.cameraswitch,
                        color: Colors.white,
                        size: 26,
                      ),
                      iconSize: 38,
                      onPressed: _isSwitchingCamera ? null : _switchCamera,
                      tooltip: 'Cambiar cámara',
                    ),
                  ),
                ),
              // Botón de grabar grande, centrado abajo
              Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                    child: IconButton(
                      icon: Icon(
                        cameraController?.value.isRecordingVideo ?? false
                            ? Icons.square
                            : Icons.circle,
                        size: 70,
                        color: cameraController?.value.isRecordingVideo ?? false
                            ? Colors.red
                            : Colors.white,
                      ),
                      onPressed: recordMins > 0 && recordCount >= 0
                          ? () {
                              if (_storageService.saveDir == null) {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext ctx) {
                                    return const AlertDialog(
                                      title: Text('Error de Almacenamiento'),
                                      content: Text(
                                        'No se pudo configurar el directorio de almacenamiento. Este error es irrecuperable.',
                                      ),
                                    );
                                  },
                                );
                              } else {
                                recordRecursively();
                              }
                            }
                          : null,
                    ),
                  ),
                ),
              ),
              // Overlay de conteo regresivo antes de grabar
              if (_countdownSeconds > 0 && working)
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      '$_countdownSeconds',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              // Indicador de tiempo de grabación
              if (cameraController?.value.isRecordingVideo ?? false)
                Positioned(
                  top: 100 + MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${recordMins - _start}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            's',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Loader si está inicializando cámara
              if (_isInitializingCamera)
                const Center(child: CircularProgressIndicator()),
              // Barra de progreso FFmpeg
              if (ffmpegRunning)
                Positioned(
                  bottom: 200,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Procesando video...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${procesCompleted + 1}/$noProccess',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: porcentGlobal / 100,
                          backgroundColor: Colors.grey[600],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${porcentGlobal.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Calcula las dimensiones del preview según la calidad del video
  /// Retorna un Map con width y eight optimizados para la resolución seleccionada
  Map<String, double> _calculatePreviewDimensions() {
    final screenHeight = MediaQuery.of(context).size.height;
    final aspectRatio = cameraController!.value.aspectRatio;
    final currentResolution = resolutionPreset;

    // Definir factores de escala según la calidad del video
    double widthFactor;
    double heightFactor;

    switch (currentResolution) {
      case ResolutionPreset.low:
        // Para baja calidad, usar factor más pequeño para mejor rendimiento
        widthFactor = 0.8;
        heightFactor = 0.15;
        break;
      case ResolutionPreset.medium:
        // Calidad media, balance entre rendimiento y calidad
        widthFactor = 0.1;
        heightFactor = 0.22;
        break;
      case ResolutionPreset.high:
        // Alta calidad, factor más grande para mejor visualización
        widthFactor = 0.04;
        heightFactor = 0.12;
        break;
      case ResolutionPreset.veryHigh:
        // Muy alta calidad, máximo factor para mejor detalle
        widthFactor = 0.018;
        heightFactor = 0.06;
        break;
      default:
        // Fallback a calidad media
        widthFactor = 0.1;
        heightFactor = 0.22;
    }

    // Calcular dimensiones base respetando el aspect ratio de la cámara
    double baseWidth = aspectRatio * screenHeight * widthFactor;
    // double baseWidth = aspectRatio * screenHeight * widthFactor;
    double baseHeight = screenHeight * heightFactor;

    return {'width': baseWidth, 'height': baseHeight};
  }

  Widget _buildCameraPreview() {
    if (!(cameraController?.value.isInitialized ?? false)) {
      return const Center(child: Text('Sin acceso a la cámara'));
    }

    // Obtener dimensiones calculadas según la calidad
    final dimensions = _calculatePreviewDimensions();

    // Usar las dimensiones calculadas en lugar de valores fijos
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: dimensions['width']!,
          height: dimensions['height']!,
          child: CameraPreview(cameraController!),
        ),
      ),
    );
  }

  void showInSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? getStatusText() {
    if (recordMins <= 0 || recordCount < 0) {
      return null;
    }
    String status1 = cameraController?.value.isRecordingVideo ?? false
        ? 'Now recording'
        : 'Set to record';
    int totalMins = recordMins * recordCount;
    String status2 =
        '$recordMins min clips ${recordCount == 0 ? '(until space runs out)' : '(keeping the latest ${totalMins < 60 ? '$totalMins minutes' : '${totalMins / 60} hours'})'}.';
    return '$status1 $status2';
  }

  Future<void> recordRecursively() async {
    if (recordMins > 0 && recordCount >= 0) {
      try {
        if (!cameraController!.value.isInitialized) {
          throw CameraException(
            'camera_not_initialized',
            'La cámara no está inicializada',
          );
        }

        setState(() {
          _countdownSeconds = 3;
          working = true;
        });

        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(seconds: 1));
          setState(() {
            _countdownSeconds--;
          });
        }

        await cameraController!.startVideoRecording();
        startTimer();
        setState(() {
          currentClipStart = DateTime.now();
        });
        await Future.delayed(
          Duration(milliseconds: (recordMins * 1000).toInt()),
        );
        await stopRecording(true);
      } catch (e) {
        LoggingService.instance.error(
          'Recording',
          'Error al iniciar la grabación',
          e,
        );
        setState(() {
          working = false;
          _countdownSeconds = 3;
        });
        showInSnackBar('Error al iniciar la grabación: $e');
      }
    }
  }

  Future<void> stopRecording(bool cleanup) async {
    if (cameraController?.value.isRecordingVideo ?? false) {
      try {
        if (!cameraController!.value.isInitialized) {
          throw CameraException(
            'camera_not_initialized',
            'La cámara no está inicializada',
          );
        }

        LoggingService.instance.info('Recording', 'Deteniendo la grabación...');
        XFile tempFile = await cameraController!.stopVideoRecording();
        setState(() {});

        String filePath = _storageService.latestFilePath();
        LoggingService.instance.info(
          'Recording',
          'Guardando video temporal en: $filePath',
        );

        setState(() {
          saving = true;
          ffmpegRunning = true;
        });

        await _storageService.saveDir?.create(recursive: true);

        await tempFile.saveTo(filePath);
        LoggingService.instance.info(
          'Recording',
          'Video temporal guardado correctamente',
        );

        if (!await File(filePath).exists()) {
          throw Exception('Failed to save temporary video file');
        }

        await File(tempFile.path).delete();

        setState(() {
          saving = false;
        });

        await cameraController?.dispose();
        await Future.delayed(const Duration(milliseconds: 500));

        await initCam();

        String out = filePath;

        if (socket != null && socketConected) {
          socket!.emit("serverInitCoding", "app conectada");
        }

        String bitrate = "3000k";
        String crf = "";
        String codec = "-c:v libx264 -c:a aac";

        noProccess = 0;
        if (config.enabledVideoFilter) noProccess++;
        if (config.enabledContornoVideo) noProccess++;
        if (config.enabledLogo) noProccess++;
        if (config.enabledAudioFondo) noProccess++;

        LoggingService.instance.info(
          'FFmpeg',
          'Número de procesos FFmpeg a ejecutar: $noProccess',
        );
        LoggingService.instance.info(
          'FFmpeg',
          'Configuración: VideoFilter=${config.enabledVideoFilter}, Contorno=${config.enabledContornoVideo}, Logo=${config.enabledLogo}, Audio=${config.enabledAudioFondo}',
        );

        procesCompleted = 0;

        int durationTotal = config.duration;

        if (config.enabledVideoFilter) {
          LoggingService.instance.info(
            'FFmpeg',
            'Iniciando procesamiento de efectos de video...',
          );
          out = _storageService.efectoFilePath();
          LoggingService.instance.info(
            'FFmpeg',
            'Ruta de salida para efectos: $out',
          );

          if (!await File(filePath).exists()) {
            throw Exception('Input video file not found: $filePath');
          }

          int duration = config.duration;
          int duracionParte1N = calcDuration(30, duration);
          int duracionParte2L = calcDuration(20, duration);
          int duracionParte3N = calcDuration(25, duration);
          int parte1Ini = 0;
          int parte1End = duracionParte1N;
          int parte2Ini = duracionParte1N;
          int parte2End = duracionParte1N + duracionParte2L;
          int parte3Ini = duracionParte1N + duracionParte2L;
          int parte3End = duracionParte1N + duracionParte2L + duracionParte3N;

          totalDurationGlobal =
              duracionParte1N * 2 + duracionParte2L * 2 + duracionParte3N * 4;

          String inputs = '-i $filePath';
          String filtercomplex =
              '[0]trim=start=0:end=$parte1End,setpts=PTS-STARTPTS[normal1];';
          filtercomplex +=
              '[0]trim=start=$parte2Ini:end=$parte2End,setpts=PTS-STARTPTS[toslow];';
          filtercomplex +=
              '[0]trim=start=$parte3Ini:end=$parte3End,setpts=PTS-STARTPTS[normal2];';
          filtercomplex +=
              '[0]trim=start=$parte3Ini:end=$parte3End,setpts=PTS-STARTPTS[tr1];';
          filtercomplex +=
              '[0]trim=start=$parte2Ini:end=$parte2End,setpts=PTS-STARTPTS[toreverseslow1];';
          filtercomplex +=
              '[0]trim=start=$parte1Ini:end=$parte1End,setpts=PTS-STARTPTS[toreverse2];';
          filtercomplex += '[toslow]setpts=1.5*PTS[slow];';
          filtercomplex += '[tr1]reverse[reverse1];';
          filtercomplex +=
              '[toreverseslow1]setpts=1.5*PTS,reverse[reverseslow1];';
          filtercomplex += '[toreverse2]reverse[reverse2];';
          filtercomplex +=
              '[normal1][slow][normal2][reverse1][reverseslow1][reverse2]concat=n=6:v=1:a=0[out]';

          String comm =
              '$inputs -filter_complex $filtercomplex -map "[out]" $crf -b:v $bitrate $codec -y $out';

          try {
            LoggingService.instance.info(
              'FFmpeg',
              'Ejecutando filter_complex: $comm',
            );
            final session = await FFmpegKit.execute(comm).timeout(
              const Duration(minutes: 5),
              onTimeout: () {
                LoggingService.instance.warning(
                  'FFmpeg',
                  'Timeout en efectos de video (5min), cancelando',
                );
                FFmpegKit.cancel();
                throw TimeoutException('FFmpeg video filter timeout');
              },
            );
            final returnCode = await session.getReturnCode();

            if (ReturnCode.isSuccess(returnCode)) {
              if (!await File(out).exists()) {
                throw Exception('Failed to create effect video file');
              }
              final mediaInformation = await FFprobeKit.getMediaInformation(
                out,
              );
              final information = mediaInformation.getMediaInformation();
              final duration = information?.getDuration();
              if (duration != null) {
                try {
                  durationTotal = int.parse(duration.split('.')[0]);
                  totalDurationGlobal = durationTotal;
                } catch (e) {
                  LoggingService.instance.warning(
                    'FFmpeg',
                    'Error al parsear la duración: $e',
                  );
                  durationTotal = config.duration;
                }
              }

              procesCompleted++;
              filePath = out;
            } else {
              // ERROR RECOVERY: Si el filtro falla, continuar sin filtro
              final logs = await session.getLogs();
              final lastLogs =
                  (logs.length > 10 ? logs.sublist(logs.length - 10) : logs)
                      .map((l) => l.getMessage())
                      .join(' | ');
              LoggingService.instance.error(
                'FFmpeg',
                'Efectos fallaron, continuando sin filtro',
                null,
                null,
                {'returnCode': returnCode?.toString(), 'lastLogs': lastLogs},
              );
              procesCompleted++;
              // No cambiar filePath — se usa el video original sin filtro
            }
          } catch (e) {
            // ERROR RECOVERY: Continuar sin filtro si falla
            if (e is TimeoutException) {
              LoggingService.instance.warning(
                'FFmpeg',
                'Timeout en efectos, continuando sin filtro',
              );
            } else {
              LoggingService.instance.error(
                'FFmpeg',
                'Error procesando efectos, continuando sin filtro',
                e,
              );
            }
            procesCompleted++;
            // No cambiar filePath — se usa el video original sin filtro
          }
        }

        if (config.enabledContornoVideo) {
          LoggingService.instance.info(
            'FFmpeg',
            'Iniciando procesamiento de marco...',
          );
          out = _storageService.marcoVideoFilePath();
          LoggingService.instance.info(
            'FFmpeg',
            'Ruta de salida para marco: $out',
          );

          if (!await File(filePath).exists()) {
            throw Exception('Input video file not found for marco: $filePath');
          }

          var input = config.contornoVideo;
          LoggingService.instance.info(
            'FFmpeg',
            'Intentando usar archivo de marco: $input',
          );
          if (input == '1' || !(await File(input).exists())) {
            LoggingService.instance.info(
              'FFmpeg',
              'Archivo de marco no existe o es valor por defecto, usando asset.',
            );
            input = await _storageService.getMarcoVideo('1');
            setState(() {
              config = ConfigCabina(
                duration: config.duration,
                enabledVideoFilter: config.enabledVideoFilter,
                enabledContornoVideo: config.enabledContornoVideo,
                enabledLogo: config.enabledLogo,
                enabledAudioFondo: config.enabledAudioFondo,
                contornoVideo: input,
                audioFondo: config.audioFondo,
                logoPosition: config.logoPosition,
                whatsApp: config.whatsApp,
                enabledINTERNET: config.enabledINTERNET,
              );
            });
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('marcoPath', input);
          }
          LoggingService.instance.info(
            'FFmpeg',
            'Archivo de marco realmente usado: $input',
          );

          if (!await File(input).exists()) {
            LoggingService.instance.error(
              'FFmpeg',
              'El archivo de marco no existe: $input',
            );
          }

          // 1. Obtener resolución del video
          final probeSession = await FFprobeKit.getMediaInformation(filePath);
          final info = probeSession.getMediaInformation();
          final width = info
              ?.getStreams()
              .firstWhere((s) => s.getType() == 'video')
              .getWidth();
          final height = info
              ?.getStreams()
              .firstWhere((s) => s.getType() == 'video')
              .getHeight();
          if (width == null || height == null) {
            throw Exception('No se pudo obtener la resolución del video');
          }
          LoggingService.instance.info(
            'FFmpeg',
            'Resolución del video: ${width}x${height}',
          );

          // 2. Escalar marco a resolución exacta
          final marcoEscalado = input + '_scaled.png';
          final scaleCmd =
              '-i "$input" -vf scale=${width}:${height} "$marcoEscalado" -y';
          LoggingService.instance.info(
            'FFmpeg',
            'Comando para escalar marco: $scaleCmd',
          );
          final scaleSession = await FFmpegKit.execute(scaleCmd);
          if (!ReturnCode.isSuccess(await scaleSession.getReturnCode())) {
            LoggingService.instance.warning(
              'FFmpeg',
              'Error al escalar el marco, usando el original',
            );
          }

          // 3. Overlay usando el marco escalado
          String marcoParaOverlay = await File(marcoEscalado).exists()
              ? marcoEscalado
              : input;
          String filtercomplex =
              '-filter_complex "[1]format=rgba[wm];[0][wm]overlay=0:0[out]"';
          String comm =
              ' -i $filePath -i $marcoParaOverlay $filtercomplex -map "[out]" $crf -b:v $bitrate $codec -y $out';

          LoggingService.instance.info(
            'FFmpeg',
            'Comando overlay de marco: $comm',
          );

          try {
            final session = await FFmpegKit.execute(comm);
            final returnCode = await session.getReturnCode();
            final logs = await session.getLogs();

            // Capturar logs de FFmpeg solo si hay error
            if (!ReturnCode.isSuccess(returnCode)) {
              final lastLogs =
                  (logs.length > 10 ? logs.sublist(logs.length - 10) : logs)
                      .map((l) => l.getMessage())
                      .join(' | ');
              LoggingService.instance.warning(
                'FFmpeg',
                'Logs marco: $lastLogs',
              );
            }

            if (!ReturnCode.isSuccess(returnCode)) {
              LoggingService.instance.warning(
                'FFmpeg',
                'Error en overlay de marco, intentando comando alternativo...',
              );
              // Comando alternativo: overlay sin formato rgba
              String altFiltercomplex =
                  '-filter_complex "[1]scale=${width}:${height}[wm];[0][wm]overlay=0:0[out]"';
              String altComm =
                  ' -i $filePath -i $input $altFiltercomplex -map "[out]" $crf -b:v $bitrate $codec -y $out';
              LoggingService.instance.info(
                'FFmpeg',
                'Comando alternativo: $altComm',
              );
              final altSession = await FFmpegKit.execute(altComm);
              final altReturnCode = await altSession.getReturnCode();
              if (!ReturnCode.isSuccess(altReturnCode)) {
                throw Exception(
                  "Error en la ejecución de FFmpeg para marco (ambos comandos fallaron)",
                );
              }
            }

            if (!await File(out).exists()) {
              throw Exception('Failed to create marco video file');
            }

            filePath = out;
            procesCompleted++;
          } catch (e) {
            LoggingService.instance.error(
              'FFmpeg',
              'Error crítico en procesamiento de marco, continuando sin marco',
              e,
            );
            procesCompleted++;
          }
        }

        if (config.enabledLogo) {
          LoggingService.instance.info(
            'FFmpeg',
            'Iniciando procesamiento de logo...',
          );
          out = _storageService.logoVideoFilePath();
          LoggingService.instance.info(
            'FFmpeg',
            'Ruta de salida para logo: $out',
          );

          final outputFile = File(out);
          if (await outputFile.exists()) {
            LoggingService.instance.debug(
              'FFmpeg',
              'Eliminando archivo de salida existente: $out',
            );
            await outputFile.delete();
          }

          if (!await File(filePath).exists()) {
            throw Exception('Input video file not found for logo: $filePath');
          }

          final prefs = await SharedPreferences.getInstance();
          String img1 = prefs.getString('logoPath') ?? config.logoPosition;
          LoggingService.instance.info(
            'FFmpeg',
            'Intentando usar archivo de logo: $img1',
          );
          if (img1 == 'rb' ||
              img1 == 'lt' ||
              img1 == 'rt' ||
              img1 == 'lb' ||
              !(await File(img1).exists())) {
            LoggingService.instance.info(
              'FFmpeg',
              'Archivo de logo no existe o es posición, usando asset.',
            );
            img1 = await _storageService.getLogo();
            setState(() {
              config = ConfigCabina(
                duration: config.duration,
                enabledVideoFilter: config.enabledVideoFilter,
                enabledContornoVideo: config.enabledContornoVideo,
                enabledLogo: config.enabledLogo,
                enabledAudioFondo: config.enabledAudioFondo,
                contornoVideo: config.contornoVideo,
                audioFondo: config.audioFondo,
                logoPosition: config.logoPosition,
                whatsApp: config.whatsApp,
                enabledINTERNET: config.enabledINTERNET,
              );
            });
            await prefs.setString('logoPath', img1);
          }
          LoggingService.instance.info(
            'FFmpeg',
            'Archivo de logo realmente usado: $img1',
          );

          if (!await File(img1).exists()) {
            LoggingService.instance.error(
              'FFmpeg',
              'El archivo de logo no existe: $img1',
            );
          }

          // 1. Obtener resolución del video
          final probeSession = await FFprobeKit.getMediaInformation(filePath);
          final info = probeSession.getMediaInformation();
          final width = info
              ?.getStreams()
              .firstWhere((s) => s.getType() == 'video')
              .getWidth();
          final height = info
              ?.getStreams()
              .firstWhere((s) => s.getType() == 'video')
              .getHeight();
          if (width == null || height == null) {
            throw Exception('No se pudo obtener la resolución del video');
          }
          LoggingService.instance.info(
            'FFmpeg',
            'Resolución del video para logo: ${width}x${height}',
          );

          // 2. Calcular tamaño del logo proporcional al video (5% del ancho del video)
          final logoSize = (width * 0.05).round(); // 5% del ancho del video
          LoggingService.instance.info(
            'FFmpeg',
            'Tamaño del logo calculado: ${logoSize}x${logoSize}',
          );

          // 3. Escalar logo al tamaño calculado
          final logoEscalado = img1 + '_scaled.png';
          final scaleCmd =
              '-i "$img1" -vf scale=${logoSize}:${logoSize} "$logoEscalado" -y';
          LoggingService.instance.info(
            'FFmpeg',
            'Comando para escalar logo: $scaleCmd',
          );
          final scaleSession = await FFmpegKit.execute(scaleCmd);
          if (!ReturnCode.isSuccess(await scaleSession.getReturnCode())) {
            LoggingService.instance.warning(
              'FFmpeg',
              'Error al escalar el logo, usando el original',
            );
          }

          // 4. Calcular posición del logo
          const margenX = 10;
          const margenY = 10;
          String esquinaSuperiroIzquierda = '$margenX:$margenY';
          String esquinaSuperiroDerecha =
              'main_w-($logoSize+$margenX):$margenY';
          String esquinaInferiorDerecha =
              'main_w-($logoSize+$margenX):main_h-($logoSize+$margenY)';
          String esquinaInferiorIzquierda =
              '$margenX:main_h-($logoSize+$margenY)';

          String position = config.logoPosition;
          String postionSelected = esquinaSuperiroIzquierda;
          if (position == "lt") postionSelected = esquinaSuperiroIzquierda;
          if (position == "rt") postionSelected = esquinaSuperiroDerecha;
          if (position == "rb") postionSelected = esquinaInferiorDerecha;
          if (position == "lb") postionSelected = esquinaInferiorIzquierda;

          // 5. Overlay usando el logo escalado
          String logoParaOverlay = await File(logoEscalado).exists()
              ? logoEscalado
              : img1;
          String filtercomplex =
              '-filter_complex "[1]format=rgba[wm];[0][wm]overlay=$postionSelected[out]"';
          String comm =
              '-i $filePath -i $logoParaOverlay $filtercomplex -map "[out]" $crf -b:v $bitrate $codec -y $out';

          LoggingService.instance.info(
            'FFmpeg',
            'Comando overlay de logo: $comm',
          );

          try {
            final session = await FFmpegKit.execute(comm);
            final returnCode = await session.getReturnCode();
            final logs = await session.getLogs();

            // Capturar logs de FFmpeg solo si hay error
            if (!ReturnCode.isSuccess(returnCode)) {
              final lastLogs =
                  (logs.length > 10 ? logs.sublist(logs.length - 10) : logs)
                      .map((l) => l.getMessage())
                      .join(' | ');
              LoggingService.instance.warning('FFmpeg', 'Logs logo: $lastLogs');
            }

            if (!ReturnCode.isSuccess(returnCode)) {
              LoggingService.instance.warning(
                'FFmpeg',
                'Error en overlay de logo, intentando comando alternativo...',
              );
              // Comando alternativo: overlay sin formato rgba
              String altFiltercomplex =
                  '-filter_complex "[1]scale=${logoSize}:${logoSize}[wm];[0][wm]overlay=$postionSelected[out]"';
              String altComm =
                  '-i $filePath -i $img1 $altFiltercomplex -map "[out]" $crf -b:v $bitrate $codec -y $out';
              LoggingService.instance.info(
                'FFmpeg',
                'Comando alternativo logo: $altComm',
              );
              final altSession = await FFmpegKit.execute(altComm);
              final altReturnCode = await altSession.getReturnCode();
              if (!ReturnCode.isSuccess(altReturnCode)) {
                LoggingService.instance.warning(
                  'FFmpeg',
                  'Error en FFmpeg para logo, continuando sin logo...',
                );
                procesCompleted++;
                return;
              }
            }

            if (!await File(out).exists()) {
              throw Exception('Failed to create logo video file');
            }

            filePath = out;
            procesCompleted++;
          } catch (e) {
            LoggingService.instance.error(
              'FFmpeg',
              'Error crítico en procesamiento de logo, continuando sin logo',
              e,
            );
            procesCompleted++;
          }
        }

        if (config.enabledAudioFondo) {
          LoggingService.instance.info(
            'FFmpeg',
            'Iniciando procesamiento de audio...',
          );
          out = _storageService.audioVideoFilePath();
          LoggingService.instance.info(
            'FFmpeg',
            'Ruta de salida para audio: $out',
          );

          try {
            final prefs = await SharedPreferences.getInstance();
            String audioPath =
                prefs.getString('audioPath') ?? config.audioFondo;
            LoggingService.instance.info(
              'FFmpeg',
              'Intentando usar archivo de audio: $audioPath',
            );
            if (audioPath == '1' || !(await File(audioPath).exists())) {
              LoggingService.instance.info(
                'FFmpeg',
                'Archivo de audio no existe o es valor por defecto, usando asset.',
              );
              audioPath = await _storageService.getAudioPath();
              setState(() {
                config = ConfigCabina(
                  duration: config.duration,
                  enabledVideoFilter: config.enabledVideoFilter,
                  enabledContornoVideo: config.enabledContornoVideo,
                  enabledLogo: config.enabledLogo,
                  enabledAudioFondo: config.enabledAudioFondo,
                  contornoVideo: config.contornoVideo,
                  audioFondo: audioPath,
                  logoPosition: config.logoPosition,
                  whatsApp: config.whatsApp,
                  enabledINTERNET: config.enabledINTERNET,
                );
              });
              await prefs.setString('audioPath', audioPath);
            }
            LoggingService.instance.info(
              'FFmpeg',
              'Archivo de audio realmente usado: $audioPath',
            );

            if (!await File(filePath).exists()) {
              throw Exception(
                'Input video file not found for audio: $filePath',
              );
            }
            if (!await File(audioPath).exists()) {
              LoggingService.instance.error(
                'FFmpeg',
                'El archivo de audio no existe: $audioPath',
              );
            }

            var audioCuted = _storageService.audioCutedFilePath();

            String comm =
                '-ss 0 -i $audioPath -to $durationTotal -c copy -y $audioCuted';
            LoggingService.instance.info(
              'FFmpeg',
              'Comando para cortar audio: $comm',
            );

            final cutSession = await FFmpegKit.execute(comm);
            if (!ReturnCode.isSuccess(await cutSession.getReturnCode())) {
              throw Exception('Failed to cut audio file');
            }

            if (!await File(audioCuted).exists()) {
              throw Exception('Failed to create cut audio file');
            }

            comm =
                '-i $filePath -i $audioCuted -c:v copy -c:a aac -strict experimental -shortest -y $out';
            LoggingService.instance.info(
              'FFmpeg',
              'Comando para mezclar audio: $comm',
            );

            final session = await FFmpegKit.execute(comm);
            final returnCode = await session.getReturnCode();
            final logs = await session.getLogs();

            // Capturar logs de FFmpeg solo si hay error
            if (!ReturnCode.isSuccess(returnCode)) {
              final lastLogs =
                  (logs.length > 10 ? logs.sublist(logs.length - 10) : logs)
                      .map((l) => l.getMessage())
                      .join(' | ');
              LoggingService.instance.warning(
                'FFmpeg',
                'Logs audio: $lastLogs',
              );
            }

            if (!ReturnCode.isSuccess(returnCode)) {
              throw Exception('Failed to mix audio with video');
            }

            if (!await File(out).exists()) {
              throw Exception('Failed to create final video with audio');
            }

            filePath = out;
            procesCompleted++;
          } catch (e) {
            // ERROR RECOVERY: Continuar sin audio si falla
            LoggingService.instance.error(
              'FFmpeg',
              'Error en procesamiento de audio, continuando sin audio',
              e,
            );
            procesCompleted++;
          }
        }

        LoggingService.instance.info(
          'FFmpeg',
          'Video final procesado en: $filePath',
        );

        // NUEVO: Aplicar preset de video si está seleccionado
        if (_videoPresetsService.hasPresetSelected) {
          try {
            LoggingService.instance.info(
              'FFmpeg',
              'Aplicando preset: ${_videoPresetsService.selectedPreset!.name}',
            );
            final presetVideoPath = await _videoPresetsService
                .applyPresetToVideo(
                  inputVideoPath: filePath,
                  onProgress: (progress) {
                    LoggingService.instance.debug(
                      'FFmpeg',
                      'Progreso del preset: ${progress.toStringAsFixed(1)}%',
                    );
                  },
                );

            if (presetVideoPath != filePath) {
              // El preset se aplicó exitosamente, usar el nuevo archivo
              filePath = presetVideoPath;
              LoggingService.instance.info(
                'FFmpeg',
                'Preset aplicado exitosamente: $filePath',
              );
            }
          } catch (e) {
            LoggingService.instance.warning(
              'FFmpeg',
              'Error aplicando preset, continuando con video original: $e',
            );
          }
        }

        LoggingService.instance.info(
          'FFmpeg',
          'Verificando existencia del archivo final...',
        );
        bool fileExists = await File(filePath).exists();
        LoggingService.instance.info(
          'FFmpeg',
          '¿El archivo final existe?: $fileExists',
        );

        if (!fileExists) {
          throw Exception(
            'El archivo final no existe después del procesamiento',
          );
        }

        if (socket != null && socketConected) {
          socket!.emit("serverUpload", "load video");
        }

        await upLoadVideo(filePath);
        LoggingService.instance.info('App', 'Video subido al servidor');

        procesCompleted++;

        if (socket != null && socketConected) {
          socket!.emit("serverCompleted", "ok");
        }

        if (await File(filePath).exists()) {
          final recordingDir = _storageService.saveDir;
          if (recordingDir != null) {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final finalVideoPath = '${recordingDir.path}/video_$timestamp.mp4';
            final displayName = 'video_$timestamp.mp4';

            await File(filePath).copy(finalVideoPath);
            LoggingService.instance.info(
              'App',
              'Video final guardado en: $finalVideoPath',
            );

            // NUEVO: Guardar copia en la galería pública
            await _mediaStoreService.saveVideoToPublicGallery(
              File(finalVideoPath),
              displayName,
            );
          }
        }

        LoggingService.instance.info('App', 'Limpiando archivos temporales...');
        await _storageService.deletedVideosTmp();
        progressOlder = 0.0;

        LoggingService.instance.info('App', 'Proceso completado exitosamente');
      } catch (e, stack) {
        LoggingService.instance.error(
          'App',
          'Error en el proceso de grabación',
          e,
          stack,
        );
        setState(() {
          saving = false;
          ffmpegRunning = false;
          working = false;
        });
        showInSnackBar('Error al detener la grabación: $e');
      }
    }
  }

  int calcDuration(porcentaje, duracion) {
    double r = ((porcentaje * duracion) / 100);
    return r.floor();
  }

  Future upLoadVideo(String path) async {
    setState(() {
      ffmpegRunning = false;
      working = false;
      saving = false;
      moving = false;

      totalDurationGlobal = 0;
      noProccess = 0;
      porcentGlobal = 0.0;
      progressGlobal = 0.0;
      procesCompleted = 0;
      progressOlder = 0.0;

      _countdownSeconds = 3;
    });
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configString = prefs.getString('config');
    if (configString != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(configString);
        config = ConfigCabina.fromJson(json);
        recordMins = config.duration;
        lenController.text = config.duration.toString();
        // Mapear la resolución guardada a ResolutionPreset
        resolutionPreset = _mapStringToResolutionPreset(config.videoResolution);
        setState(() {});
      } catch (e) {
        LoggingService.instance.error('App', 'Error cargando configuración', e);
      }
    } else {
      config = ConfigCabina(
        duration: 5,
        enabledVideoFilter: true,
        enabledContornoVideo: true,
        enabledLogo: true,
        enabledAudioFondo: true,
        contornoVideo: '1',
        audioFondo: '1',
        logoPosition: 'rb',
        whatsApp: '',
        enabledINTERNET: false,
        videoResolution: 'medium',
      );
      recordMins = config.duration;
      lenController.text = config.duration.toString();
      resolutionPreset = _mapStringToResolutionPreset('medium');
      setState(() {});
    }
  }

  ResolutionPreset _mapStringToResolutionPreset(String res) {
    switch (res) {
      case 'low':
        return ResolutionPreset.low;
      case 'medium':
        return ResolutionPreset.medium;
      case 'high':
        return ResolutionPreset.high;
      case 'veryHigh':
        return ResolutionPreset.veryHigh;
      default:
        return ResolutionPreset.medium;
    }
  }

  void _toggleWifiServer() async {
    try {
      if (!_wifiServerRunning) {
        // Solicitar permisos y mostrar mensaje si es denegado
        await _wifiServer.requestNetworkInfoWithPermissionFeedback(
          showInSnackBar,
        );
        final success = await _wifiServer.startServer();
        if (success) {
          setState(() {
            _wifiServerRunning = true;
          });

          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('🌐 Servidor Web Iniciado'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📱 Para conectar otros dispositivos:'),
                    const SizedBox(height: 10),
                    const Text(
                      '1. Asegúrate de que ambos dispositivos estén en la misma red WiFi',
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '2. Red WiFi actual: ${_wifiServer.wifiName ?? "N/A"}',
                    ),
                    const SizedBox(height: 10),
                    const Text('🌍 URL del servidor:'),
                    Text('${_wifiServer.serverUrl ?? "N/A"}'),
                    const SizedBox(height: 10),
                    const Text(
                      '💡 Abre esta URL en el navegador de cualquier dispositivo conectado a la misma red WiFi para ver y descargar los videos.',
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    child: const Text('Cerrar'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        } else {
          showInSnackBar('Error al iniciar el servidor WiFi');
        }
      } else {
        await _wifiServer.stopServer();
        setState(() {
          _wifiServerRunning = false;
        });
        showInSnackBar('Servidor WiFi detenido');
      }
    } catch (e) {
      LoggingService.instance.error('WiFi', 'Error con servidor WiFi', e);
      showInSnackBar('Error: $e');
    }
  }

  Future<void> clearAllRecordings() async {
    try {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Borrar Videos'),
            content: const Text(
              '¿Estás seguro de que deseas borrar todos los videos grabados? Esta acción no se puede deshacer.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: const Text('Borrar Todo'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      setState(() {
        saving = true;
      });

      final recordingDir = _storageService.saveDir;
      LoggingService.instance.info(
        'App',
        'Ruta de borrado de videos: ${recordingDir?.path}',
      );
      if (recordingDir != null && await recordingDir.exists()) {
        final files = await recordingDir.list().toList();
        LoggingService.instance.info(
          'App',
          'Archivos encontrados: ${files.length}',
        );
        for (var entity in files) {
          if (entity is File && entity.path.toLowerCase().endsWith('.mp4')) {
            LoggingService.instance.debug(
              'App',
              'Borrando archivo: ${entity.path}',
            );
            try {
              await entity.delete();
              LoggingService.instance.debug(
                'App',
                'Archivo borrado: ${entity.path}',
              );
            } catch (e) {
              LoggingService.instance.error(
                'App',
                'Error al borrar archivo: ${entity.path}',
                e,
              );
            }
          } else if (entity is Directory) {
            LoggingService.instance.debug(
              'App',
              'Omitiendo directorio: ${entity.path}',
            );
          } else {
            LoggingService.instance.debug(
              'App',
              'Entidad desconocida: ${entity.path}',
            );
          }
        }
      }

      final appDir = await getApplicationDocumentsDirectory();
      final thumbnailsDir = Directory('${appDir.path}/CVR_Thumbnails');
      if (await thumbnailsDir.exists()) {
        await thumbnailsDir.delete(recursive: true);
      }

      setState(() {
        saving = false;
      });

      if (mounted) {
        showInSnackBar('Todos los videos han sido borrados');
      }
    } catch (e) {
      LoggingService.instance.error('App', 'Error al borrar los videos', e);
      setState(() {
        saving = false;
      });
      if (mounted) {
        showInSnackBar('Error al borrar los videos: $e');
      }
    }
  }

  /// Mostrar selector de presets de video
  Future<void> _showPresetSelector() async {
    final presets = _videoPresetsService.getAvailablePresets();

    final selectedPreset = await showDialog<VideoPreset>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🎬 Seleccionar Preset de Video'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: presets.length,
              itemBuilder: (context, index) {
                final preset = presets[index];
                final isSelected =
                    _videoPresetsService.selectedPreset?.key == preset.key;

                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.orange : Colors.grey,
                  ),
                  title: Text(
                    preset.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(preset.description),
                  trailing: preset.effects.isNotEmpty
                      ? Chip(
                          label: Text('${preset.effects.length} efectos'),
                          backgroundColor: Colors.blue.withValues(alpha: 0.2),
                        )
                      : const Chip(
                          label: Text('Sin efectos'),
                          backgroundColor: Colors.grey,
                        ),
                  onTap: () {
                    Navigator.of(context).pop(preset);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            if (_videoPresetsService.hasPresetSelected)
              TextButton(
                onPressed: () async {
                  await _videoPresetsService.clearPreset();
                  Navigator.of(context).pop();
                  setState(() {});
                  showInSnackBar('Preset limpiado');
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Limpiar'),
              ),
          ],
        );
      },
    );

    if (selectedPreset != null) {
      await _videoPresetsService.selectPreset(selectedPreset);
      setState(() {});
      showInSnackBar('Preset seleccionado: ${selectedPreset.name}');
    }
  }
}
