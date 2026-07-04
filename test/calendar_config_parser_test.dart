import 'package:celechron/http/calendar_config_parser.dart';
import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('academic year changes in September, not July', () {
    expect(academicYearStartFor(DateTime(2026, 7, 4)), 2025);
    expect(academicYearStartFor(DateTime(2026, 8, 31)), 2025);
    expect(academicYearStartFor(DateTime(2026, 9, 1)), 2026);
  });

  test('calendar key matches academic term', () {
    expect(calendarObjectKeyForSemester('2025-2026-2'), '2025-2026-2.json');
    expect(
      calendarConfigUriForSemester('2025-2026-2').toString(),
      'http://calendar.celechron.top/2025-2026-2.json',
    );
  });

  test('diagnostic text removes credentials and URL query values', () {
    final sanitized = DiagnosticLogService.sanitizeForDiagnostic(
      'password=secret | Cookie: session=abc | '
      'https://identity.zju.edu.cn/cas/login?ticket=ST-secret '
      '| student=3201234567',
    );
    expect(sanitized, isNot(contains('secret')));
    expect(sanitized, isNot(contains('session=abc')));
    expect(sanitized, isNot(contains('3201234567')));
    expect(sanitized, contains('/cas/login'));
  });
}
