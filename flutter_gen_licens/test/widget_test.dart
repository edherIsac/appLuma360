import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen_licens/services/license_generator_service.dart';

void main() {
  group('LicenseGeneratorService', () {
    test('generateSignature produces correct HMAC-SHA256', () {
      // This matches the Node.js output for deviceId=V1UGS35H.75-14-3-7, expires=2026-05-30
      final signature = LicenseGeneratorService.generateSignature(
        'V1UGS35H.75-14-3-7',
        '2026-05-30',
      );
      expect(
        signature,
        'a5bffd6f06abc08da62c430b5198f13166f7c15e11335c8d3ee796428230a9fb',
      );
    });

    test('generateLicenseBase64 produces correct Base64 output', () {
      final base64 = LicenseGeneratorService.generateLicenseBase64(
        'V1UGS35H.75-14-3-7',
        '2026-05-30',
      );
      // This should match the content of licencia_2026-04-30_V1UGS35H.75-14-3-7.txt
      expect(
        base64,
        'eyJkZXZpY2VfaWQiOiJWMVVHUzM1SC43NS0xNC0zLTciLCJleHBpcmVzIjoiMjAyNi0wNS0zMCIsInNpZ25hdHVyZSI6ImE1YmZmZDZmMDZhYmMwOGRhNjJjNDMwYjUxOThmMTMxNjZmN2MxNWUxMTMzNWM4ZDNlZTc5NjQyODIzMGE5ZmIifQ==',
      );
    });

    test('addMonths adds months correctly', () {
      final date = DateTime(2026, 1, 15);
      final result = LicenseGeneratorService.addMonths(date, 3);
      expect(result.year, 2026);
      expect(result.month, 4);
      expect(result.day, 15);
    });

    test('addDays adds days correctly', () {
      final date = DateTime(2026, 1, 15);
      final result = LicenseGeneratorService.addDays(date, 10);
      expect(result.day, 25);
    });

    test('formatDate formats as YYYY-MM-DD', () {
      final date = DateTime(2026, 5, 30);
      expect(LicenseGeneratorService.formatDate(date), '2026-05-30');
    });

    test('generateFileName produces correct format', () {
      final fileName = LicenseGeneratorService.generateFileName('ABC123');
      expect(fileName, startsWith('licencia_'));
      expect(fileName, endsWith('_ABC123.txt'));
    });
  });
}
