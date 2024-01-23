import 'package:celechron/http/zjuServices/tuple.dart';
import 'package:celechron/model/grade.dart';

class GpaHelper {
  static Tuple<List<double>, double> calculateGpa(Iterable<Grade> grades) {
    // 总学分
    var earnedCredits = grades.fold<double>(0.0, (p, e) => p + e.earnedCredit);
    // 不计GPA的科目不算
    var affectGpaList = grades.where((e) => e.gpaIncluded);
    var affectGpaCredit =
        affectGpaList.fold<double>(0.0, (p, e) => p + e.credit);
    if (affectGpaCredit == 0.0) return Tuple([0.0, 0.0, 0.0, 0.0], 0.0);
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
}
