import 'package:get/get.dart';

import 'package:celechron/model/semester.dart';
import 'package:celechron/model/user.dart';
import 'package:celechron/model/course.dart';

class CourseListController extends GetxController {
  final _user = Get.find<Rx<User>>(tag: 'user');
  late final RxInt semesterIndex;

  CourseListController({required String initialName}) {
    semesterIndex = semesters.indexWhere((e) => e.name == initialName).obs;
  }

  Semester get semester => _user.value.semesters[semesterIndex.value];
  List<Semester> get semesters => _user.value.semesters;

  List<Course> get courses => semester.courses.values.toList();
}
