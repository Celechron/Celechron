import 'package:get/get.dart';
import 'package:celechron/model/user.dart';
import 'package:celechron/model/course.dart';

class SearchPageController extends GetxController {

  final _user = Get.find<Rx<User>>(tag: 'user');
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
    allCourses = _user.value.semesters.fold(<Course>[], (p, e) {
      p.addAll(e.courses.values);
      return p;
    });
    ever(_user, (callback) => refreshAllCourses());
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

  void refreshAllCourses(){
    allCourses = _user.value.semesters.fold(<Course>[], (p, e) {
      p.addAll(e.courses.values);
      return p;
    });
  }
}