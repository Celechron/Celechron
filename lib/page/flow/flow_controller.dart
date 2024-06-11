import 'dart:async';
import 'package:get/get.dart';
import 'package:celechron/algorithm/arrange.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/task.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/utils/utils.dart';
import 'package:celechron/pigeon/flow_messenger.dart';

class FlowController extends GetxController {
  final scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final flowList = Get.find<RxList<Period>>(tag: 'flowList');
  final flowListLastUpdate = Get.find<Rx<DateTime>>(tag: 'flowListLastUpdate');
  final taskList = Get.find<RxList<Task>>(tag: 'taskList');
  final taskListLastUpdate =
      Get.find<Rx<DateTime>>(tag: 'taskListLastUpdate');
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  late var _scholarFlowList = scholar.value.periods;
  var _currentScholarFlowCursor = -1;
  var timeNow = DateTime.now().obs;
  final _flowMessenger = FlowMessenger();

  bool get isDuringFlow => flowList.first.startTime.isBefore(DateTime.now());

  @override
  void onInit() {
    // 按表走，把应用关闭期间的事务项清理掉
    walkFlowList();
    refreshWidget();

    // 每秒刷新，不断更新当前事务的结束时间。当某个事务结束，就把它清理掉。
    Timer.periodic(const Duration(seconds: 1), (Timer t) {
      timeNow.value = DateTime.now();
      walkFlowList();
    });

    // 把基本事项给排序好，看目前在上哪节课（和排序有关系）
    _scholarFlowList.sort((a, b) => a.startTime.compareTo(b.startTime));
    _currentScholarFlowCursor = _scholarFlowList
        .indexWhere((element) => element.endTime.isAfter(DateTime.now()));

    // 当“学业”页面有更新（例如出现新课程），更新基本Flow列表
    ever(scholar, (callback) {
      refreshScholarFlowList();
      refreshWidget();
    });
    ever(taskList, (callback) {
      refreshWidget();
    });

    super.onInit();
  }

  Future<void> saveFlowListToDb() async {
    await _db.setFlowList(flowList);
    await _db.setFlowListUpdateTime(flowListLastUpdate.value);
  }

  void loadFlowListLastUpdate() {
    flowListLastUpdate.value = _db.getFlowListUpdateTime();
  }

  bool isFlowListOutdated() {
    return flowListLastUpdate.value.isBefore(taskListLastUpdate.value);
  }

  void updateDeadlineListTime() {
    flowListLastUpdate.value = taskListLastUpdate.value.copyWith();
  }

  void removeFlowInFlowList() {
    flowList.removeWhere((element) => element.type == PeriodType.flow);
  }

  // 生成新的安排
  int generateNewFlowList(DateTime startsAt) {
    Duration workTime = _db.getWorkTime();
    Duration restTime = _db.getRestTime();

    List<Task> deadlines = [];
    DateTime lastDeadlineEndsAt = startsAt;
    for (var x in taskList) {
      if (x.type == TaskType.deadline) {
        if (x.status == TaskStatus.running) {
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
    flowList.removeWhere((element) =>
        element.type == PeriodType.flow || element.type == PeriodType.classes);
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
    for (var x in taskList) {
      if (x.type == TaskType.fixed && x.blockArrangements) {
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

    for (var x in _scholarFlowList) {
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

    for (var x in _scholarFlowList) {
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
    _currentScholarFlowCursor =
        _scholarFlowList.indexWhere((e) => e.endTime.isAfter(DateTime.now()));
    walkFlowList();
    refreshWidget();
    return ans.restTime.inMinutes;
  }

  // 根据安排走，已完成的就剔除
  void walkFlowList() {
    /* 同步Task页面的DDL描述同步到Flow页面 */
    Map<String, Task> existingDeadlineUid = {};
    // 把《真DDL》记录下来（详见utils.dart）
    for (var x in taskList) {
      if (x.type == TaskType.deadline) {
        existingDeadlineUid[x.uid] = x;
      }
    }
    // 移除所有固定日程，只保留Celechron安排的DDL
    for (var i = 0; i < flowList.length; i++) {
      if (flowList[i].type == PeriodType.user ||
          flowList[i].type == PeriodType.classes ||
          flowList[i].type == PeriodType.test) {
        flowList.removeAt(i);
        i--;
        continue;
      }
      // 同步信息
      if (flowList[i].type == PeriodType.flow) {
        if (!existingDeadlineUid.containsKey(flowList[i].fromUid)) {
          flowList.removeAt(i);
          i--;
        } else {
          flowList[i].summary =
              existingDeadlineUid[flowList[i].fromUid]!.summary;
          flowList[i].location =
              existingDeadlineUid[flowList[i].fromUid]!.location;
          flowList[i].description =
              existingDeadlineUid[flowList[i].fromUid]!.description;
        }
      }
    }
    flowList.sort((a, b) {
      return a.startTime.compareTo(b.startTime);
    });

    /* 同步Flow页面的任务进度到Task页面 */
    for (var i = 0; i < flowList.length; i++) {
      if (flowList[i].startTime.isAfter(DateTime.now())) break;
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

        for (var deadline in taskList) {
          if (deadline.uid != flowList[i].fromUid) continue;
          deadline.updateTimeSpent(
              deadline.timeSpent - prevProgress + currProgress);
        }
        taskList.refresh();
        flowList.refresh();
      }
      if (flowList[i].endTime.isBefore(DateTime.now())) {
        flowList.removeAt(i);
        i--;
        flowList.refresh();
        taskList.refresh();
      }
    }

    /* 重新添加最近48h内的至多5节课程（防止Flow页面太乱）*/
    refreshScholarFlowList();
    if (_currentScholarFlowCursor != -1) {
      for (var i = 0;
          i < 6 && i + _currentScholarFlowCursor < _scholarFlowList.length;
          i++) {
        // 防止重复添加
        if (!flowList.any((e) =>
                e.uid == _scholarFlowList[i + _currentScholarFlowCursor].uid) &&
            _scholarFlowList[i + _currentScholarFlowCursor]
                    .endTime
                    .difference(DateTime.now())
                    .inMinutes <
                2880) {
          flowList
              .add(_scholarFlowList[i + _currentScholarFlowCursor].copyWith());
        }
      }
    }

    /* 每个固定日程添加至多5项 */
    for (var x in taskList) {
      if (x.type == TaskType.fixed) {
        DateTime time = DateTime.now();
        DateTime? last;
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

    saveFlowListToDb();
  }

  void refreshScholarFlowList() {
    _scholarFlowList = scholar.value.periods;
    _scholarFlowList.sort((a, b) {
      return a.startTime.compareTo(b.startTime);
    });
    _currentScholarFlowCursor =
        _scholarFlowList.indexWhere((e) => e.endTime.isAfter(DateTime.now()));
  }

  void refreshWidget() {
    List<PeriodDto?>? flowListDto = flowList.where((e) => e.type == PeriodType.flow).map((e) {
      return PeriodDto(
        uid: e.uid,
        type: PeriodTypeDto.flow,
        name: e.summary,
        startTime: e.startTime.millisecondsSinceEpoch ~/ 1000,
        endTime: e.endTime.millisecondsSinceEpoch ~/ 1000,
        location: e.location,
      );
    }).toList();
    flowListDto.addAll(_scholarFlowList.map((e) => PeriodDto(
      uid: e.uid,
      type: e.type == PeriodType.classes ? PeriodTypeDto.classes : PeriodTypeDto.test,
      name: e.summary,
      startTime: e.startTime.millisecondsSinceEpoch ~/ 1000,
      endTime: e.endTime.millisecondsSinceEpoch ~/ 1000,
      location: e.type == PeriodType.classes ? e.location.replaceAll(RegExp(r'[(（].*录播.*[)）]'), '') : e.location,
    )).toList());
    for (var task in taskList.where((e) => e.type == TaskType.fixed)) {
      DateTime time = DateTime.now();
      DateTime? last;
      for (int i = 0; i < 5; i++) {
        Period? period = task.deadlineOfTime(time, predicting: true);
        if (period != null) {
          if (last == null || last.compareTo(period.startTime) != 0) {
            flowListDto.add(PeriodDto(
              uid: period.uid,
              type: PeriodTypeDto.user,
              name: task.summary,
              startTime: period.startTime.millisecondsSinceEpoch ~/ 1000,
              endTime: period.endTime.millisecondsSinceEpoch ~/ 1000,
              location: task.location,
            ));
            last = period.startTime.copyWith();
          }
        }
        time = time.add(Duration(days: task.repeatPeriod));
      }
    }
    _flowMessenger.transfer(FlowMessage(flowListDto: flowListDto));
  }
}
