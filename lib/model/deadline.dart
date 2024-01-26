import 'package:celechron/model/period.dart';
import 'package:celechron/utils/utils.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import 'package:quiver/time.dart';

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
class Deadline {
  @HiveField(0)
  String uid;
  @HiveField(1)
  DeadlineStatus deadlineStatus;
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
  DeadlineType deadlineType;
  @HiveField(10)
  DateTime startTime;
  @HiveField(11)
  DeadlineRepeatType deadlineRepeatType;
  @HiveField(12)
  int deadlineRepeatPeriod; // 固定日程重复的周期（单位为天）。
  @HiveField(13)
  DateTime deadlineRepeatEndsTime; // 固定日程重复的截止日期（没有时间）。晚于这个日期的话就不再重复。
  @HiveField(14)
  bool blockArrangements;
  @HiveField(15)
  String? fromUid;

  Deadline({
    this.uid = '114514',
    this.deadlineStatus = DeadlineStatus.running,
    this.description = "1. 到变隐龙商店购买一个苹果\n2. 把苹果存到袋兽阿姨仓库里",
    this.timeSpent = const Duration(minutes: 0),
    this.timeNeeded = const Duration(days: 0, hours: 2, minutes: 30),
    required this.endTime,
    this.location = "宝藏镇",
    this.summary = "作业：不可思议迷宫导论",
    this.isBreakable = false,
    this.deadlineType = DeadlineType.normal,
    required this.startTime,
    this.deadlineRepeatType = DeadlineRepeatType.norepeat,
    this.deadlineRepeatPeriod = 1,
    required this.deadlineRepeatEndsTime,
    this.blockArrangements = true,
    this.fromUid,
  });

  void reset() {
    genUid();
    deadlineStatus = DeadlineStatus.deleted;
    description = "";
    timeSpent = const Duration(minutes: 0);
    timeNeeded = const Duration(hours: 1);
    endTime = DateTime.now();
    endTime = DateTime(
        endTime.year, endTime.month, endTime.day, endTime.hour, endTime.minute);
    location = "";
    summary = "";
    isBreakable = true;

    deadlineType = DeadlineType.normal;
    startTime = endTime;
    deadlineRepeatType = DeadlineRepeatType.norepeat;
    deadlineRepeatPeriod = 1;
    deadlineRepeatEndsTime =
        DateTime(startTime.year, startTime.month, startTime.day);
    blockArrangements = true;
    fromUid = null;
  }

  void copy(Deadline another) {
    uid = another.uid;
    deadlineStatus = another.deadlineStatus;
    description = another.description;
    timeSpent = another.timeSpent;
    timeNeeded = another.timeNeeded;
    endTime = another.endTime;
    location = another.location;
    summary = another.summary;
    isBreakable = another.isBreakable;
    deadlineType = another.deadlineType;
    startTime = another.startTime;
    deadlineRepeatType = another.deadlineRepeatType;
    deadlineRepeatPeriod = another.deadlineRepeatPeriod;
    deadlineRepeatEndsTime = another.deadlineRepeatEndsTime;
    blockArrangements = another.blockArrangements;
    fromUid = another.fromUid;
  }

  Deadline copyWith({
    String? uid,
    DeadlineStatus? deadlineStatus,
    String? description,
    Duration? timeSpent,
    Duration? timeNeeded,
    DateTime? endTime,
    String? location,
    String? summary,
    bool? isBreakable,
    DeadlineType? deadlineType,
    DateTime? startTime,
    DeadlineRepeatType? deadlineRepeatType,
    int? deadlineRepeatPeriod,
    DateTime? deadlineRepeatEndsTime,
    bool? blockArrangements,
    String? fromUid,
  }) {
    return Deadline(
      uid: uid ?? this.uid,
      deadlineStatus: deadlineStatus ?? this.deadlineStatus,
      description: description ?? this.description,
      timeSpent: timeSpent ?? this.timeSpent,
      timeNeeded: timeNeeded ?? this.timeNeeded,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      summary: summary ?? this.summary,
      isBreakable: isBreakable ?? this.isBreakable,
      deadlineType: deadlineType ?? this.deadlineType,
      startTime: startTime ?? this.startTime,
      deadlineRepeatType: deadlineRepeatType ?? this.deadlineRepeatType,
      deadlineRepeatPeriod: deadlineRepeatPeriod ?? this.deadlineRepeatPeriod,
      deadlineRepeatEndsTime:
          deadlineRepeatEndsTime ?? this.deadlineRepeatEndsTime,
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
    if (deadlineType == DeadlineType.fixed) {
      if (DateTime.now().isBefore(startTime)) {
        progress = 0;
      } else if (DateTime.now().isAfter(endTime)) {
        progress = 1;
      } else {
        progress = (DateTime.now().difference(startTime).inSeconds) /
            (endTime.difference(startTime).inSeconds);
      }
    } else if (deadlineType == DeadlineType.normal) {
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
    if (deadlineType != DeadlineType.normal) {
      return;
    }
    timeSpent = length;
    if (timeSpent > timeNeeded) {
      timeSpent = timeNeeded;
    }
    refreshStatus();
  }

  void refreshStatus() {
    if (deadlineType == DeadlineType.normal) {
      if (timeSpent >= timeNeeded) {
        deadlineStatus = DeadlineStatus.completed;
      } else if (endTime.isBefore(DateTime.now())) {
        deadlineStatus = DeadlineStatus.failed;
      }
    } else if (deadlineType == DeadlineType.fixed) {
      if (dateOnly(startTime).isAfter(deadlineRepeatEndsTime)) {
        deadlineStatus = DeadlineStatus.outdated;
      } else {
        deadlineStatus = DeadlineStatus.running;
      }
    }
  }

  void forceRefreshStatus() {
    if (deadlineType == DeadlineType.normal) {
      if (timeSpent >= timeNeeded) {
        deadlineStatus = DeadlineStatus.completed;
      } else if (endTime.isBefore(DateTime.now())) {
        deadlineStatus = DeadlineStatus.failed;
      } else {
        deadlineStatus = DeadlineStatus.running;
      }
    } else if (deadlineType == DeadlineType.fixed) {
      if (dateOnly(startTime).isAfter(deadlineRepeatEndsTime)) {
        deadlineStatus = DeadlineStatus.outdated;
      } else {
        deadlineStatus = DeadlineStatus.running;
      }
    }
  }

  bool setToNextPeriod() {
    if (deadlineType != DeadlineType.fixed ||
        deadlineStatus == DeadlineStatus.outdated) {
      return false;
    }
    if (deadlineRepeatType == DeadlineRepeatType.norepeat) {
      deadlineStatus = DeadlineStatus.outdated;
      return false;
    } else if (deadlineRepeatType == DeadlineRepeatType.days) {
      if (deadlineRepeatPeriod < 1) {
        deadlineRepeatPeriod = 1;
      }
      startTime = startTime.add(Duration(days: deadlineRepeatPeriod));
      endTime = endTime.add(Duration(days: deadlineRepeatPeriod));
    } else if (deadlineRepeatType == DeadlineRepeatType.month) {
      DateTime nex = DateTime(startTime.year, startTime.month + 1, 1);
      while (daysInMonth(nex.year, nex.month) < startTime.day) {
        nex = DateTime(nex.year, nex.month + 1, 1);
      }
      nex = DateTime(nex.year, nex.month, startTime.day);
      int difference = nex.difference(startTime).inDays;
      startTime = startTime.add(Duration(days: difference));
      endTime = endTime.add(Duration(days: difference));
    } else if (deadlineRepeatType == DeadlineRepeatType.year) {
      DateTime nex = DateTime(startTime.year + 1, startTime.month, 1);
      while (daysInMonth(nex.year, nex.month) < startTime.day) {
        nex = DateTime(nex.year + 1, nex.month, 1);
      }
      nex = DateTime(nex.year, startTime.month, startTime.day);
      int difference = nex.difference(startTime).inDays;
      startTime = startTime.add(Duration(days: difference));
      endTime = endTime.add(Duration(days: difference));
    }
    if (dateOnly(startTime).isAfter(dateOnly(deadlineRepeatEndsTime))) {
      deadlineStatus = DeadlineStatus.outdated;
    }
    return true;
  }

  Period? deadlineOfTime(DateTime dateTime, {bool predicting = false}) {
    if (deadlineType != DeadlineType.fixed) {
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

    if (dateTime.isBefore(startTime)) {
      if (predicting) {
        return period.copyWith(
          startTime: startTime.copyWith(),
          endTime: endTime.copyWith(),
        );
      }
      return null;
    }

    if (deadlineRepeatType == DeadlineRepeatType.norepeat) {
      if ((predicting || !startTime.isAfter(dateTime)) &&
          !endTime.isBefore(dateTime)) {
        return period.copyWith(
          startTime: startTime.copyWith(),
          endTime: endTime.copyWith(),
        );
      }
      return null;
    } else {
      Deadline dummy = copyWith();
      while ((predicting || !dummy.startTime.isAfter(dateTime)) &&
          dummy.deadlineStatus != DeadlineStatus.outdated) {
        if (!dummy.endTime.isBefore(dateTime)) {
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
    if (deadlineType != DeadlineType.fixed &&
        deadlineType != DeadlineType.fixedlegacy) {
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
      fromFromUid: deadlineType == DeadlineType.fixed ? null : fromUid,
    );
    List<Period> ans = <Period>[];

    DateTimePair? pair;
    if (deadlineRepeatType == DeadlineRepeatType.norepeat) {
      pair = chopDatePeriod(startTime, endTime, date);
      if (pair != null) {
        ans.add(period.copyWith(
          startTime: pair.first,
          endTime: pair.second,
        ));
      }
    } else {
      Deadline dummy = copyWith();
      while (!dateOnly(dummy.startTime).isAfter(date) &&
          dummy.deadlineStatus != DeadlineStatus.outdated) {
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

  bool differentForFlow(Deadline another) {
    if (deadlineType != another.deadlineType ||
        timeSpent != another.timeSpent ||
        timeNeeded != another.timeNeeded ||
        (deadlineType == DeadlineType.fixed && endTime != another.endTime) ||
        endTime != another.endTime ||
        deadlineStatus != another.deadlineStatus ||
        isBreakable != another.isBreakable ||
        deadlineRepeatType != another.deadlineRepeatType ||
        deadlineRepeatPeriod != another.deadlineRepeatPeriod ||
        deadlineRepeatEndsTime != another.deadlineRepeatEndsTime ||
        (deadlineType == DeadlineType.fixed &&
            blockArrangements != another.blockArrangements)) {
      return true;
    }
    return false;
  }
}
