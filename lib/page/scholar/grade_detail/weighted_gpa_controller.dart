import 'package:celechron/database/database_helper.dart';
import 'package:get/get.dart';
import 'package:celechron/model/grade.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/semester.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/utils/gpa_helper.dart';

/// 加权绩点控制器
/// 
/// 功能说明：
/// - 管理课程的加权比例数据（Map<String, double>，key为grade.id，value为加权比例，默认1.0）
/// - 提供加权比例的设置和获取接口
/// - 计算加权后的绩点（支持全部课程或按学期筛选）
/// - 支持按学期筛选和显示模式切换（全部学期/单个学期）
/// - 自动监听Scholar数据变化，更新学期列表
/// 
/// 核心属性：
/// - weightedMap: RxMap<String, double>，存储所有课程的加权比例，响应式更新
/// - semesterIndex: 当前选中的学期索引（仅在按学期模式下有效）
/// - showAllSemesters: 是否显示全部学期（true=全部，false=按学期）
/// - semestersWithGrades: 包含成绩的学期列表（自动过滤空学期）
/// 
/// 使用的函数和依赖：
/// - DatabaseHelper.getWeightedGpa(): 从数据库读取加权比例数据（初始化时调用）
/// - DatabaseHelper.setWeightedGpa(): 保存加权比例数据到数据库（每次设置时调用）
/// - GpaHelper.calculateWeightedGpa(): 计算加权后的绩点（绩点×加权比例，学分不变）
/// - Scholar.grades: 获取所有成绩数据
/// - Scholar.semesters: 获取学期数据
/// 
/// 数据存储：
/// - 加权比例存储在 Hive 数据库中（通过 DatabaseHelper）
/// - 使用 RxMap 实现响应式更新，修改后自动触发UI刷新
/// - 每次设置加权比例时自动保存到数据库
/// 
/// 响应式更新：
/// - weightedMap 使用 RxMap，修改后自动通知所有 Obx 监听者
/// - semesterIndex 和 showAllSemesters 使用 .obs，修改后触发相关UI更新
/// - 通过 ever(scholar, ...) 监听Scholar数据变化，自动刷新学期列表

class WeightedGpaController extends GetxController {
  final scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  final RxMap<String, double> weightedMap = RxMap<String, double>();
  final semesterIndex = 0.obs;
  final showAllSemesters = false.obs;
  late RxList<Semester> semestersWithGrades;

  @override
  void onInit() {
    super.onInit();
    weightedMap.value = _db.getWeightedGpa();
    semestersWithGrades = scholar.value.semesters
        .where((element) => element.grades.isNotEmpty)
        .toList()
        .obs;
    ever(scholar, (callback) => refreshSemesters());
  }

  void refreshSemesters() {
    semestersWithGrades.value = scholar.value.semesters
        .where((element) => element.grades.isNotEmpty)
        .toList();
    semestersWithGrades.refresh();
  }

  /// 获取指定课程的加权比例
  /// 
  /// 参数：
  /// - [gradeId] 课程ID
  /// 
  /// 返回值：
  /// - 如果已设置加权比例，返回该值；否则返回默认值1.0
  double getWeight(String gradeId) {
    return weightedMap[gradeId] ?? 1.0;
  }

  /// 设置指定课程的加权比例
  /// 
  /// 参数：
  /// - [gradeId] 课程ID
  /// - [weight] 加权比例（通常为0.8-1.2之间的值）
  /// 
  /// 说明：
  /// - 设置后会自动保存到数据库
  /// - 由于weightedMap是RxMap，修改后会自动触发UI更新
  void setWeight(String gradeId, double weight) {
    weightedMap[gradeId] = weight;
    refreshWeightedGpa();
  }

  /// 保存加权比例到数据库
  /// 
  /// 说明：
  /// - 将当前的weightedMap完整保存到数据库
  /// - 每次调用setWeight()时自动调用此方法
  void refreshWeightedGpa() {
    _db.setWeightedGpa(Map<String, double>.from(weightedMap));
  }

  /// 获取所有成绩
  /// 
  /// 返回值：
  /// - 所有学期的所有成绩列表（扁平化）
  List<Grade> getAllGrades() {
    return scholar.value.grades.values.expand((g) => g).toList();
  }

  /// 获取当前筛选范围的成绩列表
  /// 
  /// 返回值：
  /// - 如果showAllSemesters为true，返回所有成绩
  /// - 如果showAllSemesters为false，返回当前选中学期的成绩
  /// - 如果学期索引无效，返回空列表
  List<Grade> getCurrentSemesterGrades() {
    if (showAllSemesters.value) {
      return getAllGrades();
    }
    if (semestersWithGrades.isEmpty || 
        semesterIndex.value >= semestersWithGrades.length) {
      return [];
    }
    return semestersWithGrades[semesterIndex.value].grades;
  }

  /// 计算加权后的绩点（所有课程）
  /// 
  /// 返回值：
  /// - Tuple<List<double>, double>:
  ///   - item1: [五分制, 四分制(4.3分制), 原始四分制, 百分制]
  ///   - item2: 总学分
  Tuple<List<double>, double> calculateWeightedGpa() {
    final allGrades = getAllGrades();
    return GpaHelper.calculateWeightedGpa(allGrades, weightedMap);
  }

  /// 计算当前显示的加权绩点
  /// 
  /// 说明：
  /// - 根据showAllSemesters和semesterIndex决定计算范围
  /// - 如果showAllSemesters为true，计算所有课程
  /// - 如果showAllSemesters为false，计算当前学期的课程
  /// 
  /// 返回值：
  /// - Tuple<List<double>, double>:
  ///   - item1: [五分制, 四分制(4.3分制), 原始四分制, 百分制]
  ///   - item2: 总学分
  Tuple<List<double>, double> calculateCurrentSemesterWeightedGpa() {
    final grades = getCurrentSemesterGrades();
    return GpaHelper.calculateWeightedGpa(grades, weightedMap);
  }
}

