enum PeriodType { classes, test, user, virtual, flow }

enum DeadlineType { normal, fixed, fixedlegacy }

enum DeadlineStatus { running, suspended, completed, failed, deleted, outdated }

enum DeadlineRepeatType { norepeat, days, month, year }

const Map<DeadlineType, String> deadlineTypeName = {
  DeadlineType.normal: 'DDL',
  DeadlineType.fixed: '日程',
  DeadlineType.fixedlegacy: '过去日程',
};

const Map<DeadlineStatus, String> deadlineStatusName = {
  DeadlineStatus.running: '进行中',
  DeadlineStatus.suspended: '已暂停',
  DeadlineStatus.completed: '完成',
  DeadlineStatus.failed: '已过期', // DDL 失败
  DeadlineStatus.deleted: '已删除',
  DeadlineStatus.outdated: '已过期',
};

const Map<DeadlineRepeatType, String> deadlineRepeatTypeName = {
  DeadlineRepeatType.norepeat: '不重复',
  DeadlineRepeatType.days: '每隔几天',
  DeadlineRepeatType.month: '每月的这一天',
  DeadlineRepeatType.year: '每年的这一天',
};

DateTime dateOnly(DateTime date, {int? hour, int? minute}) {
  return DateTime(date.year, date.month, date.day, hour ?? 0, minute ?? 0);
}

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
