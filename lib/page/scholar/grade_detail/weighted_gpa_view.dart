import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:celechron/design/custom_colors.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/design/two_line_card.dart';
import 'package:celechron/design/persistent_headers.dart';
import 'package:celechron/page/scholar/grade_detail/weighted_gpa_controller.dart';

/// 加权绩点页面
/// 
/// 功能说明：
/// - 显示加权后的绩点统计（加权学分、加权五分制）
/// - 提供课程列表，每个课程可以设置加权比例（0.8-1.2，步长0.2，共3个刻度）
/// - 支持按学期查看或查看全部学期的成绩
/// - 实时更新加权绩点计算结果
/// - 提供重置功能，可一键清除所有加权比例设置
/// 
/// 页面结构：
/// 1. 顶部标题栏：显示"加权成绩"，右侧有"重置"和"全选/按学期"切换按钮
/// 2. 绩点统计卡片：显示当前筛选范围内的加权绩点统计
/// 3. 学期选择器（按学期模式）：横向滚动的学期卡片列表，点击切换学期
/// 4. 课程列表：显示所有计入GPA的课程，每个课程可调整加权比例
/// 
/// 使用的函数和依赖：
/// - WeightedGpaController.calculateCurrentSemesterWeightedGpa(): 计算当前显示的加权绩点
/// - WeightedGpaController.getCurrentSemesterGrades(): 获取当前筛选范围的成绩列表
/// - WeightedGpaController.getWeight(): 获取指定课程的加权比例（默认1.0）
/// - WeightedGpaController.setWeight(): 设置指定课程的加权比例并保存到数据库
/// - WeightedGpaController.showAllSemesters: 控制是否显示全部学期（true）或按学期筛选（false）
/// - GpaHelper.calculateWeightedGpa(): 核心计算函数（绩点×加权比例，学分不变）
/// 
/// UI组件：
/// - CelechronSliverTextHeader: 页面标题栏，支持右侧自定义按钮
/// - TwoLineCard: 显示绩点统计卡片（加权学分、加权五分制）
/// - RoundRectangleCard: 课程信息卡片和学期选择器容器
/// - CupertinoSlider: 加权比例滑动条（0.8-1.2，步长0.2，共3个刻度：0.8, 1.0, 1.2）
/// 
/// 数据筛选：
/// - 只显示计入GPA的课程（gpaIncluded == true）
/// - 课程按名称排序显示
/// - 根据showAllSemesters决定显示全部课程还是当前学期的课程

class WeightedGpaPage extends StatelessWidget {
  final _controller = Get.put(WeightedGpaController());

  WeightedGpaPage({super.key});

  Widget _buildWeightedGpaBrief(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Hero(
                tag: 'weightedGpaBrief',
                child: RoundRectangleCard(
                  child: Obx(() {
                    final gpaResult = _controller.calculateCurrentSemesterWeightedGpa();
                    final gpa = gpaResult.item1;
                    final credits = gpaResult.item2;
                    
                    return Row(
                      children: [
                        Expanded(
                          child: TwoLineCard(
                            title: '加权学分',
                            content: credits.toStringAsFixed(1),
                            backgroundColor:
                                CustomCupertinoDynamicColors.sand,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TwoLineCard(
                            title: '加权五分制',
                            content: gpa[0].toStringAsFixed(2),
                            backgroundColor:
                                CustomCupertinoDynamicColors.sakura,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSemesterPicker(BuildContext context) {
    return RoundRectangleCard(
      animate: false,
      child: Column(
        children: [
          SizedBox(
            height: 81,
            child: Obx(
              () => ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _controller.semestersWithGrades.length,
                itemBuilder: (context, index) {
                  final semester = _controller.semestersWithGrades[index];
                  
                  return Obx(
                    () => Row(
                      children: [
                        TwoLineCard(
                          animate: true,
                          withColoredFont: true,
                          width: 120,
                          title: '${semester.name.substring(2, 5)}${semester.name.substring(7, 11)}',
                          content: '${semester.gpa[0].toStringAsFixed(2)}/${semester.credits.toStringAsFixed(1)}',
                          onTap: () {
                            _controller.semesterIndex.value = index;
                            _controller.semesterIndex.refresh();
                          },
                          backgroundColor: _controller.semesterIndex.value == index
                              ? CustomCupertinoDynamicColors.cyan
                              : CupertinoColors.systemFill,
                        ),
                        if (index != _controller.semestersWithGrades.length - 1)
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final semesterGrades = _controller.getCurrentSemesterGrades();
      // 只显示计入GPA的课程
      final affectGpaGrades = semesterGrades.where((g) => g.gpaIncluded).toList();
      // 按课程名排序
      affectGpaGrades.sort((a, b) => a.name.compareTo(b.name));

    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(
          CupertinoColors.systemGroupedBackground, context),
      child: CustomScrollView(
        slivers: [
          CelechronSliverTextHeader(
            subtitle: '加权成绩',
            right: Obx(
              () => Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text(
                        '重置',
                        style: TextStyle(fontSize: 16),
                      ),
                      onPressed: () {
                        _controller.weightedMap.value = {};
                        _controller.refreshWeightedGpa();
                      },
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Text(
                        _controller.showAllSemesters.value ? '按学期' : '全选',
                        style: const TextStyle(fontSize: 16),
                      ),
                      onPressed: () {
                        _controller.showAllSemesters.value =
                            !_controller.showAllSemesters.value;
                      },
                    ),
                  ],
                ),
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
                      child: _buildWeightedGpaBrief(context),
                    ),
                    const SizedBox(width: 18),
                  ],
                ),
                Obx(
                  () => _controller.showAllSemesters.value
                      ? const SizedBox.shrink()
                      : Row(
                          children: [
                            const SizedBox(width: 18),
                            Expanded(
                              child: _buildSemesterPicker(context),
                            ),
                            const SizedBox(width: 18),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final grade = affectGpaGrades[index];
                return Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 18),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.only(
                                left: 12, right: 12, bottom: 16, top: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: CupertinoDynamicColor.resolve(
                                  CupertinoColors.systemBackground, context),
                              boxShadow: [
                                BoxShadow(
                                  color: CupertinoColors.black
                                      .withValues(alpha: 0.1),
                                  spreadRadius: 0,
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            grade.name,
                                            style: CupertinoTheme.of(context)
                                                .textTheme
                                                .textStyle
                                                .copyWith(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.normal,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                          ),
                                          Text(
                                            '${grade.realId} / ${grade.credit.toStringAsFixed(1)} 学分',
                                            style: CupertinoTheme.of(context)
                                                .textTheme
                                                .textStyle
                                                .copyWith(
                                                  color: CupertinoTheme.of(
                                                          context)
                                                      .textTheme
                                                      .textStyle
                                                      .color!
                                                      .withValues(alpha: 0.5),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.normal,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${grade.original} / ${grade.fivePoint.toStringAsFixed(1)}',
                                      style: CupertinoTheme.of(context)
                                          .textTheme
                                          .textStyle
                                          .copyWith(
                                            fontSize: 20,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Obx(() {
                                  const double minValue = 0.8;
                                  const double maxValue = 1.2;
                                  const double devideStep = 0.2;
                                  // TODO: 是否有特殊情况需要处理
                                  final int divisions = ((maxValue - minValue) / devideStep).round();

                                  final currentWeight = _controller.getWeight(grade.id);
                                  
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 56,
                                        child: Text(
                                          '加权比例',
                                          style: CupertinoTheme.of(context)
                                              .textTheme
                                              .textStyle
                                              .copyWith(
                                                fontSize: 12,
                                                color: CupertinoTheme.of(context)
                                                    .textTheme
                                                    .textStyle
                                                    .color!
                                                    .withValues(alpha: 0.5),
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: SizedBox(
                                          height: 8,
                                          child: CupertinoSlider(
                                            value: currentWeight,
                                            min: minValue,
                                            max: maxValue,
                                            divisions: divisions,
                                            activeColor: CupertinoDynamicColor.resolve(
                                                CupertinoColors.systemTeal, context),
                                            onChanged: (value) {
                                              _controller.setWeight(grade.id, value);
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        width: 24,
                                        child: Text(
                                          currentWeight.toStringAsFixed(1),
                                          textAlign: TextAlign.right,
                                          style: CupertinoTheme.of(context)
                                              .textTheme
                                              .textStyle
                                              .copyWith(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: CupertinoTheme.of(context)
                                                    .textTheme
                                                    .textStyle
                                                    .color!
                                                    .withValues(alpha: 0.7),
                                              ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
              childCount: affectGpaGrades.length,
            ),
          ),
        ],
      ),
    );
    });
  }
}

