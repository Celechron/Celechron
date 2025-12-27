import 'dart:io';

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
import 'package:celechron/model/option.dart';
import 'package:celechron/page/home_page.dart';
import 'package:celechron/page/option/ecard_pay_page.dart';
import 'package:celechron/worker/ecard_widget_messenger.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/utils/global.dart';

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

  var scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  if (scholar.value.isLogan) {
    scholar.value.login().then((value) async {
      GlobalStatus.isFirstScreenReq = true;
      await scholar.value.refresh();
      GlobalStatus.isFirstScreenReq = false;
    }).then((value) => scholar.refresh());
  }

  ECardWidgetMessenger.update();
}

class CelechronApp extends StatefulWidget {
  const CelechronApp({super.key});

  @override
  State<CelechronApp> createState() => _CelechronAppState();
}

class _CelechronAppState extends State<CelechronApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 监听AppLinks，用于跳转至付款码页面
    _initAppLinks();
    // 初始化通知
    _initNotification();
    // 设置Android状态栏和导航栏样式
    if (Platform.isAndroid) {
      _initStatusBar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ECardWidgetMessenger.update();
    }
  }

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
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
        ));
  }

  void _initAppLinks() {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen((uri) {
      if (uri.toString() == 'celechron://ecardpaypage') {
        navigator?.popUntil((route) =>
            !(route.settings.name?.endsWith('ecardpaypage') ?? false));
        navigator?.pushNamed('/ecardpaypage');
      }
    });
  }

  void _initStatusBar() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    var brightnessMode = Get.find<Option>(tag: 'option').brightnessMode;
    var dispatcher = SchedulerBinding.instance.platformDispatcher;

    ever(brightnessMode, (mode) {
      if (mode == BrightnessMode.system) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarIconBrightness:
              dispatcher.platformBrightness == Brightness.light
                  ? Brightness.dark
                  : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
        ));
        dispatcher.onPlatformBrightnessChanged = () {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarIconBrightness:
                dispatcher.platformBrightness == Brightness.light
                    ? Brightness.dark
                    : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
          ));
        };
      } else {
        dispatcher.onPlatformBrightnessChanged = null;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarIconBrightness:
              mode == BrightnessMode.light ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
        ));
      }
    });
    brightnessMode.refresh();
  }

  void _initNotification() {
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    const initializationSettingsDarwin = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    // const initializationSettingsWindows = WindowsInitializationSettings(
    //     appName: 'Celechron',
    //     appUserModelId: 'top.celechron.app',
    //     guid: '7c85e25b-fa7d-489e-9b10-b4c22a3458f0');
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      // windows: initializationSettingsWindows);
    );
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }
}
