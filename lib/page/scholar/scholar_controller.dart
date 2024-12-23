import 'dart:async';
import 'package:celechron/utils/utils.dart';
import 'package:get/get.dart';

import 'package:celechron/model/semester.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/option.dart';


class ScholarController extends GetxController {
  final _scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final _option = Get.find<Option>(tag: 'option');
  final Rx<Duration> _durationToLastUpdate = const Duration().obs;

  late final RxInt semesterIndex;

  Scholar get scholar => _scholar.value;

  List<Semester> get semesters => _scholar.value.semesters;

  Semester get selectedSemester {
    if (semesterIndex >= semesters.length || semesterIndex < 0) {
      var thisSemesterIndex =
          semesters.indexWhere((e) => e.name == _scholar.value.thisSemester.name);
      semesterIndex.value = thisSemesterIndex >= 0 ? thisSemesterIndex : 0;
    }
    return semesters[semesterIndex.value];
  }

  Duration get durationToLastUpdate => _durationToLastUpdate.value;

  List<double> get gpa => _option.gpaStrategy.value == GpaStrategy.first
      ? _scholar.value.gpa
      : _scholar.value.aboardGpa;

  Future<List<String?>> fetchData() async {
    return await _scholar.value.refresh().then((value) {
      _scholar.refresh();
      _durationToLastUpdate.value =
          DateTime.now().difference(_scholar.value.lastUpdateTime);
      return value;
    });
  }

  @override
  void onReady() {
    super.onReady();
    semesterIndex = semesters
        .indexWhere((e) => e.name == _scholar.value.thisSemester.name)
        .obs;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _durationToLastUpdate.value =
          DateTime.now().difference(_scholar.value.lastUpdateTime);
    });
  }
}
