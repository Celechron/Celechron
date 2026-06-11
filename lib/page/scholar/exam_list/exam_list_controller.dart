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
    final groupedExams = <String, List<Exam>>{};
    for (final exam in semester.exams) {
      groupedExams.putIfAbsent(_examDayKey(exam), () => []).add(exam);
    }
    return groupedExams.values.toList();
  }

  String _examDayKey(Exam exam) {
    if (exam.dateLabel != null) return 'label:${exam.dateLabel}';
    final date = exam.time[0];
    return 'date:${date.year}-${date.month}-${date.day}';
  }

  @override
  void onReady() {
    super.onReady();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _durationToLastUpdate.value =
          DateTime.now().difference(_scholar.value.lastUpdateTimeCourse);
    });
  }
}
