import 'package:device_calendar/device_calendar.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/semester.dart';

/// 系统日历同步管理器
/// 负责创建和管理Celechron课表在系统日历中的同步
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

  /// 获取设备日历权限
  Future<bool> requestPermissions() async {
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && permissionsGranted.data!) {
        // print('日历权限已获取');
        return true;
      } else {
        var permissionsRequested =
            await _deviceCalendarPlugin.requestPermissions();
        if (permissionsRequested.isSuccess && permissionsRequested.data!) {
          // print('日历权限获取成功');
          return true;
        } else {
          // print('日历权限获取失败');
          return false;
        }
      }
    } catch (e) {
      // print('检查日历权限时出错: $e');
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
            // print('找到已存在的Celechron日历: ${existingCalendar.name}');
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
          // print('找到已存在的Celechron日历: ${existingCalendar.name}');
          _celechronCalendarId = existingCalendar.id;
          return existingCalendar.id;
        }
      }

      // 创建新的Celechron日历
      var createResult =
          await _deviceCalendarPlugin.createCalendar(celechronCalendarName);
      if (createResult.isSuccess && createResult.data != null) {
        _celechronCalendarId = createResult.data;
        // print('成功创建Celechron日历，ID: $_celechronCalendarId');
        return _celechronCalendarId;
      } else {
        // print('创建Celechron日历失败');
        return null;
      }
    } catch (e) {
      // print('获取或创建Celechron日历时出错: $e');
      return null;
    }
  }

  /// 同步学者的课程到系统日历
  /// [scholar] 学者信息
  /// [semester] 指定要同步的学期，如果为null则同步当前学期
  /// [syncAllSemesters] 是否同步所有学期，默认false
  Future<bool> syncScholarToSystemCalendar(
    Scholar scholar, {
    Semester? semester,
    bool syncAllSemesters = false,
  }) async {
    try {
      // print('开始同步课程到系统日历...');

      // 检查权限
      if (!await requestPermissions()) {
        // print('没有日历权限，无法同步');
        return false;
      }

      // 获取或创建Celechron日历
      var calendarId = await getOrCreateCelechronCalendar();
      if (calendarId == null) {
        // print('无法获取或创建Celechron日历');
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

      // print('开始同步 $syncDescription 的课程，找到 ${allPeriods.length} 个课程期间');

      // 只同步课程和考试，不同步用户日程
      var coursePeriods = allPeriods
          .where((period) =>
              period.type == PeriodType.classes ||
              period.type == PeriodType.test)
          .toList();

      // print('需要同步的课程/考试期间: ${coursePeriods.length} 个');

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
            // print('成功同步事件: ${period.summary}');
          } else {
            // print('同步事件失败: ${period.summary}');
          }
        } catch (e) {
          // print('同步单个事件时出错: ${period.summary}, 错误: $e');
        }
      }

      // 更新统计信息
      _syncedCourseCount = syncedCourseNames.length;
      _syncedEventCount = syncedCount;

      // print('同步完成! 成功同步: $syncedCount 个, 跳过: $skippedCount 个');
      return syncedCount > 0;
    } catch (e) {
      // print('同步课程到系统日历时出错: $e');
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
    if (period.location.isNotEmpty) {
      event.location = period.location;
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
        event.title = '🏆 ${period.summary}';
        break;
      default:
        event.availability = Availability.Free;
    }

    return event;
  }

  /// 生成事件的唯一标识符
  /// 基于期间的关键信息生成，确保相同的课程不会重复添加
  String _generateEventId(Period period) {
    // 使用摘要、开始时间、结束时间和地点生成唯一ID
    var key =
        '${period.summary}_${period.startTime.toIso8601String()}_${period.endTime.toIso8601String()}_${period.location}';
    return key.hashCode.toString();
  }

  /// 清除所有已同步的事件（可选功能）
  Future<bool> clearSyncedEvents() async {
    try {
      if (_celechronCalendarId == null) {
        // print('没有找到Celechron日历，无需清除');
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
        // print('找到 ${events.length} 个事件需要清除');
        for (var event in events) {
          try {
            await _deviceCalendarPlugin.deleteEvent(
              _celechronCalendarId!,
              event.eventId!,
            );
          } catch (e) {
            // print('删除事件失败: ${event.title}, 错误: $e');
          }
        }

        // print('成功删除事件');
        _syncedEventIds.clear();
        _syncedCourseCount = 0;
        _syncedEventCount = 0;
        return true;
      }

      return false;
    } catch (e) {
      // print('清除已同步事件时出错: $e');
      return false;
    }
  }

  /// 获取可用学期列表（供UI使用）
  List<String> getAvailableSemesters(Scholar scholar) {
    return scholar.semesters.map((semester) => semester.name).toList();
  }

  /// 根据学期名称获取学期对象
  Semester? getSemesterByName(Scholar scholar, String semesterName) {
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
        // print('没有找到Celechron日历，无需删除');
        return true;
      }

      // 删除整个日历
      var deleteResult =
          await _deviceCalendarPlugin.deleteCalendar(_celechronCalendarId!);

      if (deleteResult.isSuccess && deleteResult.data!) {
        // print('成功删除Celechron日历');
        // 清空所有缓存信息
        _celechronCalendarId = null;
        _syncedEventIds.clear();
        _syncedCourseCount = 0;
        _syncedEventCount = 0;
        return true;
      } else {
        // print('删除Celechron日历失败');
        return false;
      }
    } catch (e) {
      // print('删除Celechron日历时出错: $e');
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
}
