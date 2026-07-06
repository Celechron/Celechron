import 'dart:convert';

import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:celechron/utils/json_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/utils.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'top.celechron.celechron.backgroundScholarFetch':
        await refreshScholar();
        break;
      default:
        break;
    }
    return Future.value(true);
  });
}

Future<void> refreshScholar() async {
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
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // 成绩变动通知 channel
  const gradeNotificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'top.celechron.celechron.gradeChange',
      '成绩变动提醒',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    ),
    iOS: DarwinNotificationDetails(
      presentSound: true,
      presentBadge: true,
      presentBanner: true,
      presentList: true,
      sound: 'default',
      badgeNumber: 0,
    ),
  );

  // DDL 截止提醒 channel
  const ddlNotificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'top.celechron.celechron.ddlReminder',
      '作业截止提醒',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    ),
    iOS: DarwinNotificationDetails(
      presentSound: true,
      presentBadge: true,
      presentBanner: true,
      presentList: true,
      sound: 'default',
      badgeNumber: 0,
    ),
  );

  var scholar = Scholar();
  var secureStorage = const FlutterSecureStorage();
  scholar.username = await secureStorage.read(
      key: 'username', iOptions: secureStorageIOSOptions);
  scholar.password = await secureStorage.read(
      key: 'password', iOptions: secureStorageIOSOptions);
  var oldGpa =
      await secureStorage.read(key: 'gpa', iOptions: secureStorageIOSOptions) ??
          '0.0';
  var gradedCourseCount = await secureStorage.read(
          key: 'gradedCourseCount', iOptions: secureStorageIOSOptions) ??
      '0';
  var pushOnGradeChangeFuse = await secureStorage.read(
      key: 'pushOnGradeChangeFuse', iOptions: secureStorageIOSOptions);
  var pushOnGradeChange = await secureStorage.read(
      key: 'pushOnGradeChange', iOptions: secureStorageIOSOptions);
  var pushOnDdlReminder = await secureStorage.read(
      key: 'pushOnDdlReminder', iOptions: secureStorageIOSOptions);
  var notifiedDdlIdsStr = await secureStorage.read(
      key: 'notifiedDdlIds', iOptions: secureStorageIOSOptions);

  try {
    final refreshErrors =
        await scholar.refresh(origin: RefreshOrigin.background);
    // 后台刷新拿到整体降级结果时不发通知，避免把旧缓存误判为新成绩或新作业。
    if (refreshErrors.whereType<String>().any((error) =>
        isDegradedRefreshText(error) && shortErrorText(error).contains('刷新'))) {
      return;
    }
    bool failed(String interfaceName) => refreshErrors
        .whereType<String>()
        .any((error) => shortErrorText(error).contains(interfaceName));

    // 成绩变动通知
    if (pushOnGradeChange != 'false' && !failed('成绩')) {
      if (pushOnGradeChangeFuse == null) {
        await flutterLocalNotificationsPlugin.show(
            0,
            '首次成绩推送',
            '若有新出分的课程，Celechron 将会通知您。若不需要此功能，可在 Celechron 的设置页面中关闭。',
            gradeNotificationDetails);
        await secureStorage.write(
            key: 'pushOnGradeChangeFuse',
            value: '1',
            iOptions: secureStorageIOSOptions);
      } else if (scholar.gpa[0] != double.tryParse(oldGpa) ||
          scholar.gradedCourseCount != int.tryParse(gradedCourseCount)) {
        await flutterLocalNotificationsPlugin.show(0, '成绩变动提醒',
            '有新出分的课程，可在 Celechron 的学业页面中刷新查看。', gradeNotificationDetails);
      }
      await secureStorage.write(
          key: 'gpa',
          value: scholar.gpa[0].toString(),
          iOptions: secureStorageIOSOptions);
      await secureStorage.write(
          key: 'gradedCourseCount',
          value: scholar.gradedCourseCount.toString(),
          iOptions: secureStorageIOSOptions);
    }

    // DDL 截止提醒
    if (pushOnDdlReminder != 'false' && !failed('作业')) {
      Set<String> notifiedDdlIds = {};
      if (notifiedDdlIdsStr != null && notifiedDdlIdsStr.isNotEmpty) {
        final decoded = jsonDecode(notifiedDdlIdsStr);
        notifiedDdlIds = (asDynamicList(decoded) ?? const [])
            .map(asString)
            .whereType<String>()
            .toSet();
      }

      var now = DateTime.now();
      var upcomingTodos = scholar.todos.where((todo) {
        if (todo.endTime == null) return false;
        var timeLeft = todo.endTime!.difference(now);
        // 24 小时内到期且尚未通知过
        return timeLeft.inHours >= 0 &&
            timeLeft.inHours <= 24 &&
            !notifiedDdlIds.contains(todo.id);
      }).toList();

      if (upcomingTodos.isNotEmpty) {
        var notificationId = 1000; // DDL 通知从 1000 开始
        for (var todo in upcomingTodos) {
          var hoursLeft = todo.endTime!.difference(now).inHours;
          var timeDesc = hoursLeft > 0 ? '$hoursLeft 小时后' : '即将';
          await flutterLocalNotificationsPlugin.show(
              notificationId++,
              '作业截止提醒',
              '「${todo.course}」的作业「${todo.name}」将于$timeDesc截止',
              ddlNotificationDetails);
          notifiedDdlIds.add(todo.id);
        }
      }

      // 清理已过期的通知记录，避免无限增长
      notifiedDdlIds.removeWhere((id) {
        var todo = scholar.todos.where((t) => t.id == id);
        if (todo.isEmpty) return true;
        return todo.first.endTime != null && todo.first.endTime!.isBefore(now);
      });

      await secureStorage.write(
          key: 'notifiedDdlIds',
          value: jsonEncode(notifiedDdlIds.toList()),
          iOptions: secureStorageIOSOptions);
    }
  } on Object catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('后台学业刷新失败：${error.runtimeType}: $error\n$stackTrace');
    }
    return;
  }
}
