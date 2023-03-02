import 'package:celechron/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../data/period.dart';

class CalendarPage extends StatefulWidget {
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  var _selectedDay = DateTime.now();
  var _focusedDay = DateTime.now();
  var _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<Period>> events = {};

  DateTime chopDate(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }

  List<Period> getEventsForDay(DateTime day) {
    DateTime chop = chopDate(day);
    return events[chop] ?? [];
  }

  Future<void> showCardDialog(BuildContext context, Period period) async {
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(period.summary),
            content: SizedBox(
              width: double.maxFinite,
              height: 128,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
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

  Widget singleMarkerBuilder(context, day, Period event) {
    if (event.periodType == PeriodType.virtual) {
      return const SizedBox.shrink();
    }

    Color color = Colors.red;
    if (event.periodType != PeriodType.test) {
      if (event.startTime.hour == 8 && event.startTime.minute == 50) {
        color = Colors.red;
      }
      if (event.startTime.hour == 10 && event.startTime.minute == 0) {
        color = Colors.amber;
      }
      if (event.startTime.hour == 10 && event.startTime.minute == 50) {
        color = Colors.amber;
      }
      if (event.startTime.hour == 11 && event.startTime.minute == 40) {
        color = Colors.amber;
      }
      if (event.startTime.hour == 13 && event.startTime.minute == 25) {
        color = const Color.fromARGB(255, 163, 232, 0);
      }
      if (event.startTime.hour == 14 && event.startTime.minute == 15) {
        color = Colors.green;
      }
      if (event.startTime.hour == 15 && event.startTime.minute == 05) {
        color = Colors.green;
      }
      if (event.startTime.hour == 16 && event.startTime.minute == 15) {
        color = Colors.lightBlue;
      }
      if (event.startTime.hour == 17 && event.startTime.minute == 05) {
        color = Colors.lightBlue;
      }
      if (event.startTime.hour == 18 && event.startTime.minute == 50) {
        color = const Color.fromARGB(255, 38, 0, 255);
      }
      if (event.startTime.hour == 19 && event.startTime.minute == 40) {
        color = const Color.fromARGB(255, 38, 0, 255);
      }
      if (event.startTime.hour == 20 && event.startTime.minute == 30) {
        color = const Color.fromARGB(255, 195, 0, 255);
      }
      if (event.startTime.hour == 21 && event.startTime.minute == 20) {
        color = const Color.fromARGB(255, 195, 0, 255);
      }
    }

    BoxShape shape = BoxShape.circle;
    if (event.periodType == PeriodType.test) {
      shape = BoxShape.rectangle;
    }

    double size = 6;

    if (event.periodType == PeriodType.test) {
      size = 8;
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

  @override
  Widget build(BuildContext context) {
    updateBasePeriodList();

    events.clear();
    for (var element in basePeriodList) {
      DateTime chop = chopDate(element.startTime);
      if (events[chop] == null) events[chop] = <Period>[];
      setState(() {
        events[chop]!.add(element);
      });
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TableCalendar(
            locale: 'zh_CN',
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableGestures: AvailableGestures.all,
            availableCalendarFormats: const {
              CalendarFormat.month: '显示整月',
              CalendarFormat.week: '显示一周',
            },
            headerVisible: true,
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            calendarFormat: _calendarFormat,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            eventLoader: (day) {
              return getEventsForDay(day);
            },
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Colors.black12,
                shape: BoxShape.circle,
              ),
              selectedTextStyle:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            calendarBuilders: CalendarBuilders(
              singleMarkerBuilder: singleMarkerBuilder,
            ),
          ),
          Expanded(
            child: ListView(
              children: getEventsForDay(_selectedDay)
                  .map((e) => createCard(context, e))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
