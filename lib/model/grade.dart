class Grade {
  String id;              // 课程号
  String name;            // 课程名
  double credit;          // 学分
  String original;        // 原始成绩
  double fivePoint;       // 五分制成绩
  late double fourPoint;  // 四分制成绩
  late int hundredPoint;  // 百分制成绩
  bool major=false;       // 计入主修

  // 计入GPA（弃修、待录、缓考、二级制的不计）
  late bool gpaIncluded;
  // 计入学分（弃修、待录、缓考的不计）
  late bool creditIncluded;

  // 获得的学分（挂科、不计学分的不计）
  double get earnedCredit => (creditIncluded || fivePoint != 0) ? credit : 0.0;

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

  // 从所有成绩查询处爬取，不含主修标记
  Grade(Map<String, dynamic> json)
      : id = json['xkkh'] as String,
        name = json['kcmc'] as String,
        credit = double.parse(json['xf'] as String),
        original = json['cj'] as String,
        fivePoint = double.parse(json['jd'] as String) {
    hundredPoint = _toHundredPoint[original] ?? int.parse(original);
    fourPoint = fivePoint > 4.0 ? _toFourPoint[fivePoint]! : fivePoint;
    creditIncluded =
        original != "弃修" && original != "待录" && original != "缓考";
    gpaIncluded = creditIncluded && original != "合格" && original != "不合格";
  }

  // 从主修成绩查询处爬取，含主修标记
  Grade.fromMajor(Map<String, dynamic> json)
      : id = json['xkkh'] as String,
        name = json['kcmc'] as String,
        credit = double.parse(json['xf'] as String),
        original = json['cj'] as String,
        fivePoint = double.parse(json['jd'] as String) {
    hundredPoint = _toHundredPoint[original] ?? int.parse(original);
    fourPoint = fivePoint > 4.0 ? _toFourPoint[fivePoint]! : fivePoint;
    creditIncluded =
        original != "弃修" && original != "待录" && original != "缓考";
    gpaIncluded = creditIncluded && original != "合格" && original != "不合格";
    major = true;
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
