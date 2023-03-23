import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../database/database_helper.dart';
import '../../model/period.dart';
import '../../utils/utils.dart';

import 'flow_controller.dart';

class FlowPage extends StatelessWidget {
  FlowPage({super.key});

  final _flowController = Get.put(FlowController());
  final db = Get.find<DatabaseHelper>(tag: 'db');

  Widget createCard(context, Period period) {
    return GestureDetector(
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
                        period.summary,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    toStringHumanReadable(period.startTime),
                    style: const TextStyle(),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    toStringHumanReadable(period.endTime),
                    style: const TextStyle(),
                  ),
                  if (period.location.isNotEmpty) ...[
                    const SizedBox(height: 8.0),
                    Text(
                      period.location,
                      style: const TextStyle(),
                    ),
                  ],
                  if (period.periodType == PeriodType.flow) ...[
                    const SizedBox(height: 8.0),
                    Text(
                      period.uid,
                      style: const TextStyle(),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      '来自 ${period.fromUid}',
                      style: const TextStyle(),
                    ),
                  ],
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> newFlowList(context) async {
    DateTime newTime = DateTime.now();

    await showDialog(
        context: context,
        builder: (BuildContext context) {
          DateTime time = DateTime.now()
              .copyWith(second: 0, millisecond: 0, microsecond: 0)
              .add(const Duration(minutes: 2));
          newTime = time;

          return AlertDialog(
            title: const Text(
              '选择规划开始时间',
            ),
            content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return SizedBox(
                  width: double.maxFinite,
                  height: 170,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${time.year} 年 ${time.month} 月 ${time.day} 日',
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              var res = await showDatePicker(
                                context: context,
                                initialDate: time,
                                firstDate: DateTime(2023, 1, 1),
                                lastDate: DateTime(2099, 1, 1),
                              );
                              if (res != null) {
                                setState(() {
                                  time = time.copyWith(
                                    year: res.year,
                                    month: res.month,
                                    day: res.day,
                                  );
                                  newTime = time.copyWith();
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
                            time.toIso8601String().substring(11, 16),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              var res = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(time),
                              );
                              if (res != null) {
                                setState(() {
                                  time = time.copyWith(
                                    hour: res.hour,
                                    minute: res.minute,
                                  );
                                  newTime = time.copyWith();
                                });
                              }
                            },
                            child: const Text('更改时间'),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        '工作 ${durationToString(db.getWorkTime())}',
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        '休息 ${durationToString(db.getRestTime())}',
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => navigator!.pop(),
                child: const Text('返回'),
              ),
              TextButton(
                onPressed: () async {
                  if (newTime.isAfter(DateTime.now())) {
                    int ret = _flowController.updateFlowList(newTime);
                    if (ret < 0) {
                      await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return const AlertDialog(
                            title: Text(
                              '时间不够了！',
                            ),
                            content: SizedBox(
                              child: Text('即使是完全不休息也有任务无法完成。请压缩任务的预期时间。'),
                            ),
                          );
                        },
                      );
                    } else if (ret != db.getRestTime().inMinutes) {
                      Fluttertoast.showToast(
                        msg:
                            '因为任务过多，你需要把休息时间压缩到 ${durationToString(Duration(minutes: ret))}才能完成任务',
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    }
                    navigator!.pop();
                  } else {
                    Fluttertoast.showToast(
                      msg: '开始时间必须晚于现在',
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.CENTER,
                      timeInSecForIosWeb: 1,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                  }
                },
                child: const Text('创建'),
              )
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '接下来',
        ),
        actions: [
          IconButton(
            tooltip: '创建新的规划',
            onPressed: () async {
              await newFlowList(context);
              _flowController.flowList.refresh();
            },
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            if (_flowController.isFlowListOutdated()) {
              return MaterialBanner(
                content: const Text('规划方案已过期'),
                leading: const Icon(Icons.warning),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await newFlowList(context);
                      _flowController.flowList.refresh();
                    },
                    child: const Text('创建新的规划'),
                  ),
                ],
              );
            }
            return const SizedBox();
          }),
          Obx(() {
            if (_flowController.flowList.isEmpty) {
              return const Expanded(
                child: Center(
                  child: Text('今日无事可做'),
                ),
              );
            } else {
              return Expanded(
                child: ListView(
                  children: _flowController.flowList
                      .map((e) => createCard(context, e))
                      .toList(),
                ),
              );
            }
          }),
        ],
      ),
    );
  }
}
