import 'package:celechron/utils/utils.dart';
import 'package:flutter/material.dart';
import '../data/deadline.dart';

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

  Card createCard(context, Deadline deadline) {
    String deadlineEnds =
        deadline.endTime.toIso8601String().replaceFirst(RegExp(r'T'), ' ');
    deadlineEnds = deadlineEnds.substring(0, deadlineEnds.length - 7);
    if (deadline.endTime.isBefore(DateTime.now())) {
      deadlineEnds = '$deadlineEnds - 已过期';
    }
    return Card(
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
                  '截止于 $deadlineEnds',
                  style: const TextStyle(),
                ),
                const SizedBox(height: 8.0),
                Text(
                  '${100.00 * deadline.timeSpent.inMicroseconds ~/ deadline.timeNeeded.inMicroseconds}%：预期 ${durationToString(deadline.timeNeeded)}，还要 ${durationToString(deadline.timeNeeded - deadline.timeSpent)}',
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
