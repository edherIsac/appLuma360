import 'dart:io';
import 'dart:convert'; // NUEVO: Importar para JSON

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../services/camera_service.dart'; // NUEVO: Importar CameraService
import '../services/logging_service.dart'; // NUEVO: Importar LoggingService
import '../services/wifi_server_service.dart'; // Importar para recargar logo
import '../screens/advanced_config_screen.dart';
import '../screens/usability_config_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ConfigScreen extends StatefulWidget {
  final ConfigCabina initialConfig;
  final void Function(ConfigCabina) onConfigChanged;
  const ConfigScreen({
    Key? key,
    required this.initialConfig,
    required this.onConfigChanged,
  }) : super(key: key);

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late ConfigCabina config;
  late TextEditingController durationController;
  late TextEditingController whatsappController;
  late TextEditingController logoPositionController;
  late TextEditingController wifiNameController;
  String? marcoPath;
  String? logoPath;
  String? audioPath;
  bool _isLoading = true; // NUEVO: Indicador de carga

  @override
  void initState() {
    super.initState();
    config = widget.initialConfig;
    durationController = TextEditingController(
      text: config.duration.toString(),
    );
    whatsappController = TextEditingController(text: config.whatsApp);
    logoPositionController = TextEditingController(text: config.logoPosition);
    wifiNameController = TextEditingController(text: config.wifiName);
    marcoPath = config.contornoVideo;
    logoPath = config.logoPosition;
    audioPath = config.audioFondo;

    // NUEVO: Cargar paths de forma segura
    _loadCustomPathsSafely();
  }

  // NUEVO: Método seguro para cargar paths
  Future<void> _loadCustomPathsSafely() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _loadCustomPaths();
    } catch (e) {
      print('Error cargando paths personalizados: $e');
      // Usar valores por defecto si hay error
      setState(() {
        marcoPath = config.contornoVideo;
        logoPath = config.logoPosition;
        audioPath = config.audioFondo;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateDurationController() {
    durationController.text = config.duration.toString();
  }

  @override
  void dispose() {
    durationController.dispose();
    whatsappController.dispose();
    logoPositionController.dispose();
    wifiNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomPaths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        marcoPath = prefs.getString('marcoPath') ?? config.contornoVideo;
        logoPath = prefs.getString('logoPath') ?? config.logoPosition;
        audioPath = prefs.getString('audioPath') ?? config.audioFondo;
      });
    } catch (e) {
      print('Error en _loadCustomPaths: $e');
      // Usar valores por defecto si hay error
      setState(() {
        marcoPath = config.contornoVideo;
        logoPath = config.logoPosition;
        audioPath = config.audioFondo;
      });
    }
  }

  Future<void> _saveCustomPaths() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('marcoPath', marcoPath ?? config.contornoVideo);
    await prefs.setString('logoPath', logoPath ?? config.logoPosition);
    await prefs.setString('audioPath', audioPath ?? config.audioFondo);
  }

  Future<String?> _copyToPermanentDir(
    String originalPath,
    String folder,
    String filename,
  ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${appDir.path}/$folder');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final newPath = '${targetDir.path}/$filename';
      final newFile = await File(originalPath).copy(newPath);
      return newFile.path;
    } catch (e) {
      print('Error copiando archivo: $e');
      return null;
    }
  }

  Future<String?> _processAudioFile(String originalPath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/audios');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final processedPath = '${audioDir.path}/audio_processed.mp3';

      // Comando FFmpeg para optimizar el audio
      // Convertir a AAC, 44.1kHz, 128kbps para compatibilidad óptima
      final command =
          '-i "$originalPath" -c:a aac -ar 44100 -b:a 128k -y "$processedPath"';

      print('Procesando audio con FFmpeg: $command');

      // Ejecutar FFmpeg para procesar el audio
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('Audio procesado exitosamente: $processedPath');
        return processedPath;
      } else {
        print('Error procesando audio con FFmpeg');
        return null;
      }
    } catch (e) {
      print('Error procesando audio: $e');
      return null;
    }
  }

  Future<void> _pickFile(String type) async {
    FileType fileType = FileType.any;
    List<String>? allowedExtensions;
    if (type == 'marco') {
      fileType = FileType.custom;
      allowedExtensions = ['png'];
    } else if (type == 'logo') {
      fileType = FileType.custom;
      allowedExtensions = ['png'];
    } else if (type == 'audio') {
      fileType = FileType.custom;
      allowedExtensions = [
        'mp3',
        'wav',
        'aac',
        'm4a',
        'ogg',
        'flac',
        'wma',
        'aiff',
      ];
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: fileType,
      allowedExtensions: allowedExtensions,
    );

    // Si no se encontraron archivos con el filtro y es audio, intentar sin filtro
    if (result == null && type == 'audio') {
      print(
        'No se encontraron archivos de audio con el filtro, intentando sin filtro...',
      );
      result = await FilePicker.platform.pickFiles(type: FileType.any);
    }

    if (result != null && result.files.single.path != null) {
      String? newPath;

      // Validar que el archivo sea del tipo correcto
      if (type == 'marco' || type == 'logo') {
        final fileName = result.files.single.name.toLowerCase();
        final isPng = fileName.endsWith('.png');
        if (!isPng) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Por favor selecciona un archivo PNG (.png) con transparencia.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      } else if (type == 'audio') {
        final fileName = result.files.single.name.toLowerCase();
        final isAudioFile =
            fileName.endsWith('.mp3') ||
            fileName.endsWith('.wav') ||
            fileName.endsWith('.aac') ||
            fileName.endsWith('.m4a') ||
            fileName.endsWith('.ogg') ||
            fileName.endsWith('.flac') ||
            fileName.endsWith('.wma') ||
            fileName.endsWith('.aiff');
        if (!isAudioFile) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Por favor selecciona un archivo de audio válido (mp3, wav, aac, etc.)',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (type == 'marco') {
        final ext = result.files.single.extension ?? 'png';
        newPath = await _copyToPermanentDir(
          result.files.single.path!,
          'marcos',
          'marco.$ext',
        );
        setState(() {
          marcoPath = newPath;
          config = ConfigCabina(
            duration: config.duration,
            enabledVideoFilter: config.enabledVideoFilter,
            enabledContornoVideo: config.enabledContornoVideo,
            enabledLogo: config.enabledLogo,
            enabledAudioFondo: config.enabledAudioFondo,
            contornoVideo: newPath ?? config.contornoVideo,
            audioFondo: config.audioFondo,
            logoPosition: config.logoPosition,
            whatsApp: config.whatsApp,
            enabledINTERNET: config.enabledINTERNET,
          );
        });
      } else if (type == 'logo') {
        final ext = result.files.single.extension ?? 'png';
        newPath = await _copyToPermanentDir(
          result.files.single.path!,
          'logos',
          'logo.$ext',
        );
        // Recargar logo en el servidor web para que se actualice en el QR
        await WifiServerService.instance.reloadLogo();
        setState(() {
          logoPath = newPath;
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
      } else if (type == 'audio') {
        final ext = result.files.single.extension ?? 'mp3';
        // Procesar el audio para optimizarlo
        newPath = await _processAudioFile(result.files.single.path!);
        if (newPath == null) {
          // Si falla el procesamiento, usar el archivo original
          newPath = await _copyToPermanentDir(
            result.files.single.path!,
            'audios',
            'audio.$ext',
          );
        }
        setState(() {
          audioPath = newPath;
          config = ConfigCabina(
            duration: config.duration,
            enabledVideoFilter: config.enabledVideoFilter,
            enabledContornoVideo: config.enabledContornoVideo,
            enabledLogo: config.enabledLogo,
            enabledAudioFondo: config.enabledAudioFondo,
            contornoVideo: config.contornoVideo,
            audioFondo: newPath ?? config.audioFondo,
            logoPosition: config.logoPosition,
            whatsApp: config.whatsApp,
            enabledINTERNET: config.enabledINTERNET,
          );
        });
      }
      await _saveCustomPaths();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('config', _configToJson(config));
      widget.onConfigChanged(config);
    }
  }

  Future<void> _saveConfig() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final newConfig = ConfigCabina(
        duration: int.tryParse(durationController.text) ?? 5,
        enabledVideoFilter: config.enabledVideoFilter,
        enabledContornoVideo: config.enabledContornoVideo,
        enabledLogo: config.enabledLogo,
        enabledAudioFondo: config.enabledAudioFondo,
        contornoVideo: marcoPath ?? config.contornoVideo,
        audioFondo: audioPath ?? config.audioFondo,
        logoPosition: logoPositionController.text,
        whatsApp: whatsappController.text,
        enabledINTERNET: config.enabledINTERNET,
        useFrontCamera: config.useFrontCamera,
        wifiName: wifiNameController.text.trim(),
        videoResolution: config.videoResolution,
      );

      final configJson = _configToJson(newConfig);
      await prefs.setString('config', configJson);

      widget.onConfigChanged(newConfig);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error guardando configuración: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreDefaults() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('marcoPath');
      await prefs.remove('logoPath');
      await prefs.remove('audioPath');

      setState(() {
        marcoPath = '1';
        logoPath = 'rb';
        audioPath = '1';
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
          useFrontCamera: false,
          wifiName: '',
          videoResolution: 'medium',
        );
        _updateDurationController();
        whatsappController.text = '';
        logoPositionController.text = 'rb';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración restaurada por defecto'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error restaurando configuración: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restaurar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // NUEVO: Método JSON seguro usando dart:convert
  String _configToJson(ConfigCabina config) {
    try {
      final Map<String, dynamic> jsonMap = {
        'duration': config.duration,
        'enabledVideoFilter': config.enabledVideoFilter,
        'enabledContornoVideo': config.enabledContornoVideo,
        'enabledLogo': config.enabledLogo,
        'enabledAudioFondo': config.enabledAudioFondo,
        'contornoVideo': config.contornoVideo,
        'audioFondo': config.audioFondo,
        'logoPosition': config.logoPosition,
        'whatsApp': config.whatsApp,
        'enabledINTERNET': config.enabledINTERNET,
        'useFrontCamera': config.useFrontCamera,
        'wifiName': config.wifiName,
        'videoResolution': config.videoResolution,
      };

      return jsonEncode(jsonMap);
    } catch (e) {
      print('Error serializando configuración: $e');
      // Retornar configuración por defecto si hay error
      return '{"duration":5,"enabledVideoFilter":true,"enabledContornoVideo":true,"enabledLogo":true,"enabledAudioFondo":true,"contornoVideo":"1","audioFondo":"1","logoPosition":"rb","whatsApp":"","enabledINTERNET":false,"useFrontCamera":false,"wifiName":"","videoResolution":"medium"}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración de Cabina 360')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    value: config.duration.clamp(1, 60),
                    items: List.generate(60, (i) => i + 1)
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('$v segundos'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          config = ConfigCabina(
                            duration: value,
                            enabledVideoFilter: config.enabledVideoFilter,
                            enabledContornoVideo: config.enabledContornoVideo,
                            enabledLogo: config.enabledLogo,
                            enabledAudioFondo: config.enabledAudioFondo,
                            contornoVideo: config.contornoVideo,
                            audioFondo: config.audioFondo,
                            logoPosition: config.logoPosition,
                            whatsApp: config.whatsApp,
                            enabledINTERNET: config.enabledINTERNET,
                            useFrontCamera: config.useFrontCamera,
                            wifiName: config.wifiName,
                            videoResolution: config.videoResolution,
                          );
                          durationController.text = value.toString();
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Duración (segundos)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: config.videoResolution,
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Baja (low)')),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Text('Media (medium)'),
                      ),
                      DropdownMenuItem(
                        value: 'high',
                        child: Text('Alta (high)'),
                      ),
                      DropdownMenuItem(
                        value: 'veryHigh',
                        child: Text('Muy Alta (veryHigh)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
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
                            useFrontCamera: config.useFrontCamera,
                            wifiName: config.wifiName,
                            videoResolution: value,
                          );
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Resolución de grabación',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Efectos de video (slow motion y reverse)',
                    ),
                    value: config.enabledVideoFilter,
                    onChanged: (v) => setState(() {
                      config = ConfigCabina(
                        duration: config.duration,
                        enabledVideoFilter: v,
                        enabledContornoVideo: config.enabledContornoVideo,
                        enabledLogo: config.enabledLogo,
                        enabledAudioFondo: config.enabledAudioFondo,
                        contornoVideo: config.contornoVideo,
                        audioFondo: config.audioFondo,
                        logoPosition: config.logoPosition,
                        whatsApp: config.whatsApp,
                        enabledINTERNET: config.enabledINTERNET,
                      );
                      _updateDurationController();
                    }),
                  ),
                  SwitchListTile(
                    title: const Text('Marco del video'),
                    value: config.enabledContornoVideo,
                    onChanged: (v) => setState(() {
                      config = ConfigCabina(
                        duration: config.duration,
                        enabledVideoFilter: config.enabledVideoFilter,
                        enabledContornoVideo: v,
                        enabledLogo: config.enabledLogo,
                        enabledAudioFondo: config.enabledAudioFondo,
                        contornoVideo: config.contornoVideo,
                        audioFondo: config.audioFondo,
                        logoPosition: config.logoPosition,
                        whatsApp: config.whatsApp,
                        enabledINTERNET: config.enabledINTERNET,
                      );
                      _updateDurationController();
                    }),
                  ),
                  Row(
                    children: [
                      if (marcoPath != null && File(marcoPath!).existsSync())
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey, width: 1),
                              color: Colors.black,
                            ),
                            child: Image.file(
                              File(marcoPath!),
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey, width: 1),
                              color: Colors.white,
                            ),
                            child: Image.asset(
                              'assets/logos/m1.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          marcoPath != null
                              ? 'Marco: ${marcoPath!.split('/').last}'
                              : 'Marco por defecto',
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text('Seleccionar Marco'),
                        onPressed: () => _pickFile('marco'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text(
                      'Recomendación: Usa solo imágenes PNG con transparencia y resolución 1080x1920 px para que funcione correctamente.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Logo'),
                    value: config.enabledLogo,
                    onChanged: (v) => setState(() {
                      config = ConfigCabina(
                        duration: config.duration,
                        enabledVideoFilter: config.enabledVideoFilter,
                        enabledContornoVideo: config.enabledContornoVideo,
                        enabledLogo: v,
                        enabledAudioFondo: config.enabledAudioFondo,
                        contornoVideo: config.contornoVideo,
                        audioFondo: config.audioFondo,
                        logoPosition: config.logoPosition,
                        whatsApp: config.whatsApp,
                        enabledINTERNET: config.enabledINTERNET,
                      );
                      _updateDurationController();
                    }),
                  ),
                  Row(
                    children: [
                      if (logoPath != null && File(logoPath!).existsSync())
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Image.file(
                              File(logoPath!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Image.asset(
                              'assets/logos/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          logoPath != null
                              ? 'Logo: ${logoPath!.split('/').last}'
                              : 'Logo por defecto',
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text('Seleccionar Logo'),
                        onPressed: () => _pickFile('logo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text(
                      'Recomendación: Usa imágenes PNG (preferentemente con transparencia). No es obligatorio que sea cuadrado, pero se recomienda un tamaño mínimo de 400 px en el lado más corto para buena calidad en grabaciones de alta resolución.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: DropdownButtonFormField<String>(
                      value: logoPositionController.text.isNotEmpty
                          ? logoPositionController.text
                          : 'rb',
                      items: const [
                        DropdownMenuItem(
                          value: 'lt',
                          child: Text('Superior Izquierda (lt)'),
                        ),
                        DropdownMenuItem(
                          value: 'rt',
                          child: Text('Superior Derecha (rt)'),
                        ),
                        DropdownMenuItem(
                          value: 'rb',
                          child: Text('Inferior Derecha (rb)'),
                        ),
                        DropdownMenuItem(
                          value: 'lb',
                          child: Text('Inferior Izquierda (lb)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            logoPositionController.text = value;
                            config = ConfigCabina(
                              duration: config.duration,
                              enabledVideoFilter: config.enabledVideoFilter,
                              enabledContornoVideo: config.enabledContornoVideo,
                              enabledLogo: config.enabledLogo,
                              enabledAudioFondo: config.enabledAudioFondo,
                              contornoVideo: config.contornoVideo,
                              audioFondo: config.audioFondo,
                              logoPosition: value,
                              whatsApp: config.whatsApp,
                              enabledINTERNET: config.enabledINTERNET,
                            );
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Posición del logo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Audio de fondo'),
                    value: config.enabledAudioFondo,
                    onChanged: (v) => setState(() {
                      config = ConfigCabina(
                        duration: config.duration,
                        enabledVideoFilter: config.enabledVideoFilter,
                        enabledContornoVideo: config.enabledContornoVideo,
                        enabledLogo: config.enabledLogo,
                        enabledAudioFondo: v,
                        contornoVideo: config.contornoVideo,
                        audioFondo: config.audioFondo,
                        logoPosition: config.logoPosition,
                        whatsApp: config.whatsApp,
                        enabledINTERNET: config.enabledINTERNET,
                      );
                      _updateDurationController();
                    }),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          audioPath != null
                              ? 'Audio: ${audioPath!.split('/').last}'
                              : 'Audio por defecto',
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.audiotrack),
                        label: const Text('Seleccionar Audio'),
                        onPressed: () => _pickFile('audio'),
                      ),
                    ],
                  ),
                  // NUEVA SECCIÓN: Configuración de Cámara
                  const SizedBox(height: 24),
                  const Text(
                    'Configuración de Cámara',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Selector de Cámara
                  if (CameraService.instance.hasMultipleCameras)
                    SwitchListTile(
                      title: const Text('Usar Cámara Frontal'),
                      subtitle: const Text(
                        'Cambia entre cámara frontal y trasera',
                      ),
                      value: config.useFrontCamera,
                      onChanged: (value) {
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
                            useFrontCamera: value, // NUEVO
                            wifiName: config.wifiName, // NUEVO
                          );
                        });

                        // Guardar preferencia
                        CameraService.instance.saveUserPreference(value);
                      },
                      secondary: Icon(
                        config.useFrontCamera
                            ? Icons.camera_front
                            : Icons.camera_rear,
                        color: config.useFrontCamera
                            ? Colors.blue
                            : Colors.green,
                      ),
                    )
                  else
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Solo hay una cámara disponible en este dispositivo',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // NUEVA SECCIÓN: Configuración de WiFi
                  const SizedBox(height: 24),
                  const Text(
                    'Nombre de la red WiFi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: wifiNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre exacto de la red WiFi',
                      border: OutlineInputBorder(),
                      helperText:
                          'Escribe el nombre exacto de la red WiFi a la que se conecta la cabina',
                    ),
                  ),
                  // NUEVA SECCIÓN: Herramientas de Configuración
                  const SizedBox(height: 32),
                  const Text(
                    'Herramientas de Configuración',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Configuración Avanzada
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.settings, color: Colors.orange),
                      title: const Text('Configuración Avanzada'),
                      subtitle: const Text(
                        'Presets, importar/exportar configuraciones',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdvancedConfigScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  // Configuración de Usabilidad
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.accessibility,
                        color: Colors.purple,
                      ),
                      title: const Text('Configuración de Usabilidad'),
                      subtitle: const Text('Temas, tutoriales y accesibilidad'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UsabilityConfigScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _saveConfig,
                        child: const Text('Guardar'),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.restore),
                        label: const Text('Restaurar por defecto'),
                        onPressed: _restoreDefaults,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // NUEVO: Botón para enviar logs al equipo de desarrollo
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          // Mostrar indicador de carga
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Generando reporte de logs...'),
                            ),
                          );

                          // Exportar logs con diagnóstico
                          final logFile = await LoggingService.instance
                              .exportLogsWithDiagnostics();

                          // Compartir archivo
                          await Share.shareXFiles(
                            [XFile(logFile.path)],
                            text:
                                'Logs Cabina 360 - ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                            subject: 'Reporte de error Cabina 360',
                          );

                          // Abrir WhatsApp directo al número del equipo
                          final whatsappUrl =
                              'https://wa.me/${DeviceDiagnosticsService.whatsappNumber}';
                          final uri = Uri.parse(whatsappUrl);
                          if (await canLaunchUrl(uri)) {
                            await Future.delayed(const Duration(seconds: 2));
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error enviando logs: $e'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.bug_report),
                      label: const Text('📧 Enviar Logs al Equipo (WhatsApp)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
