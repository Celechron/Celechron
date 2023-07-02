import 'package:celechron/model/session.dart';
import 'package:celechron/widget/sub_title.dart';
import 'course_schedule_controller.dart';
import 'package:get/get.dart';
import 'package:celechron/widget/animate_button.dart';
import 'package:celechron/widget/round_rectangle_card.dart';
import 'package:celechron/widget/two_line_card.dart';
import 'course_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:celechron/page/scholar/scholar_view.dart';

class CourseSchedulePage extends StatelessWidget {
  late final CourseScheduleController _courseScheduleController;

  CourseSchedulePage(String name, bool first, {Key? key}) : super(key: key) {
    Get.delete<CourseScheduleController>();
    _courseScheduleController = Get.put(CourseScheduleController(
        initialName: name, initialFirstOrSecondSemester: first));
  }

  Widget _semesterPicker(BuildContext context) {
    return RoundRectangleCard(
      animate: false,
      child: Column(children: [
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 30,
              child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _courseScheduleController.semesters.length,
                  itemBuilder: (context, index) {
                    final semester = _courseScheduleController.semesters[index];
                    return Obx(() => Stack(children: [
                          AnimateButton(
                            text:
                                '${semester.name.substring(2, 5)}${semester.name.substring(7, 11)}',
                            onTap: () {
                              _courseScheduleController.semesterIndex.value =
                                  index;
                              _courseScheduleController.semesterIndex.refresh();
                            },
                            backgroundColor:
                                _courseScheduleController.semesterIndex.value ==
                                        index
                                    ? ScholarPageColors.cyan
                                    : CupertinoColors.systemFill,
                          ),
                          const SizedBox(width: 90),
                        ]));
                  }),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Obx(() => Hero(
            tag: 'courseSchedule',
            child: Row(
              children: [
                Expanded(
                  child: TwoLineCard(
                      animate: true,
                      onTap: () {
                        _courseScheduleController.firstOrSecondSemester.value =
                            true;
                      },
                      title:
                          '${_courseScheduleController.semester.firstHalfName}学期课时',
                      content:
                          '${_courseScheduleController.semester.firstHalfSessionCount}节/两周',
                      backgroundColor: _courseScheduleController
                              .firstOrSecondSemester.value
                          ? _courseScheduleController.semester.name[9] == '春'
                              ? ScholarPageColors.spring
                              : ScholarPageColors.autumn
                          : CupertinoColors.systemFill,
                      withColoredFont: true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TwoLineCard(
                      animate: true,
                      onTap: () {
                        _courseScheduleController.firstOrSecondSemester.value =
                            false;
                      },
                      title:
                          '${_courseScheduleController.semester.secondHalfName}学期课时',
                      content:
                          '${_courseScheduleController.semester.secondHalfSessionCount}节/两周',
                      backgroundColor: _courseScheduleController
                              .firstOrSecondSemester.value
                          ? CupertinoColors.systemFill
                          : _courseScheduleController.semester.name[9] == '春'
                              ? ScholarPageColors.summer
                              : ScholarPageColors.winter,
                      withColoredFont: true),
                ),
              ],
            ))),
      ]),
    );
  }

  Widget _courseSchedule(BuildContext context) {
    return RoundRectangleCard(
        child: Column(children: [
      Row(
        children: [
          const Spacer(flex: 1),
          Expanded(
              flex: 2,
              child: Center(
                  child: Text('一',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(
                            fontSize: 14,
                          )))),
          Expanded(
              flex: 2,
              child: Center(
                  child: Text('二',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(
                            fontSize: 14,
                          )))),
          Expanded(
              flex: 2,
              child: Center(
                  child: Text('三',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(
                            fontSize: 14,
                          )))),
          Expanded(
              flex: 2,
              child: Center(
                  child: Text('四',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(
                            fontSize: 14,
                          )))),
          Expanded(
              flex: 2,
              child: Center(
                  child: Text('五',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(
                            fontSize: 14,
                          )))),
          Expanded(
              flex: 2,
              child: Center(
                  child: Text('六',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(
                            fontSize: 14,
                          )))),
          Expanded(
              flex: 2,
              child: Center(
                  child: Text('日',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(
                            fontSize: 14,
                          )))),
        ],
      ),
      const SizedBox(height: 4),
      SizedBox(
          height: 650,
          child: Obx(() {
            var sessionsByDayOfWeek =
                _courseScheduleController.sessionsByDayOfWeek;
            return Row(children: [
              Expanded(
                  flex: 1,
                  child: Column(children: [
                    for (var i = 1; i <= 13; i++)
                      Expanded(
                          child: Center(
                              child: Text(
                        i.toString(),
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(
                              fontSize: 14,
                            ),
                      ))),
                  ])),
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
                                          child: Container(
                                              decoration: BoxDecoration(
                                                  border: Border(
                                                      bottom: BorderSide(
                                                          color: CupertinoDynamicColor
                                                              .resolve(
                                                                  CupertinoColors
                                                                      .systemGrey4,
                                                                  context)),
                                                      right: BorderSide(
                                                          color: CupertinoDynamicColor
                                                              .resolve(
                                                                  CupertinoColors
                                                                      .systemGrey4,
                                                                  context)))))),
                                    Expanded(
                                        child: Container(
                                            decoration: BoxDecoration(
                                                border: Border(
                                                    right: BorderSide(
                                                        color: CupertinoDynamicColor
                                                            .resolve(
                                                                CupertinoColors
                                                                    .systemGrey4,
                                                                context))))))
                                  ],
                                ),
                                ..._buildCourseScheduleByDayOfWeek(
                                    sessionsByDayOfWeek, i, constraints)
                              ],
                            ))),
              Expanded(
                  flex: 2,
                  child: LayoutBuilder(
                      builder: (context, constraints) => Stack(
                            children: [
                              Column(
                                children: [
                                  for (var j = 1; j <= 12; j++)
                                    Expanded(
                                        child: Container(
                                            decoration: BoxDecoration(
                                                border: Border(
                                                    bottom: BorderSide(
                                                        color: CupertinoDynamicColor
                                                            .resolve(
                                                                CupertinoColors
                                                                    .systemGrey4,
                                                                context)))))),
                                  Expanded(child: Container())
                                ],
                              ),
                              ..._buildCourseScheduleByDayOfWeek(
                                  sessionsByDayOfWeek, 7, constraints)
                            ],
                          )))
            ]);
          })),
    ]));
  }

  List<Widget> _buildCourseScheduleByDayOfWeek(
      List<List<Session>> sessionsByDayOfWeek,
      int day,
      BoxConstraints constraints) {
    return sessionsByDayOfWeek[day]
        .map((e) => Positioned.fromRelativeRect(
            rect: RelativeRect.fromLTRB(
                0,
                (e.time.first - 1) * constraints.maxHeight / 13,
                0,
                (13 - e.time.last) * constraints.maxHeight / 13),
            child: SessionCard(session: e)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
        child: CustomScrollView(
      slivers: [
        SubtitlePersistentHeader(subtitle: '课表'),
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _semesterPicker(context),
                    const SizedBox(height: 20),
                    _courseSchedule(context),
                    const SizedBox(height: 20),
                  ],
                ))),
      ],
    ));
  }
}
