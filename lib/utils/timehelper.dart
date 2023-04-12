class TimeHelper {
  static List<DateTime> parseExamDateTime(String datetimeStr) {
    // Input format: 2021年01月22日(08:00-10:00)
    var date = '${datetimeStr.substring(0, 4)}${datetimeStr.substring(5, 7)}${datetimeStr.substring(8, 10)}T';
    var timeBegin = datetimeStr.substring(12, 17);
    var timeEnd = datetimeStr.substring(18, 23);
    return [DateTime.parse(date + timeBegin), DateTime.parse(date + timeEnd)];
  }

  static String chineseTime(DateTime begin, DateTime end) {
    var beginStr = '${begin.year}年${begin.month}月${begin.day}日 ${begin.hour}:${begin.minute.toString().padLeft(2, '0')}';
    var endStr = '${end.hour}:${end.minute.toString().padLeft(2, '0')}';
    return '$beginStr - $endStr';
  }

  static String chineseDay(DateTime date) {
    var dayStr = '${date.month}月${date.day}日';
    return dayStr;
  }
}