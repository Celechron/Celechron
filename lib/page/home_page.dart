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
  double _horizontalDragDistance = 0.0; // 跟踪水平拖动距离

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

    return Offstage(
      offstage: _indexNum != index,
      child: TickerMode(
        enabled: _indexNum == index,
        child: GestureDetector(
          // 使用 onHorizontalDrag 专门处理水平滑动，不会干扰垂直滚动
          onHorizontalDragStart: (_) {
            // 初始化拖动距离
            _horizontalDragDistance = 0.0;
          },
          onHorizontalDragUpdate: (details) {
            // 累积水平拖动距离
            _horizontalDragDistance += details.delta.dx;
          },
          onHorizontalDragEnd: (details) {
            // 根据滑动速度和距离判断是否切换页面
            final screenWidth = MediaQuery.of(context).size.width;
            final velocity = details.primaryVelocity ?? 0;
            final threshold = screenWidth * 0.15; // 滑动距离阈值（屏幕宽度的15%）

            // 向右滑动（显示左侧页面）- 向右滑动意味着显示前一个页面
            if (velocity > 200 || _horizontalDragDistance > threshold) {
              if (_indexNum > 0) {
                changeIndex(_indexNum - 1);
              }
            }
            // 向左滑动（显示右侧页面）- 向左滑动意味着显示后一个页面
            else if (velocity < -200 || _horizontalDragDistance < -threshold) {
              if (_indexNum < 4) {
                changeIndex(_indexNum + 1);
              }
            }
            // 重置状态
            _horizontalDragDistance = 0.0;
          },
          onHorizontalDragCancel: () {
            // 取消时重置状态
            _horizontalDragDistance = 0.0;
          },
          // 使用 deferToChild 让子组件的垂直滚动优先处理
          behavior: HitTestBehavior.deferToChild,
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
      if (!mounted) return;
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
