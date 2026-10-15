import 'package:permission_handler/permission_handler.dart';

/// Result of a permission request batch operation.
class PermissionResult {
  final Map<Permission, PermissionStatus> statuses;

  const PermissionResult(this.statuses);

  /// Whether all permissions (required + optional) were granted.
  bool get allGranted => statuses.values.every((s) => s.isGranted);

  /// Whether all required permissions were granted.
  /// This ignores optional permissions that were denied.
  bool allRequiredGranted(List<Permission> requiredPermissions) {
    return requiredPermissions.every((p) => statuses[p]?.isGranted ?? false);
  }

  /// Permissions that were denied (but not permanently).
  List<Permission> get denied {
    return statuses.entries
        .where((e) => e.value.isDenied)
        .map((e) => e.key)
        .toList();
  }

  /// Permissions that were permanently denied.
  List<Permission> get permanentlyDenied {
    return statuses.entries
        .where((e) => e.value.isPermanentlyDenied)
        .map((e) => e.key)
        .toList();
  }

  /// Permissions that were granted.
  List<Permission> get granted {
    return statuses.entries
        .where((e) => e.value.isGranted)
        .map((e) => e.key)
        .toList();
  }

  /// Whether any permission is permanently denied.
  bool get hasPermanentlyDenied => permanentlyDenied.isNotEmpty;

  /// Whether any permission is denied.
  bool get hasDenied => denied.isNotEmpty;
}
