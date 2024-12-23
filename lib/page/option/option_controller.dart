import 'dart:io';

import 'package:celechron/worker/ecard_widget_messenger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/option.dart';
import 'package:celechron/worker/fuse.dart';
import 'package:celechron/worker/background.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:workmanager/workmanager.dart';

import 'package:flutter/cupertino.dart';

class OptionController extends GetxController {
  final option = Get.find<Option>(tag: 'option');
  final scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final _fuse = Get.find<Rx<Fuse>>(tag: 'fuse');
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  late final RxInt allowTimeLength = option.allowTime.length.obs;

  static const int BRIGHTNESS_MODE_SYSTEM = 0;
  static const int BRIGHTNESS_MODE_LIGHT = 1;
  static const int BRIGHTNESS_MODE_DARK = 2;

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
              ))
          .then((value) {
        if (Platform.isIOS) return Workmanager().printScheduledTasks();
      });
    } else {
      Workmanager()
          .cancelByUniqueName('top.celechron.celechron.backgroundScholarFetch')
          .then((value) {
        if (Platform.isIOS) return Workmanager().printScheduledTasks();
      });
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

  int get gpaStrategy => option.gpaStrategy.value;

  set gpaStrategy(int value) {
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
              ))
          .then((value) {
        if (Platform.isIOS) return Workmanager().printScheduledTasks();
      });
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

  Brightness matcher(int v){
    switch (v) {
      case BRIGHTNESS_MODE_SYSTEM:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
      case BRIGHTNESS_MODE_LIGHT:
        return Brightness.light;
      case BRIGHTNESS_MODE_DARK:
        return Brightness.dark;
      default:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  Brightness get brightness => matcher(option.brightnessMode.value);

  void toggleBrightness(int value) {
    option.brightnessMode.value = value;
    _db.setBrightnessMode(value);
  }

}
