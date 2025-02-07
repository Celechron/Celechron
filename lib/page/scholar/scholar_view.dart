// Official packages
import 'package:celechron/page/scholar/todo/todo_card.dart';
import 'package:extended_sliver/extended_sliver.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Custom widgets and colors
import 'package:celechron/design/multiple_columns.dart';
import 'package:celechron/design/two_line_card.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/design/custom_colors.dart';
import 'package:celechron/design/animate_button.dart';

import 'package:celechron/page/search/search_view.dart';
import 'course_list/course_list_view.dart';
import 'course_schedule/course_schedule_view.dart';
import 'exam_list/exam_list_view.dart';
import 'grade_detail/grade_detail_view.dart';
import 'scholar_controller.dart';

class ScholarErrorHandler extends StatelessWidget {
  final FlutterErrorDetails errorDetails;
  final _scholarController = Get.put(ScholarController());

  ScholarErrorHandler({
    super.key,
    required this.errorDetails,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate([
        CupertinoListSection.insetGrouped(
          header: Container(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: Text(
              '获取数据时遇到问题。请检查网络连接情况，并尝试重新获取数据。\n注意：你需要完成所有的教学评价才能获取成绩信息。',
              style: TextStyle(
                  color: CupertinoDynamicColor.resolve(
                      CupertinoColors.secondaryLabel, context),
                  fontSize: 14),
            ),
          ),
          children: [
            CupertinoButton(
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
                        });
                  }
                }
              },
              child: const Text('重新获取数据'),
            ),
          ],
        ),
      ]),
    );
  }
}

class ScholarPage extends StatelessWidget {
  ScholarPage({super.key}) {
    ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
      return ScholarErrorHandler(errorDetails: errorDetails);
    };
  }

  final _scholarController = Get.put(ScholarController());

  Widget _buildGradeBrief(BuildContext context) {
    return RoundRectangleCard(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: Hero(
                        tag: 'gradeBrief',
                        child: RoundRectangleCardWithForehead(
                            foreheadColor: CustomCupertinoDynamicColors
                                .okGreen.darkColor
                                .withValues(alpha: 0.25),
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
                                            color:
                                                CupertinoDynamicColor.resolve(
                                                    CupertinoColors.label,
                                                    context),
                                          ))),
                                  const Spacer(),
                                  // alert icon
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 4, bottom: 4),
                                    child: Icon(
                                      _scholarController.durationToLastUpdate
                                                  .inMinutes <
                                              5
                                          ? CupertinoIcons
                                              .check_mark_circled_solid
                                          : CupertinoIcons
                                              .exclamationmark_circle_fill,
                                      color: CupertinoDynamicColor.resolve(
                                          CupertinoColors.label, context),
                                      size: 14,
                                    ),
                                  ),
                                  Padding(
                                      padding: const EdgeInsets.only(
                                          left: 4,
                                          top: 4,
                                          bottom: 4,
                                          right: 16),
                                      child: Text(
                                          _scholarController
                                                      .durationToLastUpdate
                                                      .inMinutes >
                                                  10000000
                                              ? '获取数据时遇到问题'
                                              : '更新于 ${_scholarController.durationToLastUpdate.inMinutes} 分钟前',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            overflow: TextOverflow.ellipsis,
                                            color:
                                                CupertinoDynamicColor.resolve(
                                                    CupertinoColors.label,
                                                    context),
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
                                          content: _scholarController.gpa[0]
                                              .toStringAsFixed(2),
                                          backgroundColor:
                                              CustomCupertinoDynamicColors
                                                  .cyan)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Obx(() => TwoLineCard(
                                          title: '获得学分',
                                          content: _scholarController
                                              .scholar.credit
                                              .toStringAsFixed(1),
                                          backgroundColor:
                                              CustomCupertinoDynamicColors
                                                  .peach)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Obx(() => TwoLineCard(
                                          title: '四分制',
                                          content: _scholarController.gpa[1]
                                              .toStringAsFixed(2),
                                          extraContent: _scholarController
                                              .gpa[2]
                                              .toStringAsFixed(2),
                                          backgroundColor:
                                              CustomCupertinoDynamicColors
                                                  .spring)),
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
                                              .scholar.majorGpaAndCredit[0]
                                              .toStringAsFixed(2),
                                          backgroundColor:
                                              CustomCupertinoDynamicColors
                                                  .sakura)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Obx(() => TwoLineCard(
                                          title: '主修学分',
                                          content: _scholarController
                                              .scholar.majorGpaAndCredit[1]
                                              .toStringAsFixed(1),
                                          backgroundColor:
                                              CustomCupertinoDynamicColors
                                                  .sand)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Obx(() => TwoLineCard(
                                          title: '百分制',
                                          content: _scholarController.gpa[3]
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
          ],
        ));
  }

  Widget _buildSemester(BuildContext context) {
    return RoundRectangleCard(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: RoundRectangleCardWithForehead(
                        animate: false,
                        foreheadColor: CustomCupertinoDynamicColors
                            .cyan.darkColor
                            .withValues(alpha: 0.25),
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
                                    _scholarController
                                        .selectedSemester.courseCredit
                                        .toString(),
                                    style: CupertinoTheme.of(context)
                                        .textTheme
                                        .navTitleTextStyle
                                        .copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                Text(
                                    _scholarController
                                        .selectedSemester.examCount
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
                                            initialSemesterName:
                                                _scholarController
                                                    .selectedSemester.name),
                                        title: '课程')),
                                null,
                                () => Navigator.of(context, rootNavigator: true)
                                    .push(CupertinoPageRoute(
                                        builder: (context) => ExamListPage(
                                            initialSemesterName:
                                                _scholarController
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
                                      onTap: () => Navigator.of(context,
                                                  rootNavigator: true)
                                              .push(
                                            CupertinoPageRoute(
                                              builder: (context) =>
                                                  CourseSchedulePage(
                                                      _scholarController
                                                          .selectedSemester
                                                          .name,
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
                                      onTap: () => Navigator.of(context,
                                                  rootNavigator: true)
                                              .push(
                                            CupertinoPageRoute(
                                              builder: (context) =>
                                                  CourseSchedulePage(
                                                      _scholarController
                                                          .selectedSemester
                                                          .name,
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
          ],
        ));
  }

  Widget _buildTodos(BuildContext context) {
    return RoundRectangleCard(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: RoundRectangleCardWithForehead(
                        animate: false,
                        foreheadColor: CustomCupertinoDynamicColors
                            .magenta.darkColor
                            .withValues(alpha: 0.25),
                        forehead: Obx(() => Row(children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 12, top: 6, bottom: 6),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: CupertinoDynamicColor.resolve(
                                      CupertinoColors.label, context),
                                  size: 18,
                                ),
                              ),
                              Padding(
                                  padding: const EdgeInsets.only(
                                      left: 6, top: 6, bottom: 6),
                                  child: Text('作业',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        overflow: TextOverflow.ellipsis,
                                        color: CupertinoDynamicColor.resolve(
                                            CupertinoColors.label, context),
                                      ))),
                              const Spacer(),
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
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            MultipleColumns(
                              contents: [
                                Text(_scholarController.todos.length.toString(),
                                    style: CupertinoTheme.of(context)
                                        .textTheme
                                        .navTitleTextStyle
                                        .copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                Text(
                                    _scholarController.todosInOneDay.length
                                        .toString(),
                                    style: CupertinoTheme.of(context)
                                        .textTheme
                                        .navTitleTextStyle
                                        .copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                Text(
                                    _scholarController.todosInOneWeek.length
                                        .toString(),
                                    style: CupertinoTheme.of(context)
                                        .textTheme
                                        .navTitleTextStyle
                                        .copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                              ],
                              titles: const ["总计", "一天内", "本周截止"],
                              onTaps: [() {}, () {}, () {}],
                            ),
                            const SizedBox(height: 16),
                            if (_scholarController.todos.isNotEmpty)
                              SizedBox(
                                  height: 102,
                                  child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _scholarController.todos.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(width: 8),
                                      itemBuilder: (context, index) {
                                        final todo =
                                            _scholarController.todos[index];
                                        return SizedBox(
                                            width: 200,
                                            child: TodoCard(todo: todo));
                                    }))
                          ],
                        ))),
              ],
            ),
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
        /*backgroundColor: CupertinoDynamicColor.resolve(
            CupertinoColors.systemGroupedBackground, context),*/
        child: CustomScrollView(
      slivers: [
        SliverPinnedToBoxAdapter(
            child: Container(
          decoration: BoxDecoration(
            color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemBackground, context),
            /*boxShadow: [
              BoxShadow(
                color: CupertinoDynamicColor.resolve(
                    CupertinoColors.systemGrey5, context),
                offset: const Offset(0, 0),
                blurRadius: 4,
              ),
            ],
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16)),*/
          ),
          child: Padding(
              padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 4,
                  top: 8 + MediaQuery.of(context).padding.top),
              child: Column(children: [
                Row(
                  children: [
                    const SizedBox(width: 2),
                    Text(
                      '学业',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .navLargeTitleTextStyle
                          .copyWith(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoSearchTextField(
                        placeholder: '搜索课程、事项...',
                        placeholderStyle: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(
                                color: CupertinoColors.systemGrey,
                                height: 1.25,
                                fontSize: 18),
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(height: 1.25, fontSize: 18),
                        borderRadius: BorderRadius.circular(12),
                        itemColor: CupertinoColors.systemGrey,
                        itemSize: 20,
                        suffixInsets:
                            const EdgeInsetsDirectional.fromSTEB(0, 0, 5, 0),
                        prefixInsets:
                            const EdgeInsetsDirectional.fromSTEB(10, 0, 0, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        onTap: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(context, rootNavigator: true).push(
                              CupertinoPageRoute(
                                  builder: (context) => SearchPage()));
                        },
                        focusNode: AlwaysDisabledFocusNode(),
                        // Do not popup the keyboard
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 30,
                        child: Obx(
                          () => ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _scholarController.semesters.length,
                            itemBuilder: (context, index) {
                              final semester =
                                  _scholarController.semesters[index];
                              return Stack(
                                children: [
                                  Obx(
                                    () => AnimateButton(
                                      text:
                                          '${semester.name.substring(2, 5)}${semester.name.substring(7, 11)}',
                                      onTap: () {
                                        _scholarController.semesterIndex.value =
                                            index;
                                        _scholarController.semesterIndex
                                            .refresh();
                                      },
                                      backgroundColor: _scholarController
                                                  .semesterIndex.value ==
                                              index
                                          ? CustomCupertinoDynamicColors.cyan
                                          : CupertinoColors.systemFill,
                                    ),
                                  ),
                                  const SizedBox(width: 90),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Divider(
                  thickness: 0,
                  color: CupertinoDynamicColor.resolve(
                      CupertinoColors.separator, context),
                  height: 14,
                ),
              ])),
        )),
        if (_scholarController.scholar.isLogan)
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
          if (_scholarController.scholar.semesters.isNotEmpty) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                    top: 8,
                    right: 16,
                    left: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 4),
                child: Column(
                  children: _scholarController.scholar.isGrs
                      ? [
                          const SizedBox(height: 12),
                          _buildSemester(context),
                          const SizedBox(height: 12),
                          Divider(
                            thickness: 0,
                            color: CupertinoDynamicColor.resolve(
                                CupertinoColors.separator, context),
                            height: 14,
                          ),
                          const SizedBox(height: 12),
                          _buildTodos(context),
                        ]
                      : [
                          _buildGradeBrief(context),
                          const SizedBox(height: 12),
                          Divider(
                            thickness: 0,
                            color: CupertinoDynamicColor.resolve(
                                CupertinoColors.separator, context),
                            height: 14,
                          ),
                          const SizedBox(height: 12),
                          _buildSemester(context),
                          const SizedBox(height: 12),
                          Divider(
                            thickness: 0,
                            color: CupertinoDynamicColor.resolve(
                                CupertinoColors.separator, context),
                            height: 14,
                          ),
                          const SizedBox(height: 12),
                          _buildTodos(context),
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
                      Text(_scholarController.scholar.isLogan ? '下拉刷新' : '未登录',
                          style:
                              CupertinoTheme.of(context).textTheme.textStyle),
                      const Spacer()
                    ])));
          }
        }),
      ],
    ));
  }
}

class AlwaysDisabledFocusNode extends FocusNode {
  @override
  bool get hasFocus => false;
}
