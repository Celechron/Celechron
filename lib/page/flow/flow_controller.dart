import 'dart:async';
import 'package:get/get.dart';
import 'package:celechron/algorithm/arrange.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/deadline.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/user.dart';
import 'package:celechron/utils/utils.dart';

class FlowController extends GetxController {
  final user = Get.find<Rx<User>>(tag: 'user');
  final flowList = Get.find<RxList<Period>>(tag: 'flowList');
  final flowListLastUpdate = Get.find<Rx<DateTime>>(tag: 'flowListLastUpdate');
  final deadlineList = Get.find<RxList<Deadline>>(tag: 'deadlineList');
  final deadlineListLastUpdate =
      Get.find<Rx<DateTime>>(tag: 'deadlineListLastUpdate');
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  late var _basePeriodList = user.value.periods;
  var _currentBasePeriodCursor = -1;
  var timeNow = DateTime.now().obs;

  bool get isDuringFlow => flowList.first.startTime.isBefore(DateTime.now());

  @override
  void onInit() {
    refreshFlowList();
    Timer.periodic(const Duration(seconds: 1), (Timer t) {
      timeNow.value = DateTime.now();
      refreshFlowList();
    });
    _basePeriodList.sort((a, b) => a.startTime.compareTo(b.startTime));
    _currentBasePeriodCursor = _basePeriodList
        .indexWhere((element) => element.startTime.isAfter(DateTime.now()));
    ever(user, (callback) => refreshBasePeriodList());
    super.onInit();
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

  void removeFlowInFlowList() {
    flowList.removeWhere((element) => element.type == PeriodType.flow);
  }

  int updateFlowList(DateTime startsAt) {
    Duration workTime = _db.getWorkTime();
    Duration restTime = _db.getRestTime();

    List<Deadline> deadlines = [];
    DateTime lastDeadlineEndsAt = startsAt;
    for (var x in deadlineList) {
      if (x.deadlineType == DeadlineType.normal) {
        if (x.deadlineStatus == DeadlineStatus.running) {
          if (x.endTime.isBefore(startsAt)) {
            return -1;
          } else {
            deadlines.add(x.copyWith());
            if (x.endTime.isAfter(lastDeadlineEndsAt)) {
              lastDeadlineEndsAt = x.endTime;
            }
          }
        }
      }
    }
    flowList.clear();
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

    List<Period> blockedPeriod = <Period>[];
    for (var x in deadlineList) {
      if (x.deadlineType == DeadlineType.fixed && x.blockArrangements) {
        DateTime date = DateTime(startsAt.year, startsAt.month, startsAt.day);
        while (!date.isAfter(dateOnly(lastDeadlineEndsAt))) {
          List<Period> periods = x.getPeriodOfDay(date);
          for (var p in periods) {
            DateTime tmpl = p.startTime;
            DateTime tmpr = p.endTime;
            if (tmpr.isAfter(lastDeadlineEndsAt)) tmpr = lastDeadlineEndsAt;
            if (tmpl.isBefore(startsAt)) tmpl = startsAt;
            tmpl = tmpl.copyWith();
            tmpr = tmpr.copyWith();

            mappedList.add(tmpl);
            mappedList.add(tmpr);
            blockedPeriod.add(Period(startTime: tmpl, endTime: tmpr));
          }
          date = date.add(const Duration(days: 1));
        }
      }
    }

    for (var x in _basePeriodList) {
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

    for (var p in blockedPeriod) {
      int indexl = atListIndex[p.startTime]!;
      int indexr = atListIndex[p.endTime]!;
      for (int i = indexl; i < indexr; i++) {
        useAble[i] = false;
      }
    }

    for (var x in _basePeriodList) {
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

    for (int i = 0, j = 0; i < mappedList.length; i++) {
      if (!useAble[i]) continue;
      j = i;
      while (j + 1 < mappedList.length && useAble[j]) {
        j++;
      }
      Period period = Period(
        type: PeriodType.virtual,
        startTime: mappedList[i],
        endTime: mappedList[j],
      );
      period.genUid();
      if (period.endTime.difference(period.startTime) > restTime) {
        ableList.add(period);
      }
      i = j;
    }

    TimeAssignSet ans =
        getTimeAssignSet(workTime, restTime, deadlines, ableList);
    if (!ans.isValid) return -1;
    flowList.addAll(ans.assignSet);
    flowList.sort((a, b) {
      return a.startTime.compareTo(b.startTime);
    });
    updateDeadlineListTime();
    flowList.refresh();
    _currentBasePeriodCursor =
        _basePeriodList.indexWhere((e) => e.startTime.isAfter(DateTime.now()));
    refreshFlowList();
    return ans.restTime.inMinutes;
  }

  void refreshFlowList() {
    refreshBasePeriodList();

    Map<String, Deadline> existingUid = {};
    for (var x in deadlineList) {
      if (x.deadlineType == DeadlineType.normal) {
        existingUid[x.uid] = x;
      }
    }

    for (var i = 0; i < flowList.length; i++) {
      if (flowList[i].type == PeriodType.user) {
        flowList.removeAt(i);
        i--;
        continue;
      }

      if (flowList[i].type == PeriodType.flow) {
        if (!existingUid.containsKey(flowList[i].fromUid)) {
          flowList.removeAt(i);
          i--;
        } else {
          flowList[i].summary = existingUid[flowList[i].fromUid]!.summary;
          flowList[i].location = existingUid[flowList[i].fromUid]!.location;
          flowList[i].description =
              existingUid[flowList[i].fromUid]!.description;
        }
      }
    }

    flowList.sort((a, b) {
      return a.startTime.compareTo(b.startTime);
    });

    for (var i = 0; i < flowList.length; i++) {
      if (flowList[i].startTime.isAfter(DateTime.now())) {
        break;
      }
      if (flowList[i].type == PeriodType.flow) {
        Duration prevProgress =
            (flowList[i].lastUpdateTime ?? flowList[i].startTime)
                .difference(flowList[i].startTime);
        flowList[i].lastUpdateTime = DateTime.now();
        Duration currProgress =
            flowList[i].lastUpdateTime!.difference(flowList[i].startTime);
        Duration length = flowList[i].endTime.difference(flowList[i].startTime);

        if (currProgress <= Duration.zero) break;
        if (currProgress > length) currProgress = length;

        for (var deadline in deadlineList) {
          if (deadline.uid != flowList[i].fromUid) continue;
          deadline.updateTimeSpent(
              deadline.timeSpent - prevProgress + currProgress);
        }
        deadlineList.refresh();
        flowList.refresh();
      }
      if (flowList[i].endTime.isBefore(DateTime.now())) {
        flowList.removeAt(i);
        i--;
        flowList.refresh();
        deadlineList.refresh();
      }
    }

    if (flowList.length <= 5 && _currentBasePeriodCursor != -1) {
      for (var i = 0;
          i < 5 && i + _currentBasePeriodCursor < _basePeriodList.length;
          i++) {
        if (!flowList.any((e) =>
                e.uid == _basePeriodList[i + _currentBasePeriodCursor].uid) &&
            _basePeriodList[i + _currentBasePeriodCursor]
                    .endTime
                    .difference(DateTime.now())
                    .inMinutes <
                2880) {
          flowList
              .add(_basePeriodList[i + _currentBasePeriodCursor].copyWith());
        }
      }
    }

    for (var x in deadlineList) {
      if (x.deadlineType == DeadlineType.fixed) {
        DateTime time = DateTime.now();
        // ignore: avoid_init_to_null
        DateTime? last = null;
        for (int i = 0; i < 5; i++) {
          Period? period = x.deadlineOfTime(time, predicting: true);
          if (period != null) {
            if (last == null || last.compareTo(period.startTime) != 0) {
              flowList.add(period);
              last = period.startTime.copyWith();
            }
          }
          time = time.add(const Duration(days: 1));
        }
      }
    }
    flowList.sort((a, b) {
      return a.startTime.compareTo(b.startTime);
    });

    saveToDb();
  }

  void refreshBasePeriodList() {
    _basePeriodList = user.value.periods;
    _basePeriodList.sort((a, b) {
      return a.startTime.compareTo(b.startTime);
    });
    _currentBasePeriodCursor =
        _basePeriodList.indexWhere((e) => e.startTime.isAfter(DateTime.now()));
  }
}
