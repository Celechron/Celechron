import 'package:celechron/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'calendar/calendar.dart';
import 'flow/flow.dart';
import 'tasklist/tasklist.dart';
import 'options/options.dart';
import 'options/optionspage.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  await Hive.initFlutter();
  options = Options();
  await options.init();
  initializeDateFormatting().then((_) => runApp(const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      locale: Locale('zh'),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!),
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
      CalendarPage(),
      FlowPage(),
      TaskListPage(),
      OptionsPage(),
    ];

    return Offstage(
      offstage: _indexNum != index,
      child: TickerMode(enabled: _indexNum == index, child: widgetList[index]),
    );
  }
}
