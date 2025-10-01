import 'package:celechron/database/database_helper.dart';
import 'package:get/get.dart';

import 'package:celechron/model/semester.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/utils/gpa_helper.dart';
import 'package:celechron/model/grade.dart';

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
    var s1 = semestersWithGrades[semesterIndex];

    // Find paired semester in the same academic year
    int pairedIndex = -1;
    for (var i = 0; i < semestersWithGrades.length; i++) {
      if (i != semesterIndex &&
          semestersWithGrades[i].name.substring(2, 5) ==
              s1.name.substring(2, 5)) {
        pairedIndex = i;
        break;
      }
    }

    // If no paired semester found, return only this semester's major GPA
    if (pairedIndex == -1) {
      var majorGrades = s1.grades.where((g) => g.major);
      return GpaHelper.calculateGpa(majorGrades);
    }

    // Calculate combined major GPA for both semesters
    var s2 = semestersWithGrades[pairedIndex];
    var majorGrades = [
      ...s1.grades.where((g) => g.major),
      ...s2.grades.where((g) => g.major)
    ];
    return GpaHelper.calculateGpa(majorGrades);
  }
}
