import 'package:celechron/utils/utils.dart';
import 'package:flutter/material.dart';
import '../../model/deadline.dart';
import './deadlineeditpage.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
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
                onPressed: () => setState(() {
                  if (deadline.deadlineType != DeadlineType.completed) {
                    deadline.deadlineType = DeadlineType.completed;
                  } else {
                    deadline.forceRefreshType();
                  }
                  updateDeadlineListTime();
                  Navigator.of(context).pop();
                }),
                child: Text(
                    '标记为${deadline.deadlineType == DeadlineType.completed ? '未' : ''}完成'),
              ),
              if (deadline.deadlineType == DeadlineType.running ||
                  deadline.deadlineType == DeadlineType.suspended)
                TextButton(
                  onPressed: () => setState(() {
                    if (deadline.deadlineType == DeadlineType.running) {
                      deadline.deadlineType = DeadlineType.suspended;
                    } else {
                      deadline.deadlineType = DeadlineType.running;
                    }
                    updateDeadlineListTime();
                    Navigator.of(context).pop();
                  }),
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
                    updateDeadlineListTime();
                  }
                  setState(() {
                    deadline.uid = res.uid;
                    deadline.summary = res.summary;
                    deadline.description = res.description;
                    deadline.timeSpent = res.timeSpent;
                    deadline.timeNeeded = res.timeNeeded;
                    deadline.endTime = res.endTime;
                    deadline.location = res.location;
                    deadline.deadlineType = res.deadlineType;
                    deadline.isBreakable = res.isBreakable;
                  });
                },
                child: const Text('编辑'),
              ),
            ],
          );
        });
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

  Future<void> newDeadline(context) async {
    Deadline? deadline = Deadline();
    deadline.reset();
    Deadline? res = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => DeadlineEditPage(deadline)));
    if (res != null) {
      deadlineList.add(res);
      updateDeadlineListTime();
    }
  }

  void removeCompletedDeadline(context) {
    deadlineList.removeWhere(
        (element) => element.deadlineType == DeadlineType.completed);
  }

  void removeFailedDeadline(context) {
    deadlineList
        .removeWhere((element) => element.deadlineType == DeadlineType.failed);
  }

  @override
  Widget build(BuildContext context) {
    setState(() {});
    updateDeadlineList();

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
                removeCompletedDeadline(context);
              } else if (result == 2) {
                removeFailedDeadline(context);
              }

              setState(() {
                updateDeadlineList();
              });
            },
            icon: const Icon(Icons.menu),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (deadlineList.isEmpty) ...[
            const Expanded(
              child: Center(
                child: Text('没有任务'),
              ),
            ),
          ] else ...[
            Expanded(
              child: ListView(
                children:
                    deadlineList.map((e) => createCard(context, e)).toList(),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
