import 'dart:async';
import 'dart:io';

import 'package:celechron/page/home_page.dart';
import 'package:celechron/page/option/ecard_pay_page.dart';
import 'package:celechron/utils/utils.dart';
import 'package:celechron/worker/ecard_widget_messenger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:app_links/app_links.dart';

import 'package:celechron/model/scholar.dart';
import 'package:celechron/database/database_helper.dart';

import 'model/option.dart'; // 确保导入了控制器

void main() async {
  // 初始化数据库
  await Hive.initFlutter();
  var db = Get.put(DatabaseHelper(), tag: 'db');
  await db.init();

  // 注入数据观察项（相当于事件总线，更新这些变量将导致Widget重绘
  Get.put((await db.getScholar()).obs, tag: 'scholar');
  Get.put(db.getTaskList().obs, tag: 'taskList');
  Get.put(db.getTaskListUpdateTime().obs, tag: 'taskListLastUpdate');
  Get.put(db.getFlowList().obs, tag: 'flowList');
  Get.put(db.getFlowListUpdateTime().obs, tag: 'flowListLastUpdate');
  Get.put(db.getOption(), tag: 'option');
  Get.put(db.getFuse().obs, tag: 'fuse');

  runApp(const CelechronApp());

  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    if(uri.toString() == 'celechron://ecardpaypage') {
      navigator?.popUntil((route) => !(route.settings.name?.endsWith('ecardpaypage') ?? false));
      navigator?.pushNamed('/ecardpaypage');
    }
  });

  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    var brightnessMode = Get.find<Option>(tag: 'option').brightnessMode;
    var dispatcher = SchedulerBinding.instance.platformDispatcher;

    ever(brightnessMode, (mode) {
      if (mode == BrightnessMode.system) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarIconBrightness: dispatcher.platformBrightness == Brightness.light ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
        ));
        dispatcher.onPlatformBrightnessChanged = () {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarIconBrightness: dispatcher.platformBrightness == Brightness.light ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
          ));
        };
      } else {
        dispatcher.onPlatformBrightnessChanged = null;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarIconBrightness: mode == BrightnessMode.light ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
        ));
      }
    });

    brightnessMode.refresh();
  }

  Future<void> initTimezone() async {}

  Future<void> initScholar() async {
    var scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
    if (scholar.value.isLogan) {
      await scholar.value.login();
      await scholar.value.refresh();
      scholar.refresh();
    }
  }
  
  initTimezone();
  initScholar();
  ECardWidgetMessenger.update();

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  const initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  const initializationSettingsDarwin = DarwinInitializationSettings(
    requestSoundPermission: true,
    requestBadgePermission: true,
    requestAlertPermission: true,
  );
  const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin);
  flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

class CelechronApp extends StatefulWidget {
  const CelechronApp({super.key});

  @override
  State<CelechronApp> createState() => _CelechronAppState();
}

class _CelechronAppState extends State<CelechronApp> {
  @override
  Widget build(BuildContext context) {
    var brightnessMode = Get.find<Option>(tag: 'option').brightnessMode;
    return Obx(() => GetCupertinoApp(
      theme: CupertinoThemeData(
        brightness: brightnessMode.value == BrightnessMode.system
            ? null
            : brightnessMode.value == BrightnessMode.dark
            ? Brightness.dark
            : Brightness.light,
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
        barBackgroundColor: CupertinoColors.systemBackground,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh'),
        Locale('en'),
      ],
      locale: const Locale('zh'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
      title: 'Celechron',
      home: const HomePage(title: 'Celechron'),
      initialRoute: '/',
      routes: {
        '/ecardpaypage': (context) => ECardPayPage(),
      },
    ));
  }
}
