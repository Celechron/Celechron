import 'package:get/get.dart';

import 'package:celechron/model/semester.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/course.dart';

class CourseListController extends GetxController {
  final _scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  late final RxInt semesterIndex;

  CourseListController({required String initialName}) {
    semesterIndex = semesters.indexWhere((e) => e.name == initialName).obs;
  }

  Semester get semester => _scholar.value.semesters[semesterIndex.value];
  List<Semester> get semesters => _scholar.value.semesters;

  List<Course> get courses => semester.courses.values.toList();
}
