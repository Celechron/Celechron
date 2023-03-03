import '../utils/utils.dart';
import 'dart:io';
import 'package:const_date_time/const_date_time.dart';

class Deadline {
  DeadlineType deadlineType;
  String description;
  Duration timeSpent;
  Duration timeNeeded;
  DateTime endTime;
  String location;
  String summary;

  Deadline(
      {this.deadlineType = DeadlineType.running,
      this.description = "1. 到变隐龙商店购买一个苹果\n2. 把苹果存到袋兽阿姨仓库里",
      this.timeSpent = const Duration(minutes: 0),
      this.timeNeeded = const Duration(days: 0, hours: 1, minutes: 30),
      this.endTime = const ConstDateTime(2023, 3, 2, 8, 00, 00, 00),
      this.location = "宝藏镇",
      this.summary = "作业：不可思议迷宫导论"});

  Deadline copyWith({
    DeadlineType? deadlineType,
    String? description,
    Duration? timeSpent,
    Duration? timeNeeded,
    DateTime? endTime,
    String? location,
    String? summary,
  }) {
    return Deadline(
      deadlineType: deadlineType ?? this.deadlineType,
      description: description ?? this.description,
      timeSpent: timeSpent ?? this.timeSpent,
      timeNeeded: timeNeeded ?? this.timeNeeded,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      summary: summary ?? this.summary,
    );
  }

  double getProgress() {
    return 100.00 * timeSpent.inMicroseconds / timeNeeded.inMicroseconds;
  }

  void forceRefreshType() {
    if (timeSpent >= timeNeeded) {
      deadlineType = DeadlineType.completed;
    } else if (endTime.isBefore(DateTime.now())) {
      deadlineType = DeadlineType.failed;
    } else {
      deadlineType = DeadlineType.running;
    }
  }
}

int compareDeadline(Deadline a, Deadline b) {
  return a.endTime.compareTo(b.endTime);
}

var deadlineList = <Deadline>[];
int __got = 0;

void updateDeadlineList() {
  print('sorted deadlineList');
  deadlineList.sort(compareDeadline);
  if (__got == 1) return;
  __got = 1;

  deadlineList.clear();

  Deadline tmp = Deadline();
  deadlineList.add(tmp);
  Deadline tmp2 = tmp.copyWith();
  tmp2.endTime = tmp2.endTime.add(const Duration(days: 1));
  tmp2.timeSpent += const Duration(minutes: 10);
  deadlineList.add(tmp2);
  Deadline tmp3 = tmp2.copyWith();
  tmp3.endTime = tmp3.endTime.add(const Duration(days: 1));
  tmp3.timeSpent += const Duration(minutes: 10);
  tmp3.deadlineType = DeadlineType.suspended;
  deadlineList.add(tmp3);
  Deadline tmp4 = tmp3.copyWith();
  tmp4.endTime = tmp4.endTime.add(const Duration(days: 1));
  tmp4.timeSpent += const Duration(minutes: 10);
  tmp4.deadlineType = DeadlineType.running;
  deadlineList.add(tmp4);
  Deadline tmp5 = tmp4.copyWith();
  tmp5.endTime = tmp5.endTime.add(const Duration(days: 1));
  tmp5.timeSpent += const Duration(minutes: 10);
  deadlineList.add(tmp5);
  Deadline tmp6 = tmp5.copyWith();
  tmp6.endTime = tmp6.endTime.add(const Duration(days: 1));
  tmp6.timeSpent = tmp6.timeNeeded;
  deadlineList.add(tmp6);

  for (var deadline in deadlineList) {
    if (deadline.timeSpent >= deadline.timeNeeded) {
      deadline.deadlineType = DeadlineType.completed;
    } else if (deadline.endTime.isBefore(DateTime.now())) {
      deadline.deadlineType = DeadlineType.failed;
    }
  }

  deadlineList.sort(compareDeadline);
  print('rebulit deadlineList');
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

String deadlineProgress(Deadline deadline) {
  return '${(deadline.getProgress()).toInt()}%：预期 ${durationToString(deadline.timeNeeded)}，还要 ${durationToString(deadline.timeNeeded <= deadline.timeSpent ? Duration.zero : (deadline.timeNeeded - deadline.timeSpent))}';
}
