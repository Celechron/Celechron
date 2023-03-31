import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:celechron/widget/title_card.dart';
import 'package:celechron/widget/two_line_card.dart';
import '../../../widget/grade_card.dart';
import '../scholar_controller.dart';
import '../scholar_view.dart';

class GradeDetailPage extends StatelessWidget {
  final _scholarController = Get.find<ScholarController>();

  GradeDetailPage({super.key});

  Widget _buildGradeBrief(BuildContext context) {
    return Column(
      children: [
        // 成绩概览
        Row(
          children: [
            Expanded(
                child: TitleCard(
                    title: '成绩',
                    right: // a text box with rounded rectangle shape and green background
                        Obx(() => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: _scholarController.durationToLastUpdate > const Duration(minutes: 5)
                                        ? const Color.fromRGBO(255, 0, 0, 1.0)
                                        : ScholarPageColors.okGreen.darkColor,
                                    width: 1),
                                color: _scholarController.durationToLastUpdate >
                                        const Duration(minutes: 5)
                                    ? const Color.fromRGBO(255, 0, 0, 1.0)
                                    : const Color.fromRGBO(0, 0, 0, 0),
                                borderRadius: BorderRadius.circular(10)),
                            child: Text('更新于${_scholarController.durationToLastUpdate.inMinutes}分钟前',
                                style: TextStyle(
                                    color: _scholarController.durationToLastUpdate >
                                            const Duration(minutes: 5)
                                        ? const Color.fromRGBO(255, 255, 255, 1.0)
                                        : ScholarPageColors.okGreen.darkColor,
                                    fontSize: 12)))),
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
        child: CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () async {
            await _scholarController.fetchData();
          },
        ),
        SliverToBoxAdapter(
            child: Column(children: [
              const SizedBox(height: 40),
          Row(
            children: [
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    Hero(tag: 'gradeBrief', child: _buildGradeBrief(context)),
                    _buildHistory(context),
                  ],
                ),
              ),
              const SizedBox(width: 18),
            ],
          )
        ])),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return Column(children: [
              Row(
                children: [
                  const SizedBox(width: 18),
                  Expanded(
                      child: GradeCard(
                        grade: _scholarController.semesters[0].grades[index],
                      )),
                  const SizedBox(width: 18),
                ],
              ),
              const SizedBox(height: 8),
            ]);
          }, childCount: _scholarController.semesters[0].grades.length),
        ),
      ],
    ));
  }
}
