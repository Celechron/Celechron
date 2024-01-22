// Official packages
import 'package:extended_sliver/extended_sliver.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Custom widgets and colors
import 'package:celechron/design/multiple_columns.dart';
import 'package:celechron/design/sub_title.dart';
import 'package:celechron/design/two_line_card.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/design/custom_colors.dart';
import 'package:celechron/design/animate_button.dart';

import 'package:celechron/model/semester.dart';
import 'course_list/course_list_view.dart';
import 'course_schedule/course_schedule_view.dart';
import 'exam_list/exam_list_view.dart';
import 'grade_detail/grade_detail_view.dart';
import 'scholar_controller.dart';

class ScholarPage extends StatelessWidget {
  ScholarPage({super.key});

  final _scholarController = Get.put(ScholarController());

  Widget _buildGradeBrief(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: Hero(
                    tag: 'gradeBrief',
                    child: RoundRectangleCardWithForehead(
                        foreheadColor: CustomCupertinoDynamicColors
                            .okGreen.darkColor
                            .withOpacity(0.25),
                        forehead: Obx(() => Row(children: [
                              // University Icon
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 12, top: 6, bottom: 6),
                                child: Icon(
                                  Icons.school,
                                  color: CupertinoDynamicColor.resolve(
                                      CupertinoColors.label, context),
                                  size: 18,
                                ),
                              ),
                              Padding(
                                  padding: const EdgeInsets.only(
                                      left: 6, top: 6, bottom: 6),
                                  child: Text('成绩',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        overflow: TextOverflow.ellipsis,
                                        color: CupertinoDynamicColor.resolve(
                                            CupertinoColors.label, context),
                                      ))),
                              const Spacer(),
                              // alert icon
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 4, bottom: 4),
                                child: Icon(
                                  _scholarController
                                              .durationToLastUpdate.inMinutes <
                                          5
                                      ? CupertinoIcons.check_mark_circled_solid
                                      : CupertinoIcons
                                          .exclamationmark_circle_fill,
                                  color: CupertinoDynamicColor.resolve(
                                      CupertinoColors.label, context),
                                  size: 14,
                                ),
                              ),
                              Padding(
                                  padding: const EdgeInsets.only(
                                      left: 4, top: 4, bottom: 4, right: 16),
                                  child: Text(
                                      _scholarController.durationToLastUpdate
                                                  .inMinutes >
                                              10000000
                                          ? '获取数据时遇到问题'
                                          : '更新于 ${_scholarController.durationToLastUpdate.inMinutes} 分钟前',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        overflow: TextOverflow.ellipsis,
                                        color: CupertinoDynamicColor.resolve(
                                            CupertinoColors.label, context),
                                      )))
                            ])),
                        onTap: () async =>
                            Navigator.of(context, rootNavigator: true).push(
                                CupertinoPageRoute(
                                    builder: (context) => GradeDetailPage(),
                                    fullscreenDialog: true)),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Obx(() => TwoLineCard(
                                      title: '五分制',
                                      content: _scholarController.user.gpa[0]
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
                                      content: _scholarController.user.gpa[1]
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
                                      content: _scholarController.user.gpa[2]
                                          .toStringAsFixed(2),
                                      backgroundColor:
                                          CustomCupertinoDynamicColors
                                              .magenta)),
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

  Widget _buildSemester(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: RoundRectangleCardWithForehead(
                    animate: false,
                    foreheadColor: CustomCupertinoDynamicColors.cyan.darkColor
                        .withOpacity(0.25),
                    forehead: Obx(() => Row(children: [
                          // University Icon
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 12, top: 6, bottom: 6),
                            child: Icon(
                              Icons.calendar_month_rounded,
                              color: CupertinoDynamicColor.resolve(
                                  CupertinoColors.label, context),
                              size: 18,
                            ),
                          ),
                          Padding(
                              padding: const EdgeInsets.only(
                                  left: 6, top: 6, bottom: 6),
                              child: Text('课程',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    overflow: TextOverflow.ellipsis,
                                    color: CupertinoDynamicColor.resolve(
                                        CupertinoColors.label, context),
                                  ))),
                          const Spacer(),
                          // alert icon
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            child: Icon(
                              _scholarController
                                          .durationToLastUpdate.inMinutes <
                                      5
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.exclamationmark_circle_fill,
                              color: CupertinoDynamicColor.resolve(
                                  CupertinoColors.label, context),
                              size: 14,
                            ),
                          ),
                          Padding(
                              padding: const EdgeInsets.only(
                                  left: 4, top: 4, bottom: 4, right: 16),
                              child: Text(
                                  _scholarController
                                              .durationToLastUpdate.inMinutes >
                                          10000000
                                      ? '获取数据时遇到问题'
                                      : '更新于 ${_scholarController.durationToLastUpdate.inMinutes} 分钟前',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    overflow: TextOverflow.ellipsis,
                                    color: CupertinoDynamicColor.resolve(
                                        CupertinoColors.label, context),
                                  )))
                        ])),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        MultipleColumns(
                          contents: [
                            Text(
                                _scholarController
                                    .selectedSemester.courses.length
                                    .toString(),
                                style: CupertinoTheme.of(context)
                                    .textTheme
                                    .navTitleTextStyle
                                    .copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                            Text(
                                _scholarController.selectedSemester.courseCredit
                                    .toString(),
                                style: CupertinoTheme.of(context)
                                    .textTheme
                                    .navTitleTextStyle
                                    .copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                            Text(
                                _scholarController.selectedSemester.examCount
                                    .toString(),
                                style: CupertinoTheme.of(context)
                                    .textTheme
                                    .navTitleTextStyle
                                    .copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                          ],
                          titles: const ['课程', '学分', '考试'],
                          onTaps: [
                            () => Navigator.of(context, rootNavigator: true)
                                .push(CupertinoPageRoute(
                                    builder: (context) => CourseListPage(
                                        initialSemesterName: _scholarController
                                            .selectedSemester.name),
                                    title: '课程')),
                            null,
                            () => Navigator.of(context, rootNavigator: true)
                                .push(CupertinoPageRoute(
                                    builder: (context) => ExamListPage(
                                        initialSemesterName: _scholarController
                                            .selectedSemester.name),
                                    title: '考试'))
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TwoLineCard(
                                  animate: true,
                                  // With CupertinoPageTransition
                                  onTap: () =>
                                      Navigator.of(context, rootNavigator: true)
                                          .push(
                                        CupertinoPageRoute(
                                          builder: (context) =>
                                              CourseSchedulePage(
                                                  _scholarController
                                                      .selectedSemester.name,
                                                  true),
                                          title: '课表',
                                        ),
                                      ),
                                  title:
                                      '${_scholarController.selectedSemester.firstHalfName}学期课时',
                                  content:
                                      '${_scholarController.selectedSemester.firstHalfSessionCount}节/两周',
                                  backgroundColor: _scholarController
                                              .selectedSemester.name[9] ==
                                          '春'
                                      ? CustomCupertinoDynamicColors.spring
                                      : CustomCupertinoDynamicColors.autumn,
                                  withColoredFont: true),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TwoLineCard(
                                  animate: true,
                                  onTap: () =>
                                      Navigator.of(context, rootNavigator: true)
                                          .push(
                                        CupertinoPageRoute(
                                          builder: (context) =>
                                              CourseSchedulePage(
                                                  _scholarController
                                                      .selectedSemester.name,
                                                  false),
                                          title: '课表',
                                        ),
                                      ),
                                  title:
                                      '${_scholarController.selectedSemester.secondHalfName}学期课时',
                                  content:
                                      '${_scholarController.selectedSemester.secondHalfSessionCount}节/两周',
                                  backgroundColor: _scholarController
                                              .selectedSemester.name[9] ==
                                          '春'
                                      ? CustomCupertinoDynamicColors.summer
                                      : CustomCupertinoDynamicColors.winter,
                                  withColoredFont: true),
                            ),
                          ],
                        ),
                      ],
                    ))),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHistory(BuildContext context) {
    return Column(
      children: [
        SubtitleRow(subtitle: '历史学期'),
        Row(
          children: [
            Expanded(
                child: RoundRectangleCard(
              child: Column(children: [
                // Horizontal scrollable list to list all semesters
                SizedBox(
                  height: 81,
                  child: Obx(() => ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _scholarController.user.semesters.length,
                      itemBuilder: (context, index) {
                        final semester = _scholarController.user.semesters[
                            _scholarController.user.semesters.length -
                                1 -
                                index];
                        return Row(children: [
                          TwoLineCard(
                            animate: true,
                            withColoredFont: true,
                            width: 120,
                            title:
                                '${semester.name.substring(2, 5)}${semester.name.substring(7, 11)}',
                            content:
                                '${semester.gpa[0].toStringAsFixed(2)}/${semester.credits.toStringAsFixed(1)}',
                            backgroundColor: CupertinoColors.systemFill,
                          ),
                          const SizedBox(width: 6),
                        ]);
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
        child: SafeArea(
            child: CustomScrollView(
          slivers: [
            SliverPinnedToBoxAdapter(
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(children: [
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoSearchTextField(
                            placeholder: '搜索课程、事项……',
                            placeholderStyle: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(
                                    color: CupertinoColors.systemGrey,
                                    height: 1.25,
                                    fontSize: 14),
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(height: 1.25, fontSize: 14),
                            borderRadius: BorderRadius.circular(12),
                            itemColor: CupertinoColors.systemGrey,
                            itemSize: 18,
                            suffixInsets: const EdgeInsetsDirectional.fromSTEB(
                                0, 0, 5, 0),
                            prefixInsets: const EdgeInsetsDirectional.fromSTEB(
                                10, 0, 0, 0),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                          ),
                        ),
                        // Refresh Icon on the right
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Icon(
                              CupertinoIcons.refresh_circled_solid,
                              size: 24,
                              color: CupertinoColors.systemGrey),
                          onPressed: () async {
                            var error = await _scholarController.fetchData();
                            if (error.any((e) => e != null)) {
                              if (context.mounted) {
                                showCupertinoDialog(
                                  context: context,
                                  builder: (context) {
                                    return CupertinoAlertDialog(
                                      title: const Text('刷新失败'),
                                      content: Text(error
                                          .where((e) => e != null)
                                          .fold('', (p, v) => '$p\n$v')
                                          .trim()),
                                      actions: [
                                        CupertinoDialogAction(
                                          child: const Text('确定'),
                                          onPressed: () async {
                                            Navigator.of(context).pop();
                                          },
                                        )
                                      ],
                                    );
                                  },
                                );
                              }
                            }
                          },
                        ),
                        // Setting Icon on the right
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: SizedBox(
                          height: 30,
                          child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _scholarController.semesters.length,
                              itemBuilder: (context, index) {
                                final semester =
                                    _scholarController.semesters[index];
                                return Obx(() => Stack(children: [
                                      AnimateButton(
                                        text:
                                            '${semester.name.substring(2, 5)}${semester.name.substring(7, 11)}',
                                        onTap: () {
                                          _scholarController
                                              .semesterIndex.value = index;
                                          _scholarController.semesterIndex
                                              .refresh();
                                        },
                                        backgroundColor: _scholarController
                                                    .semesterIndex.value ==
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
                  ])),
            ),
            if (_scholarController.user.isLogin)
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  var error = await _scholarController.fetchData();
                  if (error.any((e) => e != null)) {
                    if (context.mounted) {
                      showCupertinoDialog(
                          context: context,
                          builder: (context) {
                            return CupertinoAlertDialog(
                              title: const Text('刷新失败'),
                              content: Text(error
                                  .where((e) => e != null)
                                  .fold('', (p, v) => '$p\n$v')
                                  .trim()),
                              actions: [
                                CupertinoDialogAction(
                                  child: const Text('确定'),
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                  },
                                )
                              ],
                            );
                          });
                    }
                  }
                },
              ),
            Obx(() {
              if (_scholarController.user.semesters.isNotEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildGradeBrief(context),
                        const SizedBox(height: 20),
                        _buildSemester(context),
                        //_buildHistory(context),
                      ],
                    ),
                  ),
                );
              } else {
                return SliverToBoxAdapter(
                    child: SizedBox(
                        height: 500,
                        child: Column(children: [
                          const Spacer(),
                          Text(_scholarController.user.isLogin ? '下拉刷新' : '未登录',
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle),
                          const Spacer()
                        ])));
              }
            })
          ],
        )));
  }
}
