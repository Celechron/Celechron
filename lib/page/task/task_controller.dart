import 'dart:async';
import 'package:get/get.dart';
import '../../database/database_helper.dart';
import '../../model/deadline.dart';
import '../../utils/utils.dart';


class TaskController extends GetxController {
  final deadlineList = Get.find<RxList<Deadline>>(tag: 'deadlineList');
  final deadlineListLastUpdate = Get.find<Rx<DateTime>>(tag: 'deadlineListLastUpdate');
  final _db = Get.find<DatabaseHelper>(tag: 'db');

  List<Deadline> get todoDeadlineList => deadlineList
      .where((element) =>
          element.deadlineType == DeadlineType.running ||
          element.deadlineType == DeadlineType.suspended)
      .toList();

  List<Deadline> get doneDeadlineList => deadlineList
      .where((element) => element.deadlineType == DeadlineType.completed || element.deadlineType == DeadlineType.failed)
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
    deadlineList.sort((a,b) => a.endTime.compareTo(b.endTime));

    for (var deadline in deadlineList) {
      if (deadline.timeSpent >= deadline.timeNeeded) {
        deadline.deadlineType = DeadlineType.completed;
      } else if (deadline.endTime.isBefore(DateTime.now())) {
        deadline.deadlineType = DeadlineType.failed;
      }
    }

    print('sorted deadlineList');

    /*
  if (__got == 1) return;
  __got = 1;

  deadlineList.clear();

  Deadline tmp = Deadline();
  tmp.genUid();
  deadlineList.add(tmp);
  Deadline tmp2 = tmp.copyWith();
  tmp2.endTime = tmp2.endTime.add(const Duration(days: 1));
  tmp2.timeSpent += const Duration(minutes: 10);
  tmp2.isBreakable = !tmp2.isBreakable;
  tmp2.genUid();
  deadlineList.add(tmp2);
  Deadline tmp3 = tmp2.copyWith();
  tmp3.endTime = tmp3.endTime.add(const Duration(days: 1));
  tmp3.timeSpent += const Duration(minutes: 10);
  tmp3.isBreakable = !tmp3.isBreakable;
  tmp3.deadlineType = DeadlineType.suspended;
  tmp3.genUid();
  deadlineList.add(tmp3);
  Deadline tmp4 = tmp3.copyWith();
  tmp4.endTime = tmp4.endTime.add(const Duration(days: 1));
  tmp4.timeSpent += const Duration(minutes: 10);
  tmp4.isBreakable = !tmp4.isBreakable;
  tmp4.deadlineType = DeadlineType.running;
  tmp4.genUid();
  deadlineList.add(tmp4);
  Deadline tmp5 = tmp4.copyWith();
  tmp5.endTime = tmp5.endTime.add(const Duration(days: 1));
  tmp5.timeSpent += const Duration(minutes: 10);
  tmp5.isBreakable = !tmp5.isBreakable;
  tmp5.genUid();
  deadlineList.add(tmp5);
  Deadline tmp6 = tmp5.copyWith();
  tmp6.endTime = tmp6.endTime.add(const Duration(days: 1));
  tmp6.timeSpent = tmp6.timeNeeded;
  tmp6.isBreakable = !tmp6.isBreakable;
  tmp6.genUid();
  deadlineList.add(tmp6);

  deadlineList.sort(compareDeadline);
  print('rebulit deadlineList');
  */
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