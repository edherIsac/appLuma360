import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Defines the SDK range where a permission is applicable on Android.
class AndroidSdkRange {
  final int? minSdk;
  final int? maxSdk;

  const AndroidSdkRange({this.minSdk, this.maxSdk});

  bool isApplicable(int sdkInt) {
    if (minSdk != null && sdkInt < minSdk!) return false;
    if (maxSdk != null && sdkInt > maxSdk!) return false;
    return true;
  }
}

/// Describes a single permission with metadata for UI display and logic.
class PermissionConfig {
  final Permission permission;
  final String title;
  final String description;
  final IconData icon;
  final bool isRequired;
  final AndroidSdkRange? androidSdkRange;
  final bool iosSupported;

  const PermissionConfig({
    required this.permission,
    required this.title,
    required this.description,
    required this.icon,
    this.isRequired = true,
    this.androidSdkRange,
    this.iosSupported = true,
  });

  /// Whether this permission should be requested on the current platform
  /// given the provided Android SDK version (ignored on non-Android).
  bool isApplicableOnPlatform(int? androidSdkInt) {
    if (Platform.isIOS) return iosSupported;
    if (Platform.isAndroid &&
        androidSdkRange != null &&
        androidSdkInt != null) {
      return androidSdkRange!.isApplicable(androidSdkInt);
    }
    return true;
  }
}
