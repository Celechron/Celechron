import '../utils/utils.dart';
import 'period.dart';
import 'deadline.dart';
import '../database/database_helper.dart';
import '../algorithm/arrange.dart';

List<Period> flowList = [];

bool updateFlowList(DateTime startsAt) {
  print('updateFlowList');
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
  print(startsAt);
  print(lastDeadlineEndsAt);

  List<DateTime> mappedList = [];

  mappedList.add(startsAt);
  mappedList.add(lastDeadlineEndsAt);

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
  mappedList.sort();
  Map<DateTime, int> atListIndex = {};
  for (int i = 0; i < mappedList.length; i++) {
    atListIndex[mappedList[i]] = i;
  }
  List<bool> useAble = List.generate(mappedList.length, (index) => false);

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

    if (!tmpl.isBefore(lastDeadlineEndsAt)) continue;
    if (!tmpr.isAfter(startsAt)) continue;
    if (tmpr.isAfter(lastDeadlineEndsAt)) tmpr = lastDeadlineEndsAt;
    if (tmpl.isBefore(startsAt)) tmpl = startsAt;

    int indexl = atListIndex[tmpl]!;
    int indexr = atListIndex[tmpr]!;
    for (int i = indexl; i < indexr; i++) {
      useAble[i] = false;
    }
  }

  print('???');
  print(mappedList[0]);
  print(mappedList[1]);
  print(mappedList[2]);
  print(useAble);

  List<Period> ableList = [];

  for (int i = 0, j = 0; i < mappedList.length; i++) {
    if (!useAble[i]) continue;
    j = i;
    while (j < mappedList.length && useAble[j]) {
      j++;
    }
    Period period = Period(
      periodType: PeriodType.virtual,
      startTime: mappedList[i],
      endTime: mappedList[j],
    );
    print('ableList:');
    print(period.startTime);
    print(period.endTime);
    period.genUid();
    ableList.add(period);
    i = j;
  }

  TimeAssignSet ans = findSolution(workTime, restTime, deadlineList, ableList);
  print('updateFlowList');
  print(ans.isValid);
  if (!ans.isValid) return false;
  print(ans.assignSet);
  flowList = List.from(ans.assignSet);

  return true;
}
