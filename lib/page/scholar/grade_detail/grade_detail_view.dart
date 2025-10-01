import 'package:celechron/design/custom_colors.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/model/grade.dart';
import 'package:celechron/model/semester.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/design/two_line_card.dart';
import 'package:celechron/design/persistent_headers.dart';
import 'grade_card.dart';
import 'package:celechron/page/scholar/scholar_controller.dart';
import 'grade_detail_controller.dart';
import 'package:celechron/utils/gpa_helper.dart';

class GradeDetailPage extends StatelessWidget {
  final _scholarController = Get.find<ScholarController>();
  final _gradeDetailController = Get.put(GradeDetailController());

  GradeDetailPage({super.key}) {
    _gradeDetailController.init();
  }

  int getPairedSemesterIndex(int idx) {
    for (var i = 0;
        i < _gradeDetailController.semestersWithGrades.length;
        i++) {
      if (i != idx &&
          _gradeDetailController.semestersWithGrades[i].name.substring(2, 5) ==
              _gradeDetailController.semestersWithGrades[idx].name
                  .substring(2, 5)) {
        return i;
      }
    }
    return idx;
  }

  Tuple<List<double>, double> getYearStats(int semesterIndex) {
    var s1 = _gradeDetailController.semestersWithGrades[semesterIndex];
    int another = getPairedSemesterIndex(semesterIndex);
    if (another == semesterIndex) {
      return Tuple([s1.gpa[0], s1.gpa[1], s1.gpa[2]], s1.credits);
    }
    var s2 = _gradeDetailController.semestersWithGrades[another];
    double credits = s1.credits + s2.credits;
    if (credits == 0) {
      return Tuple([0, 0, 0], 0);
    }
    return Tuple(
        List.generate(
            3,
            (int i) =>
                (s1.credits * s1.gpa[i] + s2.credits * s2.gpa[i]) / credits),
        credits);
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
                                title: '学年学分',
                                content: getYearStats(_gradeDetailController
                                        .semesterIndex.value)
                                    .item2
                                    .toStringAsFixed(1),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.sand)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Obx(() => TwoLineCard(
                                title: '学年均绩',
                                content: getYearStats(_gradeDetailController
                                        .semesterIndex.value)
                                    .item1[0]
                                    .toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.sakura)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Obx(() => TwoLineCard(
                                title: '学年四分制',
                                content: getYearStats(_gradeDetailController
                                        .semesterIndex.value)
                                    .item1[1]
                                    .toStringAsFixed(2),
                                extraContent: getYearStats(
                                        _gradeDetailController
                                            .semesterIndex.value)
                                    .item1[2]
                                    .toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.magenta)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Obx(() => TwoLineCard(
                                title: '学年主修学分',
                                content: _gradeDetailController
                                    .getYearMajorGpa(_gradeDetailController
                                        .semesterIndex.value)
                                    .item2
                                    .toStringAsFixed(1),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.peach)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Obx(() => TwoLineCard(
                                title: '学年主修均绩',
                                content: _gradeDetailController
                                    .getYearMajorGpa(_gradeDetailController
                                        .semesterIndex.value)
                                    .item1[0]
                                    .toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.cyan)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Obx(() => TwoLineCard(
                                title: '学年主修四分制',
                                content: _gradeDetailController
                                    .getYearMajorGpa(_gradeDetailController
                                        .semesterIndex.value)
                                    .item1[1]
                                    .toStringAsFixed(2),
                                extraContent: _gradeDetailController
                                    .getYearMajorGpa(_gradeDetailController
                                        .semesterIndex.value)
                                    .item1[2]
                                    .toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.spring)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCustomGpaBrief(BuildContext context) {
    List<Grade> inSelected = [], notSelected = [];
    for (var semester in _gradeDetailController.semestersWithGrades) {
      for (var grade in semester.grades) {
        if (_gradeDetailController.customGpaSelected[grade.id] ?? false) {
          inSelected.add(grade);
        } else {
          notSelected.add(grade);
        }
      }
    }
    var inGpa = GpaHelper.calculateGpa(inSelected);
    var notGpa = GpaHelper.calculateGpa(notSelected);

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
                                title: '已选学分',
                                content: inGpa.item2.toStringAsFixed(1),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.sand)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Obx(() => TwoLineCard(
                                title: '已选五分制',
                                content: inGpa.item1[0].toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.sakura)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Obx(() => TwoLineCard(
                                title: '已选四分制',
                                content: inGpa.item1[1].toStringAsFixed(2),
                                extraContent: inGpa.item1[2].toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.magenta)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Obx(() => TwoLineCard(
                                title: '未选学分',
                                content: notGpa.item2.toStringAsFixed(1),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.peach)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Obx(() => TwoLineCard(
                                title: '未选五分制',
                                content: notGpa.item1[0].toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.cyan)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Obx(() => TwoLineCard(
                                title: '未选四分制',
                                content: notGpa.item1[1].toStringAsFixed(2),
                                extraContent:
                                    notGpa.item1[2].toStringAsFixed(2),
                                backgroundColor:
                                    CustomCupertinoDynamicColors.spring)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  int getSelectedGradeCount(Semester semester) {
    int selectedCount = 0;
    for (var i in semester.grades) {
      if (_gradeDetailController.customGpaSelected[i.id] ?? false) {
        selectedCount++;
      }
    }
    return selectedCount;
  }

  Widget _buildHistory(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: RoundRectangleCard(
                animate: false,
                child: Column(
                  children: [
                    // Horizontal scrollable list to list all semesters
                    SizedBox(
                      height: 81,
                      child: Obx(
                        () => ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              _gradeDetailController.semestersWithGrades.length,
                          itemBuilder: (context, index) {
                            final semester = _gradeDetailController
                                .semestersWithGrades[index];

                            return Obx(
                              () => Row(
                                children: [
                                  Obx(
                                    () => TwoLineCard(
                                      animate: true,
                                      withColoredFont: true,
                                      width: 120,
                                      title:
                                          '${semester.name.substring(2, 5)}${semester.name.substring(7, 11)}',
                                      content: _gradeDetailController
                                              .customGpaMode.value
                                          ? '${getSelectedGradeCount(semester)} / ${semester.grades.length}'
                                          : '${semester.gpa[0].toStringAsFixed(2)}/${semester.credits.toStringAsFixed(1)}',
                                      onTap: () {
                                        _gradeDetailController
                                            .semesterIndex.value = index;
                                        _gradeDetailController.semesterIndex
                                            .refresh();
                                      },
                                      backgroundColor: _gradeDetailController
                                                  .semesterIndex.value ==
                                              index
                                          ? CustomCupertinoDynamicColors.cyan
                                          : CupertinoColors.systemFill,
                                    ),
                                  ),
                                  if (index !=
                                      _gradeDetailController
                                              .semestersWithGrades.length -
                                          1)
                                    const SizedBox(width: 6),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
          CelechronSliverTextHeader(
            subtitle: '成绩',
            right: Obx(
              () => Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_gradeDetailController.customGpaMode.value)
                    GestureDetector(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text('长按清空'),
                        onPressed: () {},
                      ),
                      onLongPress: () {
                        _gradeDetailController.customGpaSelected.value = {};
                        _gradeDetailController.refreshCustomGpa();
                      },
                    ),
                  const SizedBox(
                    width: 16,
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(
                      _gradeDetailController.customGpaMode.value
                          ? CupertinoIcons.square_fill_line_vertical_square_fill
                          : CupertinoIcons.square_line_vertical_square,
                      semanticLabel: 'Custom GPA',
                    ),
                    onPressed: () {
                      _gradeDetailController.customGpaMode.value =
                          !_gradeDetailController.customGpaMode.value;
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        children: [
                          Obx(() => _gradeDetailController.customGpaMode.value
                              ? _buildCustomGpaBrief(context)
                              : _buildGradeBrief(context)),
                          _buildHistory(context),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                  ],
                )
              ],
            ),
          ),
          Obx(
            () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 18),
                          Expanded(
                            child: GradeCard(
                              grade: _gradeDetailController
                                  .semestersWithGrades[_gradeDetailController
                                      .semesterIndex.value]
                                  .grades[index],
                            ),
                          ),
                          const SizedBox(width: 18),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
                childCount: _gradeDetailController
                    .semestersWithGrades[
                        _gradeDetailController.semesterIndex.value]
                    .grades
                    .length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
