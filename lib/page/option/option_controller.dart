import 'package:get/get.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/option.dart';
import 'package:celechron/model/fuse.dart';
import 'package:celechron/database/database_helper.dart';

class OptionController extends GetxController {
  final option = Get.find<Option>(tag: 'option');
  final scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final _fuse = Get.find<Rx<Fuse>>(tag: 'fuse');
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  late final RxInt allowTimeLength = option.allowTime.length.obs;


  Duration get workTime => option.workTime.value;
  set workTime(Duration value) {
    option.workTime.value = value;
    _db.setWorkTime(value);
  }

  Duration get restTime => option.restTime.value;
  set restTime(Duration value) {
    option.restTime.value = value;
    _db.setRestTime(value);
  }

  Map<DateTime, DateTime> get allowTime => option.allowTime;
  set allowTime(Map<DateTime, DateTime> value) {
    option.allowTime.value = value;
    _db.setAllowTime(value);
    allowTimeLength.value = value.length;
  }

  int get gpaStrategy => option.gpaStrategy.value;
  set gpaStrategy(int value) {
    option.gpaStrategy.value = value;
    _db.setGpaStrategy(value);
  }

  String get celechronVersion => _fuse.value.displayVersion;
  bool get hasNewVersion => _fuse.value.hasNewVersion;

  void logout() {
    scholar.value.logout();
    scholar.refresh();
  }
}
