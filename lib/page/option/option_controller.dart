import 'package:get/get.dart';
import 'package:celechron/model/user.dart';
import 'package:celechron/model/option.dart';
import 'package:celechron/database/database_helper.dart';

class OptionController extends GetxController {
  final option = Get.find<Option>(tag: 'option');
  final user = Get.find<Rx<User>>(tag: 'user');
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

  void logout() {
    user.value.logout();
    user.refresh();
  }
}
