import 'package:celechron/model/scholar.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
  const initializationSettingsDarwin = DarwinInitializationSettings(
    requestSoundPermission: true,
    requestBadgePermission: true,
    requestAlertPermission: true,
  );
  const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  const darwinNotificationDetails = DarwinNotificationDetails(
      presentSound: true,
      presentBadge: true,
      presentBanner: true,
      presentList: true,
      sound: 'default',
      badgeNumber: 0,
  );
  const notificationDetails = NotificationDetails(
    iOS: darwinNotificationDetails,
  );

  var scholar = Scholar();
  var secureStorage = const FlutterSecureStorage();
  const iOSOptions = IOSOptions(accessibility: KeychainAccessibility.first_unlock, accountName: 'Celechron');
  scholar.username = await secureStorage.read(key: 'username', iOptions: iOSOptions);
  scholar.password = await secureStorage.read(key: 'password', iOptions: iOSOptions);
  var oldGpa = await secureStorage.read(key: 'gpa', iOptions: iOSOptions) ?? '0.0';
  var gradedCourseCount = await secureStorage.read(key: 'gradedCourseCount', iOptions: iOSOptions) ?? '0';
  var pushOnGradeChangeFuse = await secureStorage.read(key: 'pushOnGradeChangeFuse', iOptions: iOSOptions);

  try {
    var error = await scholar.login();
    if (error.any((e) => e != null)) return;
    error = await scholar.refresh();
    if (error.any((e) => e != null)) return;

    if (pushOnGradeChangeFuse == null) {
      await flutterLocalNotificationsPlugin.show(
          0,
          '首次成绩推送',
          '若有新出分的课程，Celechron将会通知您。若不需要此功能，可在Celechron的设置页面中关闭。',
          notificationDetails
      );
      await secureStorage.write(key: 'pushOnGradeChangeFuse', value: '1', iOptions: iOSOptions);
    } else if (scholar.gpa[0] != double.tryParse(oldGpa) ||
        scholar.gradedCourseCount != int.tryParse(gradedCourseCount)) {
      await flutterLocalNotificationsPlugin.show(
          0,
          '成绩变动提醒',
          '有新出分的课程，可在Celechron的学业页面中刷新查看。',
          notificationDetails
      );
    }
    await secureStorage.write(key: 'gpa', value: scholar.gpa[0].toString(), iOptions: iOSOptions);
    await secureStorage.write(key: 'gradedCourseCount', value: scholar.gradedCourseCount.toString(), iOptions: iOSOptions);
  } catch(e) {
    return;
  }

}