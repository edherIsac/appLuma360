import 'dart:io';
import 'package:flutter/services.dart';

import 'package:cabina360_v2_2/services/permission_service.dart';
import 'package:cabina360_v2_2/services/logging_service.dart';

class MediaStoreService {
  static const _channel = MethodChannel('cabina360/media_store');

  Future<String?> saveVideoToPublicGallery(
    File sourceFile,
    String displayName,
  ) async {
    // Use centralized PermissionService instead of requesting here
    if (!PermissionService.instance.areAllRequiredGranted()) {
      LoggingService.instance.warning(
        'MediaStore',
        'Permisos de almacenamiento no concedidos, intentando solicitar...',
      );
      await PermissionService.instance.requestRequired();
      if (!PermissionService.instance.areAllRequiredGranted()) {
        LoggingService.instance.warning(
          'MediaStore',
          'Permisos de almacenamiento denegados.',
        );
        return null;
      }
    }

    if (!await sourceFile.exists()) {
      LoggingService.instance.warning(
        'MediaStore',
        'El archivo de origen no existe: ${sourceFile.path}',
      );
      return null;
    }

    try {
      LoggingService.instance.info(
        'MediaStore',
        'Iniciando guardado en galería: ${sourceFile.path}',
      );
      final String? uriString = await _channel.invokeMethod('saveVideo', {
        'sourcePath': sourceFile.path,
        'displayName': displayName,
      });

      if (uriString != null) {
        LoggingService.instance.info(
          'MediaStore',
          'Video guardado en la galería exitosamente: $uriString',
        );
      } else {
        LoggingService.instance.warning(
          'MediaStore',
          'Falló el guardado en la galería (método nativo retornó null).',
        );
      }
      return uriString;
    } on PlatformException catch (e) {
      LoggingService.instance.error(
        'MediaStore',
        'PlatformException al guardar en galería: ${e.message}',
      );
      return null;
    } catch (e) {
      LoggingService.instance.error(
        'MediaStore',
        'Error desconocido al guardar en galería',
        e,
      );
      return null;
    }
  }
}
