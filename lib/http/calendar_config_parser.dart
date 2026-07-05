import 'dart:convert';

import 'package:celechron/http/zjuServices/response_utils.dart';
import 'package:celechron/model/semester.dart';
import 'package:flutter/foundation.dart';

const calendarConfigBaseUrl = 'http://calendar.celechron.top/';

int academicYearStartFor(DateTime now) =>
    now.month >= DateTime.september ? now.year : now.year - 1;

class TimetableAcademicYearPlan {
  final int normalUpperBound;
  final int probeUpperBound;

  const TimetableAcademicYearPlan({
    required this.normalUpperBound,
    required this.probeUpperBound,
  });

  Iterable<int> yearsFrom(int enrollmentYearStart) sync* {
    for (var year = enrollmentYearStart; year <= probeUpperBound; year++) {
      yield year;
    }
  }

  bool isProbeYear(int academicYearStart) =>
      academicYearStart > normalUpperBound;
}

TimetableAcademicYearPlan timetableAcademicYearPlan({
  required DateTime now,
  required int graduationYearStart,
}) {
  final currentAcademicYearStart = academicYearStartFor(now);
  final normalUpperBound = currentAcademicYearStart < graduationYearStart
      ? currentAcademicYearStart
      : graduationYearStart;
  final nextAcademicYearStart = currentAcademicYearStart + 1;
  final probeUpperBound = nextAcademicYearStart < graduationYearStart
      ? nextAcademicYearStart
      : graduationYearStart;
  return TimetableAcademicYearPlan(
    normalUpperBound: normalUpperBound,
    probeUpperBound: probeUpperBound,
  );
}

bool isExpectedTimetableProbeMiss(Object? error) {
  if (error == null) return true;
  final text = error.toString().toLowerCase();
  return text.contains('404') ||
      text.contains('not found') ||
      text.contains('no data') ||
      text.contains('暂无数据') ||
      text.contains('无数据') ||
      text.contains('未开放') ||
      text.contains('尚未开放') ||
      text.contains('空响应') ||
      text.contains('响应为空') ||
      text.contains('正文为空') ||
      text.contains('empty response') ||
      text.contains('缺少 kblist');
}

String calendarObjectKeyForSemester(String semesterId) {
  if (!RegExp(r'^\d{4}-\d{4}-[12]$').hasMatch(semesterId)) {
    throw FormatException('无效的学年学期：$semesterId');
  }
  return '$semesterId.json';
}

Uri calendarConfigUriForSemester(String semesterId) {
  final key = calendarObjectKeyForSemester(semesterId);
  return Uri.parse(calendarConfigBaseUrl).resolve(key);
}

Map<String, dynamic> decodeAndValidateCalendarConfig(
  String rawConfig, {
  required String context,
}) {
  final config = decodeJsonMap(rawConfig, context: context);
  final startEnd = asDynamicList(config['startEnd']);
  final sessionTime = asDynamicList(config['sessionTime']);
  if (startEnd == null || startEnd.length != 4) {
    throw FormatException('$context：startEnd 应包含四个日期');
  }
  if (sessionTime == null || sessionTime.length < 15) {
    throw FormatException('$context：sessionTime 缺失或节次数不足');
  }
  return config;
}

String buildSafeDefaultCalendarConfig(
  String semesterId, {
  Map<String, dynamic>? template,
}) {
  final parts = semesterId.split('-');
  final year = int.parse(parts.first);
  final term = int.parse(parts.last);
  final firstStart = _mondayOnOrAfter(
    term == 1 ? DateTime(year, 9, 14) : DateTime(year + 1, 2, 20),
  );
  final firstEnd = firstStart.add(const Duration(days: 55));
  final secondStart = firstEnd.add(const Duration(days: 1));
  final secondEnd = secondStart.add(const Duration(days: 55));

  final templateTimes = asDynamicList(template?['sessionTime']);
  final sessionTime = templateTimes != null && templateTimes.length >= 15
      ? templateTimes
      : _defaultSessionTime;
  return jsonEncode({
    'sessionTime': sessionTime,
    'startEnd': [
      _compactDate(firstStart),
      _compactDate(firstEnd),
      _compactDate(secondStart),
      _compactDate(secondEnd),
    ],
    'holiday': <String, String>{},
    'dummy': <String, String>{},
    'exchange': <String, String>{},
  });
}

DateTime _mondayOnOrAfter(DateTime date) {
  final offset = (DateTime.monday - date.weekday) % 7;
  return date.add(Duration(days: offset));
}

String _compactDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
}

const _defaultSessionTime = [
  ['00:00', '00:00'],
  ['08:00', '08:45'],
  ['08:50', '09:35'],
  ['10:00', '10:45'],
  ['10:50', '11:35'],
  ['11:40', '12:25'],
  ['13:25', '14:10'],
  ['14:15', '15:00'],
  ['15:05', '15:50'],
  ['16:15', '17:00'],
  ['17:05', '17:50'],
  ['18:50', '19:35'],
  ['19:40', '20:25'],
  ['20:30', '21:15'],
  ['21:20', '22:05'],
  ['22:10', '22:55'],
];

void applyCalendarConfig(
  String rawConfig,
  Semester semester,
  Map<DateTime, String> specialDates, {
  required String context,
}) {
  final config = decodeAndValidateCalendarConfig(rawConfig, context: context);
  semester.addZjuCalendar(config);

  void addDates(Object? raw, String suffix) {
    final entries = asStringMap(raw);
    if (entries == null) return;
    for (final entry in entries.entries) {
      final date = asDateTime(entry.key);
      final name = asString(entry.value);
      if (date == null || name == null) {
        debugPrint('$context：跳过异常日期 ${entry.key}=${entry.value}');
        continue;
      }
      specialDates[date] = '$name$suffix';
    }
  }

  addDates(config['holiday'], '放假');
  addDates(config['dummy'], '放假');

  final exchanges = asStringMap(config['exchange']);
  if (exchanges == null) return;
  for (final entry in exchanges.entries) {
    final key = entry.key;
    if (key.length < 16) {
      debugPrint('$context：跳过异常调休键 $key');
      continue;
    }
    final holiday = asDateTime(key.substring(0, 8));
    final workday = asDateTime(key.substring(8, 16));
    final name = asString(entry.value);
    if (holiday == null || workday == null || name == null) {
      debugPrint('$context：跳过异常调休 $key=${entry.value}');
      continue;
    }
    specialDates[holiday] = '$name放假·调 ${workday.month} 月 ${workday.day} 日';
    specialDates[workday] = '$name调休·调 ${holiday.month} 月 ${holiday.day} 日';
  }
}
