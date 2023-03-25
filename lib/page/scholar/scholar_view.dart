import 'package:celechron/widget/two_line_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'scholar_controller.dart';

class ScholarPage extends StatelessWidget {
  ScholarPage({super.key});

  final _scholarController = Get.put(ScholarController());
  final _refreshController = RefreshController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('学业数据'),
        ),
        body: SmartRefresher(
          onRefresh: () async {
            await _scholarController.user.value.refresh();
            _scholarController.user.refresh();
            _refreshController.refreshCompleted();
          },
          controller: _refreshController,
          header: WaterDropHeader(),
          child: ListView(
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Obx(() => TwoLineCard(
                        title: '五分制',
                        content: _scholarController.user.value.gpa[0]
                            .toStringAsFixed(2),
                        backgroundColor:
                            CupertinoColors.activeBlue.withOpacity(0.1))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Obx(() => TwoLineCard(
                        title: '四分制',
                        content: _scholarController.user.value.gpa[1]
                            .toStringAsFixed(2),
                        backgroundColor:
                            CupertinoColors.activeOrange.withOpacity(0.1))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Obx(() => TwoLineCard(
                        title: '百分制',
                        content: _scholarController.user.value.gpa[2]
                            .toStringAsFixed(2),
                        backgroundColor:
                            CupertinoColors.activeGreen.withOpacity(0.1))),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Obx(() => TwoLineCard(
                        title: '主修均绩',
                        content: _scholarController.user.value.majorGpaAndCredit[0]
                            .toStringAsFixed(2),
                        backgroundColor:
                        CupertinoColors.systemRed.withOpacity(0.1))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Obx(() => TwoLineCard(
                        title: '获得学分',
                        content: _scholarController.user.value.credit
                            .toStringAsFixed(1),
                        backgroundColor:
                        CupertinoColors.systemIndigo.withOpacity(0.1))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Obx(() => TwoLineCard(
                        title: '主修学分',
                        content: _scholarController.user.value.majorGpaAndCredit[1]
                            .toStringAsFixed(1),
                        backgroundColor:
                        CupertinoColors.systemPink.withOpacity(0.1))),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ],
          ),
        ));
  }
}
