import 'package:get/get.dart';

import 'package:celechron/model/semester.dart';
import 'package:celechron/model/user.dart';
import 'package:celechron/model/exam.dart';

class SearchController extends GetxController {

  final _user = Get.find<Rx<User>>(tag: 'user');
  late final RxInt semesterIndex;

  SearchController({required String initialName}){
    semesterIndex = semesters.indexWhere((e) => e.name == initialName).obs;
  }

  Semester get semester => _user.value.semesters[semesterIndex.value];
  List<Semester> get semesters => _user.value.semesters;

  List<List<Exam>> get exams {
    var exams = semester.exams
        .fold(<List<Exam>>[], (previousValue, element) {
      if (previousValue.isEmpty) {
        previousValue.add([element]);
      } else {
        if (previousValue.last[0].time[0].year == element.time[0].year && previousValue.last[0].time[0].month == element.time[0].month && previousValue.last[0].time[0].day == element.time[0].day ) {
          previousValue.last.add(element);
        } else {
          previousValue.add([element]);
        }
      }
      return previousValue;
    });
    exams.sort((a, b) => a[0].time[0].compareTo(b[0].time[0]));
    return exams;
  }

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