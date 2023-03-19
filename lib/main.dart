import 'package:celechron/pages/scholar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'calendar/calendar.dart';
import 'data/user.dart';
import 'flow/flowpage.dart';
import 'tasklist/tasklist.dart';
import 'options/options.dart';
import 'options/optionspage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';

void main() async {
  await Hive.initFlutter();
  options = Options();
  await options.init();
  User user = User();
  await user.loadFromSp();
  initializeDateFormatting().then((_) => runApp(const MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<void> initTimezone() async {
    tz.initializeTimeZones();
    final String locationName = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(locationName));
    print(locationName);
  }

  Future<void> initUser() async {
    // 初始化在这里，打断点看数据（因为不想糊前端页面捏）
    User user = User();
    if (user.isLogin) {
      print("数据加载成功，GPA为${user.gpa[0]}");
      await user.init();
    } else {
      print("数据加载失败");
    }
  }

  @override
  void initState() {
    super.initState();
    initTimezone();
    initUser();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      title: 'Cele',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: const MyHomePage(title: 'Cele'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _indexNum = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          _getPagesWidget(0),
          _getPagesWidget(1),
          _getPagesWidget(2),
          _getPagesWidget(3),
          _getPagesWidget(4),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: '日程',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_view_day_outlined),
            activeIcon: Icon(Icons.calendar_view_day_rounded),
            label: '接下来',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_outlined),
            activeIcon: Icon(Icons.task_rounded),
            label: '任务',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            activeIcon: Icon(Icons.school),
            label: '学业',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_applications_outlined),
            activeIcon: Icon(Icons.settings_applications),
            label: '工具',
          ),
        ],
        iconSize: 24,
        currentIndex: _indexNum,
        type: BottomNavigationBarType.fixed,
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
      const CalendarPage(),
      const FlowPage(),
      const TaskListPage(),
      const ScholarPage(),
      const OptionsPage(),
    ];

    return Offstage(
      offstage: _indexNum != index,
      child: TickerMode(enabled: _indexNum == index, child: widgetList[index]),
    );
  }
}
