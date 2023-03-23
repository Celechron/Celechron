import 'package:celechron/page/task/task_controller.dart';
import 'package:celechron/utils/utils.dart';
import 'package:flutter/material.dart';
import '../../model/deadline.dart';
import './deadlineeditpage.dart';
import 'dart:async';
import 'package:get/get.dart';

class TaskPage extends StatelessWidget {
  TaskPage({super.key});

  final _taskController = Get.put(TaskController());

  String deadlineProgress(Deadline deadline) {
    return '${(deadline.getProgress()).toInt()}%：预期 ${durationToString(deadline.timeNeeded)}，还要 ${durationToString(deadline.timeNeeded <= deadline.timeSpent ? Duration.zero : (deadline.timeNeeded - deadline.timeSpent))}';
  }

  Future<void> showCardDialog(BuildContext context, Deadline deadline) async {
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Text(
                  deadline.summary,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      deadlineTypeName[deadline.deadlineType]!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      '截止于 ${toStringHumanReadable(deadline.endTime)}${deadline.endTime.isBefore(DateTime.now()) ? ' - 已过期' : ''}',
                      style: const TextStyle(),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      deadlineProgress(deadline),
                      style: const TextStyle(),
                    ),
                    if (deadline.location.isNotEmpty) ...[
                      const SizedBox(height: 8.0),
                      Text(
                        deadline.location,
                        style: const TextStyle(),
                      ),
                    ],
                    if (deadline.description.isNotEmpty) ...[
                      const SizedBox(height: 8.0),
                      Text(
                        deadline.description,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回'),
              ),
              TextButton(
                onPressed: () {
                  if (deadline.deadlineType != DeadlineType.completed) {
                    deadline.deadlineType = DeadlineType.completed;
                  } else {
                    deadline.forceRefreshType();
                  }
                  _taskController.updateDeadlineListTime();
                  _taskController.deadlineList.refresh();
                  Navigator.of(context).pop();
                },
                child: Text(
                    '标记为${deadline.deadlineType == DeadlineType.completed ? '未' : ''}完成'),
              ),
              if (deadline.deadlineType == DeadlineType.running ||
                  deadline.deadlineType == DeadlineType.suspended)
                TextButton(
                  onPressed: () {
                    if (deadline.deadlineType == DeadlineType.running) {
                      deadline.deadlineType = DeadlineType.suspended;
                    } else {
                      deadline.deadlineType = DeadlineType.running;
                    }
                    _taskController.updateDeadlineListTime();
                    _taskController.deadlineList.refresh();
                    Navigator.of(context).pop();
                  },
                  child: Text(deadline.deadlineType == DeadlineType.running
                      ? '暂停'
                      : '继续'),
                ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  Deadline res = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  DeadlineEditPage(deadline))) ??
                      deadline;
                  if (deadline != res) {
                    _taskController.updateDeadlineListTime();
                  }
                  deadline.uid = res.uid;
                  deadline.summary = res.summary;
                  deadline.description = res.description;
                  deadline.timeSpent = res.timeSpent;
                  deadline.timeNeeded = res.timeNeeded;
                  deadline.endTime = res.endTime;
                  deadline.location = res.location;
                  deadline.deadlineType = res.deadlineType;
                  deadline.isBreakable = res.isBreakable;
                  _taskController.updateDeadlineList();
                  _taskController.updateDeadlineListTime();
                  _taskController.deadlineList.refresh();
                },
                child: const Text('编辑'),
              ),
            ],
          );
        });
  }

  Future<void> newDeadline(context) async {
    Deadline? deadline = Deadline();
    deadline.reset();
    Deadline? res = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => DeadlineEditPage(deadline)));
    if (res != null) {
      _taskController.deadlineList.add(res);
      _taskController.updateDeadlineListTime();
    }
  }

  Widget createCard(context, Deadline deadline) {
    String deadlineEnds =
        deadline.endTime.toIso8601String().replaceFirst(RegExp(r'T'), ' ');
    deadlineEnds = deadlineEnds.substring(0, deadlineEnds.length - 7);
    if (deadline.endTime.isBefore(DateTime.now())) {
      deadlineEnds = '$deadlineEnds - 已过期';
    }
    return GestureDetector(
      onTap: () => showCardDialog(context, deadline),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        deadline.summary,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          deadlineTypeName[deadline.deadlineType]!,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    '截止于 ${toStringHumanReadable(deadline.endTime)}${deadline.endTime.isBefore(DateTime.now()) ? ' - 已过期' : ''}',
                    style: const TextStyle(),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    deadlineProgress(deadline),
                    style: const TextStyle(),
                  ),
                  if (deadline.location.isNotEmpty) ...[
                    const SizedBox(height: 8.0),
                    Text(
                      deadline.location,
                      style: const TextStyle(),
                    ),
                  ],
                  const SizedBox(height: 8.0),
                  Text(
                    deadline.uid,
                    style: const TextStyle(),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '任务列表',
        ),
        actions: [
          PopupMenuButton(
            tooltip: '保存',
            itemBuilder: (context) => <PopupMenuEntry>[
              const PopupMenuItem(
                value: 0,
                child: Text('新建任务'),
              ),
              const PopupMenuItem(
                value: 1,
                child: Text('移除已完成任务'),
              ),
              const PopupMenuItem(
                value: 2,
                child: Text('移除已过期任务'),
              ),
            ],
            onSelected: (result) async {
              if (result == 0) {
                await newDeadline(context);
              } else if (result == 1) {
                _taskController.removeCompletedDeadline(context);
              } else if (result == 2) {
                _taskController.removeFailedDeadline(context);
              }
              _taskController.updateDeadlineList();
              _taskController.deadlineList.refresh();
            },
            icon: const Icon(Icons.menu),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            if (_taskController.deadlineList.isEmpty) {
              return const Expanded(
                child: Center(
                  child: Text('没有任务'),
                ),
              );
            } else {
              return Expanded(
                child: ListView(
                  children: _taskController.deadlineList
                      .map((e) => createCard(context, e))
                      .toList(),
                ),
              );
            }
          })
        ],
      ),
    );
  }
}
