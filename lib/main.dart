import 'dart:async';
import 'dart:io';

import 'package:celechron/page/option/ecard_pay_page.dart';
import 'package:celechron/worker/ecard_widget_messenger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Icons;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:app_links/app_links.dart';

import 'package:celechron/page/scholar/scholar_view.dart';
import 'package:celechron/page/search/search_view.dart';
import 'package:celechron/page/flow/flow_view.dart';
import 'package:celechron/page/task/task_view.dart';
import 'package:celechron/page/calendar/calendar_view.dart';
import 'package:celechron/page/option/option_view.dart';

import 'package:celechron/model/scholar.dart';
import 'package:celechron/worker/fuse.dart';
import 'package:celechron/database/database_helper.dart';

void main() async {
  // 从数据库读取数据
  await Hive.initFlutter();

  // 注入数据库
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
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness:
          SchedulerBinding.instance.platformDispatcher.platformBrightness ==
                  Brightness.dark
              ? Brightness.light
              : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ));
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
    return GetCupertinoApp(
      theme: const CupertinoThemeData(
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
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _indexNum = 0;
  final CupertinoTabController _controller = CupertinoTabController();

  @override
  void initState() {
    super.initState();
    _controller.index = 0;
    initFuse();
  }

  void changeIndex(int index) {
    if (_indexNum != index) {
      setState(() {
        _indexNum = index;
        _controller.index = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _controller,
      tabBuilder: (context, index) => CupertinoTabView(
        builder: (context) => _getPagesWidget(index),
      ),
      tabBar: CupertinoTabBar(
        iconSize: 26,
        backgroundColor: CupertinoDynamicColor.resolve(
                CupertinoColors.secondarySystemBackground, context)
            .withValues(alpha: 0.5),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.time),
            label: '接下来',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            label: '日程',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.check_mark),
            label: '任务',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_rounded),
            label: '学业',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: '设置',
          ),
        ],
        currentIndex: _indexNum,
        onTap: (int index) {
          if (index != _indexNum) {
            setState(() {
              _indexNum = index;
            });
          }
        },
      ),
    );
  }

  Widget _getPagesWidget(int index) {
    List<Widget> widgetList = [
      FlowPage(),
      CalendarPage(),
      TaskPage(),
      ScholarPage(),
      OptionPage(),
      SearchPage(), // 缓存一下
    ];

    if (Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarIconBrightness:
            SchedulerBinding.instance.platformDispatcher.platformBrightness ==
                    Brightness.dark
                ? Brightness.light
                : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
      ));
    }
    String? swipeDirection;
    return Offstage(
      offstage: _indexNum != index,
      child: TickerMode(
        enabled: _indexNum == index,
        child: GestureDetector(
          onPanUpdate: (details) {
            int sensitivity = 4;
            if (details.delta.dy > sensitivity / 2 ||
                details.delta.dy < -sensitivity / 2) {
              return;
            }
            if (details.delta.dx > sensitivity) {
              swipeDirection = 'right';
            } else if (details.delta.dx < -sensitivity) {
              swipeDirection = 'left';
            }
          },
          onPanEnd: (details) {
            if (swipeDirection == null) {
              return;
            }
            if (swipeDirection == 'left') {
              if (_indexNum < 4) {
                changeIndex(_indexNum + 1);
              }
            }
            if (swipeDirection == 'right') {
              if (_indexNum > 0) {
                changeIndex(_indexNum - 1);
              }
            }
          },
          child: widgetList[index],
        ),
      ),
    );
  }

  Future<void> initFuse() async {
    await Future.delayed(const Duration(seconds: 1));
    var fuse = Get.find<Rx<Fuse>>(tag: 'fuse');
    var response =
        await fuse.value.checkUpdate().whenComplete(() => fuse.refresh());
    if (response != null) {
      if (context.mounted) {
        showCupertinoDialog(
            context: context,
            builder: (context) {
              return CupertinoAlertDialog(
                title: const Text('更新可用'),
                content: Text(response),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('忽略'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                    },
                  ),
                  CupertinoDialogAction(
                    child: const Text('访问网站'),
                    onPressed: () async {
                      await launchUrlString(
                        'https://celechron.top',
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                ],
              );
            });
      }
    }
  }
}
