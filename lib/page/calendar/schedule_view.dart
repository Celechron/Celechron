import 'dart:math';

import 'package:celechron/utils/tuple.dart';
import 'package:celechron/model/session.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/page/scholar/course_schedule/course_card.dart';
import 'package:celechron/page/calendar/calendar_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class ScheduleView extends StatelessWidget {
  final CalendarController controller;

  const ScheduleView({super.key, required this.controller});

  Widget _courseSchedule(BuildContext context) {
    const List<String> courseStartTime = [
      "08:00",
      "08:50",
      "10:00",
      "10:50",
      "11:40",
      "13:25",
      "14:15",
      "15:05",
      "16:15",
      "17:05",
      "18:50",
      "19:40",
      "20:30"
    ];
    return RoundRectangleCard(
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(flex: 1),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '一',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                            ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '二',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                            ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '三',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                            ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '四',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                            ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '五',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                            ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '六',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                            ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '日',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                            ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 560,
            child: Obx(
              () {
                final semester = controller.getCurrentSemester();
                if (semester == null) {
                  return Center(
                    child: Text(
                      '当前不在学期内',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(fontSize: 16),
                    ),
                  );
                }

                final isFirstHalf = controller.isFirstHalfSemester(semester);
                final sessionsByDayOfWeek = isFirstHalf
                    ? semester.firstHalfTimetable
                    : semester.secondHalfTimetable;

                return Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          for (var i = 1; i <= 13; i++)
                            Expanded(
                              child: Center(
                                child: Column(
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.fitWidth,
                                      child: Text(
                                        courseStartTime[i - 1],
                                        style: CupertinoTheme.of(context)
                                            .textTheme
                                            .textStyle
                                            .copyWith(
                                              fontSize: 10,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 2,
                                    ),
                                    Text(
                                      i.toString(),
                                      style: CupertinoTheme.of(context)
                                          .textTheme
                                          .textStyle
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (var i = 1; i <= 6; i++)
                      Expanded(
                        flex: 2,
                        child: LayoutBuilder(
                          builder: (context, constraints) => Stack(
                            children: [
                              Column(
                                children: [
                                  for (var j = 1; j <= 12; j++)
                                    Expanded(
                                      child: Container(),
                                    ),
                                  Expanded(
                                    child: Container(),
                                  ),
                                ],
                              ),
                              ..._buildCourseScheduleByDayOfWeek(
                                  sessionsByDayOfWeek, i, constraints)
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      flex: 2,
                      child: LayoutBuilder(
                        builder: (context, constraints) => Stack(
                          children: [
                            Column(
                              children: [
                                for (var j = 1; j <= 12; j++)
                                  Expanded(
                                    child: Container(),
                                  ),
                                Expanded(child: Container())
                              ],
                            ),
                            ..._buildCourseScheduleByDayOfWeek(
                                sessionsByDayOfWeek, 7, constraints)
                          ],
                        ),
                      ),
                    )
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCourseScheduleByDayOfWeek(
      List<List<Session>> sessionsByDayOfWeek,
      int day,
      BoxConstraints constraints) {
    List<Tuple<int, int>> period = [];
    for (var i = 1; i <= 13; i++) {
      period.add(Tuple(i, i));
    }
    for (var s in sessionsByDayOfWeek[day]) {
      int sl = s.time.first, sr = s.time.last;
      int xl = sl, xr = sr;
      for (var i in period) {
        if (!(i.item2 < sl || sr < i.item1)) {
          xl = min(xl, i.item1);
          xr = max(xr, i.item2);
        }
      }
      period.removeWhere((x) => xl <= x.item1 && x.item2 <= xr);
      period.add(Tuple(xl, xr));
    }
    List<List<Session>> sessionList = [];
    for (var _ in period) {
      sessionList.add([]);
    }
    for (var s in sessionsByDayOfWeek[day]) {
      int sl = s.time.first, sr = s.time.last;
      for (int i = 0; i < period.length; i++) {
        if (!(period[i].item2 < sl || sr < period[i].item1)) {
          bool added = false;
          for (var t in sessionList[i]) {
            if (t.id == s.id) {
              added = true;
              Set<int> timeSet = Set.from(t.time);
              timeSet.addAll(s.time);
              t.time = List.from(timeSet);
              t.time.sort();
              break;
            }
          }
          if (!added) {
            sessionList[i].add(Session.fromJson(s.toJson()));
          }
        }
      }
    }

    List<Widget> cardList = [];
    for (int i = 0; i < period.length; i++) {
      if (sessionList[i].isNotEmpty) {
        cardList.add(
          Positioned.fromRelativeRect(
            rect: RelativeRect.fromLTRB(
              0,
              (period[i].item1 - 1) * constraints.maxHeight / 13,
              0,
              (13 - period[i].item2) * constraints.maxHeight / 13,
            ),
            child: SessionCard(
              sessionList: sessionList[i],
              hideInfomation: false,
            ),
          ),
        );
      }
    }

    return cardList;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: _courseSchedule(context),
      ),
    );
  }
}

