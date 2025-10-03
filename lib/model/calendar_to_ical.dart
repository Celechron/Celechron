import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/semester.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// iCal日历格式转换器
/// 将课程信息转换为iCal格式，支持导入到各种日历应用
class CalendarToIcal {
  /// 将DateTime转换为iCal格式的时间字符串
  /// 格式：YYYYMMDDTHHMMSS
  static String _toISOString(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}'
        '${dateTime.month.toString().padLeft(2, '0')}'
        '${dateTime.day.toString().padLeft(2, '0')}'
        'T'
        '${dateTime.hour.toString().padLeft(2, '0')}'
        '${dateTime.minute.toString().padLeft(2, '0')}'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  /// iCal日期格式常量
  static const String dateLayoutUTC = "yyyyMMddTHHmmssZ";

  /// 单个课程事件
  static String _generateVEvent(Period period) {
    final buffer = StringBuffer();
    final utcStr =
        '${DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.')[0]}Z';
    final startStr = _toISOString(period.startTime);
    final endStr = _toISOString(period.endTime);

    // 生成唯一ID
    final hash = _generateHash(period);

    buffer.writeln('BEGIN:VEVENT');
    buffer.writeln('CLASS:PUBLIC');
    buffer.writeln('CREATED:$utcStr');

    // 描述信息
    if (period.description.isNotEmpty) {
      // 处理特殊字符和换行
      String description = period.description
          .replaceAll('\n', '\\n')
          .replaceAll(',', '\\,')
          .replaceAll(';', '\\;');

      buffer.writeln('DESCRIPTION:$description');
    }

    buffer.writeln('DTSTAMP:$utcStr');
    buffer.writeln('DTSTART;TZID=Asia/Shanghai:$startStr');
    buffer.writeln('DTEND;TZID=Asia/Shanghai:$endStr');
    buffer.writeln('LAST-MODIFIED:$utcStr');

    // 地点信息
    if (period.location.isNotEmpty) {
      buffer.writeln('LOCATION:${period.location}');
    }

    buffer.writeln('SEQUENCE:0');
    buffer.writeln('SUMMARY;LANGUAGE=zh-cn:${period.summary}');
    buffer.writeln('TRANSP:OPAQUE');
    buffer.writeln('UID:$hash');

    // 可以选择是否添加提醒
    buffer.writeln('BEGIN:VALARM');
    buffer.writeln('TRIGGER:-PT15M');
    buffer.writeln('ACTION:DISPLAY');
    buffer.writeln('DESCRIPTION:提醒');
    buffer.writeln('END:VALARM');

    buffer.writeln('END:VEVENT');

    return buffer.toString();
  }

  /// 生成事件的哈希ID
  static String _generateHash(Period period) {
    final content =
        '${period.description}${period.summary}${period.location}${_toISOString(period.startTime)}';
    final bytes = utf8.encode(content);
    final digest = sha1.convert(bytes);
    return digest.toString();
  }

  /// 生成完整的iCal日历文件
  static String generateIcal({
    required List<Period> periods,
    String calendarName = "浙大课程表",
    bool includeExams = true,
  }) {
    final buffer = StringBuffer();

    // iCal文件头
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('X-WR-CALNAME:$calendarName');
    buffer.writeln('X-APPLE-CALENDAR-COLOR:#2BBFF0');
    buffer.writeln('PRODID:-//Celechron//Course Calendar 1.0//CN');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('METHOD:PUBLISH');

    // 时区信息
    buffer.writeln('BEGIN:VTIMEZONE');
    buffer.writeln('TZID:Asia/Shanghai');
    buffer.writeln('BEGIN:STANDARD');
    buffer.writeln('DTSTART:16010101T000000');
    buffer.writeln('TZOFFSETFROM:+0800');
    buffer.writeln('TZOFFSETTO:+0800');
    buffer.writeln('END:STANDARD');
    buffer.writeln('END:VTIMEZONE');

    // 筛选并添加课程事件
    for (final period in periods) {
      // 根据参数决定是否包含考试
      if (!includeExams && period.type == PeriodType.test) {
        continue;
      }
      buffer.write(_generateVEvent(period));
    }

    buffer.writeln('END:VCALENDAR');

    return buffer.toString();
  }

  /// 显示提示弹窗
  static void _showAlert(String title, String message, {bool isError = false}) {
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

  /// 从Scholar对象生成iCal
  static String generateIcalFromScholar({
    required Scholar scholar,
    String? semesterName,
    String calendarName = "浙大课程表",
    bool includeExams = true,
    bool includeAllSemesters = false,
  }) {
    List<Period> periods = [];

    if (includeAllSemesters) {
      // 包含所有学期
      periods = scholar.periods;
    } else if (semesterName != null) {
      // 指定学期
      final semester = scholar.semesters.firstWhere(
        (s) => s.name == semesterName,
        orElse: () => scholar.thisSemester,
      );
      periods = semester.periods;
    } else {
      // 当前学期
      periods = scholar.thisSemester.periods;
    }

    return generateIcal(
      periods: periods,
      calendarName: calendarName,
      includeExams: includeExams,
    );
  }

  /// 从指定学期生成iCal
  static String generateIcalFromSemester({
    required Semester semester,
    String? calendarName,
    bool includeExams = true,
  }) {
    final name = calendarName ?? '${semester.name} 课程表';
    return generateIcal(
      periods: semester.periods,
      calendarName: name,
      includeExams: includeExams,
    );
  }

  /// 导出ICS课程表文件
  static Future<void> exportIcsFile(Scholar scholar) async {
    try {
      if (!scholar.isLogan) {
        _showAlert('提示', '请先登录后再导出课程表');
        return;
      }

      // 生成iCal内容
      final icalContent = generateIcalFromScholar(
        scholar: scholar,
        calendarName: "浙大课程表-${scholar.thisSemester.name}",
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
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          subject: '浙大课程表',
          text: '从 Celechron 导出的课程表文件，可导入到其他日历应用中使用。',
        ),
      );

      _showAlert('成功', '课程表已导出，请选择保存位置或分享');
    } catch (e) {
      _showAlert('错误', '导出失败: $e', isError: true);
    }
  }

  /// 导出指定学期
  static Future<void> exportSpecificSemester(
      Scholar scholar, String semesterName) async {
    try {
      final icalContent = generateIcalFromScholar(
        scholar: scholar,
        semesterName: semesterName,
        calendarName: "浙大课程表-$semesterName",
        includeExams: true,
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'celechron_${semesterName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.ics';
      final tempFile = File('${directory.path}/$fileName');

      await tempFile.writeAsString(icalContent);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          subject: '浙大课程表-$semesterName',
          text: '从 Celechron 导出的 $semesterName 课程表文件。',
        ),
      );

      _showAlert('成功', '$semesterName 课程表已导出');
    } catch (e) {
      _showAlert('错误', '导出失败: $e', isError: true);
    }
  }

  /// 导出所有学期
  static Future<void> exportAllSemesters(Scholar scholar) async {
    try {
      final icalContent = generateIcalFromScholar(
        scholar: scholar,
        calendarName: "课程表-完整版",
        includeExams: true,
        includeAllSemesters: true,
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'celechron_all_semesters_${DateTime.now().millisecondsSinceEpoch}.ics';
      final tempFile = File('${directory.path}/$fileName');

      await tempFile.writeAsString(icalContent);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          subject: '浙大课程表-完整版',
          text: '从 Celechron 导出的完整课程表文件，包含所有学期。',
        ),
      );

      _showAlert('成功', '完整课程表已导出');
    } catch (e) {
      _showAlert('错误', '导出失败: $e', isError: true);
    }
  }

  /// 获取可用的学期列表
  static List<String> getAvailableSemesters(Scholar scholar) {
    return scholar.semesters.map((s) => s.name).toList();
  }

  /// 显示导出课程表对话框
  static void showExportDialog(BuildContext context, Scholar scholar) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('导出课程表'),
        message: const Text('选择导出方式'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              exportIcsFile(scholar);
            },
            child: const Text('导出当前学期'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showSemesterSelectionDialog(context, scholar);
            },
            child: const Text('选择学期导出'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  /// 显示学期选择对话框（UI界面）
  static void _showSemesterSelectionDialog(
      BuildContext context, Scholar scholar) {
    final semesters = getAvailableSemesters(scholar);

    if (semesters.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('提示'),
          content: const Text('没有可导出的课程表数据'),
          actions: [
            CupertinoDialogAction(
              child: const Text('确定'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    /// 显示学期选择对话框 （UI界面）
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('选择学期'),
        message: const Text('选择要导出的学期'),
        actions: [
          ...semesters.map((semester) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  exportSpecificSemester(scholar, semester);
                },
                child: Text(semester),
              )),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              exportAllSemesters(scholar);
            },
            child: const Text('导出所有学期'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  /// 生成课程统计信息
  static Map<String, dynamic> getCalendarStatistics(List<Period> periods) {
    final stats = <String, dynamic>{};

    // 按类型统计
    final typeCount = <PeriodType, int>{};
    for (final period in periods) {
      typeCount[period.type] = (typeCount[period.type] ?? 0) + 1;
    }

    stats['totalEvents'] = periods.length;
    stats['courseCount'] = typeCount[PeriodType.classes] ?? 0;
    stats['examCount'] = typeCount[PeriodType.test] ?? 0;
    stats['userEventCount'] = typeCount[PeriodType.user] ?? 0;
    stats['flowCount'] = typeCount[PeriodType.flow] ?? 0;

    // 时间范围
    if (periods.isNotEmpty) {
      final sortedPeriods = periods.toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      stats['startDate'] = sortedPeriods.first.startTime;
      stats['endDate'] = sortedPeriods.last.endTime;
    }

    return stats;
  }
}
