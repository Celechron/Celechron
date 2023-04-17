import 'package:celechron/widget/multiple_columns.dart';
import 'package:celechron/widget/sub_title.dart';
import 'package:celechron/widget/two_line_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import '../../model/semester.dart';
import '../../widget/title_card.dart';
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
        SubtitleRow(
            subtitle: '成绩',
            right: Obx(() => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    border: Border.all(
                        color: _scholarController.durationToLastUpdate >
                                const Duration(minutes: 5)
                            ? const Color.fromRGBO(255, 0, 0, 1.0)
                            : ScholarPageColors.okGreen.darkColor,
                        width: 1),
                    color: _scholarController.durationToLastUpdate >
                            const Duration(minutes: 5)
                        ? const Color.fromRGBO(255, 0, 0, 1.0)
                        : const Color.fromRGBO(0, 0, 0, 0),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                    '更新于${_scholarController.durationToLastUpdate.inMinutes}分钟前',
                    style: TextStyle(
                        color: _scholarController.durationToLastUpdate >
                                const Duration(minutes: 5)
                            ? const Color.fromRGBO(255, 255, 255, 1.0)
                            : ScholarPageColors.okGreen.darkColor,
                        fontSize: 12))))),
        Row(
          children: [
            Expanded(
                child: Hero(
                    tag: 'gradeBrief',
                    child: TitleCard(
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
                                      backgroundColor: ScholarPageColors.cyan)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Obx(() => TwoLineCard(
                                      title: '获得学分',
                                      content: _scholarController.user.credit
                                          .toStringAsFixed(1),
                                      backgroundColor:
                                          ScholarPageColors.peach)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Obx(() => TwoLineCard(
                                      title: '四分制',
                                      content: _scholarController.user.gpa[1]
                                          .toStringAsFixed(2),
                                      backgroundColor:
                                          ScholarPageColors.spring)),
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
                                          ScholarPageColors.sakura)),
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
                                      backgroundColor:
                                          ScholarPageColors.magenta)),
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

  Widget _buildSemester(BuildContext context, Semester semester) {
    return Column(
      children: [
        SubtitleRow(
            subtitle: '本学期',
            right: Container(
                // A text box with rounded rectangle shape, only show border, and with 10px radius
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    border: Border.all(
                        color: ScholarPageColors.winter.darkColor, width: 1),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(semester.name,
                    style: TextStyle(
                      color: ScholarPageColors.winter.darkColor,
                      fontSize: 12,
                      // italics
                    )))),
        Row(
          children: [
            Expanded(
                child: TitleCard(
                    animate: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        MultipleColumns(
                          contents: [
                            Text(semester.courses.length.toString(),
                                style: CupertinoTheme.of(context)
                                    .textTheme
                                    .navTitleTextStyle
                                    .copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                            Text(semester.courseCredit.toString(),
                                style: CupertinoTheme.of(context)
                                    .textTheme
                                    .navTitleTextStyle
                                    .copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                            Text(semester.examCount.toString(),
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
                                    builder: (context) =>
                                        CourseListPage(semester: semester), title: '课程')),
                            null,
                            () => Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(
                                builder: (context) =>
                                    ExamListPage(semester: semester), title: '考试'))
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
                                                    semester.name, true),
                                            title: '课表',
                                          ),
                                        ),
                                    title: '${semester.firstHalfName}学期课时',
                                    content:
                                        '${semester.firstHalfSessionCount}节/两周',
                                    backgroundColor: semester.name[9] == '春'
                                        ? ScholarPageColors.spring
                                        : ScholarPageColors.autumn,
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
                                                    semester.name, false),
                                            title: '课表',
                                          ),
                                        ),
                                    title: '${semester.secondHalfName}学期课时',
                                    content:
                                        '${semester.secondHalfSessionCount}节/两周',
                                    backgroundColor: semester.name[9] == '春'
                                        ? ScholarPageColors.summer
                                        : ScholarPageColors.winter,
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
                child: TitleCard(
              child: Column(children: [
                // Horizontal scrollable list to list all semesters
                SizedBox(
                  height: 81,
                  child: Obx(() => ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _scholarController.user.semesters.length - 1,
                      itemBuilder: (context, index) {
                        final semester = _scholarController.user.semesters[
                            _scholarController.user.semesters.length -
                                2 -
                                index];
                        return Stack(children: [
                          TwoLineCard(
                            title:
                                '${semester.name.substring(2, 5)}${semester.name.substring(7, 11)}',
                            content:
                                '${semester.gpa[0].toStringAsFixed(2)}/${semester.credits.toStringAsFixed(1)}',
                          ),
                          const SizedBox(width: 125),
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
        child: SafeArea(child: CustomScrollView(
          slivers: [
            if (_scholarController.user.isLogin)
                CupertinoSliverRefreshControl(
                  onRefresh: () async {
                    await _scholarController.fetchData();
                  },
                ),
            const CupertinoSliverNavigationBar(
              largeTitle: Text('学业'),
              border: null,
              stretch: true,
            ),
            Obx(() {if (_scholarController.user.semesters.isNotEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child:
                      Column(
                          children: [
                            _buildGradeBrief(context),
                            _buildSemester(context, _scholarController.thisSemester),
                            _buildHistory(context),
                          ],
                        ),
                      ),
                  );
            } else {
              return SliverToBoxAdapter(child: SizedBox(
                  height: 500,
    child: Column(children: [const Spacer(),Text(_scholarController.user.isLogin ? '下拉刷新' : '未登录', style: CupertinoTheme.of(context).textTheme.textStyle),const Spacer()])
    ));
            }})
          ],
        )));
  }
}

class ScholarPageColors {
  static const CupertinoDynamicColor spring =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 255, 226, 1.0),
    darkColor: Color.fromRGBO(147, 251, 56, 1.0),
  );

  static const CupertinoDynamicColor summer =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 226, 226, 1.0),
    darkColor: Color.fromRGBO(255, 25, 69, 1.0),
  );

  static const CupertinoDynamicColor autumn =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 234, 230, 1.0),
    darkColor: Color.fromRGBO(255, 101, 56, 1.0),
  );

  static const CupertinoDynamicColor winter =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(226, 239, 255, 1.0),
    darkColor: Color.fromRGBO(0, 183, 251, 1.0),
  );

  static const CupertinoDynamicColor violet =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 229, 255, 1.0),
    darkColor: Color.fromRGBO(151, 131, 216, 1.0),
  );

  static const CupertinoDynamicColor sakura =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 226, 255, 1.0),
    darkColor: Color.fromRGBO(218, 130, 217, 1.0),
  );

  static const CupertinoDynamicColor sand =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 246, 211, 1.0),
    darkColor: Color.fromRGBO(252, 222, 59, 1.0),
  );

  static const CupertinoDynamicColor cyan =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(218, 234, 255, 1.0),
    darkColor: Color.fromRGBO(0, 140, 255, 1.0),
  );

  static const CupertinoDynamicColor magenta =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 229, 255, 1.0),
    darkColor: Color.fromRGBO(238, 55, 161, 1.0),
  );

  static const CupertinoDynamicColor peach =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 235, 226, 1.0),
    darkColor: Color.fromRGBO(233, 114, 70, 1.0),
  );

  static const CupertinoDynamicColor okGreen =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 255, 226, 1.0),
    darkColor: Color.fromRGBO(63, 222, 23, 1.0),
  );
}
