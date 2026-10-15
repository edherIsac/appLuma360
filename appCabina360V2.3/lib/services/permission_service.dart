import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:cabina360_v2_2/models/permission_config.dart';
import 'package:cabina360_v2_2/models/permission_result.dart';
import 'package:cabina360_v2_2/services/logging_service.dart';

/// Centralized permission management service.
///
/// Single source of truth for all permission states across the app.
/// UI layers should query this service for status and call request methods,
/// then handle the results (e.g., show dialogs) in the widget layer.
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  final Map<Permission, PermissionStatus> _statusMap = {};

  int? _androidSdkInt;
  bool _initialized = false;

  /// All permission configurations for this app.
  static const List<PermissionConfig> _allConfigs = [
    // ── Camera ──────────────────────────────────────────
    PermissionConfig(
      permission: Permission.camera,
      title: 'Cámara',
      description: 'Necesaria para grabar videos 360.',
      icon: Icons.photo_camera,
      isRequired: true,
      iosSupported: true,
    ),
    // ── Microphone ──────────────────────────────────────
    PermissionConfig(
      permission: Permission.microphone,
      title: 'Micrófono',
      description: 'Necesario para grabar audio en los videos.',
      icon: Icons.mic,
      isRequired: true,
      iosSupported: true,
    ),
    // ── Media: Photos (Android 13+) ─────────────────────
    PermissionConfig(
      permission: Permission.photos,
      title: 'Fotos',
      description: 'Acceso a la galería de fotos (Android 13+).',
      icon: Icons.photo_library,
      isRequired: true,
      androidSdkRange: AndroidSdkRange(minSdk: 33),
      iosSupported: true,
    ),
    // ── Media: Videos (Android 13+) ─────────────────────
    PermissionConfig(
      permission: Permission.videos,
      title: 'Videos',
      description: 'Acceso a la galería de videos (Android 13+).',
      icon: Icons.video_library,
      isRequired: true,
      androidSdkRange: AndroidSdkRange(minSdk: 33),
    ),
    // ── Media: Audio (Android 13+) ──────────────────────
    PermissionConfig(
      permission: Permission.audio,
      title: 'Audio',
      description: 'Acceso a archivos de audio (Android 13+).',
      icon: Icons.audiotrack,
      isRequired: true,
      androidSdkRange: AndroidSdkRange(minSdk: 33),
    ),
    // ── Storage (Android ≤ 12) ──────────────────────────
    PermissionConfig(
      permission: Permission.storage,
      title: 'Almacenamiento',
      description: 'Necesario para guardar los videos grabados.',
      icon: Icons.folder,
      isRequired: true,
      androidSdkRange: AndroidSdkRange(maxSdk: 32),
    ),
    // ── Manage External Storage (Android 11+) ──────────
    PermissionConfig(
      permission: Permission.manageExternalStorage,
      title: 'Almacenamiento completo',
      description:
          'Acceso completo al almacenamiento para gestionar videos (Android 11+).',
      icon: Icons.sd_storage,
      isRequired: true,
      androidSdkRange: AndroidSdkRange(minSdk: 30),
    ),
    // ── Location (optional — WiFi features) ─────────────
    PermissionConfig(
      permission: Permission.location,
      title: 'Ubicación',
      description: 'Opcional. Necesaria para funciones WiFi (nombre de red).',
      icon: Icons.location_on,
      isRequired: false,
      iosSupported: true,
    ),
    PermissionConfig(
      permission: Permission.locationWhenInUse,
      title: 'Ubicación en uso',
      description:
          'Opcional. Necesaria para funciones WiFi mientras la app está activa.',
      icon: Icons.location_searching,
      isRequired: false,
      iosSupported: true,
    ),
    // ── Notifications (Android 13+) ─────────────────────
    PermissionConfig(
      permission: Permission.notification,
      title: 'Notificaciones',
      description: 'Opcional. Para mostrar progreso de procesamiento de video.',
      icon: Icons.notifications,
      isRequired: false,
      androidSdkRange: AndroidSdkRange(minSdk: 33),
    ),
  ];

  /// Get the permission configs applicable to the current platform.
  List<PermissionConfig> get applicableConfigs {
    return _allConfigs
        .where((c) => c.isApplicableOnPlatform(_androidSdkInt))
        .toList();
  }

  /// Get only the required configs applicable to the current platform.
  List<PermissionConfig> get requiredConfigs {
    return applicableConfigs.where((c) => c.isRequired).toList();
  }

  /// Get only the optional configs applicable to the current platform.
  List<PermissionConfig> get optionalConfigs {
    return applicableConfigs.where((c) => !c.isRequired).toList();
  }

  /// Initialize the service: detect platform, check all current statuses.
  Future<void> initialize() async {
    if (_initialized) return;

    final log = LoggingService.instance;
    log.info('PermissionService', 'Inicializando...');

    if (Platform.isAndroid) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        _androidSdkInt = androidInfo.version.sdkInt;
        log.info('PermissionService', 'Android SDK: $_androidSdkInt');
      } catch (e) {
        log.error('PermissionService', 'Error obteniendo info de Android', e);
      }
    }

    await refreshStatuses();
    _initialized = true;
    log.info('PermissionService', 'Inicialización completada');
  }

  /// Refresh all permission statuses from the system.
  Future<void> refreshStatuses() async {
    final log = LoggingService.instance;
    _statusMap.clear();

    for (final config in applicableConfigs) {
      try {
        final status = await config.permission.status;
        _statusMap[config.permission] = status;
        log.debug(
          'PermissionService',
          '${config.permission.toString().split('.').last}: $status',
        );
      } catch (e) {
        log.error(
          'PermissionService',
          'Error checking status for ${config.permission}',
          e,
        );
        _statusMap[config.permission] = PermissionStatus.denied;
      }
    }
  }

  /// Get the current status of a specific permission.
  PermissionStatus getStatus(Permission permission) {
    return _statusMap[permission] ?? PermissionStatus.denied;
  }

  /// Get all current permission statuses.
  Map<Permission, PermissionStatus> getAllStatuses() {
    return Map.unmodifiable(_statusMap);
  }

  /// Whether all required permissions are granted.
  bool areAllRequiredGranted() {
    for (final config in requiredConfigs) {
      final status = _statusMap[config.permission];
      if (status == null || !status.isGranted) return false;
    }
    return true;
  }

  /// Get the list of required permissions that are not granted.
  List<PermissionConfig> getDeniedRequiredConfigs() {
    return requiredConfigs
        .where((c) => !(_statusMap[c.permission]?.isGranted ?? false))
        .toList();
  }

  /// Get the list of required permissions that are permanently denied.
  List<PermissionConfig> getPermanentlyDeniedConfigs() {
    return requiredConfigs
        .where((c) => _statusMap[c.permission]?.isPermanentlyDenied ?? false)
        .toList();
  }

  /// Request a single permission and update the status map.
  Future<PermissionStatus> requestPermission(Permission permission) async {
    final log = LoggingService.instance;
    log.info(
      'PermissionService',
      'Solicitando permiso: ${permission.toString().split('.').last}',
    );

    try {
      final status = await permission.request();
      _statusMap[permission] = status;
      log.info(
        'PermissionService',
        'Permiso ${permission.toString().split('.').last}: $status',
      );
      return status;
    } catch (e) {
      log.error(
        'PermissionService',
        'Error solicitando permiso ${permission.toString().split('.').last}',
        e,
      );
      _statusMap[permission] = PermissionStatus.denied;
      return PermissionStatus.denied;
    }
  }

  /// Request all applicable permissions and return a result.
  Future<PermissionResult> requestAll() async {
    final log = LoggingService.instance;
    log.info('PermissionService', 'Solicitando todos los permisos...');

    for (final config in applicableConfigs) {
      final currentStatus = _statusMap[config.permission];

      // Skip already granted permissions
      if (currentStatus?.isGranted ?? false) continue;

      // Skip permanently denied — user must go to settings
      if (currentStatus?.isPermanentlyDenied ?? false) continue;

      await requestPermission(config.permission);
    }

    final result = PermissionResult(Map.from(_statusMap));
    log.info(
      'PermissionService',
      'Resultado: concedidos=${result.granted.length}, '
          'denegados=${result.denied.length}, '
          'permanentes=${result.permanentlyDenied.length}',
    );
    return result;
  }

  /// Request only the required permissions.
  Future<PermissionResult> requestRequired() async {
    final log = LoggingService.instance;
    log.info('PermissionService', 'Solicitando permisos requeridos...');

    for (final config in requiredConfigs) {
      final currentStatus = _statusMap[config.permission];

      if (currentStatus?.isGranted ?? false) continue;
      if (currentStatus?.isPermanentlyDenied ?? false) continue;

      await requestPermission(config.permission);
    }

    return PermissionResult(Map.from(_statusMap));
  }

  /// Open the app settings page so the user can grant permanently denied permissions.
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Re-check all statuses (call on app resume from background).
  Future<void> recheckOnResume() async {
    final log = LoggingService.instance;
    log.debug('PermissionService', 'Re-checking permissions on resume...');
    await refreshStatuses();
  }

  /// Find a config by permission.
  PermissionConfig? findConfig(Permission permission) {
    try {
      return _allConfigs.firstWhere((c) => c.permission == permission);
    } catch (_) {
      return null;
    }
  }

  // ── Legacy compatibility ──────────────────────────────
  // This method is kept for backward compatibility during migration.
  // It will be removed once all callers are updated.

  /// @deprecated Use [requestAll] or [requestRequired] instead.
  /// Requests all permissions and shows dialogs for denials.
  /// This method requires BuildContext for dialog display.
  Future<void> requestPermissions(BuildContext context) async {
    await initialize();
    final result = await requestAll();

    if (!context.mounted) return;

    // Show dialog for permanently denied permissions
    final permDenied = getPermanentlyDeniedConfigs();
    if (permDenied.isNotEmpty) {
      _showPermanentlyDeniedDialog(context, permDenied);
      return;
    }

    // Show dialog for denied (not permanent) permissions
    final denied = getDeniedRequiredConfigs();
    if (denied.isNotEmpty) {
      _showRetryDialog(context, denied);
    }
  }

  void _showPermanentlyDeniedDialog(
    BuildContext context,
    List<PermissionConfig> deniedConfigs,
  ) {
    final names = deniedConfigs.map((c) => c.title).join(', ');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Permisos Requeridos'),
          content: Text(
            'Los siguientes permisos están permanentemente denegados: $names.\n\n'
            'Por favor, habilítalos en la configuración del dispositivo.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Ir a Configuración'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await openSettings();
              },
            ),
          ],
        );
      },
    );
  }

  void _showRetryDialog(
    BuildContext context,
    List<PermissionConfig> deniedConfigs,
  ) {
    final names = deniedConfigs.map((c) => c.title).join(', ');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Permisos Requeridos'),
          content: Text(
            'Los siguientes permisos son necesarios: $names.\n\n'
            '¿Deseas intentar concederlos de nuevo?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Más tarde'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: const Text('Conceder'),
              onPressed: () {
                Navigator.of(ctx).pop();
                requestAll();
              },
            ),
          ],
        );
      },
    );
  }
}
