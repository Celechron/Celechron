import 'dart:async';

import 'package:get/get.dart';

import 'package:celechron/model/semester.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/exam.dart';

class ExamListController extends GetxController {
  final _scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  late final RxInt semesterIndex;
  final Rx<Duration> _durationToLastUpdate = const Duration().obs;

  ExamListController({required String initialName}) {
    semesterIndex = semesters.indexWhere((e) => e.name == initialName).obs;
  }

  Semester get semester => _scholar.value.semesters[semesterIndex.value];
  List<Semester> get semesters => _scholar.value.semesters;
  Duration get durationToLastUpdate => _durationToLastUpdate.value;

  List<List<Exam>> get exams {
    semester.sortExams();
    var exams = semester.exams.fold(<List<Exam>>[], (previousValue, element) {
      if (previousValue.isEmpty) {
        previousValue.add([element]);
      } else {
        if (previousValue.last[0].time[0].year == element.time[0].year &&
            previousValue.last[0].time[0].month == element.time[0].month &&
            previousValue.last[0].time[0].day == element.time[0].day) {
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
  void onReady() {
    super.onReady();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _durationToLastUpdate.value =
          DateTime.now().difference(_scholar.value.lastUpdateTime);
    });
  }
}
