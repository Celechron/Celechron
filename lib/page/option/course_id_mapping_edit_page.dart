import 'package:flutter/cupertino.dart';

import 'package:get/get.dart';

import 'package:celechron/design/persistent_headers.dart';
import 'package:celechron/model/option.dart';
import 'option_controller.dart';

class CourseIdMappingEditForm extends StatelessWidget {
  final oldIdController = TextEditingController();
  final newIdController = TextEditingController();
  final commentController = TextEditingController();
  final String title;
  final courseIdMappingList =
      Get.find<OptionController>(tag: 'optionController').courseIdMappingList;
  final scholar = Get.find<OptionController>(tag: 'optionController').scholar;

  CourseIdMappingEditForm({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    var brightness = CupertinoTheme.of(context).brightness ??
        MediaQuery.of(context).platformBrightness;

    return Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemGroupedBackground, context)),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 6,
          right: 6,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8, top: 16),
                child: Text(
                  title,
                  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    SizedBox(
                        height: 48,
                        child: CupertinoTextField(
                          controller: oldIdController,
                          prefix: Container(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text('原课号',
                                  style: CupertinoTheme.of(context)
                                      .textTheme
                                      .textStyle)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: brightness == Brightness.light
                                ? CupertinoColors.systemBackground
                                : CupertinoColors.secondarySystemBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        )),
                    const SizedBox(height: 16),
                    SizedBox(
                        height: 48,
                        child: CupertinoTextField(
                          controller: newIdController,
                          prefix: Container(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text('新课号',
                                style: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: brightness == Brightness.light
                                ? CupertinoColors.systemBackground
                                : CupertinoColors.secondarySystemBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        )),
                    const SizedBox(height: 16),
                    SizedBox(
                        height: 48,
                        child: CupertinoTextField(
                          controller: commentController,
                          prefix: Container(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text('备注名',
                                style: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: brightness == Brightness.light
                                ? CupertinoColors.systemBackground
                                : CupertinoColors.secondarySystemBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        )),
                    const SizedBox(height: 16),
                    CupertinoButton(
                        onPressed: () async {
                          if (oldIdController.text.isEmpty ||
                              newIdController.text.isEmpty ||
                              commentController.text.isEmpty) {
                            showCupertinoDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return CupertinoAlertDialog(
                                    title: const Text('错误'),
                                    content: const Text('请填写所有字段'),
                                    actions: [
                                      CupertinoDialogAction(
                                        child: const Text('确定'),
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                      ),
                                    ],
                                  );
                                });
                            return;
                          } else {
                            courseIdMappingList.removeWhere(
                                (element) =>
                                    element.id1 == oldIdController.text ||
                                    element.id2 == oldIdController.text ||
                                    element.id1 == newIdController.text ||
                                    element.id2 == newIdController.text);
                            courseIdMappingList.add(CourseIdMap(
                                id1: oldIdController.text,
                                id2: newIdController.text,
                                comment: commentController.text));
                            Navigator.pop(context);
                            await scholar.value.recalculateGpa();
                            scholar.refresh();
                          }
                        },
                        color: CupertinoColors.activeBlue,
                        child: const SizedBox(
                          height: 24,
                          width: 60,
                          child: Center(child: Text('保存',
                              style: TextStyle(color: CupertinoColors.white))),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}

class CourseIdMappingEditPage extends StatelessWidget {
  final courseIdMappingList =
      Get.find<OptionController>(tag: 'optionController').courseIdMappingList;
  final scholar = Get.find<OptionController>(tag: 'optionController').scholar;

  CourseIdMappingEditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const CelechronSliverTextHeader(subtitle: '自定义课程代码映射'),
            Obx(() => SliverList(
              delegate: SliverChildBuilderDelegate(
                  (context, index) => Container(
                        padding: index == 0
                            ? const EdgeInsets.only(
                                top: 0, bottom: 5, left: 16, right: 16)
                            : const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 5),
                        child: CupertinoFormRow(
                          prefix: Text('${courseIdMappingList[index].comment}： ${courseIdMappingList[index].id1} <-> ${courseIdMappingList[index].id2}',
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () async {
                                  courseIdMappingList.removeAt(index);
                                  await scholar.value.recalculateGpa();
                                  scholar.refresh();
                                },
                                child: const Icon(
                                  CupertinoIcons.delete,
                                  color: CupertinoColors.destructiveRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  childCount: courseIdMappingList.length),
            )),
            SliverToBoxAdapter(
                child: Column(
              children: [
                const SizedBox(height: 8),
                CupertinoButton(
                  onPressed: () async {
                    showCupertinoModalPopup(
                        context: context,
                        builder: (BuildContext context) {
                          return CourseIdMappingEditForm(title: '添加新的映射关系');
                        });
                  },
                  child: const Text('添加新的映射关系'),
                ),
              ],
            ))
          ],
        ),
      ),
    );
  }
}
