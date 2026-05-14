import 'dart:io';

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:celechron/model/location_mapper.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/semester.dart';

/// 系统日历同步管理器
/// 负责创建和管理Celechron课表在系统日历中的同步
///
/// 主要功能:
/// - 日历权限管理: [requestPermissions], [hasCalendarPermission]
/// - 日历创建与管理: [getOrCreateCelechronCalendar], [deleteCelechronCalendar]
/// - 课程同步: [syncScholarToSystemCalendar], [resyncCalendarEvents]
/// - 学期管理: [syncSpecificSemester], [syncAllSemesters], [getAvailableSemesters]
/// - 同步状态: [calendarSyncEnabled], [checkInitialCalendarSyncStatus], [toggleCalendarSync]
/// - 事件管理: [clearSyncedEvents], [getSyncStats]
/// - UI交互: [showCalendarSyncDialog], [_showSemesterSelectionDialog]
///
/// 注意事项:
/// - 需要系统日历权限才能使用
/// - 支持单个学期或全部学期同步
/// - 可以自动处理重复事件
/// - 提供同步状态和统计信息

class CalendarToSystemManager {
  static const String celechronCalendarName = 'Celechron课表';
  static const String calendarDescription = '由Celechron自动同步的浙大课程表';

  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  // 缓存已同步的事件ID，避免重复添加
  final Set<String> _syncedEventIds = <String>{};

  // 同步统计信息
  int _syncedCourseCount = 0; // 同步的课程数量
  int _syncedEventCount = 0; // 同步的日程数量

  // Celechron课表日历的ID
  String? _celechronCalendarId;

  final Scholar scholar;

  // 日历同步状态
  final RxBool _calendarSyncEnabled = false.obs;
  final RxBool _hasCalendarPermission = false.obs;

  bool get calendarSyncEnabled => _calendarSyncEnabled.value;
  bool get hasCalendarPermission => _hasCalendarPermission.value;

  CalendarToSystemManager(this.scholar);

  /// 获取设备日历权限
  Future<bool> checkPermissions() async {
    // device_calendar plugin doesn't support macOS
    if (Platform.isMacOS) {
      _hasCalendarPermission.value = false;
      return false;
    }
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && permissionsGranted.data!) {
        _hasCalendarPermission.value = true;
        return true;
      } else {
        _hasCalendarPermission.value = false;
        return false;
      }
    } catch (e) {
      _hasCalendarPermission.value = false;
      return false;
    }
  }

  /// 获取设备日历权限
  Future<bool> requestPermissions() async {
    // device_calendar plugin doesn't support macOS
    if (Platform.isMacOS) {
      _hasCalendarPermission.value = false;
      return false;
    }
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && permissionsGranted.data!) {
        _hasCalendarPermission.value = true;
        return true;
      } else {
        var permissionsRequested =
            await _deviceCalendarPlugin.requestPermissions();
        _hasCalendarPermission.value =
            permissionsRequested.isSuccess && permissionsRequested.data!;
        return _hasCalendarPermission.value;
      }
    } catch (e) {
      _hasCalendarPermission.value = false;
      return false;
    }
  }

  /// 获取或创建Celechron专用日历
  Future<String?> getOrCreateCelechronCalendar() async {
    try {
      // 如果已有缓存的日历ID，先验证是否仍然存在
      if (_celechronCalendarId != null) {
        var calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
        if (calendarsResult.isSuccess) {
          var existingCalendar = calendarsResult.data!
              .firstWhereOrNull((cal) => cal.id == _celechronCalendarId);
          if (existingCalendar != null) {
            return _celechronCalendarId;
          }
        }
      }

      // 查找是否已存在同名日历
      var calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess) {
        var existingCalendar = calendarsResult.data!
            .firstWhereOrNull((cal) => cal.name == celechronCalendarName);

        if (existingCalendar != null) {
          _celechronCalendarId = existingCalendar.id;
          return existingCalendar.id;
        }
      }

      // 创建新的Celechron日历
      var createResult =
          await _deviceCalendarPlugin.createCalendar(celechronCalendarName);
      if (createResult.isSuccess && createResult.data != null) {
        _celechronCalendarId = createResult.data;
        return _celechronCalendarId;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// 同步Scholar中的课程到系统日历
  /// [semester] 指定要同步的学期，如果为null则同步当前学期
  /// [syncAllSemesters] 是否同步所有学期，默认false
  Future<bool> syncScholarToSystemCalendar({
    Semester? semester,
    bool syncAllSemesters = false,
  }) async {
    try {
      // 检查权限
      if (!await requestPermissions()) {
        return false;
      }

      // 获取或创建Celechron日历
      var calendarId = await getOrCreateCelechronCalendar();
      if (calendarId == null) {
        return false;
      }

      // 清空已同步事件缓存（重新开始同步）
      _syncedEventIds.clear();
      _syncedCourseCount = 0;
      _syncedEventCount = 0;

      // 获取要同步的课程期间
      List<Period> allPeriods;

      if (syncAllSemesters) {
        // 同步所有学期
        allPeriods = scholar.periods;
      } else {
        // 同步指定学期或当前学期
        var targetSemester = semester ?? scholar.thisSemester;
        allPeriods = targetSemester.periods;
      }

      // 只同步课程和考试，不同步用户日程
      var coursePeriods = allPeriods
          .where((period) =>
              period.type == PeriodType.classes ||
              period.type == PeriodType.test)
          .toList();

      int syncedCount = 0;
      Set<String> syncedCourseNames = <String>{}; // 用于统计不重复的课程名

      for (var period in coursePeriods) {
        try {
          // 生成唯一标识符，基于期间的内容
          var eventId = _generateEventId(period);

          // 检查是否已经同步过
          if (_syncedEventIds.contains(eventId)) {
            continue;
          }

          // 创建日历事件
          var event = _createEventFromPeriod(period);
          event.calendarId = calendarId;

          // 添加到系统日历
          var createResult =
              await _deviceCalendarPlugin.createOrUpdateEvent(event);

          if (createResult != null && createResult.isSuccess) {
            _syncedEventIds.add(eventId);
            syncedCount++;
            // 统计课程名称（去重）
            syncedCourseNames.add(period.summary);
          }
        } catch (e) {
          // 忽略单个事件的错误，继续同步其他事件
        }
      }

      // 更新统计信息
      _syncedCourseCount = syncedCourseNames.length;
      _syncedEventCount = syncedCount;

      return syncedCount > 0;
    } catch (e) {
      return false;
    }
  }

  /// 从Period创建日历事件
  Event _createEventFromPeriod(Period period) {
    var event = Event(period.summary);

    // 设置基本信息
    event.title = period.summary;
    event.description = period.description;
    event.start =
        tz.TZDateTime.from(period.startTime, tz.getLocation('Asia/Shanghai'));
    event.end =
        tz.TZDateTime.from(period.endTime, tz.getLocation('Asia/Shanghai'));

    // 设置地点
    final mappedLocation =
        CalendarLocationMapper.mapForCalendar(period.location);
    if (mappedLocation.isNotEmpty) {
      event.location = mappedLocation;
    }

    // 根据类型设置不同的属性
    switch (period.type) {
      case PeriodType.classes:
        // 课程 - 设置为忙碌状态
        event.availability = Availability.Busy;
        break;
      case PeriodType.test:
        // 考试 - 设置为忙碌状态，并在标题前加标识
        event.availability = Availability.Busy;
        event.title = '💯 ${period.summary}';
        break;
      default:
        event.availability = Availability.Free;
    }

    return event;
  }

  /// 生成事件的唯一标识符
  /// 基于期间的关键信息生成，确保相同的课程不会重复添加
  String _generateEventId(Period period) {
    final mappedLocation =
        CalendarLocationMapper.mapForCalendar(period.location);
    // 使用摘要、开始时间、结束时间和地点生成唯一ID
    var key =
        '${period.summary}_${period.startTime.toIso8601String()}_${period.endTime.toIso8601String()}_$mappedLocation';
    return key.hashCode.toString();
  }

  /// 清除所有已同步的事件（可选功能）
  Future<bool> clearSyncedEvents() async {
    try {
      if (_celechronCalendarId == null) {
        return true;
      }

      // 获取日历中的所有事件
      var eventsResult = await _deviceCalendarPlugin.retrieveEvents(
        _celechronCalendarId!,
        RetrieveEventsParams(
          startDate: DateTime.now().subtract(const Duration(days: 365)),
          endDate: DateTime.now().add(const Duration(days: 365)),
        ),
      );

      if (eventsResult.isSuccess) {
        var events = eventsResult.data ?? [];
        for (var event in events) {
          try {
            await _deviceCalendarPlugin.deleteEvent(
              _celechronCalendarId!,
              event.eventId!,
            );
          } catch (e) {
            // 忽略单个事件删除失败
          }
        }

        _syncedEventIds.clear();
        _syncedCourseCount = 0;
        _syncedEventCount = 0;
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// 获取可用学期列表（供UI使用）
  List<String> getAvailableSemesters() {
    return scholar.semesters.map((semester) => semester.name).toList();
  }

  /// 根据学期名称获取学期对象
  Semester? getSemesterByName(String semesterName) {
    return scholar.semesters.firstWhereOrNull((s) => s.name == semesterName);
  }

  /// 删除整个Celechron日历
  /// 这将完全删除Celechron日历及其所有事件
  Future<bool> deleteCelechronCalendar() async {
    try {
      // 如果没有缓存的日历ID，先尝试查找
      if (_celechronCalendarId == null) {
        var calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
        if (calendarsResult.isSuccess) {
          var existingCalendar = calendarsResult.data!
              .firstWhereOrNull((cal) => cal.name == celechronCalendarName);
          if (existingCalendar != null) {
            _celechronCalendarId = existingCalendar.id;
          }
        }
      }

      // 如果还是没有找到日历，说明日历不存在
      if (_celechronCalendarId == null) {
        return true;
      }

      // 删除整个日历
      var deleteResult =
          await _deviceCalendarPlugin.deleteCalendar(_celechronCalendarId!);

      if (deleteResult.isSuccess && deleteResult.data!) {
        // 清空所有缓存信息
        _celechronCalendarId = null;
        _syncedEventIds.clear();
        _syncedCourseCount = 0;
        _syncedEventCount = 0;
        _calendarSyncEnabled.value = false;
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// 获取同步统计信息
  Map<String, dynamic> getSyncStats() {
    return {
      'syncedCourseCount': _syncedCourseCount, // 课程数量
      'syncedEventCount': _syncedEventCount, // 日程数量
      'calendarId': _celechronCalendarId,
      'calendarName': celechronCalendarName,
    };
  }

  /// 显示提示弹窗
  void _showAlert(BuildContext context, String title, String message,
      {bool isError = false}) {
    if (context.mounted) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
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
  }

  /// 强制重新同步课程（先清除后同步）
  Future<void> resyncCalendarEvents(BuildContext context) async {
    try {
      if (!await requestPermissions()) {
        _showAlert(context, '权限获取失败', '请在系统设置中手动开启日历权限');
        return;
      }

      // 先清除已有事件
      await clearSyncedEvents();

      // 重新同步
      bool syncSuccess = await syncScholarToSystemCalendar();

      if (syncSuccess) {
        var stats = getSyncStats();
        _showAlert(context, '重新同步成功',
            '已重新同步 ${stats['syncedCourseCount']} 门课程，共计 ${stats['syncedEventCount']} 个日程');
      } else {
        _showAlert(context, '重新同步失败', '无法重新同步课程到系统日历');
      }
    } catch (e) {
      _showAlert(context, '错误', '重新同步时出错: $e', isError: true);
    }
  }

  /// 同步指定学期的课程
  Future<void> syncSpecificSemester(
      BuildContext context, String semesterName) async {
    try {
      if (!await requestPermissions()) {
        _showAlert(context, '权限获取失败', '请在系统设置中手动开启日历权限');
        return;
      }

      var semester = getSemesterByName(semesterName);
      if (semester == null) {
        _showAlert(context, '错误', '未找到指定的学期');
        return;
      }

      // 先清除已有事件
      await clearSyncedEvents();

      // 同步指定学期
      bool syncSuccess = await syncScholarToSystemCalendar(
        semester: semester,
      );

      if (syncSuccess) {
        var stats = getSyncStats();
        _showAlert(context, '同步成功',
            '已同步 $semesterName 的 ${stats['syncedCourseCount']} 门课程，共计 ${stats['syncedEventCount']} 个日程');
      } else {
        _showAlert(context, '同步失败', '无法同步 $semesterName 的课程');
      }
    } catch (e) {
      _showAlert(context, '错误', '同步时出错: $e', isError: true);
    }
  }

  /// 同步所有学期的课程
  Future<void> syncAllSemesters(BuildContext context) async {
    try {
      if (!await requestPermissions()) {
        _showAlert(context, '权限获取失败', '请在系统设置中手动开启日历权限');
        return;
      }

      // 先清除已有事件
      await clearSyncedEvents();

      // 同步所有学期
      bool syncSuccess = await syncScholarToSystemCalendar(
        syncAllSemesters: true,
      );

      if (syncSuccess) {
        var stats = getSyncStats();
        _showAlert(context, '同步成功',
            '已同步所有学期的 ${stats['syncedCourseCount']} 门课程，共计 ${stats['syncedEventCount']} 个日程');
      } else {
        _showAlert(context, '同步失败', '无法同步所有学期的课程');
      }
    } catch (e) {
      _showAlert(context, '错误', '同步时出错: $e', isError: true);
    }
  }

  /// 显示日历同步选项对话框
  void showCalendarSyncDialog(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext actionSheetContext) {
        return CupertinoActionSheet(
          title: const Text('同步日历选项'),
          message: const Text('选择日历同步操作'),
          actions: <Widget>[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(actionSheetContext);
                resyncCalendarEvents(context);
              },
              child: const Text('更新当前课表'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(actionSheetContext);
                _showSemesterSelectionDialog(context);
              },
              child: const Text('选择学期同步'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(actionSheetContext),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  /// 显示学期选择对话框
  void _showSemesterSelectionDialog(BuildContext context) {
    final semesters = getAvailableSemesters();

    if (semesters.isEmpty) {
      _showAlert(context, '提示', '没有可同步的学期数据，请先登录');
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext actionSheetContext) {
        return CupertinoActionSheet(
          title: const Text('选择学期'),
          message: const Text('选择要同步的学期'),
          actions: [
            ...semesters.map((semester) => CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(actionSheetContext);
                    syncSpecificSemester(context, semester);
                  },
                  child: Text(semester),
                )),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(actionSheetContext);
                syncAllSemesters(context);
              },
              child: const Text('同步所有学期'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(actionSheetContext),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  /// 检查初始日历同步状态
  Future<void> checkInitialCalendarSyncStatus() async {
    // device_calendar plugin doesn't support macOS
    if (Platform.isMacOS) {
      _calendarSyncEnabled.value = false;
      _hasCalendarPermission.value = false;
      return;
    }
    try {
      // 先检查权限
      await checkPermissions();

      // 如果没有权限，直接返回
      if (!_hasCalendarPermission.value) {
        _calendarSyncEnabled.value = false;
        return;
      }

      var calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess) {
        var existingCalendar = calendarsResult.data!
            .firstWhereOrNull((cal) => cal.name == celechronCalendarName);

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
      // 忽略错误
    }
  }

  /// 切换日历同步功能
  Future<void> toggleCalendarSync(BuildContext context, bool enabled) async {
    // macOS 暂不支持系统日历同步功能
    if (Platform.isMacOS) {
      _showAlert(context, '暂不支持', 'macOS 系统暂不支持日历同步功能');
      return;
    }

    if (enabled) {
      // 如果要开启同步，先检查权限
      if (!await requestPermissions()) {
        _showAlert(context, '权限获取失败', '请在系统设置中手动开启日历权限');
        return;
      }

      // 检查是否已登录
      if (!scholar.isLogan) {
        _showAlert(context, '提示', '请先登录后再开启日历同步功能');
        return;
      }

      // 开始同步当前学期课程到系统日历
      bool syncSuccess = await syncScholarToSystemCalendar();

      if (syncSuccess) {
        _calendarSyncEnabled.value = true;
        var stats = getSyncStats();
        _showAlert(context, '同步成功',
            '已同步 ${stats['syncedCourseCount']} 门课程，共计 ${stats['syncedEventCount']} 个日程');
      } else {
        // For iOS, show different message
        if (Platform.isIOS) {
          _showAlert(context, '同步失败', '无法同步课程到系统日历，从日历中移除Google账户后重试');
        } else {
          _showAlert(context, '同步失败', '无法同步课程到系统日历，请检查权限和网络连接');
        }
      }
    } else {
      // 关闭同步功能
      _calendarSyncEnabled.value = false;

      // 删除课表数据和Celechron日历
      try {
        bool deleteSuccess = await deleteCelechronCalendar();
        if (deleteSuccess) {
          _showAlert(context, '成功', '日历同步功能已关闭，已删除课表数据和Celechron日历');
        } else {
          _showAlert(context, '成功', '日历同步功能已关闭，但删除日历时遇到问题');
        }
      } catch (e) {
        _showAlert(context, '成功', '日历同步功能已关闭，但删除日历时出错: $e');
      }
    }
  }
}
