import 'package:celechron/utils/tuple.dart';
import 'package:celechron/model/grade.dart';

class GpaHelper {
  static Tuple<List<double>, double> calculateGpa(Iterable<Grade> grades) {
    // 总学分
    var earnedCredits = grades.fold<double>(0.0, (p, e) => p + e.earnedCredit);
    // 不计GPA的科目不算
    var affectGpaList = grades.where((e) => e.gpaIncluded);
    var affectGpaCredit =
        affectGpaList.fold<double>(0.0, (p, e) => p + e.credit);
    if (affectGpaCredit == 0.0) {
      return Tuple([0.0, 0.0, 0.0, 0.0], earnedCredits);
    }
    var sum = affectGpaList.fold<List<double>>(
        [0.0, 0.0, 0.0, 0.0],
        (p, e) => [
              p[0] + e.fivePoint * e.credit,
              p[1] + e.fourPoint * e.credit,
              p[2] + e.fourPointLegacy * e.credit,
              p[3] + e.hundredPoint * e.credit
            ]);
    return Tuple(sum.map((e) => e / affectGpaCredit).toList(), earnedCredits);
  }

  /// 计算加权绩点
  ///
  /// 功能说明：
  /// 根据课程的加权比例计算加权后的绩点。计算方式为：绩点直接乘以加权比例，学分保持不变。
  ///
  /// 参数：
  /// - [grades] 成绩列表（Iterable<Grade>）
  /// - [weightMap] 加权比例映射（Map<String, double>），key为grade.id，value为加权比例（默认1.0）
  ///
  /// 返回值：
  /// - Tuple<List<double>, double>:
  ///   - item1: [五分制, 四分制(4.3分制), 原始四分制, 百分制]
  ///   - item2: 总学分（保持不变，不乘以加权比例）
  ///
  /// 计算逻辑：
  /// 1. 筛选出计入GPA的课程（gpaIncluded == true）
  /// 2. 对每个课程：加权绩点 = 原绩点 × 加权比例
  /// 3. 按原学分进行加权平均：平均加权绩点 = Σ(加权绩点 × 原学分) / Σ(原学分)
  /// 4. 学分保持不变，不乘以加权比例
  ///
  /// 使用场景：
  /// - WeightedGpaController.calculateWeightedGpa() 调用此函数计算加权绩点
  /// - 用于加权绩点页面的实时计算和显示
  static Tuple<List<double>, double> calculateWeightedGpa(
      Iterable<Grade> grades, Map<String, double> weightMap) {
    // 总学分（保持不变）
    var earnedCredits = grades.fold<double>(0.0, (p, e) => p + e.earnedCredit);
    // 不计GPA的科目不算
    var affectGpaList = grades.where((e) => e.gpaIncluded);
    if (affectGpaList.isEmpty) {
      return Tuple([0.0, 0.0, 0.0, 0.0], earnedCredits);
    }

    // 总学分（用于计算平均绩点，保持不变）
    var totalCredit = affectGpaList.fold<double>(0.0, (p, e) => p + e.credit);
    if (totalCredit == 0.0) {
      return Tuple([0.0, 0.0, 0.0, 0.0], earnedCredits);
    }

    // 计算加权后的绩点：绩点直接乘以加权比例，然后按原学分加权平均
    var sum = affectGpaList.fold<List<double>>([0.0, 0.0, 0.0, 0.0], (p, e) {
      final weight = weightMap[e.id] ?? 1.0;
      // 绩点直接乘以加权比例
      // TODO: 是否有学院不是按照这种方式进行加权计算？
      final weightedFivePoint = e.fivePoint * weight;
      final weightedFourPoint = e.fourPoint * weight;
      final weightedFourPointLegacy = e.fourPointLegacy * weight;
      final weightedHundredPoint = e.hundredPoint * weight;
      // 按原学分加权平均
      return [
        p[0] + weightedFivePoint * e.credit,
        p[1] + weightedFourPoint * e.credit,
        p[2] + weightedFourPointLegacy * e.credit,
        p[3] + weightedHundredPoint * e.credit
      ];
    });

    return Tuple(sum.map((e) => e / totalCredit).toList(), earnedCredits);
  }
}
