import 'package:celechron/model/semester.dart';
import 'package:celechron/model/session.dart';
import 'package:get/get.dart';
import 'package:celechron/model/user.dart';

class CourseScheduleController extends GetxController {

  final _user = Get.find<Rx<User>>(tag: 'user');
  late final RxInt semesterIndex;
  late final RxBool firstOrSecondSemester;

  Semester get semester => _user.value.semesters[semesterIndex.value];
  List<Semester> get semesters => _user.value.semesters;

  CourseScheduleController({required String initialName, required bool initialFirstOrSecondSemester}){
    semesterIndex = semesters.indexWhere((e) => e.name == initialName).obs;
    firstOrSecondSemester = initialFirstOrSecondSemester.obs;
  }

  List<List<Session>> get sessionsByDayOfWeek => firstOrSecondSemester.value ? _user.value.semesters[semesterIndex.value].firstHalfTimetable : _user.value.semesters[semesterIndex.value].secondHalfTimetable;

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    super.onClose();
  }
}