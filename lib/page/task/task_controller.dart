import 'dart:async';
import 'package:get/get.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/deadline.dart';
import 'package:celechron/utils/utils.dart';

class TaskController extends GetxController {
  final deadlineList = Get.find<RxList<Deadline>>(tag: 'deadlineList');
  final deadlineListLastUpdate =
      Get.find<Rx<DateTime>>(tag: 'deadlineListLastUpdate');
  final _db = Get.find<DatabaseHelper>(tag: 'db');

  List<Deadline> get todoDeadlineList => deadlineList
      .where((element) => (element.deadlineType == DeadlineType.normal &&
          (element.deadlineStatus == DeadlineStatus.running ||
              element.deadlineStatus == DeadlineStatus.suspended)))
      .toList();

  List<Deadline> get doneDeadlineList => deadlineList
      .where((element) => (element.deadlineType == DeadlineType.normal &&
          (element.deadlineStatus == DeadlineStatus.completed ||
              element.deadlineStatus == DeadlineStatus.failed)))
      .toList();

  List<Deadline> get fixedDeadlineList => deadlineList
      .where((element) => (element.deadlineType == DeadlineType.fixed))
      .toList();

  @override
  void onInit() {
    updateDeadlineList();
    Timer.periodic(const Duration(seconds: 1), (Timer t) {
      refreshDeadlineList();
    });
    super.onInit();
  }

  void refreshDeadlineList() {
    saveDeadlineListToDb();
    //print('TaskListPage: refreshed');
  }

  Future<void> saveDeadlineListToDb() async {
    await _db.setDeadlineList(deadlineList);
    await _db.setDeadlineListUpdateTime(deadlineListLastUpdate.value);
  }

  void loadDeadlineListLastUpdate() {
    deadlineListLastUpdate.value = _db.getDeadlineListUpdateTime();
  }

  void updateDeadlineListTime() {
    deadlineListLastUpdate.value = DateTime.now();
  }

  void updateDeadlineList() {
    deadlineList.removeWhere(
        (element) => element.deadlineStatus == DeadlineStatus.deleted);

    Set<String> existingUid = {};
    List<Deadline> newDeadlineList = [];
    for (var deadline in deadlineList) {
      deadline.refreshStatus();
      if (deadline.deadlineType == DeadlineType.normal) {
        if (deadline.timeSpent >= deadline.timeNeeded) {
          deadline.deadlineStatus = DeadlineStatus.completed;
        } else if (deadline.endTime.isBefore(DateTime.now())) {
          deadline.deadlineStatus = DeadlineStatus.failed;
        }
      } else if (deadline.deadlineType == DeadlineType.fixed) {
        existingUid.add(deadline.uid);
        while (deadline.endTime.isBefore(DateTime.now()) &&
            deadline.deadlineStatus != DeadlineStatus.outdated) {
          newDeadlineList.add(deadline.copyWith(
            deadlineType: DeadlineType.fixedlegacy,
            deadlineRepeatType: DeadlineRepeatType.norepeat,
          ));
          deadline.setToNextPeriod();
        }
      }
    }
    deadlineList.addAll(newDeadlineList);
    deadlineList.removeWhere((element) =>
        element.deadlineType == DeadlineType.fixedlegacy &&
        !existingUid.contains(element.uid));

    deadlineList.sort((a, b) => a.endTime.compareTo(b.endTime));
  }

  void removeCompletedDeadline(context) {
    deadlineList.removeWhere((element) =>
        element.deadlineType == DeadlineType.normal &&
        element.deadlineStatus == DeadlineStatus.completed);
  }

  void removeFailedDeadline(context) {
    deadlineList.removeWhere((element) =>
        element.deadlineType == DeadlineType.normal &&
        element.deadlineStatus == DeadlineStatus.failed);
  }

  int suspendAllDeadline(context) {
    int count = 0;
    for (var x in deadlineList) {
      if (x.deadlineType == DeadlineType.normal &&
          x.deadlineStatus == DeadlineStatus.running) {
        x.deadlineStatus = DeadlineStatus.suspended;
        count++;
      }
    }
    return count;
  }

  int continueAllDeadline(context) {
    int count = 0;
    for (var x in deadlineList) {
      if (x.deadlineType == DeadlineType.normal &&
          x.deadlineStatus == DeadlineStatus.suspended) {
        x.deadlineStatus = DeadlineStatus.running;
        count++;
      }
    }
    return count;
  }
}
