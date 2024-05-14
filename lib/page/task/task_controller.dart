import 'dart:async';
import 'package:get/get.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/task.dart';
import 'package:celechron/utils/utils.dart';

class TaskController extends GetxController {
  final deadlineList = Get.find<RxList<Task>>(tag: 'taskList');
  final deadlineListLastUpdate =
      Get.find<Rx<DateTime>>(tag: 'taskListLastUpdate');
  final _db = Get.find<DatabaseHelper>(tag: 'db');

  List<Task> get todoDeadlineList => deadlineList
      .where((element) => (element.type == TaskType.deadline &&
          (element.status == TaskStatus.running ||
              element.status == TaskStatus.suspended)))
      .toList();

  List<Task> get doneDeadlineList => deadlineList
      .where((element) => (element.type == TaskType.deadline &&
          (element.status == TaskStatus.completed ||
              element.status == TaskStatus.failed)))
      .toList();

  List<Task> get fixedDeadlineList => deadlineList
      .where((element) => (element.type == TaskType.fixed))
      .toList();

  @override
  void onInit() {
    updateDeadlineList();
    Timer.periodic(const Duration(seconds: 1), (Timer t) {
      updateDeadlineList();
      refreshDeadlineList();
    });
    super.onInit();
  }

  void refreshDeadlineList() {
    saveDeadlineListToDb();
    //print('TaskListPage: refreshed');
  }

  Future<void> saveDeadlineListToDb() async {
    await _db.setTaskList(deadlineList);
    await _db.setTaskListUpdateTime(deadlineListLastUpdate.value);
  }

  void loadDeadlineListLastUpdate() {
    deadlineListLastUpdate.value = _db.getTaskListUpdateTime();
  }

  void updateDeadlineListTime() {
    deadlineListLastUpdate.value = DateTime.now();
  }

  void updateDeadlineList() {
    deadlineList.removeWhere(
        (element) => element.status == TaskStatus.deleted);

    Set<String> existingUid = {};
    List<Task> newDeadlineList = [];
    for (var deadline in deadlineList) {
      deadline.refreshStatus();
      if (deadline.type == TaskType.deadline) {
        if (deadline.timeSpent >= deadline.timeNeeded) {
          deadline.status = TaskStatus.completed;
        } else if (deadline.endTime.isBefore(DateTime.now())) {
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
    }
    deadlineList.addAll(newDeadlineList);
    deadlineList.removeWhere((element) =>
        element.type == TaskType.fixedlegacy &&
        !existingUid.contains(element.fromUid));

    deadlineList.sort((a, b) => a.endTime.compareTo(b.endTime));
  }

  void removeCompletedDeadline(context) {
    deadlineList.removeWhere((element) =>
        element.type == TaskType.deadline &&
        element.status == TaskStatus.completed);
  }

  void removeFailedDeadline(context) {
    deadlineList.removeWhere((element) =>
        element.type == TaskType.deadline &&
        element.status == TaskStatus.failed);
  }

  int suspendAllDeadline(context) {
    int count = 0;
    for (var x in deadlineList) {
      if (x.type == TaskType.deadline &&
          x.status == TaskStatus.running) {
        x.status = TaskStatus.suspended;
        count++;
      }
    }
    return count;
  }

  int continueAllDeadline(context) {
    int count = 0;
    for (var x in deadlineList) {
      if (x.type == TaskType.deadline &&
          x.status == TaskStatus.suspended) {
        x.status = TaskStatus.running;
        count++;
      }
    }
    return count;
  }
}
