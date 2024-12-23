import 'dart:io';

import 'package:celechron/utils/utils.dart';
import 'package:celechron/worker/ecard_widget_messenger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/option.dart';
import 'package:celechron/worker/fuse.dart';
import 'package:celechron/worker/background_app_refresh.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:workmanager/workmanager.dart';

class OptionController extends GetxController {
  final option = Get.find<Option>(tag: 'option');
  final scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final _fuse = Get.find<Rx<Fuse>>(tag: 'fuse');
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  late final RxInt allowTimeLength = option.allowTime.length.obs;

  @override
  void onInit() {
    super.onInit();
    if (option.pushOnGradeChange.value) {
      Workmanager()
          .initialize(callbackDispatcher)
          .then((value) => Workmanager().registerPeriodicTask(
                'top.celechron.celechron.backgroundScholarFetch',
                'top.celechron.celechron.backgroundScholarFetch',
                initialDelay: const Duration(seconds: 10),
                frequency: const Duration(minutes: 15),
              ));
    } else {
      Workmanager().cancelByUniqueName('top.celechron.celechron.backgroundScholarFetch');
    }
  }

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

  GpaStrategy get gpaStrategy => option.gpaStrategy.value;

  set gpaStrategy(GpaStrategy value) {
    option.gpaStrategy.value = value;
    _db.setGpaStrategy(value);
  }

  bool get pushOnGradeChange => option.pushOnGradeChange.value;

  set pushOnGradeChange(bool value) {
    option.pushOnGradeChange.value = value;
    _db.setPushOnGradeChange(value);
    Workmanager()
        .cancelByUniqueName('top.celechron.celechron.backgroundScholarFetch')
        .then((value) {
      if (Platform.isIOS) return Workmanager().printScheduledTasks();
    });
    if (value) {
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsDarwin = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );
      const initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin);
      flutterLocalNotificationsPlugin.initialize(initializationSettings);
      Workmanager()
          .initialize(callbackDispatcher)
          .then((value) => Workmanager().registerPeriodicTask(
                'top.celechron.celechron.backgroundScholarFetch',
                'top.celechron.celechron.backgroundScholarFetch',
                frequency: const Duration(minutes: 15),
                constraints: Constraints(
                  networkType: NetworkType.connected,
                ),
              ));
    }
  }

  String get celechronVersion => _fuse.value.displayVersion;

  bool get hasNewVersion => _fuse.value.hasNewVersion;

  Future<void> logout() async {
    await scholar.value.logout();
    scholar.refresh();
    pushOnGradeChange = false;
    ECardWidgetMessenger.logout();
  }

  set brightnessMode(BrightnessMode value) {
    option.brightnessMode.value = value;
    _db.setBrightnessMode(value);
  }

}
