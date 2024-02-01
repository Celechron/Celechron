import 'package:get/get.dart';

import 'package:celechron/model/semester.dart';
import 'package:celechron/model/scholar.dart';

class GradeDetailController extends GetxController {
  final scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final semesterIndex = 0.obs;
  late RxList<Semester> semestersWithGrades;

  @override
  void onInit() {
    semestersWithGrades = scholar.value.semesters
        .where((element) => element.grades.isNotEmpty)
        .toList()
        .obs;
    ever(scholar, (callback) => refreshSemesters());
    super.onInit();
  }

  void refreshSemesters() {
    semestersWithGrades.value = scholar.value.semesters
        .where((element) => element.grades.isNotEmpty)
        .toList();
    semestersWithGrades.refresh();
  }
}
