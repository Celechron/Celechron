import '../utils/utils.dart';
import 'period.dart';
import 'deadline.dart';
import '../database/database_helper.dart';
import '../algorithm/arrange.dart';

List<Period> flowList = [];

bool updateFlowList(DateTime startsAt) {
  Duration workTime = db.getWorkTime();
  Duration restTime = db.getRestTime();

  List<Deadline> deadlines = [];
  DateTime lastDeadlineEndsAt = startsAt;
  for (var x in deadlineList) {
    if (x.deadlineType == DeadlineType.running &&
        x.endTime.isAfter(lastDeadlineEndsAt)) {
      lastDeadlineEndsAt = x.endTime;
      deadlines.add(x.copyWith());
    }
  }

  List<DateTime> mappedList = [];

  Map allowTime = db.getAllowTime();
  allowTime.forEach((allowStart, allowEnd) {
    for (int i = 0;; i++) {
      DateTime tmpl = allowStart;
      tmpl = tmpl.copyWith(
          year: startsAt.year, month: startsAt.month, day: startsAt.day);
      tmpl = tmpl.add(Duration(days: i));

      DateTime tmpr = allowEnd;
      tmpr = tmpr.copyWith(
          year: startsAt.year, month: startsAt.month, day: startsAt.day);
      tmpr = tmpr.add(Duration(days: i));
      if (tmpr.isBefore(tmpl)) tmpr.add(Duration(days: 1));

      if (tmpr.isBefore(startsAt)) continue;
      if (!tmpl.isBefore(lastDeadlineEndsAt)) break;
      if (tmpr.isAfter(lastDeadlineEndsAt)) tmpr = lastDeadlineEndsAt;
      if (tmpl.isBefore(startsAt)) tmpl = startsAt;

      mappedList.add(tmpl);
      mappedList.add(tmpr);
    }
  });
  for (var x in basePeriodList) {
    if (!x.startTime.isAfter(lastDeadlineEndsAt)) {
      mappedList.add(x.startTime.copyWith());
    }
    if (!x.endTime.isBefore(startsAt)) {
      mappedList.add(x.endTime.copyWith());
    }
  }
  for (var x in deadlineList) {
    if (x.deadlineType == DeadlineType.running && x.endTime.isAfter(startsAt)) {
      mappedList.add(x.endTime.copyWith());
    }
  }

  mappedList = mappedList.toSet().toList();
  Map<DateTime, int> atListIndex = {};
  for (int i = 0; i < mappedList.length; i++) {
    atListIndex[mappedList[i]] = i;
  }
  List<bool> useAble = List.generate(mappedList.length - 1, (index) => false);

  allowTime.forEach((allowStart, allowEnd) {
    for (int i = 0;; i++) {
      DateTime tmpl = allowStart;
      tmpl = tmpl.copyWith(
          year: startsAt.year, month: startsAt.month, day: startsAt.day);
      tmpl = tmpl.add(Duration(days: i));

      DateTime tmpr = allowEnd;
      tmpr = tmpr.copyWith(
          year: startsAt.year, month: startsAt.month, day: startsAt.day);
      tmpr = tmpr.add(Duration(days: i));
      if (tmpr.isBefore(tmpl)) tmpr.add(Duration(days: 1));

      if (tmpr.isBefore(startsAt)) continue;
      if (!tmpl.isBefore(lastDeadlineEndsAt)) break;
      if (tmpr.isAfter(lastDeadlineEndsAt)) tmpr = lastDeadlineEndsAt;
      if (tmpl.isBefore(startsAt)) tmpl = startsAt;

      int indexl = atListIndex[tmpl]!;
      int indexr = atListIndex[tmpr]!;
      for (int i = indexl; i < indexr; i++) {
        useAble[i] = true;
      }
    }
  });

  for (var x in basePeriodList) {
    DateTime tmpl = x.startTime.copyWith();
    DateTime tmpr = x.endTime.copyWith();
    if (tmpr.isAfter(lastDeadlineEndsAt)) tmpr = lastDeadlineEndsAt;
    if (tmpl.isBefore(startsAt)) tmpl = startsAt;

    int indexl = atListIndex[tmpl]!;
    int indexr = atListIndex[tmpr]!;
    for (int i = indexl; i < indexr; i++) {
      useAble[i] = false;
    }
  }

  List<Period> ableList = [];
  TimeAssignSet ans = findSolution(workTime, restTime, deadlineList, ableList);
  print(ans.isValid);
  if (!ans.isValid) return false;
  flowList = List.from(ans.assignSet);

  return true;
}
