import 'dart:async';
import 'package:get/get.dart';

import 'package:celechron/model/semester.dart';
import 'package:celechron/model/user.dart';


class ScholarController extends GetxController {
  final _user = Get.find<Rx<User>>(tag: 'user');
  final _gpaStrategy = Get.find<RxInt>(tag: 'gpaStrategy');
  late final RxInt semesterIndex;
  final Rx<Duration> _durationToLastUpdate = const Duration().obs;

  User get user => _user.value;

  List<Semester> get semesters => _user.value.semesters;

  Semester get selectedSemester {
    if (semesterIndex >= semesters.length || semesterIndex < 0) {
      var thisSemesterIndex =
          semesters.indexWhere((e) => e.name == _user.value.thisSemester.name);
      semesterIndex.value = thisSemesterIndex >= 0 ? thisSemesterIndex : 0;
    }
    return semesters[semesterIndex.value];
  }

  Duration get durationToLastUpdate => _durationToLastUpdate.value;

  List<double> get gpa => _gpaStrategy.value == 0
      ? _user.value.gpa
      : _user.value.aboardGpa;

  Future<List<String?>> fetchData() async {
    return await _user.value.refresh().then((value) {
      _user.refresh();
      _durationToLastUpdate.value =
          DateTime.now().difference(_user.value.lastUpdateTime);
      return value;
    });
  }

  @override
  void onReady() {
    super.onReady();
    semesterIndex = semesters
        .indexWhere((e) => e.name == _user.value.thisSemester.name)
        .obs;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _durationToLastUpdate.value =
          DateTime.now().difference(_user.value.lastUpdateTime);
    });
  }
}
