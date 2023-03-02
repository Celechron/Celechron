import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'calendar/calendar.dart';
import 'tasklist/tasklist.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  initializeDateFormatting().then((_) => runApp(const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      const Icon(Icons.av_timer),
      TaskListPage(),
      const Icon(Icons.settings),
    ];

    return Offstage(
      offstage: _indexNum != index,
      child: TickerMode(enabled: _indexNum == index, child: widgetList[index]),
    );
  }
}
