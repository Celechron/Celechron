String celechronVersion = '0.2.1 beta';

enum PeriodType { classes, test, user, virtual, flow }

enum DeadlineType { running, suspended, completed, failed, deleted }

Map<DeadlineType, String> deadlineTypeName = {
  DeadlineType.running: '进行中',
  DeadlineType.suspended: '已暂停',
  DeadlineType.completed: '完成',
  DeadlineType.failed: '失败',
  DeadlineType.deleted: '已删除',
};

String durationToString(Duration duration) {
  String str = '';
  if (duration.inHours != 0) {
    str = '${duration.inHours} 小时';
  }
  if (duration.inMinutes % 60 != 0 || duration.inHours == 0) {
    if (str != '') str = '$str ';
    str = '$str${duration.inMinutes % 60} 分钟';
  }
  return str;
}

String toStringHumanReadable(DateTime dateTime) {
  String str = dateTime.toIso8601String().replaceFirst(RegExp(r'T'), ' ');
  str = str.substring(0, str.length - 7);
  return str;
}
