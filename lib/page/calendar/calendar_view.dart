import 'package:celechron/design/custom_decoration.dart';
import 'package:celechron/design/sub_title.dart';
import 'package:celechron/model/task.dart';
import 'package:celechron/page/task/task_controller.dart';
import 'package:celechron/page/task/task_edit_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/utils/utils.dart';

import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/design/custom_colors.dart';
import 'package:celechron/page/scholar/course_detail/course_detail_view.dart';
import 'calendar_controller.dart';

class CalendarPage extends StatelessWidget {
  CalendarPage({super.key});
  final _calendarController = Get.put(CalendarController());
  final _taskController = Get.put(TaskController());
  final deadlineList = Get.find<RxList<Task>>(tag: 'taskList');

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(
              () => SubtitleRow(
                subtitle:
                    '${_calendarController.focusedDay.value.year} 年 ${_calendarController.focusedDay.value.month} 月',
                right: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(
                        CupertinoIcons.add_circled,
                        semanticLabel: 'Add',
                      ),
                      onPressed: () async {
                        await newDeadline(
                          context,
                          time: DateTime(
                            _calendarController.selectedDay.value.year,
                            _calendarController.selectedDay.value.month,
                            _calendarController.selectedDay.value.day,
                            DateTime.now().hour,
                            DateTime.now().minute,
                          ),
                        );
                        _taskController.updateDeadlineList();
                        _taskController.taskList.refresh();
                      },
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Text('今天',
                          style: TextStyle(
                              fontSize: 18,
                              color: CupertinoDynamicColor.resolve(
                                  CupertinoColors.systemBlue, context))),
                      onPressed: () {
                        _calendarController.focusedDay.value = DateTime.now();
                        _calendarController.selectedDay.value = DateTime.now();
                      },
                    ),
                  ],
                ),
                padHorizontal: 18,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 5, left: 12, right: 12),
              child: Obx(
                () => Material(//需要一个Material包裹，否则会报错
                  type: MaterialType.transparency,//透明材质,不影响原有的颜色
                  child: TableCalendar(
                    locale: 'zh_CN',
                    firstDay: DateTime.utc(2022, 9, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    rowHeight: 48.0,
                    daysOfWeekHeight: 20.0,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    daysOfWeekStyle: DaysOfWeekStyle(
                      dowTextFormatter: (date, locale) => <String>[
                        '',
                        '一',
                        '二',
                        '三',
                        '四',
                        '五',
                        '六',
                        '日'
                      ][date.weekday],
                    ),
                    availableGestures: AvailableGestures.all,
                    availableCalendarFormats: const {
                      CalendarFormat.month: '显示整月',
                      CalendarFormat.week: '显示一周',
                    },
                    headerVisible: true, //头部显示，可切换月份
                    focusedDay: _calendarController.focusedDay.value,
                    selectedDayPredicate: (day) {
                      return isSameDay(
                          _calendarController.selectedDay.value, day);
                    },
                    calendarFormat: _calendarController.calendarFormat.value,
                    onPageChanged: (focusedDay) {
                      _calendarController.focusedDay.value = focusedDay;
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      _calendarController.focusedDay.value = focusedDay;
                      _calendarController.selectedDay.value = selectedDay;
                      _calendarController.focusedDay.refresh();
                    },
                    onFormatChanged: (format) {
                      _calendarController.calendarFormat.value = format;
                    },
                    eventLoader: (day) {
                      return _calendarController.getEventsForDay(day);
                    },
                    calendarStyle: CalendarStyle(
                      markersAnchor: -0.1,
                      markersMaxCount: 10,
                      selectedDecoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(
                            CupertinoColors.activeBlue.withOpacity(0.5), context),
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle:
                          CupertinoTheme.of(context).textTheme.textStyle,
                      todayDecoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(
                            CupertinoColors.inactiveGray.withOpacity(0.5),
                            context),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle:
                          CupertinoTheme.of(context).textTheme.textStyle,
                      defaultTextStyle:
                          CupertinoTheme.of(context).textTheme.textStyle,
                    ),
                    calendarBuilders: const CalendarBuilders(
                      singleMarkerBuilder: singleMarkerBuilder,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => SubSubtitleRow(
                  padHorizontal: 24,
                  subtitle: _calendarController.dayDescription(
                      _calendarController.selectedDay.value
                          .copyWith(isUtc: false)),
                  right: _calendarController.scholar.value.specialDates
                          .containsKey(_calendarController.selectedDay.value
                              .copyWith(isUtc: false))
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              border: Border.all(
                                  color: CustomCupertinoDynamicColors
                                      .okGreen.darkColor,
                                  width: 1),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            _calendarController.scholar.value.specialDates[
                                _calendarController.selectedDay.value
                                    .copyWith(isUtc: false)]!,
                            style: TextStyle(
                                color: CustomCupertinoDynamicColors
                                    .okGreen.darkColor,
                                fontSize: 12),
                          ),
                        )
                      : null),
            ),
            Expanded(
              child: Obx(
                () => ListView(
                  children: _calendarController
                      .getEventsForDay(_calendarController.selectedDay.value)
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 16),
                          child: createCard(context, e),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> newDeadline(context, {required DateTime time}) async {
    Task? deadline = Task(
      endTime: time,
      startTime: time,
      repeatEndsTime: time,
    );
    deadline.reset();
    deadline.startTime = time.copyWith();
    deadline.endTime = time.copyWith();
    deadline.repeatEndsTime = time.copyWith();
    deadline.type = TaskType.fixed;
    deadline.status = TaskStatus.running;
    Task? res = await showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return TaskEditPage(deadline);
      },
    );
    if (res != null &&
        res.checkTimeValid() &&
        res.status != TaskStatus.deleted) {
      _taskController.taskList.add(res);
      _taskController.updateDeadlineListTime();
      _taskController.taskList.refresh();
    }
  }

  Future<void> showCardDialog(BuildContext context, Task deadline) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(deadline.summary),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (deadline.repeatType != TaskRepeatType.norepeat) ...[
                  const Text(
                    '重复日程，接下来的时段：',
                  ),
                ],
                Text(
                  '开始于 ${toStringHumanReadable(deadline.startTime)}',
                ),
                Text(
                  '结束于 ${toStringHumanReadable(deadline.endTime)}',
                ),
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
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
            if (deadline.type == TaskType.fixed)
              CupertinoDialogAction(
                onPressed: () async {
                  Navigator.of(context).pop();
                  Task res = await showCupertinoModalPopup(
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
                  _taskController.taskList.refresh();
                },
                child: const Text('编辑'),
              ),
            if (deadline.type == TaskType.fixedlegacy)
              CupertinoDialogAction(
                onPressed: () async {
                  Navigator.of(context).pop();
                  deadline.status = TaskStatus.deleted;
                  _taskController.updateDeadlineList();
                  _taskController.taskList.refresh();
                },
                child: const Text('删除'),
              ),
          ],
        );
      },
    );
  }

  Widget createCard(context, Period period) {
    return RoundRectangleCard(
      onTap:
          (period.type == PeriodType.classes || period.type == PeriodType.test)
              ? () async => Navigator.of(context, rootNavigator: true).push(
                  CupertinoPageRoute(
                      builder: (context) =>
                          CourseDetailPage(courseId: period.fromUid)))
              : (period.type == PeriodType.user
                  ? (() async {
                      Task? deadline;
                      for (var x in deadlineList) {
                        if (x.uid == period.fromUid) {
                          deadline = x;
                          break;
                        }
                      }
                      if (deadline != null) {
                        showCardDialog(context, deadline);
                      }
                    })
                  : null),
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12.0,
                        height: 12.0,
                        decoration: customDecoration(
                          color: period.type == PeriodType.classes
                              ? (TimeColors.colorFromHour(
                                  period.startTime.hour))
                              : (period.type == PeriodType.test
                                  ? CupertinoColors.systemPink
                                  : (period.type == PeriodType.user &&
                                          period.fromUid != null
                                      ? UidColors.colorFromUid(
                                          period.fromFromUid ?? period.fromUid)
                                      : CupertinoColors.inactiveGray)),
                          shape: periodTypeShape[period.type]!,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          period.summary,
                          style: CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
                              .copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4.0),
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
                      const SizedBox(width: 6.0),
                      Expanded(
                        child: Text(
                          '时间：${period.friendlyTimeStartDayBased}',
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
                  if (period.location.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.location_solid,
                          size: 14,
                          color: CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
                              .color!
                              .withOpacity(0.5),
                        ),
                        const SizedBox(width: 6.0),
                        Expanded(
                          child: Text(
                            '地点：${period.location}',
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
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                size: 14,
                color: CupertinoTheme.of(context)
                    .textTheme
                    .textStyle
                    .color!
                    .withOpacity(0.5))
          ],
        ),
      ),
    );
  }

  static Widget singleMarkerBuilder(context, day, Period event) {
    if (event.type == PeriodType.virtual) {
      return const SizedBox.shrink();
    }

    Color color = CupertinoColors.systemPink;
    if (event.type == PeriodType.classes) {
      color = TimeColors.colorFromHour(event.startTime.hour);
    } else if (event.type == PeriodType.user) {
      color = UidColors.colorFromUid(event.fromFromUid ?? event.fromUid);
    }

    double size = 4.5;

    if (event.type == PeriodType.test) {
      size = 6;
    }

    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 0.3),
      decoration: customDecoration(
        color: color,
        shape: periodTypeShape[event.type]!,
      ),
    );
  }
}
