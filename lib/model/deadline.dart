import 'package:celechron/model/period.dart';
import 'package:celechron/utils/utils.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

DateTime dateOnly(DateTime date, {int? hour, int? minute}) {
  return DateTime(date.year, date.month, date.day, hour ?? 0, minute ?? 0);
}

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
  DateTime r = dateOnly(date, hour: 23, minute: 59);
  if (isSameDay(date, startDate)) {
    l = dateOnly(date, hour: startTime.hour, minute: startTime.minute);
  }
  if (isSameDay(date, endDate)) {
    r = dateOnly(date, hour: endTime.hour, minute: endTime.minute);
  }
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
  });

  void reset() {
    genUid();
    deadlineStatus = DeadlineStatus.deleted;
    description = "";
    timeSpent = const Duration(minutes: 0);
    timeNeeded = const Duration(hours: 1);
    endTime = DateTime.now().add(const Duration(days: 1));
    endTime = DateTime(endTime.year, endTime.month, endTime.day, 23, 59);
    location = "";
    summary = "";
    isBreakable = true;

    deadlineType = DeadlineType.normal;
    startTime = DateTime.now();
    startTime = DateTime(startTime.year, startTime.month, startTime.day,
        startTime.hashCode, startTime.minute);
    deadlineRepeatType = DeadlineRepeatType.norepeat;
    deadlineRepeatPeriod = 1;
    deadlineRepeatEndsTime =
        DateTime(startTime.year, startTime.month, startTime.day);
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
    );
  }

  void genUid() {
    uid = const Uuid().v4();
  }

  double getProgress() {
    return 100.00 * timeSpent.inMicroseconds / timeNeeded.inMicroseconds;
  }

  void updateTimeSpent(Duration length) {
    timeSpent = length;
    if (timeSpent > timeNeeded) {
      timeSpent = timeNeeded;
    }
    refreshType();
  }

  void refreshType() {
    if (timeSpent >= timeNeeded) {
      deadlineStatus = DeadlineStatus.completed;
    } else if (endTime.isBefore(DateTime.now())) {
      deadlineStatus = DeadlineStatus.failed;
    }
  }

  void forceRefreshType() {
    if (timeSpent >= timeNeeded) {
      deadlineStatus = DeadlineStatus.completed;
    } else if (endTime.isBefore(DateTime.now())) {
      deadlineStatus = DeadlineStatus.failed;
    } else {
      deadlineStatus = DeadlineStatus.running;
    }
  }

  Period? getPeriodOfDay(DateTime date) {
    if (deadlineType != DeadlineType.fixed) {
      return null;
    }

    date = dateOnly(date);
    DateTime startDate = dateOnly(startTime);
    if (date.isBefore(startDate)) {
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

    DateTimePair? pair;
    if (deadlineRepeatType == DeadlineRepeatType.norepeat) {
      pair = chopDatePeriod(startTime, endTime, date);
    } else if (deadlineRepeatType == DeadlineRepeatType.days) {
      if (deadlineRepeatPeriod <= 0) {
        return null;
      }
      int difference = date.difference(startDate).inDays;
      if (difference % deadlineRepeatPeriod != 0) {
        return null;
      }
      DateTime thatStartTime = startTime.add(Duration(days: difference));
      DateTime thatEndTime = endTime.add(Duration(days: difference));
      pair = chopDatePeriod(thatStartTime, thatEndTime, date);
    } else if (deadlineRepeatType == DeadlineRepeatType.month) {
      if (date.day != startTime.day) {
        return null;
      }
      int difference = date.difference(startDate).inDays;
      DateTime thatStartTime = startTime.add(Duration(days: difference));
      DateTime thatEndTime = endTime.add(Duration(days: difference));
      pair = chopDatePeriod(thatStartTime, thatEndTime, date);
    } else if (deadlineRepeatType == DeadlineRepeatType.year) {
      if (date.day != startTime.day || date.month != startTime.month) {
        return null;
      }
      int difference = date.difference(startDate).inDays;
      DateTime thatStartTime = startTime.add(Duration(days: difference));
      DateTime thatEndTime = endTime.add(Duration(days: difference));
      pair = chopDatePeriod(thatStartTime, thatEndTime, date);
    }

    if (pair == null) {
      return null;
    }
    period.startTime = pair.first;
    period.endTime = pair.second;

    return period;
  }
}
