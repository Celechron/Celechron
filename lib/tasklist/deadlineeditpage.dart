import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/deadline.dart';
import '../utils/utils.dart';

class DeadlineEditPage extends StatefulWidget {
  final Deadline deadline;
  DeadlineEditPage(this.deadline);

  @override
  State<DeadlineEditPage> createState() => _DeadlineEditPageState();
}

class _DeadlineEditPageState extends State<DeadlineEditPage> {
  late Deadline now;
  int __got = 0;

  void saveAndExit() {
    FormState().save();
    now.forceRefreshType();
    Navigator.of(context).pop(now);
  }

  void exitWithoutSave() {
    now = widget.deadline.copyWith();
    Navigator.of(context).pop(now);
  }

  @override
  Widget build(BuildContext context) {
    if (__got == 0) {
      now = widget.deadline.copyWith();
      __got = 1;
    }
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('编辑任务'),
        leading: IconButton(
          tooltip: '放弃更改',
          icon: const Icon(Icons.close),
          onPressed: exitWithoutSave,
        ),
        actions: [
          IconButton(
            tooltip: '保存',
            onPressed: saveAndExit,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Form(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: '任务名',
                ),
                initialValue: now.summary,
                onChanged: (value) {
                  now.summary = value;
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${now.endTime.year} 年 ${now.endTime.month} 月 ${now.endTime.day} 日',
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      var res = await showDatePicker(
                        context: context,
                        initialDate: now.endTime,
                        firstDate: DateTime(2023, 1, 1),
                        lastDate: DateTime(2099, 1, 1),
                      );
                      if (res != null) {
                        setState(() {
                          now.endTime = now.endTime.copyWith(
                            year: res.year,
                            month: res.month,
                            day: res.day,
                          );
                        });
                      }
                    },
                    child: const Text('更改日期'),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    now.endTime.toIso8601String().substring(11, 16),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      var res = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(now.endTime),
                      );
                      if (res != null) {
                        setState(() {
                          now.endTime = now.endTime.copyWith(
                            hour: res.hour,
                            minute: res.minute,
                          );
                        });
                      }
                    },
                    child: const Text('更改时间'),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('预期要做 ${durationToString(now.timeNeeded)}'),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text(
                                '预期用时',
                              ),
                              content: SizedBox(
                                width: double.maxFinite,
                                height: 200,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: CupertinoTimerPicker(
                                        mode: CupertinoTimerPickerMode.hm,
                                        initialTimerDuration: now.timeNeeded,
                                        minuteInterval: 5,
                                        onTimerDurationChanged: (value) {
                                          setState(() {
                                            now.timeNeeded = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          });
                    },
                    child: const Text('调整预期'),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('已经做了 ${durationToString(now.timeSpent)}'),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text(
                                '已经用时',
                              ),
                              content: SizedBox(
                                width: double.maxFinite,
                                height: 200,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: CupertinoTimerPicker(
                                        mode: CupertinoTimerPickerMode.hm,
                                        initialTimerDuration: now.timeSpent,
                                        onTimerDurationChanged: (value) {
                                          setState(() {
                                            now.timeSpent = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          });
                    },
                    child: const Text('调整用时'),
                  ),
                ],
              ),
              TextFormField(
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: '地址',
                ),
                initialValue: now.location,
                onChanged: (value) {
                  now.location = value;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                keyboardType: TextInputType.multiline,
                maxLines: null,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: '说明',
                ),
                initialValue: now.description,
                onChanged: (value) {
                  now.description = value;
                },
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: exitWithoutSave,
                    child: const Text('放弃更改并退出'),
                  ),
                  ElevatedButton(
                    onPressed: saveAndExit,
                    child: const Text('保存更改并退出'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
