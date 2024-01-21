import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:celechron/model/exam.dart';
import 'package:celechron/design/sub_title.dart';
import 'package:celechron/design/persistent_headers.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/design/animate_button.dart';
import 'package:celechron/design/custom_colors.dart';

import 'exam_list_controller.dart';

class ExamListPage extends StatelessWidget {
  late final ExamListController _examListController;

  ExamListPage({required String initialSemesterName, super.key}) {
    Get.delete<ExamListController>();
    _examListController =
        Get.put(ExamListController(initialName: initialSemesterName));
  }

  Widget _examCard(context, List<Exam> exams) {
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

  Widget _semesterPicker(BuildContext context) {
    return RoundRectangleCardWithForehead(
        forehead: const Row(children: [
          // alert icon
          Padding(
            padding: EdgeInsets.only(left: 12, top: 4, bottom: 4),
            child: Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              color: CupertinoColors.white,
              size: 14,
            ),
          ),
          Padding(
              padding: EdgeInsets.only(left: 4, top: 4, bottom: 4),
              child: Text('更新于10分钟前',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    overflow: TextOverflow.ellipsis,
                    color: CupertinoColors.white,
                  )))
        ]),
        foreheadColor: CupertinoColors.systemRed,
        child: Column(children: [
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 30,
                child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _examListController.semesters.length,
                    itemBuilder: (context, index) {
                      final semester = _examListController.semesters[index];
                      return Obx(() => Stack(children: [
                            AnimateButton(
                              text:
                                  '${semester.name.substring(2, 5)}${semester.name.substring(7, 11)}',
                              onTap: () {
                                _examListController.semesterIndex.value = index;
                                _examListController.semesterIndex.refresh();
                              },
                              backgroundColor:
                                  _examListController.semesterIndex.value ==
                                          index
                                      ? CustomCupertinoDynamicColors.cyan
                                      : CupertinoColors.systemFill,
                            ),
                            const SizedBox(width: 90),
                          ]));
                    }),
              ),
            ),
          ]),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CelechronSliverTextHeader(
            subtitle: '考试',
          ),
          SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, bottom: 10, top: 10),
                child: _semesterPicker(context)),
          ),
          Obx(() => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Container(
                    padding: index == 0
                        ? const EdgeInsets.only(
                            top: 0, bottom: 5, left: 16, right: 16)
                        : const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 5),
                    child: _examCard(context, _examListController.exams[index]),
                  ),
                  childCount: _examListController.exams.length,
                ),
              ))
        ],
      ),
    );
  }
}
