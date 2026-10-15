import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:cabina360_v2_2/services/permission_service.dart';
import 'package:cabina360_v2_2/services/logging_service.dart';

class StorageService {
  Directory? _saveDir;
  Directory? _tempDir;

  Future<void> init() async {
    _saveDir = await _getRecordingDir();
    _tempDir = await _getTempDir();
    await checkOldVideosRecored();
  }

  Directory? get saveDir => _saveDir;
  Directory? get tempDir => _tempDir;

  Future<Directory?> _getRecordingDir() async {
    Directory? exportDir;
    // Permission checks are now centralized in PermissionService.
    // Ensure permissions are granted before calling init().
    if (!PermissionService.instance.areAllRequiredGranted()) {
      // Attempt to initialize anyway — the app may still work with
      // app-specific storage on some Android versions.
    }

    // Usar getExternalStorageDirectory() directamente
    if (Platform.isAndroid) {
      exportDir = await getExternalStorageDirectory();
      LoggingService.instance.info(
        'Storage',
        'Usando directorio externo: ${exportDir?.path}',
      );
    } else if (Platform.isIOS) {
      exportDir = await getApplicationDocumentsDirectory();
    } else {
      exportDir = await getDownloadsDirectory();
    }

    // Crear subdirectorio CVR_Clips
    exportDir = exportDir != null
        ? Directory('${exportDir.path}/CVR_Clips')
        : null;
    if (exportDir != null) {
      exportDir.createSync(recursive: true);
      LoggingService.instance.info(
        'Storage',
        'Directorio de videos creado: ${exportDir.path}',
      );
    }

    return exportDir;
  }

  Future<Directory?> _getTempDir() async {
    Directory? exportDir = _saveDir;
    if (exportDir != null) {
      exportDir = Directory('${exportDir.path}/temp');
      exportDir.createSync(recursive: true);
    }
    return exportDir;
  }

  Future<void> checkOldVideosRecored() async {
    final log = LoggingService.instance;
    log.info('Storage', 'Revisando videos temporales previos...');

    bool videoOriginal = await File(latestFilePath()).exists();
    if (videoOriginal) {
      File(latestFilePath()).delete();
    }

    bool videoEfecto = await File(efectoFilePath()).exists();
    if (videoEfecto) {
      File(efectoFilePath()).delete();
    }

    bool videoMarco = await File(marcoVideoFilePath()).exists();
    if (videoMarco) {
      File(marcoVideoFilePath()).delete();
    }

    bool audioFondoRecortado = await File(audioCutedFilePath()).exists();
    if (audioFondoRecortado) {
      File(audioCutedFilePath()).delete();
    }

    bool audioVideoFondo = await File(audioCutedFilePath()).exists();
    if (audioVideoFondo) {
      File(audioVideoFilePath()).delete();
    }

    log.info('Storage', 'Limpieza de videos temporales previos completada');
  }

  String latestFilePath() {
    return '${_saveDir?.path ?? ''}/rec-new.mp4';
  }

  String efectoFilePath() {
    return '${_saveDir?.path ?? ''}/ffmpeg-slowreverse.mp4';
  }

  String marcoVideoFilePath() {
    return '${_saveDir?.path ?? ''}/ffmpeg-marcoVideo.mp4';
  }

  String marcoImgFilePath() {
    return 'assets/logos/m1.png';
  }

  String logoVideoFilePath() {
    return '${_saveDir?.path ?? ''}/ffmpeg-logoVideo.mp4';
  }

  String audioVideoFilePath() {
    return '${_saveDir?.path ?? ''}/ffmpeg-audioVideo.mp4';
  }

  String audioUri() {
    return 'assets/audio/audio2.mp3';
  }

  Future<String> getAudioPath() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final audioFile = File('${audioDir.path}/audio2.mp3');
      if (!await audioFile.exists()) {
        final byteData = await rootBundle.load('assets/audio/audio2.mp3');
        await audioFile.writeAsBytes(byteData.buffer.asUint8List());
      }

      return audioFile.path;
    } catch (e, stack) {
      LoggingService.instance.error(
        'Storage',
        'Error al preparar archivo de audio',
        e,
        stack,
      );
      rethrow;
    }
  }

  String audioCutedFilePath() {
    return '${_saveDir?.path ?? ''}/audio-cuted.mp3';
  }

  String textoVideoFilePath() {
    return '${_saveDir?.path ?? ''}/ffmpeg-audioVideo.mp4';
  }

  String ffmpegFilePathProcc() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${_saveDir?.path ?? ''}/ffmpeg-$timestamp.mp4';
  }

  Future<String> getLogo() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logoDir = Directory('${appDir.path}/logo');
      if (!await logoDir.exists()) {
        await logoDir.create(recursive: true);
      }

      final logoFile = File('${logoDir.path}/logo.png');
      if (!await logoFile.exists()) {
        final byteData = await rootBundle.load('assets/logos/logo.png');
        await logoFile.writeAsBytes(byteData.buffer.asUint8List());
      }

      return logoFile.path;
    } catch (e, stack) {
      LoggingService.instance.error(
        'Storage',
        'Error al preparar archivo de logo',
        e,
        stack,
      );
      rethrow;
    }
  }

  Future<String> getMarcoVideo(String no) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final marcoDir = Directory('${appDir.path}/marco');
      if (!await marcoDir.exists()) {
        await marcoDir.create(recursive: true);
      }

      final marcoFile = File('${marcoDir.path}/m1.png');
      if (!await marcoFile.exists()) {
        final byteData = await rootBundle.load('assets/logos/m1.png');
        await marcoFile.writeAsBytes(byteData.buffer.asUint8List());
      }

      return marcoFile.path;
    } catch (e, stack) {
      LoggingService.instance.error(
        'Storage',
        'Error al preparar archivo de marco',
        e,
        stack,
      );
      rethrow;
    }
  }

  String getAudioFondo(String no) {
    return 'assets/audio/audio2.mp3';
  }

  String logoImgFilePath() {
    return 'assets/logos/logo.png';
  }

  Future<void> deletedVideosTmp() async {
    final log = LoggingService.instance;
    try {
      log.info('Storage', 'Iniciando limpieza de archivos temporales...');

      final tempFiles = [
        latestFilePath(),
        efectoFilePath(),
        marcoVideoFilePath(),
        logoVideoFilePath(),
        audioCutedFilePath(),
        audioVideoFilePath(),
      ];

      for (var filePath in tempFiles) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            log.debug('Storage', 'Eliminando archivo temporal: $filePath');
            await file.delete();
          }
        } catch (e) {
          log.warning('Storage', 'Error al eliminar archivo $filePath: $e');
        }
      }

      if (_tempDir != null) {
        log.debug(
          'Storage',
          'Limpiando directorio temporal: ${_tempDir!.path}',
        );
        try {
          final files = _tempDir!.listSync();
          for (var entity in files) {
            if (entity is File) {
              await entity.delete();
            }
          }
        } catch (e) {
          log.warning('Storage', 'Error al limpiar directorio temporal', e);
        }
      }

      final recordingDir = await _getRecordingDir();
      if (recordingDir != null) {
        final indexFile = File('${recordingDir.path}/index.html');
        if (await indexFile.exists()) {
          await indexFile.delete();
        }
      }

      log.info('Storage', 'Limpieza de archivos temporales completada');
    } catch (e, stack) {
      log.error(
        'Storage',
        'Error general en limpieza de archivos temporales',
        e,
        stack,
      );
    }
  }

  Future<List<FileSystemEntity>> getExistingClips() async {
    if (_saveDir == null) return [];
    List<FileSystemEntity>? existingFiles = await _saveDir?.list().toList();
    existingFiles?.removeWhere(
      (element) => element.uri.pathSegments.last == 'index.html',
    );
    return existingFiles ?? [];
  }
}
