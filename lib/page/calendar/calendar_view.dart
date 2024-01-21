import 'package:celechron/design/sub_title.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../model/period.dart';
import '../../utils/utils.dart';

import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/design/custom_colors.dart';
import '../scholar/course_detail/course_detail_view.dart';
import 'calendar_controller.dart';

class CalendarPage extends StatelessWidget {
  CalendarPage({Key? key}) : super(key: key);
  final _calendarController = Get.put(CalendarController());

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
        child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() => SubtitleRow(
                subtitle:
                    '${_calendarController.focusedDay.value.year} 年 ${_calendarController.focusedDay.value.month} 月',
                right: CupertinoButton(
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
                padHorizontal: 18,
              )),
          Padding(
              padding: const EdgeInsets.only(bottom: 5, left: 12, right: 12),
              child: Obx(() => TableCalendar(
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
                    headerVisible: false,
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
                            CupertinoColors.activeBlue.withOpacity(0.5),
                            context),
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
                  ))),
          const SizedBox(height: 16),
          Obx(() => SubSubtitleRow(
              padHorizontal: 24,
              subtitle: _calendarController.dayDescription(
                  _calendarController.selectedDay.value.copyWith(isUtc: false)),
              right: _calendarController.user.value.specialDates.containsKey(_calendarController.selectedDay.value.copyWith(isUtc: false))
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: CustomCupertinoDynamicColors
                                  .okGreen.darkColor,
                              width: 1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(_calendarController.user.value.specialDates[_calendarController.selectedDay.value.copyWith(isUtc: false)]!,
                          style: TextStyle(color: CustomCupertinoDynamicColors.okGreen.darkColor, fontSize: 12)))
                  : null)),
          Expanded(
            child: Obx(() => ListView(
                  children: _calendarController
                      .getEventsForDay(_calendarController.selectedDay.value)
                      .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 16),
                          child: createCard(context, e)))
                      .toList(),
                )),
          ),
        ],
      ),
    ));
  }

  static Future<void> showCardDialog(
      BuildContext context, Period period) async {
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(period.summary),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    period.getTimePeriodHumanReadable(),
                    style: const TextStyle(),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    period.location,
                    style: const TextStyle(),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    period.description,
                  ),
                ],
              ),
            ),
          );
        });
  }

  Widget createCard(context, Period period) {
    return RoundRectangleCard(
        onTap: (period.type == PeriodType.classes ||
                period.type == PeriodType.test)
            ? () async => Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(
                    builder: (context) =>
                        CourseDetailPage(courseId: period.fromUid)))
            : null,
        child: Padding(
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: Row(children: [
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12.0,
                      height: 12.0,
                      decoration: BoxDecoration(
                        color: period.type == PeriodType.classes
                            ? CupertinoColors.systemTeal
                            : (period.type == PeriodType.test
                                ? CupertinoColors.systemPink
                                : CupertinoColors.inactiveGray),
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
                                  fontSize: 18,
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
                  const SizedBox(width: 6.0),
                  Expanded(
                      child: Text(
                    '时间：${period.startTime.hour}:${period.startTime.minute.toString().padLeft(2, '0')} - ${period.endTime.hour}:${period.endTime.minute.toString().padLeft(2, '0')}',
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
                    const SizedBox(width: 6.0),
                    Expanded(
                        child: Text('地点：${period.location}',
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
            Icon(CupertinoIcons.chevron_right,
                size: 14,
                color: CupertinoTheme.of(context)
                    .textTheme
                    .textStyle
                    .color!
                    .withOpacity(0.5))
          ]),
        ));
  }

  static Widget singleMarkerBuilder(context, day, Period event) {
    if (event.type == PeriodType.virtual) {
      return const SizedBox.shrink();
    }

    Color color = Colors.red;
    if (event.type != PeriodType.test) {
      if (event.startTime.hour <= 8) {
        color = Colors.red;
      } else if (event.startTime.hour >= 9 && event.startTime.hour <= 12) {
        color = Colors.amber;
      } else if (event.startTime.hour == 13) {
        color = const Color.fromARGB(255, 163, 232, 0);
      } else if (event.startTime.hour >= 14 && event.startTime.hour <= 15) {
        color = Colors.green;
      } else if (event.startTime.hour >= 16 && event.startTime.hour <= 17) {
        color = Colors.lightBlue;
      } else if (event.startTime.hour >= 18 && event.startTime.hour <= 19) {
        color = const Color.fromARGB(255, 38, 0, 255);
      } else if (event.startTime.hour >= 20) {
        color = const Color.fromARGB(255, 195, 0, 255);
      }
    }

    BoxShape shape = BoxShape.circle;
    if (event.type == PeriodType.test) {
      shape = BoxShape.rectangle;
    }

    double size = 4.5;

    if (event.type == PeriodType.test) {
      size = 6;
    }

    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 0.3),
      decoration: BoxDecoration(
        color: color,
        shape: shape,
      ),
    );
  }
}
