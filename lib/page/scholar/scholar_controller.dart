import 'dart:async';

import 'package:celechron/model/semester.dart';
import 'package:get/get.dart';
import '../../model/user.dart';

class ScholarController extends GetxController {

  final _user = Get.find<Rx<User>>(tag: 'user');
  final Rx<Duration> _durationToLastUpdate = const Duration().obs;

  User get user => _user.value;
  Semester get thisSemester => _user.value.thisSemester;
  List<Semester> get semesters => _user.value.semesters;
  Duration get durationToLastUpdate => _durationToLastUpdate.value;

  Future<List<String?>> fetchData() async {
    return await _user.value.refresh().then((value) {
      _user.refresh();
      _durationToLastUpdate.value = DateTime.now().difference(_user.value.lastUpdateTime);
      return value;
    });
  }

  @override
  void onReady() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _durationToLastUpdate.value = DateTime.now().difference(_user.value.lastUpdateTime);
    });
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

}
