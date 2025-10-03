import 'dart:io';

import 'package:get/get.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_calendar/device_calendar.dart';

import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/option.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/worker/ecard_widget_messenger.dart';
import 'package:celechron/worker/fuse.dart';
import 'package:celechron/worker/background_app_refresh.dart';
import 'package:celechron/utils/platform_features.dart';
import 'package:celechron/page/calendar/calendar_to_ical.dart';
import 'package:celechron/page/calendar/calendar_to_system.dart';

class OptionController extends GetxController {
  final _option = Get.find<Option>(tag: 'option');
  final scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final _fuse = Get.find<Rx<Fuse>>(tag: 'fuse');
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  late final RxInt allowTimeLength = _option.allowTime.length.obs;

  // 日历同步相关
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  final CalendarToSystemManager _calendarManager = CalendarToSystemManager();
  final RxBool _calendarSyncEnabled = false.obs;
  final RxBool _hasCalendarPermission = false.obs;

  @override
  void onInit() {
    super.onInit();
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
    checkCalendarPermission(showAlert: false)
        .then((_) => checkInitialCalendarSyncStatus());
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
  bool get calendarSyncEnabled => _calendarSyncEnabled.value;
  bool get hasCalendarPermission => _hasCalendarPermission.value;

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
    try {
      if (!scholar.value.isLogan) {
        _showAlert('提示', '请先登录后再导出课程表');
        return;
      }

      // 生成iCal内容
      final icalContent = CalendarToIcal.generateIcalFromScholar(
        scholar: scholar.value,
        calendarName: "浙大课程表-${scholar.value.thisSemester.name}",
        includeExams: true,
      );

      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'celechron_schedule_${DateTime.now().millisecondsSinceEpoch}.ics';
      final tempFile = File('${directory.path}/$fileName');

      // 写入临时文件
      await tempFile.writeAsString(icalContent);

      // 使用系统分享功能
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: '浙大课程表',
        text: '从 Celechron 导出的课程表文件，可导入到其他日历应用中使用。',
      );

      _showAlert('成功', '课程表已导出，请选择保存位置或分享');
    } catch (e) {
      _showAlert('错误', '导出失败: $e', isError: true);
    }
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
    try {
      final icalContent = CalendarToIcal.generateIcalFromScholar(
        scholar: scholar.value,
        semesterName: semesterName,
        calendarName: "浙大课程表-$semesterName",
        includeExams: true,
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'celechron_${semesterName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.ics';
      final tempFile = File('${directory.path}/$fileName');

      await tempFile.writeAsString(icalContent);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: '浙大课程表-$semesterName',
        text: '从 Celechron 导出的 $semesterName 课程表文件。',
      );

      _showAlert('成功', '$semesterName 课程表已导出');
    } catch (e) {
      _showAlert('错误', '导出失败: $e', isError: true);
    }
  }

  /// 导出所有学期
  Future<void> exportAllSemesters() async {
    try {
      final icalContent = CalendarToIcal.generateIcalFromScholar(
        scholar: scholar.value,
        calendarName: "课程表-完整版",
        includeExams: true,
        includeAllSemesters: true,
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'celechron_all_semesters_${DateTime.now().millisecondsSinceEpoch}.ics';
      final tempFile = File('${directory.path}/$fileName');

      await tempFile.writeAsString(icalContent);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: '浙大课程表-完整版',
        text: '从 Celechron 导出的完整课程表文件，包含所有学期。',
      );

      _showAlert('成功', '完整课程表已导出');
    } catch (e) {
      _showAlert('错误', '导出失败: $e', isError: true);
    }
  }

  /// 检查并请求日历权限
  Future<void> checkCalendarPermission({bool showAlert = true}) async {
    try {
      bool hasPermission = await _calendarManager.requestPermissions();
      _hasCalendarPermission.value = hasPermission;

      if (!hasPermission && showAlert) {
        _showAlert('权限获取失败', '请在系统设置中手动开启日历权限');
      }
    } catch (e) {
      // print('检查日历权限时出错: $e');
      _hasCalendarPermission.value = false;
      if (showAlert) {
        _showAlert('错误', '检查日历权限时出错: $e', isError: true);
      }
    }
  }

  /// 检查初始日历同步状态
  /// 通过检查Celechron日历是否存在来判断之前是否开启过日历同步
  Future<void> checkInitialCalendarSyncStatus() async {
    try {
      if (!_hasCalendarPermission.value) {
        return; // 没有权限就不检查了
      }

      var calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess) {
        var existingCalendar = calendarsResult.data!.firstWhereOrNull(
            (cal) => cal.name == CalendarToSystemManager.celechronCalendarName);

        if (existingCalendar != null) {
          // 如果找到了Celechron日历，说明之前可能开启过同步
          // 但为了保险起见，我们检查日历中是否有事件
          var eventsResult = await _deviceCalendarPlugin.retrieveEvents(
            existingCalendar.id!,
            RetrieveEventsParams(
              startDate: DateTime.now().subtract(const Duration(days: 30)),
              endDate: DateTime.now().add(const Duration(days: 30)),
            ),
          );

          if (eventsResult.isSuccess &&
              (eventsResult.data?.isNotEmpty ?? false)) {
            // 如果有事件，说明确实在使用，设置为已开启状态
            _calendarSyncEnabled.value = true;
          }
        }
      }
    } catch (e) {
      print('检查初始日历同步状态时出错: $e');
    }
  }

  /// 切换日历同步功能
  Future<void> toggleCalendarSync(bool enabled) async {
    if (enabled) {
      // 如果要开启同步，先检查权限
      await checkCalendarPermission();
      if (!_hasCalendarPermission.value) {
        return;
      }

      // 检查是否已登录
      if (!scholar.value.isLogan) {
        _showAlert('提示', '请先登录后再开启日历同步功能');
        return;
      }

      // 开始同步当前学期课程到系统日历
      bool syncSuccess =
          await _calendarManager.syncScholarToSystemCalendar(scholar.value);

      if (syncSuccess) {
        _calendarSyncEnabled.value = true;
        var stats = _calendarManager.getSyncStats();
        _showAlert('同步成功',
            '已同步 ${stats['syncedCourseCount']} 门课程，共计 ${stats['syncedEventCount']} 个日程');
      } else {
        _showAlert('同步失败', '无法同步课程到系统日历，请检查权限和网络连接');
      }
    } else {
      // 关闭同步功能
      _calendarSyncEnabled.value = false;

      // 删除课表数据和Celechron日历
      try {
        bool deleteSuccess = await _calendarManager.deleteCelechronCalendar();
        if (deleteSuccess) {
          _showAlert('成功', '日历同步功能已关闭，已删除课表数据和Celechron日历');
        } else {
          _showAlert('成功', '日历同步功能已关闭，但删除日历时遇到问题');
        }
      } catch (e) {
        _showAlert('成功', '日历同步功能已关闭，但删除日历时出错: $e');
      }
    }
  }

  /// 获取设备日历列表（用于调试）
  Future<void> getDeviceCalendars() async {
    try {
      if (!_hasCalendarPermission.value) {
        await checkCalendarPermission();
        if (!_hasCalendarPermission.value) {
          return;
        }
      }

      var calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess) {
        for (var calendar in calendarsResult.data!) {
          print('- ${calendar.name} (ID: ${calendar.id})');
        }
      }
    } catch (e) {
      print('获取设备日历时出错: $e');
    }
  }

  /// 清除已同步的日历事件
  Future<void> clearSyncedCalendarEvents() async {
    try {
      if (!_hasCalendarPermission.value) {
        await checkCalendarPermission();
        if (!_hasCalendarPermission.value) {
          return;
        }
      }

      bool clearSuccess = await _calendarManager.clearSyncedEvents();

      if (clearSuccess) {
        _showAlert('成功', '已清除所有同步的课程事件');
      } else {
        _showAlert('清除失败', '无法清除已同步的日历事件');
      }
    } catch (e) {
      _showAlert('错误', '清除日历事件时出错: $e', isError: true);
    }
  }

  /// 强制重新同步课程（先清除后同步）
  Future<void> resyncCalendarEvents() async {
    try {
      if (!_hasCalendarPermission.value) {
        await checkCalendarPermission();
        if (!_hasCalendarPermission.value) {
          return;
        }
      }

      if (!scholar.value.isLogan) {
        _showAlert('提示', '请先登录后再重新同步');
        return;
      }

      // 先清除已有事件
      await _calendarManager.clearSyncedEvents();

      // 重新同步
      bool syncSuccess =
          await _calendarManager.syncScholarToSystemCalendar(scholar.value);

      if (syncSuccess) {
        var stats = _calendarManager.getSyncStats();
        _showAlert('重新同步成功',
            '已重新同步 ${stats['syncedCourseCount']} 门课程，共计 ${stats['syncedEventCount']} 个日程');
      } else {
        _showAlert('重新同步失败', '无法重新同步课程到系统日历');
      }
    } catch (e) {
      _showAlert('错误', '重新同步时出错: $e', isError: true);
    }
  }

  /// 获取同步状态信息
  Map<String, dynamic> getCalendarSyncStatus() {
    var stats = _calendarManager.getSyncStats();
    return {
      'enabled': _calendarSyncEnabled.value,
      'hasPermission': _hasCalendarPermission.value,
      'isLoggedIn': scholar.value.isLogan,
      'syncedCourseCount': stats['syncedCourseCount'],
      'syncedEventCount': stats['syncedEventCount'],
      'calendarName': stats['calendarName'],
    };
  }

  /// 获取可用学期列表（供UI使用）
  List<String> getAvailableSemestersForSync() {
    if (!scholar.value.isLogan) {
      return [];
    }
    return _calendarManager.getAvailableSemesters(scholar.value);
  }

  /// 同步指定学期的课程
  Future<void> syncSpecificSemester(String semesterName) async {
    try {
      if (!_hasCalendarPermission.value) {
        await checkCalendarPermission();
        if (!_hasCalendarPermission.value) {
          return;
        }
      }

      if (!scholar.value.isLogan) {
        _showAlert('提示', '请先登录后再同步课程');
        return;
      }

      var semester =
          _calendarManager.getSemesterByName(scholar.value, semesterName);
      if (semester == null) {
        _showAlert('错误', '未找到指定的学期');
        return;
      }

      // 先清除已有事件
      await _calendarManager.clearSyncedEvents();

      // 同步指定学期
      bool syncSuccess = await _calendarManager.syncScholarToSystemCalendar(
        scholar.value,
        semester: semester,
      );

      if (syncSuccess) {
        var stats = _calendarManager.getSyncStats();
        _showAlert('同步成功',
            '已同步 $semesterName 的 ${stats['syncedCourseCount']} 门课程，共计 ${stats['syncedEventCount']} 个日程');
      } else {
        _showAlert('同步失败', '无法同步 $semesterName 的课程');
      }
    } catch (e) {
      _showAlert('错误', '同步时出错: $e', isError: true);
    }
  }

  /// 同步所有学期的课程
  Future<void> syncAllSemesters() async {
    try {
      if (!_hasCalendarPermission.value) {
        await checkCalendarPermission();
        if (!_hasCalendarPermission.value) {
          return;
        }
      }

      if (!scholar.value.isLogan) {
        _showAlert('提示', '请先登录后再同步课程');
        return;
      }

      // 先清除已有事件
      await _calendarManager.clearSyncedEvents();

      // 同步所有学期
      bool syncSuccess = await _calendarManager.syncScholarToSystemCalendar(
        scholar.value,
        syncAllSemesters: true,
      );

      if (syncSuccess) {
        var stats = _calendarManager.getSyncStats();
        _showAlert('同步成功',
            '已同步所有学期的 ${stats['syncedCourseCount']} 门课程，共计 ${stats['syncedEventCount']} 个日程');
      } else {
        _showAlert('同步失败', '无法同步所有学期的课程');
      }
    } catch (e) {
      _showAlert('错误', '同步时出错: $e', isError: true);
    }
  }

  /// 显示日历同步选项对话框
  void showCalendarSyncDialog(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text('同步日历选项'),
          message: const Text('选择日历同步操作'),
          actions: <Widget>[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                resyncCalendarEvents();
              },
              child: const Text('更新当前课表'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _showSemesterSelectionDialog(context);
              },
              child: const Text('选择学期同步'),
            ),
            // 测试：查看是否可以获取设备日历
            // CupertinoActionSheetAction(
            //   onPressed: () {
            //     Navigator.pop(context);
            //     getDeviceCalendars();
            //   },
            //   child: const Text('查看设备日历'),
            // ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  /// 显示学期选择对话框
  void _showSemesterSelectionDialog(BuildContext context) {
    final semesters = getAvailableSemestersForSync();

    if (semesters.isEmpty) {
      _showAlert('提示', '没有可同步的学期数据，请先登录');
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text('选择学期'),
          message: const Text('选择要同步的学期'),
          actions: [
            ...semesters.map((semester) => CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(context);
                    syncSpecificSemester(semester);
                  },
                  child: Text(semester),
                )),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                syncAllSemesters();
              },
              child: const Text('同步所有学期'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        );
      },
    );
  }
}
