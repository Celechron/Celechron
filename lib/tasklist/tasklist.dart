import 'package:celechron/utils/utils.dart';
import 'package:flutter/material.dart';
import '../data/deadline.dart';
import 'deadlineeditpage.dart';

class TaskListPage extends StatefulWidget {
  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  String durationToString(Duration duration) {
    String str = '';
    if (duration.inHours != 0) {
      str = '${duration.inHours} 小时';
    }
    if (duration.inMinutes % 60 != 0 || duration.inHours == 0) {
      if (str != '') str = '$str ';
      str = '$str${duration.inMinutes % 60} 分钟';
    }
    return str;
  }

  String toStringHumanReadable(DateTime dateTime) {
    String str = dateTime.toIso8601String().replaceFirst(RegExp(r'T'), ' ');
    str = str.substring(0, str.length - 7);
    return str;
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
                    '${(deadline.getProgress()).toInt()}%：预期 ${durationToString(deadline.timeNeeded)}，还要 ${durationToString(deadline.timeNeeded - deadline.timeSpent)}',
                    style: const TextStyle(),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    deadline.location,
                    style: const TextStyle(),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    deadline.description,
                  ),
                ],
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
                    Navigator.of(context).pop();
                  }),
                  child: Text(deadline.deadlineType == DeadlineType.running
                      ? '暂停'
                      : '继续'),
                ),
              TextButton(
                onPressed: () => setState(() {
                  print('pushed');
                  Navigator.of(context).pop();
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => DeadlineEditPage(deadline)));
                }),
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
                    '${(deadline.getProgress()).toInt()}%：预期 ${durationToString(deadline.timeNeeded)}，还要 ${durationToString(deadline.timeNeeded - deadline.timeSpent)}',
                    style: const TextStyle(),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    deadline.location,
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
    updateDeadlineList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '任务列表',
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              children:
                  deadlineList.map((e) => createCard(context, e)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
