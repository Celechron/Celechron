import 'package:celechron/utils/utils.dart';

class TimeHelper {
  static List<DateTime> parseExamDateTime(String datetimeStr) {
    // Input format: 2021年01月22日(08:00-10:00)
    String date, timeBegin, timeEnd;
    if (datetimeStr.contains("年") ?? false) {
      date =
          '${datetimeStr.substring(0, 4)}${datetimeStr.substring(5, 7)}${datetimeStr.substring(8, 10)}T';
      timeBegin = datetimeStr.substring(12, 17);
      timeEnd = datetimeStr.substring(18, 23);
    } else {
      // 校历未出时zdbk不会有具体日期 使用1970代替
      var datePat = RegExp("第(\\d+)天\\((.+)-(.+)\\)").firstMatch(datetimeStr);
      date = '197001${datePat?.group(1)?.padLeft(2, '0') ?? "14"}T';
      timeBegin = datePat?.group(2) ?? "05:14";
      timeEnd = datePat?.group(3) ?? "07:14";
    }
    return [DateTime.parse(date + timeBegin), DateTime.parse(date + timeEnd)];
  }

  static String chineseDateTime(DateTime dateTime) {
    if (dateTime.year == 1970) {
      return '考试周第 ${dateTime.day} 天 ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return '${dateTime.year} 年 ${dateTime.month} 月 ${dateTime.day} 日 ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static String chineseDate(DateTime date) {
    if (date.year == 1970) {
      return '考试周第 ${date.day} 天';
    }
    return '${date.year} 年 ${date.month} 月 ${date.day} 日';
  }

  static String chineseTime(DateTime begin, DateTime end) {
    return '${chineseDateTime(begin)} - ${end.hour}:${end.minute.toString().padLeft(2, '0')}';
  }

  static String chineseDay(DateTime date) {
    if (date.year == 1970) {
      return '考试周第 ${date.day} 天 ';
    }
    return '${date.month} 月 ${date.day} 日 ';
  }

  static String toHM(Duration duration) {
    var hours = duration.inHours;
    var minutes = duration.inMinutes - hours * 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  static String toHMS(Duration duration) {
    var hours = duration.inHours;
    var minutes = duration.inMinutes - hours * 60;
    var seconds = duration.inSeconds - hours * 3600 - minutes * 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String chineseDayAfterRelation(DateTime now, DateTime nex) {
    now = dateOnly(now);
    nex = dateOnly(nex);
    int diff = nex.difference(now).inDays;
    if (diff < 0) {
      return '${-diff} 天前 ';
    } else if (diff == 0) {
      return '';
    } else if (diff == 1) {
      return '次日 ';
    } else {
      return '$diff 天后 ';
    }
  }

  static String chineseDayRelation(DateTime date) {
    var day = date.copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    var today = DateTime.now().copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    var diff = day.difference(today).inDays;
    if (diff == 0) {
      return '';
    } else if (diff == 1) {
      return '明天 ';
    } else if (diff == 2) {
      return '后天 ';
    } else if (diff == -1) {
      return '昨天 ';
    } else if (diff == -2) {
      return '前天 ';
    } else {
      return chineseDay(date);
    }
  }
}
