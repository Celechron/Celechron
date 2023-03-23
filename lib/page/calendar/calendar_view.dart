import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../model/period.dart';
import '../../utils/utils.dart';

import 'calendar_controller.dart';

class CalendarPage extends StatelessWidget {

  CalendarPage({Key? key}) : super(key: key);
  final calendarController = Get.put(CalendarController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(
          '${calendarController.focusedDay.value.year} 年 ${calendarController.focusedDay.value.month} 月',
        )),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx (() => TableCalendar(
            locale: 'zh_CN',
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            rowHeight: 48.0,
            daysOfWeekHeight: 20.0,
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableGestures: AvailableGestures.all,
            availableCalendarFormats: const {
              CalendarFormat.month: '显示整月',
              CalendarFormat.week: '显示一周',
            },
            headerVisible: false,
            focusedDay: calendarController.focusedDay.value,
            selectedDayPredicate: (day) {
              return isSameDay(calendarController.selectedDay.value, day);
            },
            calendarFormat: calendarController.calendarFormat.value,
            onPageChanged: (focusedDay) {
              calendarController.focusedDay.value = focusedDay;
            },
            onDaySelected: (selectedDay, focusedDay) {
              calendarController.selectedDay.value = selectedDay;
              calendarController.focusedDay.value = focusedDay;
            },
            onFormatChanged: (format) {
              calendarController.calendarFormat.value = format;
            },
            eventLoader: (day) {
              return calendarController.getEventsForDay(day);
            },
            calendarStyle: CalendarStyle(
              markersAnchor: -0.1,
              markersMaxCount: 10,
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).primaryColorLight,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(fontWeight: FontWeight.bold),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).focusColor,
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            calendarBuilders: const CalendarBuilders(
              singleMarkerBuilder: singleMarkerBuilder,
            ),
          )),
          const SizedBox(height: 8.0),
          Expanded(
            child: Obx(() => ListView(
              children: calendarController.getEventsForDay(calendarController.selectedDay.value)
                  .map((e) => createCard(context, e))
                  .toList(),
            )),
          ),
        ],
      ),
    );
  }

  static Future<void> showCardDialog(BuildContext context, Period period) async {
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

  static Widget createCard(context, Period period) {
    return GestureDetector(
      onTap: () => showCardDialog(context, period),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    period.summary,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    period.getTimePeriodHumanReadable(),
                    style: const TextStyle(),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    period.location,
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

  static Widget singleMarkerBuilder(context, day, Period event) {
    if (event.periodType == PeriodType.virtual) {
      return const SizedBox.shrink();
    }

    Color color = Colors.red;
    if (event.periodType != PeriodType.test) {
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
    if (event.periodType == PeriodType.test) {
      shape = BoxShape.rectangle;
    }

    double size = 4.5;

    if (event.periodType == PeriodType.test) {
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