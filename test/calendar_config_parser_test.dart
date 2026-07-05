import 'package:celechron/http/calendar_config_parser.dart';
import 'package:celechron/model/semester.dart';
import 'package:celechron/model/session.dart';
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

  test('timetable plan probes the next academic year before September', () {
    final plan = timetableAcademicYearPlan(
      now: DateTime(2026, 7, 5),
      graduationYearStart: 2029,
    );

    expect(plan.normalUpperBound, 2025);
    expect(plan.probeUpperBound, 2026);
    expect(plan.yearsFrom(2024), [2024, 2025, 2026]);
    expect(plan.isProbeYear(2025), isFalse);
    expect(plan.isProbeYear(2026), isTrue);
  });

  test('timetable probe never goes beyond graduation year', () {
    final plan = timetableAcademicYearPlan(
      now: DateTime(2026, 7, 5),
      graduationYearStart: 2025,
    );

    expect(plan.normalUpperBound, 2025);
    expect(plan.probeUpperBound, 2025);
    expect(plan.yearsFrom(2024), [2024, 2025]);
    expect(plan.isProbeYear(2025), isFalse);
  });

  test('only expected unavailable probe results are ignored', () {
    expect(isExpectedTimetableProbeMiss(null), isTrue);
    expect(isExpectedTimetableProbeMiss('HTTP 404'), isTrue);
    expect(isExpectedTimetableProbeMiss('kbList 暂无数据'), isTrue);
    expect(isExpectedTimetableProbeMiss('响应正文为空'), isTrue);
    expect(isExpectedTimetableProbeMiss('缺少 kbList 数组'), isTrue);
    expect(isExpectedTimetableProbeMiss('网络连接失败'), isFalse);
    expect(isExpectedTimetableProbeMiss('登录态已失效'), isFalse);
  });

  test('future timetable session survives missing calendar fallback', () {
    final semester = Semester('2026-2027秋冬');
    final fallback = buildSafeDefaultCalendarConfig('2026-2027-1');
    applyCalendarConfig(
      fallback,
      semester,
      <DateTime, String>{},
      context: '虚构未来学期',
    );
    final session = Session.fromZdbk({
      'kcb': '虚构课程<br>虚构教学班<br>虚构教师<br>虚构教室zwf',
      'sfqd': '1',
      'xqj': 2,
      'dsz': '2',
      'xxq': '秋',
      'djj': 3,
      'skcd': 2,
    });

    semester.addSession(session, '2026-2027-1');

    expect(semester.sessions, hasLength(1));
    expect(semester.sessions.single.teacher, '虚构教师');
    expect(semester.sessions.single.location, '虚构教室');
    expect(semester.sessions.single.time, [3, 4]);
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
