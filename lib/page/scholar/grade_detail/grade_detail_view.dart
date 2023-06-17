import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:celechron/widget/round_rectangle_card.dart';
import 'package:celechron/widget/two_line_card.dart';
import '../../../widget/sub_title.dart';
import 'grade_card.dart';
import '../scholar_controller.dart';
import '../scholar_view.dart';
import 'grade_detail_controller.dart';

class GradeDetailPage extends StatelessWidget {

  final _scholarController = Get.find<ScholarController>();
  late final GradeDetailController _gradeDetailController;

  GradeDetailPage({super.key}){
    Get.delete<GradeDetailController>();
    _gradeDetailController = Get.put(GradeDetailController());
  }

  Widget _buildGradeBrief(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: Hero(tag: 'gradeBrief', child: RoundRectangleCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Obx(() => TwoLineCard(
                                  title: '五分制',
                                  content: _scholarController.user.gpa[0]
                                      .toStringAsFixed(2),
                                  backgroundColor: ScholarPageColors.cyan)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Obx(() => TwoLineCard(
                                  title: '获得学分',
                                  content: _scholarController.user.credit
                                      .toStringAsFixed(1),
                                  backgroundColor: ScholarPageColors.peach)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Obx(() => TwoLineCard(
                                  title: '四分制',
                                  content: _scholarController.user.gpa[1]
                                      .toStringAsFixed(2),
                                  backgroundColor: ScholarPageColors.spring)),
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
                                  backgroundColor: ScholarPageColors.sakura)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Obx(() => TwoLineCard(
                                  title: '主修学分',
                                  content: _scholarController
                                      .user.majorGpaAndCredit[1]
                                      .toStringAsFixed(1),
                                  backgroundColor: ScholarPageColors.sand)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Obx(() => TwoLineCard(
                                  title: '百分制',
                                  content: _scholarController.user.gpa[2]
                                      .toStringAsFixed(2),
                                  backgroundColor: ScholarPageColors.magenta)),
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
                      child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _gradeDetailController.semestersWithGrades.length,
                          itemBuilder: (context, index) {
                            final semester = _gradeDetailController.semestersWithGrades[index];
                            return Obx(() => Stack(children: [
                              TwoLineCard(
                                animate: true,
                                withColoredFont: true,
                                title:
                                '${semester.name.substring(2, 5)}${semester.name.substring(7, 11)}',
                                content:
                                '${semester.gpa[0].toStringAsFixed(2)}/${semester.credits.toStringAsFixed(1)}',
                                onTap: () {
                                  _gradeDetailController.semesterIndex.value = index;
                                  _gradeDetailController.semesterIndex.refresh();
                                },
                                backgroundColor: _gradeDetailController.semesterIndex.value == index
                                    ? ScholarPageColors.cyan
                                    : CupertinoColors.systemFill,
                              ),
                              const SizedBox(width: 125),
                            ]));
                          }),
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
        child: CustomScrollView(
          slivers: [
            SubtitlePersistentHeader(subtitle: '成绩'),
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
                            grade: _gradeDetailController.semestersWithGrades[_gradeDetailController.semesterIndex.value].grades[index],
                          )),
                      const SizedBox(width: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                ]);
              }, childCount: _gradeDetailController.semestersWithGrades[_gradeDetailController.semesterIndex.value].grades.length),
            )),
          ],
        ));
  }
}
