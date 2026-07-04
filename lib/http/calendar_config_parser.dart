import 'package:celechron/http/zjuServices/response_utils.dart';
import 'package:celechron/model/semester.dart';
import 'package:flutter/foundation.dart';

void applyCalendarConfig(
  String rawConfig,
  Semester semester,
  Map<DateTime, String> specialDates, {
  required String context,
}) {
  final config = decodeJsonMap(rawConfig, context: context);
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
    specialDates[holiday] =
        '$name放假·调 ${workday.month} 月 ${workday.day} 日';
    specialDates[workday] =
        '$name调休·调 ${holiday.month} 月 ${holiday.day} 日';
  }
}
