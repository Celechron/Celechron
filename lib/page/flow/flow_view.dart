import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../model/period.dart';
import '../../utils/utils.dart';

import '../../widget/sub_title.dart';
import '../../widget/title_card.dart';
import 'flow_controller.dart';

class FlowPage extends StatelessWidget {
  FlowPage({super.key});

  final _flowController = Get.put(FlowController());
  final db = Get.find<DatabaseHelper>(tag: 'db');

  Widget createCard(context, Period period, String? title) {
    return Column(children: [
      title == null ? const SizedBox(height: 0) : SubtitleRow(subtitle: title),
      TitleCard(
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Row(
              children: [
                Expanded(flex:4, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12.0,
                          height: 12.0,
                          decoration: const BoxDecoration(
                            color: CupertinoColors.systemTeal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(child: Text(period.summary,
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              overflow: TextOverflow.ellipsis,
                            ))),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Row(children: [
                      Icon(
                        CupertinoIcons.time_solid,
                        size: 14,
                        color: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .color!
                            .withOpacity(0.5),
                      ),
                      Expanded(child: Text(
                        ' 开始：${toStringHumanReadable(period.startTime)}',
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
                      )),
                    ]),
                    Row(children: [
                      Icon(
                        CupertinoIcons.stop_fill,
                        size: 14,
                        color: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .color!
                            .withOpacity(0.5),
                      ),
                      Expanded(child: Text(
                        ' 结束：${toStringHumanReadable(period.endTime)}',
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
                      )),
                    ]),
                    if (period.location.isNotEmpty) ...[
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
                        Expanded(child: Text(' 地点：${period.location}',
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
                  ],
                )),
                // If the period starts before now and ends after now, it is ongoing. Then, we show time to end
                Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (period.startTime.isBefore(DateTime.now()) &&
                            period.endTime.isAfter(DateTime.now()))
                          Text(
                            '结束还有\n${durationToString(period.endTime.difference(DateTime.now()))}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .color!
                                  .withOpacity(0.75),
                            ),
                            textAlign: TextAlign.right,
                          ) else
                          Text(
                            '开始还有\n${durationToString(period.startTime.difference(DateTime.now()))}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .color!
                                  .withOpacity(0.75),
                            ),
                            textAlign: TextAlign.right,
                          ),
                      ],
                    )),
              ],
            ),
          ))
    ],);
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
                      /*Fluttertoast.showToast(
                        msg:
                            '因为任务过多，你需要把休息时间压缩到 ${durationToString(Duration(minutes: ret))}才能完成任务',
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );*/
                    }
                    navigator!.pop();
                  } else {
                    /*Fluttertoast.showToast(
                      msg: '开始时间必须晚于现在',
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.CENTER,
                      timeInSecForIosWeb: 1,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );*/
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
    return CupertinoPageScaffold(
        child: SafeArea(child: CustomScrollView(
          // Allow the list to shrink wrap around the top and bottom bars.
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('接下来'),
              stretch: true,
              border: null,
              trailing: // Two buttons in the nav bar.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(
                      CupertinoIcons.refresh_circled,
                      semanticLabel: 'Add',
                    ),
                    onPressed: () async {
                      await newFlowList(context);
                      _flowController.flowList.refresh();
                    },
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Obx(() {
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
            ),
            Obx(() {
              if (_flowController.flowList.isEmpty) {
                return SliverToBoxAdapter(child: SizedBox(
                    height: 500,
                    child: Column(children: [const Spacer(),Text('今日无事可做', style: CupertinoTheme.of(context).textTheme.textStyle),const Spacer()])
                ));
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                    return Container(
                        padding: EdgeInsets.only(
                            top: index == 0 ? 0 : 5, bottom: 5, left: 16, right: 16),
                        child: createCard(
                            context,
                            _flowController.flowList[index],
                            index == 0
                                ? _flowController.isDuringFlow
                                ? '正在'
                                : '即将'
                                : index == 1
                                ? '然后'
                                : null));
                  },
                  childCount: _flowController.flowList.length,
                ),
              );
            }),
          ],
        )));
  }
}
