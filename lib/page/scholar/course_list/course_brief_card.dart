import 'package:flutter/cupertino.dart';

import 'package:celechron/model/course.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/page/scholar/course_detail/course_detail_view.dart';

class CourseBriefCard extends StatelessWidget {
  final Course course;
  final bool allowDirect;

  const CourseBriefCard(
      {required this.course, this.allowDirect = false, super.key});

  @override
  Widget build(BuildContext context) {
    return RoundRectangleCard(
        onTap: allowDirect
            ? () async => Navigator.of(context).push(CupertinoPageRoute(
                builder: (context) => CourseDetailPage(courseId: course.id)))
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
                            decoration: const BoxDecoration(
                              color: CupertinoColors.systemTeal,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                course.name,
                                style: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              ),
                            ),
                          ),
                          Text('  ${course.credit.toStringAsFixed(1)} 学分',
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    overflow: TextOverflow.ellipsis,
                                  )),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Row(children: [
                        Icon(
                          CupertinoIcons.number,
                          size: 14,
                          color: CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
                              .color!
                              .withOpacity(0.5),
                        ),
                        Expanded(
                            child: Text(
                                ' 课号：${course.realId}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  color: CupertinoTheme.of(context)
                                      .textTheme
                                      .textStyle
                                      .color!
                                      .withOpacity(0.75),
                                  overflow: TextOverflow.ellipsis,
                                ))),
                      ]),
                      Row(children: [
                        Icon(
                          CupertinoIcons.person_2_alt,
                          size: 14,
                          color: CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
                              .color!
                              .withOpacity(0.5),
                        ),
                        Expanded(
                            child: Text(' 教师：${course.teacher ?? '未知'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  color: CupertinoTheme.of(context)
                                      .textTheme
                                      .textStyle
                                      .color!
                                      .withOpacity(0.75),
                                  overflow: TextOverflow.ellipsis,
                                ))),
                        if (course.grade != null) ...{
                          Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            size: 14,
                            color: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .color!
                                .withOpacity(0.5),
                          ),
                          Text(
                              // grs is 90 / 100, ugrs is 4.0 / 5.0
                              ' 成绩：${course.grade!.original == "" ? course.grade!.hundredPoint : course.grade!.original}  / ${course.grade!.original == "" ? 100 : course.grade!.fivePoint.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                color: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .color!
                                    .withOpacity(0.75),
                                overflow: TextOverflow.ellipsis,
                              )),
                        }
                      ]),
                    ],
                  )),
            ],
          ),
        ));
  }
}
