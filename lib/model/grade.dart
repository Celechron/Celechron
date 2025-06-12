class Grade {
  String id; // 课程号
  String name; // 课程名
  double credit; // 学分
  String original; // 原始成绩
  double fivePoint; // 五分制成绩
  late double fourPoint; // 四分制成绩（4.3 满分）
  late double fourPointLegacy; // 原始的四分制成绩
  late int hundredPoint; // 百分制成绩
  bool major = false; // 计入主修
  bool? isOnline = false; // grs成绩使用这个字段标志是不是线上上课(hack)
  // 计入GPA（弃修、待录、缓考、二级制的不计）
  late bool gpaIncluded;
  // 计入学分（弃修、待录、缓考的不计）
  late bool creditIncluded;

  // 获得的学分（挂科、不计学分的不计）
  double get earnedCredit => (creditIncluded && fivePoint != 0) ? credit : 0.0;

  // only used for ugrs
  String get semesterId => id.length > 12 ? id.substring(1, 12) : "研究生请勿使用此函数";

  String get realId {
    var matchClass = RegExp(r'(\(.*\)-.*?)-.*').firstMatch(id);
    var key = matchClass?.group(1);
    key ??= id.length < 22 ? id : id.substring(0, 22);
    return key;
  }

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
    "无效": 0,
  };

  Grade.empty()
      : id = "",
        name = "",
        credit = 0.0,
        original = "",
        fivePoint = 0.0;

  // 从所有成绩查询处爬取，因此不含主修标记
  Grade(Map<String, dynamic> json)
      : id = json['xkkh'] as String,
        name =
            (json['kcmc'] as String).replaceAll('(', '（').replaceAll(')', '）'),
        credit = double.parse(json['xf'] as String),
        original = json['cj'] as String,
        fivePoint = double.parse(json['jd'] as String) {
    // 匹配第一组连续的数字，如果没有则返回-100000
    hundredPoint = _toHundredPoint[original] ?? int.tryParse(RegExp(r'\d+').firstMatch(original)!.group(0) ?? "-100000")!;
    fourPoint = fivePoint > 4.0 ? _toFourPoint[fivePoint]! : fivePoint;
    fourPointLegacy = fivePoint > 4.0 ? 4.0 : fivePoint;
    creditIncluded = original != "弃修" && original != "待录" && original != "缓考" && original != "无效";
    gpaIncluded = creditIncluded &&
        original != "合格" &&
        original != "不合格" &&
        !id.contains('xtwkc');
  }

  // 从主修成绩查询处爬取，因此打上主修标记
  Grade.fromMajor(Map<String, dynamic> json)
      : id = json['xkkh'] as String,
        name =
            (json['kcmc'] as String).replaceAll('(', '（').replaceAll(')', '）'),
        credit = double.parse(json['xf'] as String),
        original = json['cj'] as String,
        fivePoint = double.parse(json['jd'] as String) {
    hundredPoint = _toHundredPoint[original] ?? int.parse(original);
    fourPoint = fivePoint > 4.0 ? _toFourPoint[fivePoint]! : fivePoint;
    fourPointLegacy = fivePoint > 4.0 ? 4.0 : fivePoint;
    creditIncluded = original != "弃修" && original != "待录" && original != "缓考" && original != "无效";
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
        'fourPointLegacy': fourPointLegacy,
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
        fourPointLegacy = json['fourPointLegacy'] ?? 0.0,
        hundredPoint = json['hundredPoint'],
        gpaIncluded = json['gpaIncluded'],
        creditIncluded = json['creditIncluded'];
}
