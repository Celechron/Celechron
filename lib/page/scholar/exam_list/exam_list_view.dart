import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../model/exam.dart';
import '../../../model/semester.dart';
import '../../../design/sub_title.dart';
import '../../../design/round_rectangle_card.dart';

class ExamListPage extends StatelessWidget {

  final Semester semester;

  // Classify exams by date
  late final List<List<Exam>> exams = semester.exams
      .fold(<List<Exam>>[], (previousValue, element) {
    if (previousValue.isEmpty) {
      previousValue.add([element]);
    } else {
      if (previousValue.last[0].time[0].year == element.time[0].year && previousValue.last[0].time[0].month == element.time[0].month && previousValue.last[0].time[0].day == element.time[0].day ) {
        previousValue.last.add(element);
      } else {
        previousValue.add([element]);
      }
    }
    return previousValue;
  });

  ExamListPage({required this.semester, super.key});

  Widget createExamCard(context, List<Exam> exams) {
    return Column(
      children: [
        SubSubtitleRow(subtitle: exams[0].chineseDate),
        RoundRectangleCard(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: Column(children: [
                Row(
                  children: [
                    Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 12.0,
                                      height: 12.0,
                                      decoration: const BoxDecoration(
                                        color: CupertinoColors.systemPink,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8.0),
                                    Expanded(
                                        child: Text(exams[0].name,
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
                                  Expanded(
                                      child: Text(' 时间：${exams[0].chineseTime}',
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
                                  Expanded(
                                      child: Text(' 地点：${exams[0].location ?? '未知'}',
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
                                Row(children: [
                                  Icon(
                                    CupertinoIcons.map_pin_ellipse,
                                    size: 14,
                                    color: CupertinoTheme.of(context)
                                        .textTheme
                                        .textStyle
                                        .color!
                                        .withOpacity(0.5),
                                  ),
                                  Expanded(
                                      child: Text(' 座位：${exams[0].seat ?? '未知'}',
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
                            ),
                            for (var i = 1; i < exams.length; i++)
                              Column(
                                children: [
                                  Divider(
                                    height: 16,
                                    thickness: 1,
                                    indent: 0,
                                    endIndent: 0,
                                    color: CupertinoDynamicColor.resolve(
                                        CupertinoColors.systemFill, context),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 12.0,
                                        height: 12.0,
                                        decoration: const BoxDecoration(
                                          color: CupertinoColors.systemPink,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      Expanded(
                                          child: Text(exams[i].name,
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
                                    Expanded(
                                        child: Text(' 时间：${exams[i].chineseTime}',
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
                                    Expanded(
                                        child: Text(' 地点：${exams[i].location ?? '未知'}',
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
                                  Row(children: [
                                    Icon(
                                      CupertinoIcons.map_pin_ellipse,
                                      size: 14,
                                      color: CupertinoTheme.of(context)
                                          .textTheme
                                          .textStyle
                                          .color!
                                          .withOpacity(0.5),
                                    ),
                                    Expanded(
                                        child: Text(' 座位：${exams[i].seat ?? '未知'}',
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
                              ),
                          ],
                        )),
                  ],
                ),
              ]),
            ))
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          SubtitlePersistentHeader(
            subtitle: '考试',
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Container(
                padding: index == 0 ? const EdgeInsets.only(top: 0, bottom: 5, left: 16, right: 16) : const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: createExamCard(context, exams[index]),
              ),
              childCount: semester.exams.length,
            ),
          ),
        ],
      ),
    );
  }
}