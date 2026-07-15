import 'dart:async';
import 'package:get/get.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/task.dart';

class TaskController extends GetxController {
  final taskList = Get.find<RxList<Task>>(tag: 'taskList');
  final taskListLastUpdate = Get.find<Rx<DateTime>>(tag: 'taskListLastUpdate');
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  Timer? _timer;

  List<Task> get todoDeadlineList => taskList
      .where((element) => (element.type == TaskType.deadline &&
          (element.status == TaskStatus.running ||
              element.status == TaskStatus.suspended ||
              element.status == TaskStatus.failed)))
      .toList();

  List<Task> get doneDeadlineList => taskList
      .where((element) => (element.type == TaskType.deadline &&
          element.status == TaskStatus.completed))
      .toList();

  List<Task> get fixedDeadlineList =>
      taskList.where((element) => (element.type == TaskType.fixed)).toList();

  @override
  void onInit() {
    updateDeadlineList();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      updateDeadlineList();
    });
    super.onInit();
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> saveDeadlineListToDb() async {
    await _db.setTaskList(taskList);
    await _db.setTaskListUpdateTime(taskListLastUpdate.value);
  }

  void loadDeadlineListLastUpdate() {
    taskListLastUpdate.value = _db.getTaskListUpdateTime();
  }

  void updateDeadlineListTime() {
    taskListLastUpdate.value = DateTime.now();
    // 所有改字段不改列表结构的用户操作（标记完成、暂停/继续等）都经过这里，即时落盘
    saveDeadlineListToDb();
  }

  /// 刷新任务状态（过期判定、固定日程滚动等）。返回是否有数据变化。
  /// 只在真正有变化时执行 RxList 操作和写库，避免每秒空转通知 UI、全量写 Hive。
  bool updateDeadlineList() {
    var changed = false;

    if (taskList.any((element) => element.status == TaskStatus.deleted)) {
      taskList.removeWhere((element) => element.status == TaskStatus.deleted);
      changed = true;
    }

    Set<String> existingUid = {};
    List<Task> newDeadlineList = [];
    for (var deadline in taskList) {
      final oldStatus = deadline.status;
      final oldEndTime = deadline.endTime;
      deadline.refreshStatus();
      if (deadline.type == TaskType.deadline) {
        if (deadline.timeSpent >= deadline.timeNeeded) {
          deadline.status = TaskStatus.completed;
        } else if (deadline.status != TaskStatus.completed &&
            deadline.endTime.isBefore(DateTime.now())) {
          deadline.status = TaskStatus.failed;
        }
      } else if (deadline.type == TaskType.fixed) {
        deadline.refreshStatus();
        existingUid.add(deadline.uid);
        while (deadline.endTime.isBefore(DateTime.now()) &&
            deadline.status != TaskStatus.outdated) {
          Task temp = deadline.copyWith(
            summary: '${deadline.summary}（过去日程）',
            type: TaskType.fixedlegacy,
            repeatType: TaskRepeatType.norepeat,
            fromUid: deadline.uid,
          );
          if (deadline.setToNextPeriod()) {
            temp.genUid();
            newDeadlineList.add(temp);
          } else {
            break;
          }
        }
      }
      if (deadline.status != oldStatus || deadline.endTime != oldEndTime) {
        changed = true;
      }
    }
    if (newDeadlineList.isNotEmpty) {
      taskList.addAll(newDeadlineList);
      changed = true;
    }
    if (taskList.any((element) =>
        element.type == TaskType.fixedlegacy &&
        !existingUid.contains(element.fromUid))) {
      taskList.removeWhere((element) =>
          element.type == TaskType.fixedlegacy &&
          !existingUid.contains(element.fromUid));
      changed = true;
    }

    // 视图可能直接 taskList.add 了新任务或改了 endTime，用顺序守卫兜底
    if (!changed) {
      changed = !_isSortedByEndTime();
    }

    if (changed) {
      // sort 无条件通知，兼作纯状态翻转（无 RxList 结构操作）时的 UI 通知
      taskList.sort((a, b) => a.endTime.compareTo(b.endTime));
      saveDeadlineListToDb();
    }
    return changed;
  }

  bool _isSortedByEndTime() {
    for (var i = 1; i < taskList.length; i++) {
      if (taskList[i - 1].endTime.isAfter(taskList[i].endTime)) {
        return false;
      }
    }
    return true;
  }

  void removeCompletedDeadline(context) {
    taskList.removeWhere((element) =>
        element.type == TaskType.deadline &&
        element.status == TaskStatus.completed);
    saveDeadlineListToDb();
  }

  void removeFailedDeadline(context) {
    taskList.removeWhere((element) =>
        element.type == TaskType.deadline &&
        element.status == TaskStatus.failed);
    saveDeadlineListToDb();
  }

  int suspendAllDeadline(context) {
    int count = 0;
    for (var x in taskList) {
      if (x.type == TaskType.deadline && x.status == TaskStatus.running) {
        x.status = TaskStatus.suspended;
        count++;
      }
    }
    return count;
  }

  int continueAllDeadline(context) {
    int count = 0;
    for (var x in taskList) {
      if (x.type == TaskType.deadline && x.status == TaskStatus.suspended) {
        x.status = TaskStatus.running;
        count++;
      }
    }
    return count;
  }
}
