import 'package:celechron/database/database_helper.dart';
import 'package:get/get.dart';

import 'package:celechron/model/semester.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/utils/gpa_helper.dart';

class GradeDetailController extends GetxController {
  final scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final semesterIndex = 0.obs;
  final customGpaMode = false.obs;
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  final RxMap<String, bool> customGpaSelected = RxMap();
  late RxList<Semester> semestersWithGrades;

  void init() {
    semestersWithGrades = scholar.value.semesters
        .where((element) => element.grades.isNotEmpty)
        .toList()
        .obs;
    ever(scholar, (callback) => refreshSemesters());
    customGpaSelected.value = _db.getCustomGpa();
    semesterIndex.value = 0;
    customGpaMode.value = false;
  }

  @override
  void onInit() {
    init();
    super.onInit();
  }

  void refreshSemesters() {
    semestersWithGrades.value = scholar.value.semesters
        .where((element) => element.grades.isNotEmpty)
        .toList();
    semestersWithGrades.refresh();
  }

  void refreshCustomGpa() {
    _db.setCustomGpa(customGpaSelected);
  }

  Tuple<List<double>, double> getYearMajorGpa(int semesterIndex) {
    // 提取当前学期的学年 ID，例如 "2022-2023"
    final yearId = semestersWithGrades[semesterIndex].name.substring(0, 9);

    // 获取该学年的所有主修课程
    final majorGrades = scholar.value.grades.values
        .expand((g) => g)
        .where((g) => g.major && g.semesterId.contains(yearId))
        .toList();

    // 如果该学年没有主修课程，返回 0.0, 0.0, 0.0
    if (majorGrades.isEmpty) {
      return Tuple([0.0, 0.0, 0.0], 0.0);
    }

    return GpaHelper.calculateGpa(majorGrades);
  }
}
