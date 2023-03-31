class Grade {
  String id;
  String name;
  double credit;
  String original;
  double fivePoint;

  late double fourPoint;
  late int hundredPoint;

  // 计入GPA（弃修、待录、缓考、二级制的不计）
  late bool gpaIncluded;

  // 计入学分（弃修、待录、缓考的不计）
  late bool creditIncluded;

  // 获得的学分（挂科、不计学分的不计）
  double get effectiveCredit => (creditIncluded || fivePoint != 0) ? credit : 0.0;

  static final Map<double, double> _toFourPoint = {
    5.0: 4.3,
    4.8: 4.2,
    4.5: 4.1,
    4.2: 4.0,
  };

  static final Map<String, int> _toHundredPoint = {
    "A+": 95,
    "A": 90,
    "A-": 87,
    "B+": 83,
    "B": 80,
    "B-": 77,
    "C+": 73,
    "C": 70,
    "C-": 67,
    "D": 60,
    "F": 0,
    "优秀": 90,
    "良好": 80,
    "中等": 70,
    "及格": 60,
    "不及格": 0,
    "合格": 75,
    "不合格": 0,
    "弃修": 0,
    "缺考": 0,
    "缓考": 0,
    "待录": 0,
  };

  Grade(List<String> list)
      : id = list[0],
        name = list[1],
        credit = double.parse(list[3]),
        original = list[2],
        fivePoint = double.parse(list[4]) {
    hundredPoint = _toHundredPoint[original] ?? int.parse(original);
    fourPoint = fivePoint > 4.0 ? _toFourPoint[fivePoint]! : fivePoint;
    creditIncluded =
        original != "弃修" && original != "待录" && original != "缓考";
    gpaIncluded = creditIncluded && original != "合格" && original != "不合格";
  }

  static List<double> calculateGpa(Iterable<Grade> grades) {
    // 不计GPA的科目不算
    var affectGpaList = grades.where((e) => e.gpaIncluded);
    var credit = affectGpaList.fold<double>(0.0, (p, e) => p + e.credit);
    if (credit == 0.0) return [0.0, 0.0, 0.0];
    var sigma = affectGpaList.fold<List<double>>(
      [0.0, 0.0, 0.0], (p, e) => [p[0] + e.fivePoint * e.credit, p[1] + e.fourPoint * e.credit, p[2] + e.hundredPoint * e.credit]
    );
    return sigma.map((e) => e / credit).toList();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'credit': credit,
    'original': original,
    'fivePoint': fivePoint,
    'fourPoint': fourPoint,
    'hundredPoint': hundredPoint,
    'gpaIncluded': gpaIncluded,
    'creditIncluded': creditIncluded,
  };

  Grade.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        credit = json['credit'],
        original = json['original'],
        fivePoint = json['fivePoint'],
        fourPoint = json['fourPoint'],
        hundredPoint = json['hundredPoint'],
        gpaIncluded = json['gpaIncluded'],
        creditIncluded = json['creditIncluded'];
}
