import 'dart:io' as io;
import 'dart:convert';
import 'dart:io' show InternetAddress, InternetAddressType, NetworkInterface;
// import 'dart:typed_data'; // No se usa
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cabina360_v2_2/services/logging_service.dart';
// import 'package:permission_handler/permission_handler.dart'; // No se usa

class WifiServerService {
  static WifiServerService? _instance;
  static WifiServerService get instance => _instance ??= WifiServerService._();

  WifiServerService._();

  io.HttpServer? _server;
  bool _isServerRunning = false;
  String? _serverUrl;
  String? _wifiName;
  String? _qrCodeJsContent; // NUEVO: Contenido del JavaScript QR
  String? _configuredWifiName; // NUEVO: Nombre de WiFi desde configuración
  String? _logoBase64;

  // Getters
  bool get isServerRunning => _isServerRunning;
  String? get serverUrl => _serverUrl;
  String? get wifiName => _wifiName;

  /// Establece el nombre de WiFi desde la configuración
  void setWifiName(String? wifiName) {
    _configuredWifiName = wifiName;
    _wifiName = wifiName;
    LoggingService.instance.debug('WifiServer', 'Nombre WiFi configurado: $_configuredWifiName');
  }

  /// Inicializa el servicio
  Future<void> initialize() async {
    try {
      // Cargar el contenido del JavaScript QR una sola vez
      await _loadQRCodeJavaScript();

      // Cargar el base64 del logo desde el PNG de assets
      await _loadLogoBase64FromPng();

      // Obtener información de red
      await _loadNetworkInfo();

      LoggingService.instance.info('WifiServer', 'WifiServerService inicializado');
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'inicializando WifiServerService: $e');
    }
  }

  /// Carga el contenido del JavaScript QR desde assets
  Future<void> _loadQRCodeJavaScript() async {
    try {
      final byteData = await rootBundle.load('assets/js/qrcode.min.js');
      _qrCodeJsContent = String.fromCharCodes(byteData.buffer.asUint8List());
      LoggingService.instance.info('WifiServer', 'JavaScript QR cargado correctamente');
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'cargando JavaScript QR: $e');
      _qrCodeJsContent = null;
    }
  }

  /// Carga el base64 del logo: primero intenta el logo personalizado, luego el default
  Future<void> _loadLogoBase64FromPng() async {
    try {
      // 1. Intentar cargar logo personalizado desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final customLogoPath = prefs.getString('logoPath');
      if (customLogoPath != null && customLogoPath.isNotEmpty) {
        final customFile = io.File(customLogoPath);
        if (await customFile.exists()) {
          final bytes = await customFile.readAsBytes();
          _logoBase64 = base64Encode(bytes);
          print(
            '✅ Logo base64 cargado desde archivo personalizado: $customLogoPath',
          );
          return;
        }
      }

      // 2. Fallback: cargar logo default desde assets
      final bytes = await rootBundle.load('assets/icon/app_icon.png');
      _logoBase64 = base64Encode(bytes.buffer.asUint8List());
      LoggingService.instance.info('WifiServer', 'Logo base64 cargado desde asset default');
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'cargando logo base64: $e');
      _logoBase64 = null;
    }
  }

  /// Recarga el logo (llamar cuando se cambia el logo en configuración)
  Future<void> reloadLogo() async {
    await _loadLogoBase64FromPng();
    LoggingService.instance.info('WifiServer', 'Logo recargado');
  }

  /// Carga la información de red
  Future<void> _loadNetworkInfo({
    Function(String message)? onPermissionDenied,
  }) async {
    try {
      LoggingService.instance.info('WifiServer', '=== CARGANDO INFORMACIÓN DE RED ===');

      // 1. Intentar obtener automáticamente
      String? autoWifiName;
      try {
        final networkInfo = NetworkInfo();
        autoWifiName = await networkInfo.getWifiName();
        print(
          'Nombre WiFi desde NetworkInfo: '
          ' [1m$autoWifiName [0m',
        );
      } catch (e) {
        LoggingService.instance.error('WifiServer', 'obteniendo nombre WiFi automáticamente: $e');
      }

      // 2. Si falla, usar el de la configuración
      if (autoWifiName != null &&
          autoWifiName.isNotEmpty &&
          autoWifiName != 'null') {
        _wifiName = autoWifiName;
        LoggingService.instance.info('WifiServer', 'Usando nombre WiFi automático: $_wifiName');
        return;
      } else if (_configuredWifiName != null &&
          _configuredWifiName!.isNotEmpty) {
        _wifiName = _configuredWifiName;
        LoggingService.instance.info('WifiServer', 'Usando nombre WiFi de configuración: $_wifiName');
        return;
      } else {
        _wifiName = 'Red WiFi no detectada';
        LoggingService.instance.error('WifiServer', 'No se pudo obtener el nombre de la red WiFi');
      }
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'cargando información de red: $e');
      _wifiName = 'Red WiFi no detectada';
    }
  }

  /// Obtiene el nombre de WiFi en Android usando métodos alternativos
  // ignore: unused_element
  Future<String?> _getWifiNameAndroid() async {
    try {
      // Método 1: Intentar obtener SSID usando el método de conectividad
      final connectivityResult = await _getWifiSSIDFromConnectivity();
      if (connectivityResult != null && connectivityResult.isNotEmpty) {
        return connectivityResult;
      }

      // Método 2: Intentar obtener desde las interfaces de red
      final interfaceResult = await _getWifiNameFromInterfaces();
      if (interfaceResult != null && interfaceResult.isNotEmpty) {
        return interfaceResult;
      }

      // Método 3: Intentar obtener usando NetworkInfo con diferentes enfoques
      try {
        final networkInfo = NetworkInfo();
        String? ssid = await networkInfo.getWifiName();

        if (ssid != null && ssid.isNotEmpty && ssid != 'null') {
          LoggingService.instance.info('WifiServer', 'SSID obtenido en segundo intento: $ssid');
          return ssid;
        }
      } catch (e) {
        LoggingService.instance.error('WifiServer', 'en segundo intento con NetworkInfo: $e');
      }

      // Método 4: Intentar obtener usando comandos del sistema
      final systemResult = await _getSSIDFromSystemCommand();
      if (systemResult != null && systemResult.isNotEmpty) {
        return systemResult;
      }

      return null;
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'en _getWifiNameAndroid: $e');
      return null;
    }
  }

  /// Intenta obtener SSID desde la conectividad
  Future<String?> _getWifiSSIDFromConnectivity() async {
    try {
      // Método 1: Intentar obtener desde NetworkInfo
      final networkInfo = NetworkInfo();
      String? ssid = await networkInfo.getWifiName();

      if (ssid != null && ssid.isNotEmpty && ssid != 'null') {
        LoggingService.instance.info('WifiServer', 'SSID obtenido desde NetworkInfo: $ssid');
        return ssid;
      }

      // Método 2: Intentar obtener desde las interfaces de red
      final interfaces = await NetworkInterface.list();

      for (var interface in interfaces) {
        // Buscar interfaces WiFi específicas
        if (interface.name.toLowerCase().contains('wlan') ||
            interface.name.toLowerCase().contains('wifi')) {
          LoggingService.instance.debug('WifiServer', 'Analizando interfaz WiFi: ${interface.name}');

          // Intentar obtener información adicional de la interfaz
          if (interface.addresses.isNotEmpty) {
            for (var addr in interface.addresses) {
              if (addr.type == InternetAddressType.IPv4 &&
                  !addr.address.startsWith('127.') &&
                  addr.address.isNotEmpty) {
                LoggingService.instance.info('WifiServer', 'IP válida encontrada: ${addr.address}');

                // Método 3: Intentar obtener SSID usando comandos del sistema (sin root)
                final ssidFromSystem = await _getSSIDFromSystemCommand();
                if (ssidFromSystem != null && ssidFromSystem.isNotEmpty) {
                  print(
                    '✅ SSID obtenido desde comando del sistema: $ssidFromSystem',
                  );
                  return ssidFromSystem;
                }

                // Si no se puede obtener el SSID real, usar un nombre descriptivo
                print(
                  '⚠️ No se pudo obtener SSID real, usando nombre descriptivo',
                );
                return 'Cabina360_${addr.address.split('.').last}';
              }
            }
          }
        }
      }

      LoggingService.instance.error('WifiServer', 'No se pudo obtener SSID real');
      return null;
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'en _getWifiSSIDFromConnectivity: $e');
      return null;
    }
  }

  /// Intenta obtener SSID usando comandos del sistema (sin root)
  Future<String?> _getSSIDFromSystemCommand() async {
    try {
      if (io.Platform.isAndroid) {
        // Método 1: Intentar con iwconfig (sin root)
        try {
          final iwResult = await io.Process.run('iwconfig', []);
          if (iwResult.exitCode == 0) {
            final output = iwResult.stdout.toString();
            final ssidMatch = RegExp(r'ESSID:"([^"]+)"').firstMatch(output);
            if (ssidMatch != null) {
              LoggingService.instance.info('WifiServer', 'SSID obtenido con iwconfig: ${ssidMatch.group(1)}');
              return ssidMatch.group(1);
            }
          }
        } catch (e) {
          LoggingService.instance.debug('WifiServer', 'Comando iwconfig no disponible: $e');
        }

        // Método 2: Intentar con dumpsys (sin root)
        try {
          final result = await io.Process.run('dumpsys', ['wifi']);
          if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
            final output = result.stdout.toString();
            // Buscar SSID en la salida del comando
            final ssidMatch = RegExp(r'SSID:\s*"([^"]+)"').firstMatch(output);
            if (ssidMatch != null) {
              LoggingService.instance.info('WifiServer', 'SSID obtenido con dumpsys: ${ssidMatch.group(1)}');
              return ssidMatch.group(1);
            }
          }
        } catch (e) {
          LoggingService.instance.debug('WifiServer', 'Comando dumpsys no disponible: $e');
        }

        // Método 3: Intentar con cat /proc/net/wireless
        try {
          final result = await io.Process.run('cat', ['/proc/net/wireless']);
          if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
            final output = result.stdout.toString();
            LoggingService.instance.debug('WifiServer', 'Información de /proc/net/wireless: $output');
            // Buscar información de la interfaz WiFi
            final lines = output.split('\n');
            for (var line in lines) {
              if (line.contains('wlan') || line.contains('wifi')) {
                LoggingService.instance.info('WifiServer', 'Encontrada línea de interfaz WiFi: $line');
                // Extraer información de la línea
                final parts = line.trim().split(RegExp(r'\s+'));
                if (parts.length > 0) {
                  final interfaceName = parts[0];
                  LoggingService.instance.info('WifiServer', 'Interfaz WiFi encontrada: $interfaceName');
                  // Intentar obtener SSID usando iw dev
                  try {
                    final iwResult = await io.Process.run('iw', [
                      'dev',
                      interfaceName,
                      'info',
                    ]);
                    if (iwResult.exitCode == 0) {
                      final iwOutput = iwResult.stdout.toString();
                      final ssidMatch = RegExp(
                        r'ssid\s+([^\n]+)',
                      ).firstMatch(iwOutput);
                      if (ssidMatch != null) {
                        final ssid = ssidMatch.group(1)?.trim();
                        if (ssid != null && ssid.isNotEmpty) {
                          LoggingService.instance.info('WifiServer', 'SSID obtenido con iw dev: $ssid');
                          return ssid;
                        }
                      }
                    }
                  } catch (e) {
                    LoggingService.instance.debug('WifiServer', 'Comando iw dev no disponible: $e');
                  }
                }
              }
            }
          }
        } catch (e) {
          LoggingService.instance.debug('WifiServer', 'Comando cat /proc/net/wireless no disponible: $e');
        }

        // Método 4: Intentar con settings get global wifi_on
        try {
          final result = await io.Process.run('settings', [
            'get',
            'global',
            'wifi_on',
          ]);
          if (result.exitCode == 0) {
            LoggingService.instance.debug('WifiServer', 'Estado WiFi: ${result.stdout.toString()}');
          }
        } catch (e) {
          LoggingService.instance.debug('WifiServer', 'Comando settings no disponible: $e');
        }
      }

      return null;
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'obteniendo SSID desde comando del sistema: $e');
      return null;
    }
  }

  /// Obtiene el nombre de WiFi desde las interfaces de red
  Future<String?> _getWifiNameFromInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list();

      for (var interface in interfaces) {
        // Buscar interfaces WiFi (típicamente wlan0, wlan1, etc.)
        if (interface.name.toLowerCase().contains('wlan') ||
            interface.name.toLowerCase().contains('wifi')) {
          LoggingService.instance.info('WifiServer', 'Encontrada interfaz WiFi: ${interface.name}');

          // Para interfaces WiFi, intentar obtener información adicional
          if (interface.addresses.isNotEmpty) {
            final ip = interface.addresses.firstWhere(
              (addr) =>
                  addr.type == InternetAddressType.IPv4 &&
                  !addr.address.startsWith('127.'),
              orElse: () => interface.addresses.first,
            );

            if (ip.address.isNotEmpty) {
              LoggingService.instance.info('WifiServer', 'IP de interfaz WiFi: ${ip.address}');
              // Por ahora, usamos un nombre genérico basado en la IP
              return 'Cabina360_${ip.address.split('.').last}';
            }
          }
        }
      }

      LoggingService.instance.error('WifiServer', 'No se encontró interfaz WiFi específica');
      return null;
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'en _getWifiNameFromInterfaces: $e');
      return null;
    }
  }

  /// Inicia el servidor web
  Future<bool> startServer() async {
    try {
      if (_isServerRunning) {
        LoggingService.instance.debug('WifiServer', 'Servidor ya está ejecutándose');
        return true;
      }

      LoggingService.instance.info('WifiServer', '=== INICIANDO SERVIDOR WEB ===');

      // Inicializar el servicio si no se ha hecho
      await initialize();

      // Iniciar el servidor web
      await _startWebServer();

      _isServerRunning = true;
      LoggingService.instance.info('WifiServer', 'Servidor web iniciado exitosamente');
      return true;
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'iniciando servidor web: $e');
      return false;
    }
  }

  /// Inicia el servidor web
  Future<void> _startWebServer() async {
    try {
      // Obtener directorio de videos
      final recordingDir = await _getRecordingDir();
      if (recordingDir == null) {
        throw Exception('No se pudo obtener el directorio de videos');
      }

      // Obtener directorio de thumbnails
      final thumbnailsDir = await _getThumbnailsDir();
      if (thumbnailsDir == null) {
        throw Exception('No se pudo obtener el directorio de thumbnails');
      }

      // Crear handler para servir archivos estáticos de videos
      final videosHandler = createStaticHandler(
        recordingDir.path,
        defaultDocument: 'index.html',
      );

      // Crear handler para servir thumbnails
      final thumbnailsHandler = createStaticHandler(
        thumbnailsDir.path,
        defaultDocument: 'index.html',
      );

      // Crear handler para la página principal
      final handler = Cascade()
          .add(_createMainPageHandler())
          .add(_createOptimizedVideoHandler(recordingDir.path))
          .add(thumbnailsHandler)
          .add(videosHandler)
          .handler;

      // Iniciar servidor en puerto 8080 con configuración optimizada
      _server = await io.serve(
        handler,
        InternetAddress.anyIPv4,
        8080,
        shared: true, // Permite múltiples conexiones simultáneas
      );
      _serverUrl = 'http://${await _getLocalIpAddress()}:8080';

      LoggingService.instance.debug('WifiServer', 'Servidor web iniciado en: $_serverUrl');
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'iniciando servidor web: $e');
      rethrow;
    }
  }

  /// Crea un handler optimizado para servir videos con mejor rendimiento
  Handler _createOptimizedVideoHandler(String recordingDirPath) {
    return (Request request) async {
      final path = request.url.path;

      // Solo procesar archivos de video
      if (path.isNotEmpty &&
          (path.endsWith('.mp4') ||
              path.endsWith('.avi') ||
              path.endsWith('.mov') ||
              path.endsWith('.mkv'))) {
        final videoFile = io.File('$recordingDirPath$path');

        if (await videoFile.exists()) {
          final stat = await videoFile.stat();
          final fileSize = stat.size;

          // Headers optimizados para streaming y descarga rápida
          final headers = {
            'Content-Type': 'video/mp4',
            'Content-Length': fileSize.toString(),
            'Accept-Ranges': 'bytes',
            'Cache-Control': 'public, max-age=3600',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
            'Access-Control-Allow-Headers': 'Range',
          };

          // Manejar solicitudes de rango para streaming
          final rangeHeader = request.headers['range'];
          if (rangeHeader != null) {
            final rangeMatch = RegExp(
              r'bytes=(\d+)-(\d*)',
            ).firstMatch(rangeHeader);
            if (rangeMatch != null) {
              final start = int.parse(rangeMatch.group(1)!);
              final end = rangeMatch.group(2)?.isNotEmpty == true
                  ? int.parse(rangeMatch.group(2)!)
                  : fileSize - 1;

              final length = end - start + 1;
              final stream = videoFile.openRead(start, end + 1);

              return Response(
                206,
                headers: {
                  ...headers,
                  'Content-Range': 'bytes $start-$end/$fileSize',
                  'Content-Length': length.toString(),
                },
                body: stream,
              );
            }
          }

          // Descarga completa
          final stream = videoFile.openRead();
          return Response.ok(stream, headers: headers);
        }
      }

      return Response.notFound('Video no encontrado');
    };
  }

  /// Crea el handler para la página principal
  Handler _createMainPageHandler() {
    return (Request request) async {
      final path = request.url.path;

      if (path.isEmpty || path == '/') {
        return Response.ok(
          _generateHtmlPage(),
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      } else if (path == 'api/videos' || path == 'api/videos/') {
        // Endpoint para listar videos
        return await _listVideos();
      } else if (path == 'api/test' || path == 'api/test/') {
        // Endpoint de prueba
        return Response.ok(
          '{"status": "ok", "message": "API funcionando correctamente"}',
          headers: {
            'content-type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        );
      } else if (path == 'connect' || path == 'connect/') {
        // Página de información de conexión con códigos QR
        return Response.ok(
          _generateConnectionPage(),
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      } else if (path == 'qr' || path == 'qr/') {
        // Página simple con solo el código QR de videos
        return Response.ok(
          _generateSimpleQRPage(),
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      } else if (path == 'logo_base64.txt') {
        // Nuevo endpoint: servir el base64 del logo
        return Response.ok(
          _logoBase64 ?? '',
          headers: {'content-type': 'text/plain'},
        );
      }
      return Response.notFound('Página no encontrada');
    };
  }

  /// Lista los videos disponibles
  Future<Response> _listVideos() async {
    try {
      LoggingService.instance.info('WifiServer', '=== LISTANDO VIDEOS ===');
      final recordingDir = await _getRecordingDir();
      LoggingService.instance.debug('WifiServer', 'Directorio de videos: ${recordingDir?.path}');

      if (recordingDir == null) {
        LoggingService.instance.error('WifiServer', 'Directorio de videos es null');
        return Response.ok(
          jsonEncode({'videos': []}),
          headers: {
            'content-type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
          },
        );
      }

      if (!await recordingDir.exists()) {
        LoggingService.instance.error('WifiServer', 'Directorio de videos no existe: ${recordingDir.path}');
        return Response.ok(
          jsonEncode({'videos': []}),
          headers: {
            'content-type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
          },
        );
      }

      LoggingService.instance.info('WifiServer', 'Directorio existe, buscando archivos...');
      final List<Map<String, dynamic>> videos = [];
      final List<io.FileSystemEntity> files = await recordingDir
          .list()
          .toList();
      LoggingService.instance.debug('WifiServer', 'Archivos encontrados: ${files.length}');

      for (var file in files) {
        LoggingService.instance.debug('WifiServer', 'Archivo: ${file.path}');
        if (file is io.File) {
          final String fileName = file.path.split('/').last;
          final String extension = fileName.split('.').last.toLowerCase();
          LoggingService.instance.debug('WifiServer', 'Nombre: $fileName, Extensión: $extension');

          // Solo incluir videos finales procesados
          if (['mp4', 'avi', 'mov', 'mkv'].contains(extension)) {
            // Solo incluir archivos que empiecen con "video_" (videos finales)
            if (fileName.startsWith('video_')) {
              final stat = await file.stat();

              // Generar thumbnail para el video
              final thumbnailPath = await _generateThumbnail(file.path);
              final thumbnailUrl = thumbnailPath != null
                  ? '/${thumbnailPath.split('/').last}'
                  : null;

              final videoInfo = {
                'name': fileName,
                'path': '/$fileName',
                'thumbnail': thumbnailUrl,
                'size': stat.size,
                'modified': stat.modified.toIso8601String(),
              };
              videos.add(videoInfo);
              print(
                '✅ Video final agregado: $fileName (${stat.size} bytes) - Thumbnail: $thumbnailUrl',
              );
            } else {
              LoggingService.instance.error('WifiServer', 'Archivo temporal excluido: $fileName');
            }
          } else {
            LoggingService.instance.error('WifiServer', 'No es video: $extension');
          }
        } else {
          LoggingService.instance.error('WifiServer', 'No es archivo: ${file.runtimeType}');
        }
      }

      LoggingService.instance.debug('WifiServer', 'Total de videos finales encontrados: ${videos.length}');

      // Ordenar por fecha de modificación (más recientes primero)
      videos.sort(
        (a, b) => DateTime.parse(
          b['modified'],
        ).compareTo(DateTime.parse(a['modified'])),
      );

      final response = jsonEncode({'videos': videos});
      LoggingService.instance.debug('WifiServer', 'Respuesta JSON: $response');

      return Response.ok(
        response,
        headers: {
          'content-type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        },
      );
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'listando videos: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Error listando videos: $e'}),
        headers: {
          'content-type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        },
      );
    }
  }

  /// Genera la página HTML principal
  String _generateHtmlPage() {
    return '''
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cabina 360 - Videos</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #1976D2 0%, #2E7D32 100%);
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        h1 {
            text-align: center;
            color: #212121;
            margin-bottom: 30px;
            font-size: 2.5em;
        }
        .info {
            background: #E3F2FD;
            padding: 20px;
            border-radius: 12px;
            margin-bottom: 30px;
            border-left: 4px solid #2196F3;
            line-height: 1.6;
            color: #1976D2;
        }
        .refresh-btn {
            background: #4CAF50;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 16px;
            margin-bottom: 20px;
            transition: background 0.3s;
            font-weight: 500;
        }
        .refresh-btn:hover {
            background: #2E7D32;
        }
        .video-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .video-item {
            background: white;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            border: 2px solid #E0E0E0;
            transition: transform 0.3s, box-shadow 0.3s;
        }
        .video-item:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 25px rgba(0,0,0,0.15);
        }
        .video-item h3 {
            margin: 10px 0;
            color: #212121;
            font-size: 18px;
            font-weight: 600;
        }
        .video-item p {
            margin: 8px 0;
            color: #424242;
            font-size: 14px;
            font-weight: 500;
        }
        .video-item a {
            display: inline-block;
            background: #1976D2;
            color: white;
            text-decoration: none;
            padding: 8px 16px;
            border-radius: 6px;
            margin: 5px 5px 5px 0;
            font-size: 14px;
            transition: background 0.3s;
            font-weight: 500;
        }
        .video-item a:hover {
            background: #1565C0;
        }
        .video-placeholder {
            width: 100%;
            height: 320px;
            background: linear-gradient(135deg, #F5F5F5 0%, #E0E0E0 100%);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 10px;
            border: 2px solid #E0E0E0;
        }
        .no-videos {
            text-align: center;
            padding: 40px;
            color: #616161;
            font-size: 18px;
            background: #F5F5F5;
            border-radius: 12px;
            border: 2px dashed #E0E0E0;
            font-weight: 500;
        }
        .loading {
            text-align: center;
            padding: 20px;
            color: #616161;
            font-weight: 500;
        }
        .error {
            background: #FFEBEE;
            color: #C62828;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #F44336;
            margin: 10px 0;
            font-weight: 500;
        }
        .logo-container {
            text-align: center;
            margin-bottom: 20px;
        }
    </style>
    <link id="favicon-cabina360" rel="icon" type="image/png" href="">
</head>
<body>
    <div class="container">
        <div class="logo-container">
            <img id="logo-cabina360" alt="Cabina 360" style="height: 80px; object-fit: contain; border-radius: 15px; box-shadow: 0 4px 15px rgba(0,0,0,0.2);">
        </div>
        <h1>🎥 Cabina 360 - Videos</h1>
        
        <div class="info">
            <strong>📱 Para conectar otros dispositivos:</strong><br>
            • Asegúrate de que ambos dispositivos estén en la misma red WiFi<br>
            • Red WiFi actual: $_wifiName<br>
            • URL del servidor: $_serverUrl<br>
            • Abre la URL en cualquier navegador conectado a la misma red
        </div>
        
        <button class="refresh-btn" onclick="location.reload()">🔄 Actualizar Videos</button>
        <a href="/connect" class="refresh-btn" style="background: #1976D2; margin-left: 10px; text-decoration: none; display: inline-block;">📱 Información de Conexión</a>
        <a href="/qr" class="refresh-btn" style="background: #4CAF50; margin-left: 10px; text-decoration: none; display: inline-block;">📋 Código QR Videos</a>
        
        <div id="videos" class="video-grid">
            <div class="no-videos">Cargando videos...</div>
        </div>
    </div>

    <script>
        // JavaScript QR integrado directamente
        ${_qrCodeJsContent ?? '// JavaScript QR no disponible'}
        
        // Función para cargar videos automáticamente
        async function loadVideos() {
            try {
                console.log('Cargando videos...');
                const response = await fetch('/api/videos');
                console.log('Respuesta recibida:', response.status, response.statusText);
                
                if (!response.ok) {
                    throw new Error('HTTP ' + response.status + ': ' + response.statusText);
                }
                
                const data = await response.json();
                console.log('Datos recibidos:', data);
                
                const videosContainer = document.getElementById('videos');
                
                if (data.videos && data.videos.length > 0) {
                    let html = '';
                    data.videos.forEach(function(video) {
                        const sizeMB = (video.size / (1024 * 1024)).toFixed(1);
                        const date = new Date(video.modified).toLocaleString('es-ES');
                        
                        html += '<div class="video-item">';
                        
                        // Mostrar thumbnail si está disponible
                        if (video.thumbnail) {
                            html += '<img src="' + video.thumbnail + '" style="width: 100%; height: 320px; object-fit: cover; border-radius: 8px; margin-bottom: 10px; border: 2px solid #e0e0e0;" alt="Thumbnail de ' + video.name + '">';
                        } else {
                            // Fallback: placeholder con ícono de video
                            html += '<div class="video-placeholder">';
                            html += '<div style="text-align: center;">';
                            html += '<div style="font-size: 48px; margin-bottom: 10px;">🎥</div>';
                            html += '<div>Video disponible</div>';
                            html += '<div style="font-size: 12px; margin-top: 5px;">Sin vista previa</div>';
                            html += '</div>';
                            html += '</div>';
                        }
                        
                        html += '<h3>' + video.name + '</h3>';
                        html += '<p><strong>Tamaño:</strong> ' + sizeMB + ' MB</p>';
                        html += '<p><strong>Fecha:</strong> ' + date + '</p>';
                        html += '<a href="' + video.path + '" download="' + video.name + '">📥 Descargar</a>';
                        html += '<a href="' + video.path + '" target="_blank">👁️ Ver</a>';
                        html += '</div>';
                    });
                    videosContainer.innerHTML = html;
                } else {
                    videosContainer.innerHTML = '<div class="no-videos">No se encontraron videos. Asegúrate de haber grabado algunos videos primero.</div>';
                }
            } catch (error) {
                console.error('Error cargando videos:', error);
                document.getElementById('videos').innerHTML = 
                    '<div class="no-videos">Error cargando videos: ' + error.message + '<br><br><button onclick="loadVideos()">🔄 Reintentar</button></div>';
            }
        }

        // Cargar videos al cargar la página
        loadVideos();
        
        // Actualizar cada 30 segundos
        setInterval(loadVideos, 30000);
    </script>
</body>
</html>
    ''';
  }

  /// Genera la página HTML de conexión con códigos QR
  String _generateConnectionPage() {
    return '''
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cabina 360 - Información de Conexión</title>
    <style>
        html, body {
            overflow-y: auto;
            height: auto;
            min-height: 100vh;
        }
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #FFEB3B 0%, #1976D2 33%, #2E7D32 66%, #D500F9 100%);
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            padding: 30px 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        h1 {
            text-align: center;
            color: #212121;
            margin-bottom: 30px;
            font-size: 2.5em;
        }
        .info-section {
            background: #E3F2FD;
            padding: 20px;
            border-radius: 12px;
            margin-bottom: 30px;
            border-left: 4px solid #2196F3;
        }
        .info-section h2 {
            color: #1976D2;
            margin-bottom: 15px;
        }
        .qr-section {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 30px;
            margin-bottom: 30px;
        }
        .qr-card {
            background: white;
            padding: 20px;
            border-radius: 12px;
            text-align: center;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            border: 2px solid #E0E0E0;
        }
        .qr-card h3 {
            margin-bottom: 15px;
            color: #212121;
            font-weight: 600;
        }
        .qr-code {
            margin: 15px 0;
        }
        .instructions {
            background: #E8F5E8;
            padding: 20px;
            border-radius: 12px;
            border-left: 4px solid #4CAF50;
        }
        .instructions h2 {
            color: #2E7D32;
            margin-bottom: 15px;
        }
        .step {
            display: flex;
            align-items: flex-start;
            margin-bottom: 10px;
        }
        .step-number {
            background: #4CAF50;
            color: white;
            width: 24px;
            height: 24px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            margin-right: 12px;
            flex-shrink: 0;
        }
        .step-text {
            flex: 1;
            color: #424242;
            font-weight: 500;
        }
        .wifi-info {
            background: #FFF3E0;
            padding: 15px;
            border-radius: 8px;
            margin: 10px 0;
            border-left: 4px solid #FF9800;
            color: #E65100;
            font-weight: 500;
        }
        .server-info {
            background: #E8F5E8;
            padding: 15px;
            border-radius: 8px;
            margin: 10px 0;
            border-left: 4px solid #4CAF50;
            color: #2E7D32;
            font-weight: 500;
        }
        .server-info h3 {
            color: #2E7D32;
            margin-bottom: 10px;
        }
        .server-info a {
            color: #1976D2;
            text-decoration: none;
            font-weight: 500;
        }
        .server-info a:hover {
            text-decoration: underline;
        }
        .note {
            background: #FFF3E0;
            padding: 10px;
            border-radius: 8px;
            margin: 10px 0;
            border-left: 4px solid #FF9800;
            font-size: 14px;
            color: #E65100;
            font-weight: 500;
        }
        @media (max-width: 768px) {
            .qr-section {
                grid-template-columns: 1fr;
            }
        }
    </style>
    <link id="favicon-cabina360" rel="icon" type="image/png" href="">
</head>
<body>
    <div class="container">
        <div style="text-align: center; margin-bottom: 20px;">
            <img src="data:image/png;base64,${_logoBase64 ?? ''}" alt="Cabina 360" style="height: 80px; object-fit: contain; border-radius: 15px; box-shadow: 0 4px 15px rgba(0,0,0,0.2);" onerror="this.style.display='none'">
        </div>
        <h1>📱 Cabina 360 - Conexión</h1>
        
        <div class="info-section">
            <h2>🌐 Información de Red</h2>
            <div class="wifi-info">
                <strong>Red WiFi:</strong> $_wifiName<br>
                <strong>URL del servidor:</strong> $_serverUrl
            </div>
        </div>
        
        <div class="qr-section">
            <div class="qr-card">
                <h3>🎥 Acceder a Videos</h3>
                <div style="position: relative; display: inline-block;">
                    <div id="server-qr" class="qr-code"></div>
                    <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 66px; height: 66px; background: white; border-radius: 10px; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
                        <img src="data:image/png;base64,${_logoBase64 ?? ''}" style="width: 60px; height: 60px; object-fit: cover; border-radius: 8px;" onerror="this.style.display='none'">
                    </div>
                </div>
                <p>Escanea para acceder directamente a los videos</p>
                <div class="note">
                    <strong>Nota:</strong> Solo funciona si ya estás conectado a la misma red WiFi
                </div>
            </div>
            <div class="instructions">
                <h2>📋 Instrucciones Paso a Paso</h2>
                <div class="step">
                    <div class="step-number">1</div>
                    <div class="step-text">Conecta tu dispositivo a la red WiFi: <strong>$_wifiName</strong></div>
                </div>
                <div class="step">
                    <div class="step-number">2</div>
                    <div class="step-text">Ingresa la contraseña de la red WiFi manualmente</div>
                </div>
                <div class="step">
                    <div class="step-number">3</div>
                    <div class="step-text">Una vez conectado, escanea el código QR (Videos)</div>
                </div>
                <div class="step">
                    <div class="step-number">4</div>
                    <div class="step-text">Se abrirá automáticamente la página web con los videos</div>
                </div>
                <div class="step">
                    <div class="step-number">5</div>
                    <div class="step-text">Descarga o visualiza tus videos favoritos</div>
                </div>
            </div>
        </div>
    </div>

    <script>
        // JavaScript QR integrado directamente
        ${_qrCodeJsContent ?? '// JavaScript QR no disponible'}
        
        // Función para generar QR con manejo de errores
        function generateQR(elementId, data, size = 200) {
            const element = document.getElementById(elementId);
            if (!element) {
                console.error('Elemento no encontrado:', elementId);
                return;
            }
            
            // Limpiar el elemento
            element.innerHTML = '';
            
            try {
                // Verificar si QRCode está disponible
                if (typeof QRCode === 'undefined') {
                    throw new Error('Librería QR no disponible');
                }
                
                // Generar QR usando la API correcta de la librería
                new QRCode(element, {
                    text: data,
                    width: size,
                    height: size,
                    colorDark: '#000000',
                    colorLight: '#FFFFFF',
                    correctLevel: QRCode.CorrectLevel.H
                });
                console.log('QR generado exitosamente para', elementId);
            } catch (error) {
                console.error('Error generando QR para', elementId, ':', error);
                // Fallback: mostrar texto si falla la generación
                element.innerHTML = '<div style="padding: 20px; background: #F5F5F5; border: 2px dashed #E0E0E0; border-radius: 8px; color: #424242; font-weight: 500;"><strong>Error generando QR</strong><br>URL: ' + data + '</div>';
            }
        }
        
        // Generar códigos QR cuando la página esté lista
        document.addEventListener('DOMContentLoaded', function() {
            console.log('Generando códigos QR...');
            
            // Generar código QR para servidor
            const serverData = '$_serverUrl';
            console.log('Datos Servidor:', serverData);
            generateQR('server-qr', serverData, 200);
        });
        
        // Fallback si la librería no carga
        window.addEventListener('load', function() {
            setTimeout(function() {
                const serverQR = document.getElementById('server-qr');
                
                if (serverQR && serverQR.children.length === 0) {
                    serverQR.innerHTML = '<div style="padding: 20px; background: #F5F5F5; border: 2px dashed #E0E0E0; border-radius: 8px; color: #424242; font-weight: 500;"><strong>Servidor QR</strong><br>URL: $_serverUrl</div>';
                }
            }, 2000); // Esperar 2 segundos
        });
    </script>
</body>
</html>
    ''';
  }

  /// Genera la página HTML simple con solo el código QR de videos
  String _generateSimpleQRPage() {
    return '''
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cabina 360 - Código QR de Videos</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #1976D2 0%, #2E7D32 100%);
            min-height: 100vh;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        h1 {
            text-align: center;
            color: #212121;
            margin-bottom: 30px;
            font-size: 2.5em;
        }
        .qr-section {
            display: grid;
            grid-template-columns: 1fr;
            gap: 20px;
            margin-bottom: 30px;
        }
        .qr-card {
            background: white;
            padding: 20px;
            border-radius: 12px;
            text-align: center;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            border: 2px solid #E0E0E0;
        }
        .qr-card h3 {
            margin-bottom: 15px;
            color: #212121;
            font-weight: 600;
        }
        .qr-code {
            margin: 15px 0;
        }
        .instructions {
            background: #E8F5E8;
            padding: 20px;
            border-radius: 12px;
            border-left: 4px solid #4CAF50;
        }
        .step {
            display: flex;
            align-items: flex-start;
            margin-bottom: 10px;
        }
        .step-number {
            background: #4CAF50;
            color: white;
            width: 24px;
            height: 24px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            margin-right: 12px;
            flex-shrink: 0;
        }
        .step-text {
            flex: 1;
            color: #424242;
            font-weight: 500;
        }
        .server-info {
            background: #E8F5E8;
            padding: 15px;
            border-radius: 8px;
            margin: 10px 0;
            border-left: 4px solid #4CAF50;
            color: #2E7D32;
            font-weight: 500;
        }
        .note {
            background: #FFF3E0;
            padding: 10px;
            border-radius: 8px;
            margin: 10px 0;
            border-left: 4px solid #FF9800;
            font-size: 14px;
            color: #E65100;
            font-weight: 500;
        }
    </style>
    <link id="favicon-cabina360" rel="icon" type="image/png" href="">
</head>
<body>
    <div class="container">
        <div style="text-align: center; margin-bottom: 20px;">
            <img src="data:image/png;base64,${_logoBase64 ?? ''}" alt="Cabina 360" style="height: 80px; object-fit: contain; border-radius: 15px; box-shadow: 0 4px 15px rgba(0,0,0,0.2);" onerror="this.style.display='none'">
        </div>
        <h1>📱 Cabina 360 - Código QR de Videos</h1>
        
        <div class="qr-section">
            <div class="qr-card">
                <h3>🎥 Acceder a Videos</h3>
                <div style="position: relative; display: inline-block;">
                    <div id="server-qr" class="qr-code"></div>
                    <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 66px; height: 66px; background: white; border-radius: 10px; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
                        <img src="data:image/png;base64,${_logoBase64 ?? ''}" style="width: 60px; height: 60px; object-fit: cover; border-radius: 8px;" onerror="this.style.display='none'">
                    </div>
                </div>
                <p>Escanea para acceder directamente a los videos</p>
                <div class="note">
                    <strong>Nota:</strong> Solo funciona si ya estás conectado a la misma red WiFi
                </div>
            </div>
        </div>
        
        <div class="instructions">
            <h2>📋 Instrucciones Paso a Paso</h2>
            <div class="step">
                <div class="step-number">1</div>
                <div class="step-text">Conecta tu dispositivo a la red WiFi: <strong>$_wifiName</strong></div>
            </div>
            <div class="step">
                <div class="step-number">2</div>
                <div class="step-text">Escanea el código QR para acceder a los videos</div>
            </div>
            <div class="step">
                <div class="step-number">3</div>
                <div class="step-text">Se abrirá automáticamente la página web con los videos</div>
            </div>
            <div class="step">
                <div class="step-number">4</div>
                <div class="step-text">Descarga o visualiza tus videos favoritos</div>
            </div>
        </div>
        
        <div class="server-info">
            <h3>🔗 Acceso Directo</h3>
            <p>También puedes acceder directamente a los videos usando esta URL:</p>
            <p><strong>$_serverUrl</strong></p>
            <p>O ir a la página principal: <a href="/" style="color: #1976D2;">$_serverUrl/</a></p>
        </div>
    </div>

    <script>
        // JavaScript QR integrado directamente
        ${_qrCodeJsContent ?? '// JavaScript QR no disponible'}
        
        // Generar código QR para servidor usando la API correcta
        const serverData = '$_serverUrl';
        const element = document.getElementById('server-qr');
        
        try {
            // Verificar si QRCode está disponible
            if (typeof QRCode === 'undefined') {
                throw new Error('Librería QR no disponible');
            }
            
            new QRCode(element, {
                text: serverData,
                width: 200,
                height: 200,
                colorDark: '#000000',
                colorLight: '#FFFFFF',
                correctLevel: QRCode.CorrectLevel.H
            });
            console.log('QR generado exitosamente');
        } catch (error) {
            console.error('Error generando QR Servidor:', error);
            // Fallback si falla
            element.innerHTML = '<div style="padding: 20px; background: #F5F5F5; border: 2px dashed #E0E0E0; border-radius: 8px; color: #424242; font-weight: 500;"><strong>Error generando QR</strong><br>URL: ' + serverData + '</div>';
        }
    </script>
</body>
</html>
    ''';
  }

  /// Obtiene el directorio de videos
  Future<io.Directory?> _getRecordingDir() async {
    try {
      io.Directory? exportDir;

      // NUEVO: Usar getExternalStorageDirectory() directamente para evitar problemas de permisos
      if (io.Platform.isAndroid) {
        exportDir = await getExternalStorageDirectory();
        LoggingService.instance.info('WifiServer', 'WifiServer - Usando directorio externo: ${exportDir?.path}');
      } else if (io.Platform.isIOS) {
        exportDir = await getApplicationDocumentsDirectory();
      } else {
        exportDir = await getDownloadsDirectory();
      }

      // Crear subdirectorio CVR_Clips
      exportDir = exportDir != null
          ? io.Directory('${exportDir.path}/CVR_Clips')
          : null;
      if (exportDir != null) {
        LoggingService.instance.info('WifiServer', 'WifiServer - Directorio de videos: ${exportDir.path}');
      }

      return exportDir;
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'obteniendo directorio de videos: $e');
      return null;
    }
  }

  /// Obtiene el directorio de thumbnails
  Future<io.Directory?> _getThumbnailsDir() async {
    try {
      io.Directory? exportDir;

      // NUEVO: Usar getExternalStorageDirectory() directamente para evitar problemas de permisos
      if (io.Platform.isAndroid) {
        exportDir = await getExternalStorageDirectory();
        print(
          '📁 WifiServer - Usando directorio externo para thumbnails: ${exportDir?.path}',
        );
      } else if (io.Platform.isIOS) {
        exportDir = await getApplicationDocumentsDirectory();
      } else {
        exportDir = await getDownloadsDirectory();
      }

      final thumbnailsDir = io.Directory('${exportDir?.path}/CVR_Thumbnails');
      if (!await thumbnailsDir.exists()) {
        await thumbnailsDir.create(recursive: true);
        print(
          '📁 WifiServer - Directorio de thumbnails creado: ${thumbnailsDir.path}',
        );
      }

      return thumbnailsDir;
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'obteniendo directorio de thumbnails: $e');
      return null;
    }
  }

  /// Genera thumbnail para un video
  Future<String?> _generateThumbnail(String videoPath) async {
    try {
      final thumbnailsDir = await _getThumbnailsDir();
      if (thumbnailsDir == null) return null;

      final videoFile = io.File(videoPath);
      final videoName = videoFile.path.split('/').last;
      final thumbnailName = '${videoName.split('.').first}_thumb.jpg';
      final thumbnailPath = '${thumbnailsDir.path}/$thumbnailName';

      // Verificar si ya existe el thumbnail
      final thumbnailFile = io.File(thumbnailPath);
      if (await thumbnailFile.exists()) {
        LoggingService.instance.info('WifiServer', 'Thumbnail ya existe: $thumbnailPath');
        return thumbnailPath;
      }

      LoggingService.instance.info('WifiServer', 'Generando thumbnail para: $videoName');

      // Comando FFmpeg para generar thumbnail vertical al segundo 2
      // Aspecto 9:16 (vertical como celular), tamaño 270x480
      final command =
          '-i "$videoPath" -ss 00:00:02 -vframes 1 -vf "scale=270:480:force_original_aspect_ratio=decrease,pad=270:480:(ow-iw)/2:(oh-ih)/2" -q:v 2 "$thumbnailPath"';

      final result = await FFmpegKit.execute(command);
      final returnCode = await result.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        LoggingService.instance.info('WifiServer', 'Thumbnail generado: $thumbnailPath');
        return thumbnailPath;
      } else {
        LoggingService.instance.error('WifiServer', 'generando thumbnail: ${await result.getLogsAsString()}');
        return null;
      }
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'en _generateThumbnail: $e');
      return null;
    }
  }

  /// Obtiene la dirección IP local (preferentemente la del WiFi)
  Future<String> _getLocalIpAddress() async {
    try {
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty) {
        return wifiIP;
      }
      // Fallback: buscar la primera IP válida
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.address.startsWith('127.')) {
            return addr.address;
          }
        }
      }
      return 'localhost';
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'obteniendo IP local: $e');
      return 'localhost';
    }
  }

  /// Detiene el servidor
  Future<void> stopServer() async {
    try {
      await _server?.close();
      _server = null;
      _isServerRunning = false;
      _serverUrl = null;

      LoggingService.instance.debug('WifiServer', 'Servidor detenido');
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'deteniendo servidor: $e');
    }
  }

  /// Verifica el estado de la conexión
  Future<bool> isConnected() async {
    try {
      // Por ahora, asumir que hay conexión
      // TODO: Implementar verificación real de conectividad
      return true;
    } catch (e) {
      LoggingService.instance.error('WifiServer', 'verificando conectividad: $e');
      return false;
    }
  }

  /// Método público para solicitar info de red y mostrar feedback de permisos
  Future<void> requestNetworkInfoWithPermissionFeedback(
    Function(String message)? onPermissionDenied,
  ) async {
    await _loadNetworkInfo(onPermissionDenied: onPermissionDenied);
  }
}
