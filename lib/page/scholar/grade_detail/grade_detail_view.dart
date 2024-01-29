import 'package:celechron/design/custom_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/design/two_line_card.dart';
import 'package:celechron/design/persistent_headers.dart';
import 'grade_card.dart';
import 'package:celechron/page/scholar/scholar_controller.dart';
import 'grade_detail_controller.dart';

class GradeDetailPage extends StatelessWidget {
  final _scholarController = Get.find<ScholarController>();
  late final GradeDetailController _gradeDetailController;

  GradeDetailPage({super.key}) {
    Get.delete<GradeDetailController>();
    _gradeDetailController = Get.put(GradeDetailController());
  }

  Widget _buildGradeBrief(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: Hero(
                    tag: 'gradeBrief',
                    child: RoundRectangleCard(
                        child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Obx(() => TwoLineCard(
                                  title: '五分制',
                                  content: _scholarController.gpa[0]
                                      .toStringAsFixed(2),
                                  backgroundColor:
                                      CustomCupertinoDynamicColors.cyan)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Obx(() => TwoLineCard(
                                  title: '获得学分',
                                  content: _scholarController.user.credit
                                      .toStringAsFixed(1),
                                  backgroundColor:
                                      CustomCupertinoDynamicColors.peach)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Obx(() => TwoLineCard(
                                  title: '四分制',
                                  content: _scholarController.gpa[1]
                                      .toStringAsFixed(2),
                                  extraContent: _scholarController.gpa[2]
                                      .toStringAsFixed(2),
                                  backgroundColor:
                                      CustomCupertinoDynamicColors.spring)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Obx(() => TwoLineCard(
                                  title: '主修均绩',
                                  content: _scholarController
                                      .user.majorGpaAndCredit[0]
                                      .toStringAsFixed(2),
                                  backgroundColor:
                                      CustomCupertinoDynamicColors.sakura)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Obx(() => TwoLineCard(
                                  title: '主修学分',
                                  content: _scholarController
                                      .user.majorGpaAndCredit[1]
                                      .toStringAsFixed(1),
                                  backgroundColor:
                                      CustomCupertinoDynamicColors.sand)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Obx(() => TwoLineCard(
                                  title: '百分制',
                                  content: _scholarController.gpa[3]
                                      .toStringAsFixed(2),
                                  backgroundColor:
                                      CustomCupertinoDynamicColors.magenta)),
                            ),
                          ],
                        ),
                      ],
                    )))),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHistory(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: RoundRectangleCard(
              animate: false,
              child: Column(children: [
                // Horizontal scrollable list to list all semesters
                SizedBox(
                  height: 81,
                  child: Obx(() => ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          _gradeDetailController.semestersWithGrades.length,
                      itemBuilder: (context, index) {
                        final semester =
                            _gradeDetailController.semestersWithGrades[index];
                        return Obx(() => Row(children: [
                              TwoLineCard(
                                animate: true,
                                withColoredFont: true,
                                width: 120,
                                title:
                                    '${semester.name.substring(2, 5)}${semester.name.substring(7, 11)}',
                                content:
                                    '${semester.gpa[0].toStringAsFixed(2)}/${semester.credits.toStringAsFixed(1)}',
                                onTap: () {
                                  _gradeDetailController.semesterIndex.value =
                                      index;
                                  _gradeDetailController.semesterIndex
                                      .refresh();
                                },
                                backgroundColor: _gradeDetailController
                                            .semesterIndex.value ==
                                        index
                                    ? CustomCupertinoDynamicColors.cyan
                                    : CupertinoColors.systemFill,
                              ),
                              if (index !=
                                  _gradeDetailController
                                          .semestersWithGrades.length -
                                      1)
                                const SizedBox(width: 6),
                            ]));
                      })),
                ),
              ]),
            )),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
        backgroundColor: CupertinoDynamicColor.resolve(
            CupertinoColors.systemGroupedBackground, context),
        child: CustomScrollView(
      slivers: [
        const CelechronSliverTextHeader(subtitle: '成绩'),
        SliverToBoxAdapter(
            child: Column(children: [
          Row(
            children: [
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _buildGradeBrief(context),
                    _buildHistory(context),
                  ],
                ),
              ),
              const SizedBox(width: 18),
            ],
          )
        ])),
        Obx(() => SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return Column(children: [
                  Row(
                    children: [
                      const SizedBox(width: 18),
                      Expanded(
                          child: GradeCard(
                        grade: _gradeDetailController
                            .semestersWithGrades[
                                _gradeDetailController.semesterIndex.value]
                            .grades[index],
                      )),
                      const SizedBox(width: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                ]);
              },
                  childCount: _gradeDetailController
                      .semestersWithGrades[
                          _gradeDetailController.semesterIndex.value]
                      .grades
                      .length),
            )),
      ],
    ));
  }
}
