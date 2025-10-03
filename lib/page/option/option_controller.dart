import 'dart:io';

import 'package:get/get.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/option.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/worker/ecard_widget_messenger.dart';
import 'package:celechron/worker/fuse.dart';
import 'package:celechron/worker/background_app_refresh.dart';
import 'package:celechron/utils/platform_features.dart';
import 'package:celechron/model/calendar_to_ical.dart';
import 'package:celechron/model/calendar_to_system.dart';

class OptionController extends GetxController {
  final _option = Get.find<Option>(tag: 'option');
  final scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final _fuse = Get.find<Rx<Fuse>>(tag: 'fuse');
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  late final RxInt allowTimeLength = _option.allowTime.length.obs;

  // 日历同步相关
  late final CalendarToSystemManager _calendarManager;

  @override
  void onInit() {
    super.onInit();
    _calendarManager = CalendarToSystemManager(scholar.value);

    if (PlatformFeatures.hasBackgroundRefresh) {
      if (_option.pushOnGradeChange.value) {
        Workmanager()
            .initialize(callbackDispatcher)
            .then((value) => Workmanager().registerPeriodicTask(
                  'top.celechron.celechron.backgroundScholarFetch',
                  'top.celechron.celechron.backgroundScholarFetch',
                  initialDelay: const Duration(seconds: 10),
                  frequency: const Duration(minutes: 15),
                ));
      } else {
        Workmanager().cancelByUniqueName(
            'top.celechron.celechron.backgroundScholarFetch');
      }
    }

    ever(courseIdMappingList, (value) {
      _db.setCourseIdMappingList(value);
    });

    // 初始化时检查日历权限和同步状态（不显示提示框）
    _calendarManager.checkInitialCalendarSyncStatus();
  }

  Duration get workTime => _option.workTime.value;

  set workTime(Duration value) {
    _option.workTime.value = value;
    _db.setWorkTime(value);
  }

  Duration get restTime => _option.restTime.value;

  set restTime(Duration value) {
    _option.restTime.value = value;
    _db.setRestTime(value);
  }

  Map<DateTime, DateTime> get allowTime => _option.allowTime;

  set allowTime(Map<DateTime, DateTime> value) {
    _option.allowTime.value = value;
    _db.setAllowTime(value);
    allowTimeLength.value = value.length;
  }

  GpaStrategy get gpaStrategy => _option.gpaStrategy.value;

  set gpaStrategy(GpaStrategy value) {
    _option.gpaStrategy.value = value;
    _db.setGpaStrategy(value);
  }

  bool get pushOnGradeChange => _option.pushOnGradeChange.value;

  set pushOnGradeChange(bool value) {
    _option.pushOnGradeChange.value = value;
    _db.setPushOnGradeChange(value);

    if (!PlatformFeatures.hasBackgroundRefresh) {
      return;
    }

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

  BrightnessMode get brightnessMode => _option.brightnessMode.value;

  set brightnessMode(BrightnessMode value) {
    _option.brightnessMode.value = value;
    _db.setBrightnessMode(value);
  }

  RxList<CourseIdMap> get courseIdMappingList => _option.courseIdMappingList;

  String get celechronVersion => _fuse.value.displayVersion;

  bool get hasNewVersion => _fuse.value.hasNewVersion;

  // 日历同步相关getter
  bool get calendarSyncEnabled => _calendarManager.calendarSyncEnabled;
  bool get hasCalendarPermission => _calendarManager.hasCalendarPermission;

  Future<void> logout() async {
    await scholar.value.logout();
    scholar.refresh();
    pushOnGradeChange = false;
    ECardWidgetMessenger.logout();
  }

  /// 显示 Cupertino 风格的提示弹窗
  void _showAlert(String title, String message, {bool isError = false}) {
    Get.dialog(
      CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('确定'),
            onPressed: () => Get.back(),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  /// 导出ICS课程表文件
  Future<void> exportIcsFile() async {
    await CalendarToIcal.exportIcsFile(scholar.value, _showAlert);
  }

  /// 获取可用学期列表（供UI使用）
  List<String> getAvailableSemesters() {
    if (!scholar.value.isLogan) {
      return [];
    }
    return CalendarToIcal.getAvailableSemesters(scholar.value);
  }

  /// 导出指定学期
  Future<void> exportSpecificSemester(String semesterName) async {
    await CalendarToIcal.exportSpecificSemester(
        scholar.value, semesterName, _showAlert);
  }

  /// 导出所有学期
  Future<void> exportAllSemesters() async {
    await CalendarToIcal.exportAllSemesters(scholar.value, _showAlert);
  }

  /// 切换日历同步功能
  Future<void> toggleCalendarSync(bool enabled) async {
    await _calendarManager.toggleCalendarSync(enabled);
  }

  /// 获取同步状态信息
  Map<String, dynamic> getCalendarSyncStatus() {
    var stats = _calendarManager.getSyncStats();
    return {
      'enabled': _calendarManager.calendarSyncEnabled,
      'hasPermission': _calendarManager.hasCalendarPermission,
      'isLoggedIn': scholar.value.isLogan,
      'syncedCourseCount': stats['syncedCourseCount'],
      'syncedEventCount': stats['syncedEventCount'],
      'calendarName': stats['calendarName'],
    };
  }

  /// 显示日历同步选项对话框
  void showCalendarSyncDialog(BuildContext context) {
    _calendarManager.showCalendarSyncDialog(context);
  }
}
