import 'package:celechron/model/semester.dart';
import 'package:celechron/model/session.dart';
import 'package:get/get.dart';
import 'package:celechron/model/scholar.dart';

class CourseScheduleController extends GetxController {
  final _scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  late final RxInt semesterIndex;
  late final RxBool firstOrSecondSemester;

  Semester get semester => _scholar.value.semesters[semesterIndex.value];
  List<Semester> get semesters => _scholar.value.semesters;

  CourseScheduleController(
      {required String initialName,
      required bool initialFirstOrSecondSemester}) {
    semesterIndex = semesters.indexWhere((e) => e.name == initialName).obs;
    firstOrSecondSemester = initialFirstOrSecondSemester.obs;
  }

  List<List<Session>> get sessionsByDayOfWeek => firstOrSecondSemester.value
      ? _scholar.value.semesters[semesterIndex.value].firstHalfTimetable
      : _scholar.value.semesters[semesterIndex.value].secondHalfTimetable;
}
