import 'dart:async';
import 'dart:io';
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
  final taskListLastUpdate = Get.find<Rx<DateTime>>(tag: 'taskListLastUpdate');
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  late var _scholarFlowList = scholar.value.periods;
  var _currentScholarFlowCursor = -1;
  var timeNow = DateTime.now().obs;
  final _flowMessenger = FlowMessenger();
  Timer? _timer;
  // 数据变化时置位，下一秒执行完整 walk；平时按 _nextWalkAt 的时间边界调度
  bool _walkPending = false;
  DateTime _nextWalkAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastFlowSig = 0;
  DateTime _lastAccrualSaveAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isDuringFlow => flowList.first.startTime.isBefore(DateTime.now());

  @override
  void onInit() {
    // 把基本事项给排序好，看目前在上哪节课（和排序有关系）
    refreshScholarFlowList();
    // 按表走，把应用关闭期间的事务项清理掉
    walkFlowList();
    refreshWidget();

    // 每秒只更新时钟和进行中的进度；昂贵的完整 walk 只在数据变化或时间边界时执行
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _onTick());

    // 当“学业”页面有更新（例如出现新课程），更新基本Flow列表
    ever(scholar, (callback) {
      refreshScholarFlowList();
      _walkPending = true;
      refreshWidget();
    });
    ever(taskList, (callback) {
      _walkPending = true;
      refreshWidget();
    });

    super.onInit();
  }

  void _onTick() {
    final now = DateTime.now();
    timeNow.value = now;
    if (_walkPending || !now.isBefore(_nextWalkAt)) {
      _walkPending = false;
      walkFlowList();
    } else if (flowList.isNotEmpty && !flowList.first.startTime.isAfter(now)) {
      // 有事务已开始时，进度累计仍需每秒同步
      _syncFlowProgress(now);
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
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
    // “规划方案已过期”横幅的忽略操作只走这里，需立即持久化，重启后横幅才不会复现
    _db.setFlowListUpdateTime(flowListLastUpdate.value);
  }

  void removeFlowInFlowList() {
    flowList.removeWhere((element) => element.type == PeriodType.flow);
    _walkPending = true;
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
    _refreshScholarCursor();
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
    _syncFlowProgress(DateTime.now());

    /* 重新添加最近48h内的至多5节课程（防止Flow页面太乱）*/
    _refreshScholarCursor();
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

    // 内容没变就不写库；lastUpdateTime 的纯累计不算变化，重启后可由墙钟回填
    final sig = _computeFlowSig();
    if (sig != _lastFlowSig) {
      _lastFlowSig = sig;
      saveFlowListToDb();
    }
    _nextWalkAt = _computeNextWalkAt(DateTime.now());
  }

  /* 同步Flow页面的任务进度到Task页面 */
  void _syncFlowProgress(DateTime now) {
    var didAccrue = false;
    for (var i = 0; i < flowList.length; i++) {
      if (flowList[i].startTime.isAfter(now)) break;
      if (flowList[i].type == PeriodType.flow) {
        Duration prevProgress =
            (flowList[i].lastUpdateTime ?? flowList[i].startTime)
                .difference(flowList[i].startTime);
        flowList[i].lastUpdateTime = now;
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
        didAccrue = true;
        taskList.refresh();
        flowList.refresh();
      }
      if (flowList[i].endTime.isBefore(now)) {
        flowList.removeAt(i);
        i--;
        flowList.refresh();
        taskList.refresh();
        // 跨过了结束边界，下一秒做一次完整 walk（补课程、重算下个边界）
        _walkPending = true;
      }
    }
    // timeSpent（存于任务表）与 lastUpdateTime（存于规划表）必须成对落盘，
    // 否则杀进程重启后按墙钟回填会多算或少算，进行中每 15 秒同步一次快照。
    if (didAccrue &&
        now.difference(_lastAccrualSaveAt) >= const Duration(seconds: 15)) {
      _lastAccrualSaveAt = now;
      saveFlowListToDb();
      _db.setTaskList(taskList);
      _db.setTaskListUpdateTime(taskListLastUpdate.value);
    }
  }

  int _computeFlowSig() {
    return Object.hashAll(flowList.map((p) => Object.hash(p.uid, p.type,
        p.startTime, p.endTime, p.summary, p.location, p.description)));
  }

  DateTime _computeNextWalkAt(DateTime now) {
    // 60 秒自愈上限：即使漏枚举了某个边界，最迟一分钟后也会有一次完整 walk
    var next = now.add(const Duration(seconds: 60));
    void consider(DateTime t) {
      if (t.isAfter(now) && t.isBefore(next)) next = t;
    }

    for (var p in flowList) {
      consider(p.startTime);
      consider(p.endTime);
    }
    if (_currentScholarFlowCursor != -1) {
      for (var i = 0;
          i < 6 && i + _currentScholarFlowCursor < _scholarFlowList.length;
          i++) {
        var p = _scholarFlowList[i + _currentScholarFlowCursor];
        consider(p.endTime);
        // 距结束 2880 分钟（48 小时）的展示门槛也是一个边界
        consider(p.endTime.subtract(const Duration(minutes: 2880)));
      }
    }
    return next;
  }

  void refreshScholarFlowList() {
    _scholarFlowList = scholar.value.periods;
    _scholarFlowList.sort((a, b) {
      return a.startTime.compareTo(b.startTime);
    });
    _refreshScholarCursor();
  }

  void _refreshScholarCursor() {
    _currentScholarFlowCursor =
        _scholarFlowList.indexWhere((e) => e.endTime.isAfter(DateTime.now()));
  }

  void refreshWidget() {
    // 只有 iOS 需要向原生小组件发送数据，其他平台不必构建 DTO
    if (!Platform.isIOS) return;
    List<PeriodDto?>? flowListDto =
        flowList.where((e) => e.type == PeriodType.flow).map((e) {
      return PeriodDto(
        uid: e.uid,
        type: PeriodTypeDto.flow,
        name: e.summary,
        startTime: e.startTime.millisecondsSinceEpoch ~/ 1000,
        endTime: e.endTime.millisecondsSinceEpoch ~/ 1000,
        location: e.location,
      );
    }).toList();
    flowListDto.addAll(_scholarFlowList
        .map((e) => PeriodDto(
              uid: e.uid,
              type: e.type == PeriodType.classes
                  ? PeriodTypeDto.classes
                  : PeriodTypeDto.test,
              name: e.summary,
              startTime: e.startTime.millisecondsSinceEpoch ~/ 1000,
              endTime: e.endTime.millisecondsSinceEpoch ~/ 1000,
              location: e.type == PeriodType.classes
                  ? e.location.replaceAll(RegExp(r'[(（].*录播.*[)）]'), '')
                  : e.location,
            ))
        .toList());
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

    if (Platform.isIOS) {
      _flowMessenger.transfer(FlowMessage(flowListDto: flowListDto));
    }
  }
}
