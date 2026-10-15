import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service that generates licenses compatible with cabina360_v2_2's LicenseService.
///
/// Replicates the exact logic from nodeGenerateLicens/gen.js:
/// - HMAC-SHA256 signature with secret key
/// - License JSON structure: {device_id, expires, signature}
/// - Base64-encoded output
class LicenseGeneratorService {
  static const String _secretKey = 'mi_clave_super_segura';

  /// Generates an HMAC-SHA256 signature for the given device ID and expiration date.
  ///
  /// The signature input format is `{deviceId}:{expires}` (e.g. "V1UGS35H.75-14-3-7:2026-05-30").
  /// This matches the Node.js implementation:
  /// ```js
  /// crypto.createHmac('sha256', SECRET_KEY).update(data).digest('hex')
  /// ```
  static String generateSignature(String deviceId, String expires) {
    final data = '$deviceId:$expires';
    final hmac = Hmac(sha256, utf8.encode(_secretKey));
    final digest = hmac.convert(utf8.encode(data)).toString();
    return digest;
  }

  /// Generates a license map with device_id, expires, and signature.
  static Map<String, dynamic> generateLicenseMap(String deviceId, String expires) {
    final signature = generateSignature(deviceId, expires);
    return {
      'device_id': deviceId,
      'expires': expires,
      'signature': signature,
    };
  }

  /// Generates a Base64-encoded license string.
  ///
  /// This is the primary output format used by the cabina360 app.
  /// The JSON is encoded without indentation (compact) to match Node.js behavior:
  /// ```js
  /// Buffer.from(JSON.stringify(license)).toString('base64')
  /// ```
  static String generateLicenseBase64(String deviceId, String expires) {
    final license = generateLicenseMap(deviceId, expires);
    final jsonStr = json.encode(license);
    final base64Str = base64.encode(utf8.encode(jsonStr));
    return base64Str;
  }

  /// Generates a pretty-printed JSON string of the license.
  static String generateLicenseJson(String deviceId, String expires) {
    final license = generateLicenseMap(deviceId, expires);
    return const JsonEncoder.withIndent('  ').convert(license);
  }

  /// Adds [months] months to [date] and returns the resulting date.
  static DateTime addMonths(DateTime date, int months) {
    return DateTime(date.year, date.month + months, date.day);
  }

  /// Adds [days] days to [date] and returns the resulting date.
  static DateTime addDays(DateTime date, int days) {
    return date.add(Duration(days: days));
  }

  /// Formats a [date] as YYYY-MM-DD, matching Node.js's `toISOString().slice(0, 10)`.
  static String formatDate(DateTime date) {
    return date.toIso8601String().substring(0, 10);
  }

  /// Generates the file name for the license file.
  /// Format: `licencia_{date}_{deviceId}.txt`
  static String generateFileName(String deviceId) {
    final today = formatDate(DateTime.now());
    return 'licencia_${today}_$deviceId.txt';
  }
}
