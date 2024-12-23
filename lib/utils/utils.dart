import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum PeriodType {
  classes, // 课程
  test,    // 考试
  user,    // 日程
  virtual, // 虚拟的占位符
  flow,    // 用Celechron安排的（一个DDL被分解成若干个flow来完成）
}

enum TaskType {
  deadline,     // 只有结束时间固定的《真DDL》
  fixed,      // 开始和结束时间都固定的《日程》
  fixedlegacy // 已过的《日程》
}

enum TaskStatus { running, suspended, completed, failed, deleted, outdated }

enum TaskRepeatType { norepeat, days, month, year }

const Map<TaskType, String> deadlineTypeName = {
  TaskType.deadline: 'DDL',
  TaskType.fixed: '日程',
  TaskType.fixedlegacy: '过去日程',
};

const Map<TaskStatus, String> deadlineStatusName = {
  TaskStatus.running: '进行中',
  TaskStatus.suspended: '已暂停',
  TaskStatus.completed: '完成',
  TaskStatus.failed: '已过期', // DDL 失败
  TaskStatus.deleted: '已删除',
  TaskStatus.outdated: '已过期',
};

const Map<TaskRepeatType, String> deadlineRepeatTypeName = {
  TaskRepeatType.norepeat: '不重复',
  TaskRepeatType.days: '每隔几天',
  TaskRepeatType.month: '每月的这一天',
  TaskRepeatType.year: '每年的这一天',
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

const secureStorageIOSOptions = kDebugMode
    ? IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
        accountName: 'Celechron',
        groupId: 'group.top.celechron.celechron.debug')
    : IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
        accountName: 'Celechron',
        groupId: 'group.top.celechron.celechron');

enum BrightnessMode { system, light, dark }
enum GpaStrategy { best, first }
