import 'dart:async';
import 'dart:ui';
import 'package:celechron/design/custom_colors.dart';
import 'package:celechron/utils/timehelper.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../model/period.dart';
import '../../utils/utils.dart';

import 'package:celechron/design/sub_title.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import '../scholar/course_detail/course_detail_view.dart';
import 'flow_controller.dart';

class FlowPage extends StatelessWidget {
  FlowPage({super.key});

  final _flowController = Get.put(FlowController());
  final db = Get.find<DatabaseHelper>(tag: 'db');

  Widget createFirst(context, Period period, String? title) {
    Color themeColor = (period.type == PeriodType.flow
        ? UidColors.colorFromUid(period.fromUid ?? '')
        : CupertinoColors.systemTeal);
    return Column(
      children: [
        title == null
            ? const SizedBox(height: 0)
            : SubtitleRow(subtitle: title),
        RoundRectangleCard(
          onTap: period.type == PeriodType.classes
              ? () async => Navigator.of(context, rootNavigator: true).push(
                  CupertinoPageRoute(
                      builder: (context) =>
                          CourseDetailPage(courseId: period.fromUid)))
              : null,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Column(children: [
                      Row(children: [
                        Container(
                          width: 12.0,
                          height: 12.0,
                          decoration: BoxDecoration(
                            color: themeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(period.summary,
                                style: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      overflow: TextOverflow.ellipsis,
                                    ))),
                      ]),
                      Divider(
                        color: CupertinoDynamicColor.resolve(
                            CupertinoColors.separator, context),
                        height: 14,
                      ),
                      Row(
                        children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Row(children: [
                                  Icon(
                                    CupertinoIcons.location_solid,
                                    size: 14,
                                    color: themeColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(period.location,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                        color: CupertinoTheme.of(context)
                                            .textTheme
                                            .textStyle
                                            .color!,
                                        overflow: TextOverflow.ellipsis,
                                      ))
                                ]),
                              ])),
                        ],
                      ),
                    ])),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.time_solid,
                                size: 14,
                                color: themeColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${period.startTime.hour}:${period.startTime.minute.toString().padLeft(2, '0')} - ${period.endTime.hour}:${period.endTime.minute.toString().padLeft(2, '0')}',
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
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Obx(() => period.startTime
                                        .isBefore(_flowController.timeNow.value)
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                            Text('离结束还有',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.normal,
                                                  color:
                                                      CupertinoTheme.of(context)
                                                          .textTheme
                                                          .textStyle
                                                          .color!
                                                          .withOpacity(0.75),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                )),
                                            Text(
                                                TimeHelper.toHMS(period.endTime
                                                    .difference(_flowController
                                                        .timeNow.value)),
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      CupertinoTheme.of(context)
                                                          .textTheme
                                                          .textStyle
                                                          .color!,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ))
                                          ])
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                            Text('开始还有',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.normal,
                                                  color:
                                                      CupertinoTheme.of(context)
                                                          .textTheme
                                                          .textStyle
                                                          .color!
                                                          .withOpacity(0.75),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                )),
                                            Text(
                                                TimeHelper.toHMS(period
                                                    .startTime
                                                    .difference(_flowController
                                                        .timeNow.value)),
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  fontFeatures: const [
                                                    FontFeature.tabularFigures()
                                                  ],
                                                  color:
                                                      CupertinoTheme.of(context)
                                                          .textTheme
                                                          .textStyle
                                                          .color!,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ))
                                          ]))
                              ],
                            ),
                          )
                        ]),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                    builder: (context, constraints) => Stack(
                          children: [
                            SizedBox(
                              height: 8,
                              width: (constraints.maxWidth),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: CupertinoDynamicColor.resolve(
                                      CupertinoColors.separator, context),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            Obx(() => SizedBox(
                                  height: 8,
                                  width: _flowController.isDuringFlow
                                      ? (constraints.maxWidth) *
                                          _flowController.timeNow.value
                                              .difference(period.startTime)
                                              .inMilliseconds /
                                          period.endTime
                                              .difference(period.startTime)
                                              .inMilliseconds
                                      : (constraints.maxWidth),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: CupertinoDynamicColor.resolve(
                                          themeColor, context),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ))
                          ],
                        )),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget createCard(context, Period period, String? title) {
    Color themeColor = (period.type == PeriodType.flow
        ? UidColors.colorFromUid(period.fromUid ?? '')
        : (period.type == PeriodType.classes
            ? TimeColors.colorFromHour(period.startTime.hour)
            : CupertinoColors.systemTeal));
    return Column(
      children: [
        title == null
            ? const SizedBox(height: 0)
            : SubtitleRow(subtitle: title),
        RoundRectangleCard(
            onTap: period.type == PeriodType.classes
                ? () async => Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute(
                        builder: (context) =>
                            CourseDetailPage(courseId: period.fromUid)))
                : null,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: Row(
                children: [
                  Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12.0,
                                height: 12.0,
                                decoration: BoxDecoration(
                                  color: themeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                  child: Text(period.summary,
                                      style: CupertinoTheme.of(context)
                                          .textTheme
                                          .textStyle
                                          .copyWith(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            overflow: TextOverflow.ellipsis,
                                          ))),
                            ],
                          ),
                          const SizedBox(height: 4.0),
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
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(
                              '${TimeHelper.chineseDayRelation(period.startTime)}${period.startTime.hour}:${period.startTime.minute.toString().padLeft(2, '0')} - ${period.endTime.hour}:${period.endTime.minute.toString().padLeft(2, '0')}',
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
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(period.location,
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
                  /*Expanded(
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
                            )
                          else
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
                      )),*/
                ],
              ),
            ))
      ],
    );
  }

  Future<void> newFlowList(context) async {
    DateTime newTime = DateTime.now()
        .copyWith(second: 0, millisecond: 0, microsecond: 0)
        .add(const Duration(seconds: 90));
    await showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text(
              '开始规划',
            ),
            content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                        height: 8,
                      ),
                      const Text(
                        '点击修改开始时间',
                      ),
                      CupertinoButton(
                        onPressed: () async {
                          await showCupertinoModalPopup(
                              context: context,
                              builder: (BuildContext context) {
                                return Container(
                                  height: MediaQuery.of(context)
                                          .copyWith()
                                          .size
                                          .height /
                                      3,
                                  color: Colors.white,
                                  child: CupertinoDatePicker(
                                    initialDateTime: newTime,
                                    use24hFormat: true,
                                    minuteInterval: 1,
                                    mode: CupertinoDatePickerMode.dateAndTime,
                                    onDateTimeChanged: (DateTime val) {
                                      setState(() {
                                        newTime = val;
                                      });
                                    },
                                  ),
                                );
                              });
                        },
                        child: Text(TimeHelper.chineseDateTime(newTime)),
                      ),
                      Text(
                        '工作 ${durationToString(db.getWorkTime())} - 休息 ${durationToString(db.getRestTime())}',
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => navigator!.pop(),
                child: const Text('返回'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  if (newTime.isAfter(DateTime.now())) {
                    int ret = _flowController.updateFlowList(newTime);
                    if (ret < 0) {
                      showCupertinoDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return CupertinoAlertDialog(
                            title: const Text(
                              '时间不够了！',
                            ),
                            content: const Text(
                                '即使是完全不休息也有任务无法完成。请压缩任务的预期时间，或者检查是否有任务在规划开始时间之前就结束。'),
                            actions: [
                              CupertinoDialogAction(
                                child: const Text('确定'),
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                },
                              )
                            ],
                          );
                        },
                      );
                    } else if (ret != db.getRestTime().inMinutes) {
                      navigator!.pop();
                      showCupertinoDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return CupertinoAlertDialog(
                            title: const Text(
                              '休息时间已压缩',
                            ),
                            content: Text(
                                '因为任务过多，你需要把休息时间压缩到 ${durationToString(Duration(minutes: ret))}才能完成任务。'),
                            actions: [
                              CupertinoDialogAction(
                                child: const Text('确定'),
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                },
                              )
                            ],
                          );
                        },
                      );
                    } else {
                      navigator!.pop();
                    }
                  } else {
                    showCupertinoDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return CupertinoAlertDialog(
                          title: const Text(
                            '开始时间必须晚于现在',
                          ),
                          content: const Text('请调整开始时间。'),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('确定'),
                              onPressed: () async {
                                Navigator.of(context).pop();
                              },
                            )
                          ],
                        );
                      },
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
    return CupertinoPageScaffold(
        child: SafeArea(
            child: CustomScrollView(
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
                backgroundColor: CupertinoColors.systemGroupedBackground,
                dividerColor: Colors.transparent,
                content: const Text('规划方案已过期'),
                contentTextStyle: TextStyle(
                  fontSize: 16,
                  color: CupertinoTheme.of(context).textTheme.textStyle.color!,
                ),
                leading: const Icon(CupertinoIcons.exclamationmark_triangle),
                actions: [
                  CupertinoButton(
                    child: const Text('忽略'),
                    onPressed: () {
                      _flowController.updateDeadlineListTime();
                    },
                  ),
                  CupertinoButton(
                    onPressed: () async {
                      await newFlowList(context);
                      _flowController.flowList.refresh();
                    },
                    child: const Text('重新规划'),
                  ),
                ],
              );
            }
            return const SizedBox();
          }),
        ),
        Obx(() {
          if (_flowController.flowList.isEmpty) {
            return SliverToBoxAdapter(
                child: SizedBox(
                    height: 500,
                    child: Column(children: [
                      const Spacer(),
                      Text('今日无事可做',
                          style:
                              CupertinoTheme.of(context).textTheme.textStyle),
                      const Spacer()
                    ])));
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                return index == 0
                    ? Container(
                        padding: EdgeInsets.only(
                            top: index == 0 ? 0 : 5,
                            bottom: 5,
                            left: 16,
                            right: 16),
                        child: createFirst(
                            context,
                            _flowController.flowList[index],
                            _flowController.isDuringFlow ? '正在进行' : '即将开始'))
                    : Container(
                        padding: EdgeInsets.only(
                            top: index == 0 ? 0 : 5,
                            bottom: 5,
                            left: 16,
                            right: 16),
                        child: createCard(
                            context,
                            _flowController.flowList[index],
                            index == 1 ? '之后的安排' : null));
              },
              childCount: _flowController.flowList.length,
            ),
          );
        }),
      ],
    )));
  }
}
