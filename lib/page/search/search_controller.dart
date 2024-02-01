import 'package:get/get.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/course.dart';

class SearchPageController extends GetxController {
  final _scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  late List<Course> allCourses;

  RxString searchWord = ''.obs;
  List<Course> get courseResult {
    if (searchWord.value == '') {
      return <Course>[];
    }
    return allCourses.where((e) => e.name.contains(searchWord.value)).toList();
  }

  @override
  void onInit() {
    allCourses = _scholar.value.semesters.fold(<Course>[], (p, e) {
      p.addAll(e.courses.values);
      return p;
    });
    ever(_scholar, (callback) => refreshAllCourses());
    super.onInit();
  }

  void refreshAllCourses() {
    allCourses = _scholar.value.semesters.fold(<Course>[], (p, e) {
      p.addAll(e.courses.values);
      return p;
    });
  }
}
