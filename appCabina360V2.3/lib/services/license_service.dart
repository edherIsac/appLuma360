import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logging_service.dart';

class LicenseService {
  static const String _secretKey = 'mi_clave_super_segura';
  static const String _licenseKey = 'license_base64';
  static const String _lastUseKey = 'last_use_date';

  /// Guarda la licencia en shared_preferences
  static Future<void> saveLicense(String licenseBase64) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_licenseKey, licenseBase64);
  }

  /// Obtiene la licencia guardada
  static Future<String?> getSavedLicense() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_licenseKey);
  }

  /// Borra la licencia guardada
  static Future<void> clearLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseKey);
    await prefs.remove(_lastUseKey);
  }

  /// Valida la licencia y protege contra manipulación de fecha
  static Future<LicenseValidationResult> validateLicense(
    String licenseBase64,
    String deviceId,
  ) async {
    final log = LoggingService.instance;
    try {
      final decoded = utf8.decode(base64.decode(licenseBase64));
      final licencia = json.decode(decoded);
      final String licenciaDeviceId = licencia['device_id'];
      final String expires = licencia['expires'];
      final String signature = licencia['signature'];

      // 1. Verificar que el deviceId coincida
      if (licenciaDeviceId != deviceId) {
        log.warning(
          'LicenseService',
          'DeviceId no coincide. Esperado: $licenciaDeviceId, Actual: $deviceId',
        );
        return LicenseValidationResult.invalidDeviceId();
      }

      // 2. Verificar la firma
      final data = '$licenciaDeviceId:$expires';
      final hmac = Hmac(sha256, utf8.encode(_secretKey));
      final digest = hmac.convert(utf8.encode(data)).toString();
      if (digest != signature) {
        log.warning('LicenseService', 'Firma de licencia inválida');
        return LicenseValidationResult.invalidSignature();
      }

      // 3. Verificar la fecha de expiración
      final now = DateTime.now();
      final expiryDate = DateTime.parse(expires);
      if (now.isAfter(expiryDate)) {
        log.warning('LicenseService', 'Licencia expirada el $expiryDate');
        return LicenseValidationResult.expired();
      }

      // 4. Protección contra manipulación de fecha
      final prefs = await SharedPreferences.getInstance();
      final lastUseStr = prefs.getString(_lastUseKey);
      if (lastUseStr != null) {
        final lastUse = DateTime.parse(lastUseStr);
        if (now.isBefore(lastUse)) {
          log.warning(
            'LicenseService',
            'Manipulación de fecha detectada. Último uso: $lastUse, Ahora: $now',
          );
          return LicenseValidationResult.dateManipulation();
        }
      }

      // 5. Guardar la fecha actual como última fecha de uso
      await prefs.setString(_lastUseKey, now.toIso8601String());

      log.info(
        'LicenseService',
        'Licencia validada correctamente para device: $deviceId',
      );
      return LicenseValidationResult.valid();
    } catch (e, stack) {
      log.error('LicenseService', 'Error parseando licencia', e, stack);
      return LicenseValidationResult.invalidFormat();
    }
  }
}

class LicenseValidationResult {
  final bool isValid;
  final String error;

  LicenseValidationResult._(this.isValid, this.error);

  factory LicenseValidationResult.valid() =>
      LicenseValidationResult._(true, '');
  factory LicenseValidationResult.invalidDeviceId() =>
      LicenseValidationResult._(false, 'El ID del dispositivo no coincide.');
  factory LicenseValidationResult.invalidSignature() =>
      LicenseValidationResult._(false, 'La firma de la licencia es inválida.');
  factory LicenseValidationResult.expired() =>
      LicenseValidationResult._(false, 'La licencia ha expirado.');
  factory LicenseValidationResult.dateManipulation() =>
      LicenseValidationResult._(false, '¡Manipulación de fecha detectada!');
  factory LicenseValidationResult.invalidFormat() =>
      LicenseValidationResult._(false, 'Licencia inválida o corrupta.');
}
