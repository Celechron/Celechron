import 'dart:async';
import 'package:get/get.dart';
import '../../algorithm/arrange.dart';
import '../../database/database_helper.dart';
import '../../model/deadline.dart';
import '../../model/period.dart';
import '../../model/user.dart';
import '../../utils/utils.dart';

class FlowController extends GetxController {
  final flowList = Get.find<RxList<Period>>(tag: 'flowList');
  final flowListLastUpdate = Get.find<Rx<DateTime>>(tag: 'flowListLastUpdate');
  final deadlineList = Get.find<RxList<Deadline>>(tag: 'deadlineList');
  final deadlineListLastUpdate = Get.find<Rx<DateTime>>(tag: 'deadlineListLastUpdate');
  final _db = Get.find<DatabaseHelper>(tag: 'db');

  @override
  void onInit() {
    Timer.periodic(const Duration(seconds: 1), (Timer t) {
      refreshFlowList();
    });
    super.onInit();
  }

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  Future<void> saveToDb() async {
    await _db.setFlowList(flowList);
    await _db.setFlowListUpdateTime(flowListLastUpdate.value);
  }

  void loadFlowListLastUpdate() {
    flowListLastUpdate.value = _db.getFlowListUpdateTime();
  }

  bool isFlowListOutdated() {
    return flowListLastUpdate.value.isBefore(deadlineListLastUpdate.value);
  }

  void updateDeadlineListTime() {
    flowListLastUpdate.value = deadlineListLastUpdate.value.copyWith();
  }

  int updateFlowList(DateTime startsAt) {
    var basePeriodList = Get.find<Rx<User>>(tag: 'user').value.coursePeriods;
    flowList.clear();
    print('updateFlowList');
    Duration workTime = _db.getWorkTime();
    Duration restTime = _db.getRestTime();

    List<Deadline> deadlines = [];
    DateTime lastDeadlineEndsAt = startsAt;
    for (var x in deadlineList) {
      if (x.deadlineType == DeadlineType.running && x.endTime.isAfter(startsAt)) {
        deadlines.add(x.copyWith());
        if (x.endTime.isAfter(lastDeadlineEndsAt)) {
          lastDeadlineEndsAt = x.endTime;
        }
      }
    }
    if (lastDeadlineEndsAt.difference(startsAt) < const Duration(days: 1)) {
      lastDeadlineEndsAt = startsAt.add(const Duration(days: 1));
    }

    List<DateTime> mappedList = [];

    mappedList.add(startsAt);
    mappedList.add(lastDeadlineEndsAt);

    Map allowTime = _db.getAllowTime();
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
        if (tmpr.isBefore(tmpl)) tmpr.add(const Duration(days: 1));

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
    for (var x in deadlines) {
      mappedList.add(x.endTime.copyWith());
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
        if (tmpr.isBefore(tmpl)) tmpr.add(const Duration(days: 1));

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

      flowList.add(x.copyWith());

      int indexl = atListIndex[tmpl]!;
      int indexr = atListIndex[tmpr]!;
      for (int i = indexl; i < indexr; i++) {
        useAble[i] = false;
      }
    }

    List<Period> ableList = [];

    print('ableList:');
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
      print(period.startTime);
      print(period.endTime);
      period.genUid();
      if (period.endTime.difference(period.startTime) >
          const Duration(minutes: 25)) {
        ableList.add(period);
      }
      i = j;
    }

    print('updateFlowList: calc');
    TimeAssignSet ans = getTimeAssignSet(workTime, restTime, deadlines, ableList);
    print(ans.isValid);
    if (!ans.isValid) return -1;
    flowList.addAll(ans.assignSet);
    flowList.sort((a, b) {
      return a.startTime.compareTo(b.startTime);
    });
    updateDeadlineListTime();
    flowList.refresh();
    return ans.restTime.inMinutes;
  }

  void refreshFlowList() {
    while (flowList.isNotEmpty) {
      if (flowList[0].periodType == PeriodType.flow) {
        DateTime now =
        DateTime.now().copyWith(second: 0, millisecond: 0, microsecond: 0);
        Duration distan = now.difference(flowList[0].startTime);
        Duration length = flowList[0].endTime.difference(flowList[0].startTime);
        print(distan);
        if (distan <= Duration.zero) break;
        if (distan > length) distan = length;

        flowList[0].startTime = flowList[0].startTime.add(distan);
        for (var deadline in deadlineList) {
          if (deadline.uid != flowList[0].fromUid) continue;
          deadline.addTimeSpent(distan);
        }
        flowList.refresh();
      }
      if (!flowList[0].endTime.isAfter(DateTime.now())) {
        flowList.removeAt(0);
        flowList.refresh();
      } else {
        break;
      }
    }
    saveToDb();
    //print('FlowPage: refreshed');
  }

}
