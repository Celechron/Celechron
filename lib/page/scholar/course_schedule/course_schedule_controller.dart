import 'package:celechron/model/semester.dart';
import 'package:celechron/model/session.dart';
import 'package:get/get.dart';
import 'package:celechron/model/scholar.dart';

class CourseScheduleController extends GetxController {
  final _scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  late final RxInt semesterIndex;
  late final RxBool firstOrSecondSemester;
  RxBool hideCourseInfomation = false.obs;

  Semester get semester => _scholar.value.semesters[semesterIndex.value];
  List<Semester> get semesters => _scholar.value.semesters;

  void init(String initialName, bool initialFirstOrSecondSemester) {
    semesterIndex = semesters.indexWhere((e) => e.name == initialName).obs;
    firstOrSecondSemester = initialFirstOrSecondSemester.obs;
  }

  CourseScheduleController({
    required String initialName,
    required bool initialFirstOrSecondSemester,
    required bool initialHideCourseInfomation,
  }) {
    init(initialName, initialFirstOrSecondSemester);
    hideCourseInfomation = initialHideCourseInfomation.obs;
  }

  List<List<Session>> get sessionsByDayOfWeek => firstOrSecondSemester.value
      ? _scholar.value.semesters[semesterIndex.value].firstHalfTimetable
      : _scholar.value.semesters[semesterIndex.value].secondHalfTimetable;
}
