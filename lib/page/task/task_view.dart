import 'package:celechron/design/custom_decoration.dart';
import 'package:celechron/page/flow/flow_controller.dart';
import 'package:celechron/page/task/task_controller.dart';
import 'package:celechron/utils/utils.dart';
import 'package:celechron/design/sub_title.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/design/custom_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:celechron/model/deadline.dart';
import 'task_edit_page.dart';
import 'dart:async';
import 'package:get/get.dart';

class TaskPage extends StatelessWidget {
  TaskPage({super.key});

  final _taskController = Get.put(TaskController());
  final _flowController = Get.put(FlowController());

  String deadlineProgress(Deadline deadline) {
    return '${(deadline.getProgress() * 100).toInt()}% 已完成：预期 ${durationToString(deadline.timeNeeded)}，还要 ${durationToString(deadline.timeNeeded <= deadline.timeSpent ? Duration.zero : (deadline.timeNeeded - deadline.timeSpent))}';
  }

  Future<void> showCardDialog(BuildContext context, Deadline deadline) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(
            '${deadline.summary}：${deadline.deadlineType == DeadlineType.normal ? deadlineStatusName[deadline.deadlineStatus]! : deadline.deadlineType == DeadlineType.fixed ? deadlineTypeName[DeadlineType.fixed] : ''}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (deadline.deadlineType == DeadlineType.fixed) ...[
                    Text(
                      '开始于 ${toStringHumanReadable(deadline.startTime)}',
                    ),
                    Text(
                      '结束于 ${toStringHumanReadable(deadline.endTime)}',
                    ),
                  ],
                  if (deadline.deadlineType == DeadlineType.normal) ...[
                    Text(
                      '截止于 ${toStringHumanReadable(deadline.endTime)}${deadline.endTime.isBefore(DateTime.now()) ? ' - 已过期' : ''}',
                    ),
                    Text(
                      deadlineProgress(deadline),
                    ),
                  ],
                  if (deadline.location.isNotEmpty) ...[
                    Text(
                      '地点：${deadline.location}',
                    ),
                  ],
                  if (deadline.description.isNotEmpty) ...[
                    Text(
                      '说明：${deadline.description}',
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
            if (deadline.deadlineType == DeadlineType.normal &&
                deadline.timeSpent < deadline.timeNeeded)
              CupertinoDialogAction(
                onPressed: () {
                  if (deadline.deadlineStatus != DeadlineStatus.completed) {
                    deadline.deadlineStatus = DeadlineStatus.completed;
                  } else {
                    deadline.forceRefreshStatus();
                  }
                  _taskController.updateDeadlineListTime();
                  _taskController.deadlineList.refresh();
                  Navigator.of(context).pop();
                },
                child: Text(
                    '标记为${deadline.deadlineStatus == DeadlineStatus.completed ? '未' : ''}完成'),
              ),
            if (deadline.deadlineType == DeadlineType.normal &&
                (deadline.deadlineStatus == DeadlineStatus.running ||
                    deadline.deadlineStatus == DeadlineStatus.suspended))
              CupertinoDialogAction(
                onPressed: () {
                  if (deadline.deadlineStatus == DeadlineStatus.running) {
                    deadline.deadlineStatus = DeadlineStatus.suspended;
                  } else {
                    deadline.deadlineStatus = DeadlineStatus.running;
                  }
                  _taskController.updateDeadlineListTime();
                  _taskController.deadlineList.refresh();
                  Navigator.of(context).pop();
                },
                child: Text(deadline.deadlineStatus == DeadlineStatus.running
                    ? '暂停'
                    : '继续'),
              ),
            if (deadline.deadlineType == DeadlineType.normal ||
                deadline.deadlineType == DeadlineType.fixed)
              CupertinoDialogAction(
                onPressed: () async {
                  Navigator.of(context).pop();
                  Deadline res = await showCupertinoModalPopup(
                        context: context,
                        builder: (BuildContext context) {
                          return TaskEditPage(deadline);
                        },
                      ) ??
                      deadline;
                  bool needUpdate = deadline.differentForFlow(res);
                  deadline.copy(res);
                  _taskController.updateDeadlineList();
                  if (needUpdate) {
                    _taskController.updateDeadlineListTime();
                  }
                  _taskController.deadlineList.refresh();
                },
                child: const Text('编辑'),
              ),
            if (deadline.deadlineType == DeadlineType.fixedlegacy)
              CupertinoDialogAction(
                onPressed: () async {
                  Navigator.of(context).pop();
                  deadline.deadlineStatus = DeadlineStatus.deleted;
                  _taskController.updateDeadlineList();
                  _taskController.deadlineList.refresh();
                },
                child: const Text('删除'),
              ),
          ],
        );
      },
    );
  }

  Future<void> newDeadline(context) async {
    DateTime time = DateTime.now();
    Deadline? deadline = Deadline(
      endTime: time,
      startTime: time,
      deadlineRepeatEndsTime: time,
    );
    deadline.reset();
    Deadline? res = await showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return TaskEditPage(deadline);
      },
    );
    if (res != null && res.deadlineStatus != DeadlineStatus.deleted) {
      _taskController.deadlineList.add(res);
      _taskController.updateDeadlineListTime();
      _taskController.deadlineList.refresh();
    }
  }

  Widget createCard(context, Deadline deadline, Color color, String? title) {
    double progress = deadline.getProgress();

    return Column(
      children: [
        title == null
            ? const SizedBox(height: 0)
            : SubtitleRow(subtitle: title),
        RoundRectangleCard(
          onTap: () => showCardDialog(context, deadline),
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12.0,
                      height: 12.0,
                      decoration: customDecoration(
                        color: color,
                        shape: periodTypeShape[PeriodType.user]!,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                        flex: 4,
                        child: Text(deadline.summary,
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  overflow: TextOverflow.ellipsis,
                                ))),
                    const Spacer(),
                    Text(
                        deadline.deadlineType == DeadlineType.normal
                            ? deadlineStatusName[deadline.deadlineStatus]!
                            : (DateTime.now().isBefore(deadline.startTime)
                                ? '未开始'
                                : (!DateTime.now().isBefore(deadline.endTime)
                                    ? '已结束'
                                    : '进行中')),
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              overflow: TextOverflow.ellipsis,
                            )),
                  ],
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.time_solid,
                      size: 14,
                      color: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .color!
                          .withOpacity(0.5),
                    ),
                    Expanded(
                      child: Text(
                        deadline.deadlineType == DeadlineType.fixed
                            ? ' 开始于：${toStringHumanReadable(deadline.startTime)}'
                            : ' 截止于：${toStringHumanReadable(deadline.endTime)}${deadline.endTime.isBefore(DateTime.now()) ? ' - 已过期' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
                              .color!
                              .withOpacity(0.75),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                if (deadline.deadlineType == DeadlineType.fixed) ...[
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.time,
                        size: 14,
                        color: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .color!
                            .withOpacity(0.5),
                      ),
                      Expanded(
                        child: Text(
                          ' 结束于：${toStringHumanReadable(deadline.endTime)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .color!
                                .withOpacity(0.75),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (deadline.location.isNotEmpty) ...[
                  Row(children: [
                    Icon(
                      CupertinoIcons.location_solid,
                      size: 14,
                      color: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .color!
                          .withOpacity(0.5),
                    ),
                    Expanded(
                        child: Text(' 地点：${deadline.location}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .color!
                                  .withOpacity(0.75),
                              overflow: TextOverflow.ellipsis,
                            )))
                  ]),
                ],
                if (deadline.deadlineType == DeadlineType.normal)
                  Row(children: [
                    Icon(
                      CupertinoIcons.play_fill,
                      size: 14,
                      color: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .color!
                          .withOpacity(0.5),
                    ),
                    Expanded(
                        child: Text(deadlineProgress(deadline),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .color!
                                  .withOpacity(0.75),
                              overflow: TextOverflow.ellipsis,
                            ))),
                  ]),
                if (deadline.deadlineType == DeadlineType.fixed ||
                    deadline.deadlineStatus == DeadlineStatus.running) ...[
                  const SizedBox(height: 8.0),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: CupertinoDynamicColor.resolve(
                        CupertinoColors.separator, context),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ],
                if (deadline.deadlineType == DeadlineType.normal &&
                    deadline.deadlineStatus == DeadlineStatus.suspended) ...[
                  const SizedBox(height: 8.0),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: CupertinoDynamicColor.resolve(
                        CupertinoColors.separator, context),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ],
                if (deadline.deadlineType == DeadlineType.normal &&
                    deadline.deadlineStatus == DeadlineStatus.completed) ...[
                  const SizedBox(height: 8.0),
                  LinearProgressIndicator(
                    value: 1,
                    backgroundColor: CupertinoDynamicColor.resolve(
                        CupertinoColors.separator, context),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ],
                if (deadline.deadlineType == DeadlineType.normal &&
                    deadline.deadlineStatus == DeadlineStatus.failed) ...[
                  const SizedBox(height: 8.0),
                  LinearProgressIndicator(
                    value: 0,
                    backgroundColor: CupertinoDynamicColor.resolve(
                        CupertinoColors.separator, context),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('任务'),
              border: null,
              stretch: true,
              trailing: // Two buttons in the nav bar.
                  Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(
                      CupertinoIcons.add_circled,
                      semanticLabel: 'Add',
                    ),
                    onPressed: () async {
                      await newDeadline(context);
                      _taskController.updateDeadlineList();
                      _taskController.deadlineList.refresh();
                    },
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(
                      CupertinoIcons.ellipsis_circle,
                      semanticLabel: 'More',
                    ),
                    onPressed: () async {
                      await showCupertinoModalPopup(
                        context: context,
                        builder: (BuildContext context) => CupertinoActionSheet(
                          actions: <Widget>[
                            CupertinoActionSheetAction(
                              child: const Text('删除已完成任务'),
                              onPressed: () async {
                                _taskController
                                    .removeCompletedDeadline(context);
                                _taskController.updateDeadlineList();
                                _taskController.deadlineList.refresh();
                                Navigator.of(context).pop();
                              },
                            ),
                            CupertinoActionSheetAction(
                              child: const Text('删除已过期任务'),
                              onPressed: () async {
                                _taskController.removeFailedDeadline(context);
                                _taskController.updateDeadlineList();
                                _taskController.deadlineList.refresh();
                                Navigator.of(context).pop();
                              },
                            ),
                            CupertinoActionSheetAction(
                              child: const Text('暂停所有任务'),
                              onPressed: () {
                                if (_taskController
                                        .suspendAllDeadline(context) >
                                    0) {
                                  _flowController.removeFlowInFlowList();
                                  _taskController.updateDeadlineListTime();
                                  _taskController.deadlineList.refresh();
                                }
                                Navigator.of(context).pop();
                              },
                            ),
                            CupertinoActionSheetAction(
                              child: const Text('继续所有任务'),
                              onPressed: () {
                                if (_taskController
                                        .continueAllDeadline(context) >
                                    0) {
                                  _flowController.removeFlowInFlowList();
                                  _taskController.updateDeadlineListTime();
                                  _taskController.deadlineList.refresh();
                                }
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            isDefaultAction: true,
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('取消'),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Obx(
              () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Container(
                      padding: EdgeInsets.only(
                        top: index == 0 ? 0 : 5,
                        bottom: 5,
                        left: 16,
                        right: 16,
                      ),
                      child: createCard(
                          context,
                          _taskController.todoDeadlineList[index],
                          UidColors.colorFromUid(
                              _taskController.todoDeadlineList[index].uid),
                          index == 0 ? '待办' : null),
                    );
                  },
                  childCount: _taskController.todoDeadlineList.length,
                ),
              ),
            ),
            Obx(
              () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Container(
                      padding: EdgeInsets.only(
                        top: index == 0 ? 0 : 5,
                        bottom: 5,
                        left: 16,
                        right: 16,
                      ),
                      child: createCard(
                          context,
                          _taskController.doneDeadlineList[index],
                          UidColors.colorFromUid(
                              _taskController.doneDeadlineList[index].uid),
                          index == 0 ? '已完成' : null),
                    );
                  },
                  childCount: _taskController.doneDeadlineList.length,
                ),
              ),
            ),
            Obx(
              () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Container(
                      padding: EdgeInsets.only(
                        top: index == 0 ? 0 : 5,
                        bottom: 5,
                        left: 16,
                        right: 16,
                      ),
                      child: createCard(
                          context,
                          _taskController.fixedDeadlineList[index],
                          UidColors.colorFromUid(
                              _taskController.fixedDeadlineList[index].uid),
                          index == 0 ? '日程列表' : null),
                    );
                  },
                  childCount: _taskController.fixedDeadlineList.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                height: 100,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskPageColors {
  static const List<CupertinoDynamicColor> taskMarkColors = [
    spring,
    summer,
    winter,
    violet,
    sakura,
    cyan,
    magenta,
    peach,
    okGreen,
  ];

  static const CupertinoDynamicColor spring =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 255, 226, 1.0),
    darkColor: Color.fromRGBO(147, 251, 56, 1.0),
  );

  static const CupertinoDynamicColor summer =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 226, 226, 1.0),
    darkColor: Color.fromRGBO(255, 25, 69, 1.0),
  );

  static const CupertinoDynamicColor autumn =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 234, 230, 1.0),
    darkColor: Color.fromRGBO(255, 101, 56, 1.0),
  );

  static const CupertinoDynamicColor winter =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(226, 239, 255, 1.0),
    darkColor: Color.fromRGBO(0, 183, 251, 1.0),
  );

  static const CupertinoDynamicColor violet =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 229, 255, 1.0),
    darkColor: Color.fromRGBO(151, 131, 216, 1.0),
  );

  static const CupertinoDynamicColor sakura =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 226, 255, 1.0),
    darkColor: Color.fromRGBO(218, 130, 217, 1.0),
  );

  static const CupertinoDynamicColor sand =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 246, 211, 1.0),
    darkColor: Color.fromRGBO(252, 222, 59, 1.0),
  );

  static const CupertinoDynamicColor cyan =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(218, 234, 255, 1.0),
    darkColor: Color.fromRGBO(0, 140, 255, 1.0),
  );

  static const CupertinoDynamicColor magenta =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 229, 255, 1.0),
    darkColor: Color.fromRGBO(238, 55, 161, 1.0),
  );

  static const CupertinoDynamicColor peach =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 235, 226, 1.0),
    darkColor: Color.fromRGBO(233, 114, 70, 1.0),
  );

  static const CupertinoDynamicColor okGreen =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 255, 226, 1.0),
    darkColor: Color.fromRGBO(63, 222, 23, 1.0),
  );
}
