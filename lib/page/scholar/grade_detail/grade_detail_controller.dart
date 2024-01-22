import 'package:get/get.dart';

import 'package:celechron/model/semester.dart';
import 'package:celechron/model/user.dart';

class GradeDetailController extends GetxController {
  final user = Get.find<Rx<User>>(tag: 'user');
  final semesterIndex = 0.obs;
  late RxList<Semester> semestersWithGrades;

  @override
  void onInit() {
    semestersWithGrades = user.value.semesters
        .where((element) => element.grades.isNotEmpty)
        .toList()
        .obs;
    ever(user, (callback) => refreshSemesters());
    super.onInit();
  }

  void refreshSemesters() {
    semestersWithGrades.value = user.value.semesters
        .where((element) => element.grades.isNotEmpty)
        .toList();
    semestersWithGrades.refresh();
  }
}
