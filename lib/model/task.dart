import 'package:celechron/model/period.dart';
import 'package:celechron/utils/utils.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import 'package:quiver/time.dart';

enum TaskType {
  deadline, // 只有结束时间固定的《真DDL》
  fixed, // 开始和结束时间都固定的《日程》
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

class DateTimePair {
  DateTime first, second;
  DateTimePair({required this.first, required this.second});
}

DateTimePair? chopDatePeriod(
    DateTime startTime, DateTime endTime, DateTime date) {
  DateTime startDate = dateOnly(startTime);
  DateTime endDate = dateOnly(endTime);
  date = dateOnly(date);

  if (date.isBefore(startDate) || date.isAfter(endDate)) {
    return null;
  }
  DateTime l = dateOnly(date);
  DateTime r = dateOnly(date, hour: 24, minute: 00);
  if (isSameDay(date, startDate)) {
    l = dateOnly(date, hour: startTime.hour, minute: startTime.minute);
  }
  if (isSameDay(date, endDate)) {
    r = dateOnly(date, hour: endTime.hour, minute: endTime.minute);
  }
  if (l == r) return null;
  return DateTimePair(first: l, second: r);
}

@HiveType(typeId: 6)
class Task {
  @HiveField(0)
  String uid;
  @HiveField(1)
  TaskStatus status;
  @HiveField(2)
  String description;
  @HiveField(3)
  Duration timeSpent;
  @HiveField(4)
  Duration timeNeeded;
  @HiveField(5)
  DateTime endTime;
  @HiveField(6)
  String location;
  @HiveField(7)
  String summary;
  @HiveField(8)
  bool isBreakable;

  @HiveField(9)
  TaskType type;
  @HiveField(10)
  DateTime startTime;
  @HiveField(11)
  TaskRepeatType repeatType;
  @HiveField(12)
  int repeatPeriod; // 固定日程重复的周期（单位为天）。
  @HiveField(13)
  DateTime repeatEndsTime; // 固定日程重复的截止日期（没有时间）。晚于这个日期的话就不再重复。
  @HiveField(14)
  bool blockArrangements;
  @HiveField(15)
  String? fromUid;

  Task({
    this.uid = '114514',
    this.status = TaskStatus.running,
    this.description = "1. 到变隐龙商店购买一个苹果\n2. 把苹果存到袋兽阿姨仓库里",
    this.timeSpent = const Duration(minutes: 0),
    this.timeNeeded = const Duration(days: 0, hours: 2, minutes: 30),
    required this.endTime,
    this.location = "宝藏镇",
    this.summary = "作业：不可思议迷宫导论",
    this.isBreakable = false,
    this.type = TaskType.deadline,
    required this.startTime,
    this.repeatType = TaskRepeatType.norepeat,
    this.repeatPeriod = 1,
    required this.repeatEndsTime,
    this.blockArrangements = true,
    this.fromUid,
  });

  void reset() {
    genUid();
    status = TaskStatus.deleted;
    description = "";
    timeSpent = const Duration(minutes: 0);
    timeNeeded = const Duration(hours: 1);
    endTime = DateTime.now();
    endTime = DateTime(
        endTime.year, endTime.month, endTime.day, endTime.hour, endTime.minute);
    location = "";
    summary = "";
    isBreakable = true;

    type = TaskType.deadline;
    startTime = endTime;
    repeatType = TaskRepeatType.norepeat;
    repeatPeriod = 1;
    repeatEndsTime = DateTime(startTime.year, startTime.month, startTime.day);
    blockArrangements = true;
    fromUid = null;
  }

  void copy(Task another) {
    uid = another.uid;
    status = another.status;
    description = another.description;
    timeSpent = another.timeSpent;
    timeNeeded = another.timeNeeded;
    endTime = another.endTime;
    location = another.location;
    summary = another.summary;
    isBreakable = another.isBreakable;
    type = another.type;
    startTime = another.startTime;
    repeatType = another.repeatType;
    repeatPeriod = another.repeatPeriod;
    repeatEndsTime = another.repeatEndsTime;
    blockArrangements = another.blockArrangements;
    fromUid = another.fromUid;
  }

  Task copyWith({
    String? uid,
    TaskStatus? status,
    String? description,
    Duration? timeSpent,
    Duration? timeNeeded,
    DateTime? endTime,
    String? location,
    String? summary,
    bool? isBreakable,
    TaskType? type,
    DateTime? startTime,
    TaskRepeatType? repeatType,
    int? repeatPeriod,
    DateTime? repeatEndsTime,
    bool? blockArrangements,
    String? fromUid,
  }) {
    return Task(
      uid: uid ?? this.uid,
      status: status ?? this.status,
      description: description ?? this.description,
      timeSpent: timeSpent ?? this.timeSpent,
      timeNeeded: timeNeeded ?? this.timeNeeded,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      summary: summary ?? this.summary,
      isBreakable: isBreakable ?? this.isBreakable,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      repeatType: repeatType ?? this.repeatType,
      repeatPeriod: repeatPeriod ?? this.repeatPeriod,
      repeatEndsTime: repeatEndsTime ?? this.repeatEndsTime,
      blockArrangements: blockArrangements ?? this.blockArrangements,
      fromUid: fromUid ?? this.fromUid,
    );
  }

  void genUid() {
    uid = const Uuid().v4();
  }

  bool checkTimeValid() {
    startTime = DateTime(startTime.year, startTime.month, startTime.day,
        startTime.hour, startTime.minute);
    endTime = DateTime(
        endTime.year, endTime.month, endTime.day, endTime.hour, endTime.minute);
    if (!startTime.isBefore(endTime)) {
      return false;
    }
    return true;
  }

  double getProgress() {
    double progress = 0;
    if (type == TaskType.fixed) {
      if (DateTime.now().isBefore(startTime)) {
        progress = 0;
      } else if (DateTime.now().isAfter(endTime)) {
        progress = 1;
      } else {
        progress = (DateTime.now().difference(startTime).inSeconds) /
            (endTime.difference(startTime).inSeconds);
      }
    } else if (type == TaskType.deadline) {
      progress = timeSpent.inSeconds / timeNeeded.inSeconds;
    }
    if (progress > 1) {
      progress = 1;
    }
    if (progress < 0) {
      progress = 0;
    }
    return progress;
  }

  void updateTimeSpent(Duration length) {
    if (type != TaskType.deadline) {
      return;
    }
    timeSpent = length;
    if (timeSpent > timeNeeded) {
      timeSpent = timeNeeded;
    }
    refreshStatus();
  }

  void refreshStatus() {
    if (type == TaskType.deadline) {
      if (timeSpent >= timeNeeded) {
        status = TaskStatus.completed;
      } else if (status != TaskStatus.completed &&
          endTime.isBefore(DateTime.now())) {
        status = TaskStatus.failed;
      }
    } else if (type == TaskType.fixed) {
      if (dateOnly(startTime).isAfter(repeatEndsTime)) {
        status = TaskStatus.outdated;
      } else {
        status = TaskStatus.running;
      }
    }
  }

  void forceRefreshStatus() {
    if (type == TaskType.deadline) {
      if (timeSpent >= timeNeeded) {
        status = TaskStatus.completed;
      } else if (status != TaskStatus.completed &&
          endTime.isBefore(DateTime.now())) {
        status = TaskStatus.failed;
      } else {
        status = TaskStatus.running;
      }
    } else if (type == TaskType.fixed) {
      if (dateOnly(startTime).isAfter(repeatEndsTime)) {
        status = TaskStatus.outdated;
      } else {
        status = TaskStatus.running;
      }
    }
  }

  bool setToNextPeriod() {
    if (type != TaskType.fixed || status == TaskStatus.outdated) {
      return false;
    }
    if (repeatType == TaskRepeatType.norepeat) {
      status = TaskStatus.outdated;
      return false;
    } else if (repeatType == TaskRepeatType.days) {
      if (repeatPeriod < 1) {
        repeatPeriod = 1;
      }
      startTime = startTime.add(Duration(days: repeatPeriod));
      endTime = endTime.add(Duration(days: repeatPeriod));
    } else if (repeatType == TaskRepeatType.month) {
      DateTime nex = DateTime(startTime.year, startTime.month + 1, 1);
      while (daysInMonth(nex.year, nex.month) < startTime.day) {
        nex = DateTime(nex.year, nex.month + 1, 1);
      }
      nex = DateTime(nex.year, nex.month, startTime.day);
      int difference = nex.difference(startTime).inDays;
      startTime = startTime.add(Duration(days: difference));
      endTime = endTime.add(Duration(days: difference));
    } else if (repeatType == TaskRepeatType.year) {
      DateTime nex = DateTime(startTime.year + 1, startTime.month, 1);
      while (daysInMonth(nex.year, nex.month) < startTime.day) {
        nex = DateTime(nex.year + 1, nex.month, 1);
      }
      nex = DateTime(nex.year, startTime.month, startTime.day);
      int difference = nex.difference(startTime).inDays;
      startTime = startTime.add(Duration(days: difference));
      endTime = endTime.add(Duration(days: difference));
    }
    if (dateOnly(startTime).isAfter(dateOnly(repeatEndsTime))) {
      status = TaskStatus.outdated;
    }
    return true;
  }

  Period? deadlineOfTime(DateTime refTime, {bool predicting = false}) {
    if (type != TaskType.fixed) {
      return null;
    }

    Period period = Period(
      fromUid: uid,
      type: PeriodType.user,
      description: description,
      startTime: startTime,
      endTime: endTime,
      location: location,
      lastUpdateTime: DateTime.now(),
      summary: summary,
    );

    if (refTime.isBefore(startTime)) {
      if (predicting) {
        return period.copyWith(
          startTime: startTime.copyWith(),
          endTime: endTime.copyWith(),
        );
      }
      return null;
    }

    if (repeatType == TaskRepeatType.norepeat) {
      if ((predicting || !startTime.isAfter(refTime)) &&
          !endTime.isBefore(refTime)) {
        return period.copyWith(
          startTime: startTime.copyWith(),
          endTime: endTime.copyWith(),
        );
      }
      return null;
    } else {
      Task dummy = copyWith();
      while ((predicting || !dummy.startTime.isAfter(refTime)) &&
          dummy.status != TaskStatus.outdated) {
        if (!dummy.endTime.isBefore(refTime)) {
          return period.copyWith(
              startTime: dummy.startTime.copyWith(),
              endTime: dummy.endTime.copyWith());
        }
        dummy.setToNextPeriod();
      }
      return null;
    }
  }

  List<Period> getPeriodOfDay(DateTime date) {
    if (type != TaskType.fixed && type != TaskType.fixedlegacy) {
      return [];
    }

    date = dateOnly(date);
    DateTime startDate = dateOnly(startTime);
    if (date.isBefore(startDate)) {
      return [];
    }

    Period period = Period(
      fromUid: uid,
      type: PeriodType.user,
      description: description,
      startTime: startTime.copyWith(),
      endTime: endTime.copyWith(),
      location: location,
      lastUpdateTime: DateTime.now(),
      summary: summary,
      fromFromUid: type == TaskType.fixed ? null : fromUid,
    );
    List<Period> ans = <Period>[];

    DateTimePair? pair;
    if (repeatType == TaskRepeatType.norepeat) {
      pair = chopDatePeriod(startTime, endTime, date);
      if (pair != null) {
        ans.add(period.copyWith(
          startTime: pair.first,
          endTime: pair.second,
        ));
      }
    } else {
      Task dummy = copyWith();
      while (!dateOnly(dummy.startTime).isAfter(date) &&
          dummy.status != TaskStatus.outdated) {
        if (!dateOnly(dummy.endTime).isBefore(date)) {
          pair = chopDatePeriod(dummy.startTime, dummy.endTime, date);
          if (pair != null) {
            ans.add(period.copyWith(
              startTime: pair.first,
              endTime: pair.second,
            ));
          }
        }
        dummy.setToNextPeriod();
      }
    }

    return ans;
  }

  bool differentForFlow(Task another) {
    if (type != another.type ||
        timeSpent != another.timeSpent ||
        timeNeeded != another.timeNeeded ||
        (type == TaskType.fixed && endTime != another.endTime) ||
        endTime != another.endTime ||
        status != another.status ||
        isBreakable != another.isBreakable ||
        repeatType != another.repeatType ||
        repeatPeriod != another.repeatPeriod ||
        repeatEndsTime != another.repeatEndsTime ||
        (type == TaskType.fixed &&
            blockArrangements != another.blockArrangements)) {
      return true;
    }
    return false;
  }
}
