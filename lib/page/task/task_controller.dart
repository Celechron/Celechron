import 'dart:async';
import 'package:get/get.dart';
import '../../database/database_helper.dart';
import '../../model/deadline.dart';
import '../../utils/utils.dart';

class TaskController extends GetxController {
  final deadlineList = Get.find<RxList<Deadline>>(tag: 'deadlineList');
  final deadlineListLastUpdate =
      Get.find<Rx<DateTime>>(tag: 'deadlineListLastUpdate');
  final _db = Get.find<DatabaseHelper>(tag: 'db');

  List<Deadline> get todoDeadlineList => deadlineList
      .where((element) =>
          element.deadlineType == DeadlineType.running ||
          element.deadlineType == DeadlineType.suspended)
      .toList();

  List<Deadline> get doneDeadlineList => deadlineList
      .where((element) =>
          element.deadlineType == DeadlineType.completed ||
          element.deadlineType == DeadlineType.failed)
      .toList();

  @override
  void onInit() {
    updateDeadlineList();
    Timer.periodic(const Duration(seconds: 1), (Timer t) {
      refreshDeadlineList();
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
    deadlineList
        .removeWhere((element) => element.deadlineType == DeadlineType.deleted);
    deadlineList.sort((a, b) => a.endTime.compareTo(b.endTime));

    for (var deadline in deadlineList) {
      if (deadline.timeSpent >= deadline.timeNeeded) {
        deadline.deadlineType = DeadlineType.completed;
      } else if (deadline.endTime.isBefore(DateTime.now())) {
        deadline.deadlineType = DeadlineType.failed;
      }
    }
  }

  void removeCompletedDeadline(context) {
    deadlineList.removeWhere(
        (element) => element.deadlineType == DeadlineType.completed);
  }

  void removeFailedDeadline(context) {
    deadlineList
        .removeWhere((element) => element.deadlineType == DeadlineType.failed);
  }
}
