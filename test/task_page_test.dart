// issue #178 回归用例：
// 1) 任务页空状态必须随任务列表出现/消失，不能滞留在列表上方
// 2) 从任务卡片进入编辑页点“删除任务”应真正删除（与左滑删除共用同一实现）
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/task.dart';
import 'package:celechron/page/flow/flow_controller.dart';
import 'package:celechron/page/task/task_controller.dart';
import 'package:celechron/page/task/task_edit_page.dart';
import 'package:celechron/page/task/task_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeDb extends DatabaseHelper {
  List<Task> stored = <Task>[];
  List<Period> storedFlow = <Period>[];
  DateTime storedTime = DateTime.fromMicrosecondsSinceEpoch(0);

  @override
  List<Task> getTaskList() => stored;

  @override
  Future<void> setTaskList(List<Task> deadlineList) async {
    stored = List<Task>.of(deadlineList);
  }

  @override
  DateTime getTaskListUpdateTime() => storedTime;

  @override
  Future<void> setTaskListUpdateTime(DateTime deadlineListUpdateTime) async {
    storedTime = deadlineListUpdateTime;
  }

  @override
  List<Period> getFlowList() => storedFlow;

  @override
  Future<void> setFlowList(List<Period> flowList) async {
    storedFlow = List<Period>.of(flowList);
  }

  @override
  DateTime getFlowListUpdateTime() => storedTime;

  @override
  Future<void> setFlowListUpdateTime(DateTime flowListUpdateTime) async {
    storedTime = flowListUpdateTime;
  }

  // 重新规划会用到的偏好项，取与 DatabaseHelper 默认值一致的常量。
  @override
  Duration getWorkTime() => const Duration(minutes: 45);

  @override
  Duration getRestTime() => const Duration(minutes: 15);

  @override
  Map<DateTime, DateTime> getAllowTime() => <DateTime, DateTime>{
        DateTime(0, 0, 0, 8, 0): DateTime(0, 0, 0, 11, 35),
        DateTime(0, 0, 0, 14, 15): DateTime(0, 0, 0, 23, 0),
      };
}

Task _testTask({required String summary}) {
  final now = DateTime.now();
  return Task(
    endTime: now.add(const Duration(hours: 1)),
    startTime: now,
    repeatEndsTime: now,
    summary: summary,
  );
}

Iterable<Task> _aliveTasks(RxList<Task> taskList) =>
    taskList.where((element) => element.status != TaskStatus.deleted);

void main() {
  late RxList<Task> taskList;

  setUp(() {
    Get.reset();
    taskList = <Task>[].obs;
    Get.put<DatabaseHelper>(_FakeDb(), tag: 'db');
    Get.put<Rx<Scholar>>(Scholar().obs, tag: 'scholar');
    Get.put<RxList<Period>>(<Period>[].obs, tag: 'flowList');
    Get.put<Rx<DateTime>>(DateTime.now().obs, tag: 'flowListLastUpdate');
    Get.put<RxList<Task>>(taskList, tag: 'taskList');
    Get.put<Rx<DateTime>>(DateTime.now().obs, tag: 'taskListLastUpdate');
  });

  tearDown(() {
    Get.reset();
  });

  // TaskPage 构造出的两个 GetxController 各有一个每秒定时器。flutter_test 在测试体
  // 结束时就会检查 pending timer，晚于 tearDown，所以必须在测试体内部停掉。
  void stopTaskPageTimers() {
    if (Get.isRegistered<TaskController>()) {
      Get.find<TaskController>().onClose();
    }
    if (Get.isRegistered<FlowController>()) {
      Get.find<FlowController>().onClose();
    }
  }

  Future<void> runTaskPageTest(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    try {
      await body();
    } finally {
      stopTaskPageTimers();
    }
  }

  Future<void> pumpTaskPage(WidgetTester tester) async {
    await tester.pumpWidget(CupertinoApp(home: TaskPage()));
    await tester.pump();
  }

  // 页面里有每秒触发的定时器，pumpAndSettle 永远等不到静止，只能按帧推进。
  Future<void> pumpFor(WidgetTester tester, Duration duration) async {
    final int steps = (duration.inMilliseconds / 50).ceil();
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // RoundRectangleCard 的 onTap 是在 onTapDown 之后延迟 125ms（且必须先抬手）才触发的，
  // 与 tester.tap() 的同帧 down+up 不兼容，这里用按住两帧再抬起来模拟真实点击。
  Future<void> tapCard(WidgetTester tester, Finder finder) async {
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await pumpFor(tester, const Duration(milliseconds: 700));
  }

  Future<void> tapDeleteInEditPage(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('删除任务'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('删除任务'));
    await pumpFor(tester, const Duration(milliseconds: 700));
  }

  testWidgets('空状态在新增任务后应当消失', (tester) async {
    await runTaskPageTest(tester, () async {
      await pumpTaskPage(tester);
      expect(find.text('没有任务'), findsOneWidget);

      taskList.add(_testTask(summary: '删除功能'));
      await tester.pump();

      expect(find.text('删除功能'), findsOneWidget, reason: '新任务卡片应当出现');
      expect(find.text('没有任务'), findsNothing, reason: '有任务时不应再显示空状态');
    });
  });

  testWidgets('清空任务后应当重新出现空状态', (tester) async {
    await runTaskPageTest(tester, () async {
      taskList.add(_testTask(summary: '删除功能'));
      await pumpTaskPage(tester);
      expect(find.text('没有任务'), findsNothing);

      await tester.drag(find.text('删除功能'), const Offset(-600, 0));
      await pumpFor(tester, const Duration(milliseconds: 700));

      expect(find.text('删除功能'), findsNothing);
      expect(find.text('没有任务'), findsOneWidget);
    });
  });

  testWidgets('从卡片进入编辑页点“删除任务”应当删除任务', (tester) async {
    await runTaskPageTest(tester, () async {
      taskList.add(_testTask(summary: '删除功能'));
      await pumpTaskPage(tester);

      await tapCard(tester, find.text('删除功能'));
      expect(find.text('编辑任务'), findsOneWidget);

      await tapDeleteInEditPage(tester);

      expect(find.text('编辑任务'), findsNothing, reason: '编辑页应当已经返回上一页');
      expect(
        _aliveTasks(taskList),
        isEmpty,
        reason: '点“删除任务”后任务应当被标记为删除或从列表移除',
      );
    });
  });

  testWidgets('左滑删除仍然有效（与编辑页删除共用实现）', (tester) async {
    await runTaskPageTest(tester, () async {
      taskList.add(_testTask(summary: '删除功能'));
      await pumpTaskPage(tester);

      await tester.drag(find.text('删除功能'), const Offset(-600, 0));
      await pumpFor(tester, const Duration(milliseconds: 700));

      expect(find.text('删除功能'), findsNothing);
      expect(_aliveTasks(taskList), isEmpty);
    });
  });

  testWidgets('对照组：编辑页点“删除任务”确实会返回 status=deleted 的任务', (tester) async {
    await runTaskPageTest(tester, () async {
      final task = _testTask(summary: '删除功能');
      Task? popped;

      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (context) => CupertinoPageScaffold(
              child: CupertinoButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (context) => TaskEditPage(task),
                    ),
                  );
                },
                child: const Text('打开编辑页'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开编辑页'));
      await pumpFor(tester, const Duration(milliseconds: 700));
      expect(find.text('编辑任务'), findsOneWidget);

      await tapDeleteInEditPage(tester);

      expect(popped?.status, TaskStatus.deleted);
    });
  });
}
