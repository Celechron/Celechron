import 'dart:async';

import 'package:celechron/model/semester.dart';
import 'package:get/get.dart';
import '../../model/user.dart';

class ScholarController extends GetxController {
  final _user = Get.find<Rx<User>>(tag: 'user');
  late final RxInt semesterIndex;
  final Rx<Duration> _durationToLastUpdate = const Duration().obs;

  User get user => _user.value;
  List<Semester> get semesters => _user.value.semesters;
  Semester get selectedSemester {
    if (semesterIndex >= semesters.length || semesterIndex < 0) {
      var thisSemesterIndex = semesters.indexWhere((e) => e.name == _user.value.thisSemester.name);
      semesterIndex.value = thisSemesterIndex >= 0 ? thisSemesterIndex : 0;
    }
    return semesters[semesterIndex.value];
  }
  Duration get durationToLastUpdate => _durationToLastUpdate.value;

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
