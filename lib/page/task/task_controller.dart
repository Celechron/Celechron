import 'dart:async';
import 'package:get/get.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/task.dart';
import 'package:celechron/utils/utils.dart';
import 'package:celechron/model/scholar.dart';
class TaskController extends GetxController {
  final taskList = Get.find<RxList<Task>>(tag: 'taskList');
  final taskListLastUpdate =
      Get.find<Rx<DateTime>>(tag: 'taskListLastUpdate');
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  final _scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  List<Task> get todoDeadlineList => taskList
      .where((element) => (element.type == TaskType.deadline &&
          (element.status == TaskStatus.running ||
              element.status == TaskStatus.suspended)))
      .toList();

  List<Task> get doneDeadlineList => taskList
      .where((element) => (element.type == TaskType.deadline &&
          (element.status == TaskStatus.completed ||
              element.status == TaskStatus.failed)))
      .toList();

  List<Task> get fixedDeadlineList => taskList
      .where((element) => (element.type == TaskType.fixed))
      .toList();

  @override
  void onInit() {
    updateDeadlineList(updateXzzd: true);
    Timer.periodic(const Duration(seconds: 1), (Timer t) {
      updateDeadlineList(updateXzzd: false);
      refreshDeadlineList();
    });
    Timer.periodic(const Duration(seconds: 10), (Timer t) {
      updateDeadlineList(updateXzzd: true);
      refreshDeadlineList();
    });
    super.onInit();
  }

  void refreshDeadlineList() {
    saveDeadlineListToDb();
    //print('TaskListPage: refreshed');
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
  }

  void updateDeadlineList({bool updateXzzd=false}) {
    taskList.removeWhere(
        (element) => element.status == TaskStatus.deleted);
    // taskList.removeWhere(
    //   (element) => element.timeNeeded==const Duration(days: 0, hours: 2, minutes: 30)
    // );
    Set<String> existingUid = {};
    List<Task> newDeadlineList = [];
    if(updateXzzd){
      //删除原有的xzzd任务
      taskList.removeWhere(
        (element) => element.description=="xzzd" //这里应该给Task增加一个属性，但是要改的地方太多了，所以就这样了
      );
      newDeadlineList=_scholar.value.xzzdTask;
    }
    for (var deadline in taskList) {
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
    taskList.addAll(newDeadlineList);
    taskList.removeWhere((element) =>
        element.type == TaskType.fixedlegacy &&
        !existingUid.contains(element.fromUid));

    taskList.sort((a, b) => a.endTime.compareTo(b.endTime));
  }

  void removeCompletedDeadline(context) {
    taskList.removeWhere((element) =>
        element.type == TaskType.deadline &&
        element.status == TaskStatus.completed);
  }

  void removeFailedDeadline(context) {
    taskList.removeWhere((element) =>
        element.type == TaskType.deadline &&
        element.status == TaskStatus.failed);
  }

  int suspendAllDeadline(context) {
    int count = 0;
    for (var x in taskList) {
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
    for (var x in taskList) {
      if (x.type == TaskType.deadline &&
          x.status == TaskStatus.suspended) {
        x.status = TaskStatus.running;
        count++;
      }
    }
    return count;
  }
}