import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:celechron/page/scholar/scholar_view.dart';
import 'package:celechron/page/search/search_view.dart';
import 'package:celechron/page/flow/flow_view.dart';
import 'package:celechron/page/task/task_view.dart';
import 'package:celechron/page/calendar/calendar_view.dart';
import 'package:celechron/page/option/option_view.dart';

import 'package:celechron/worker/fuse.dart';


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
            .withOpacity(0.5),
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