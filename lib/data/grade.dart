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
    "优": 90,
    "良": 80,
    "中": 70,
    "及格": 60,
    "不及格": 0,
    "合格": 75,
    "不合格": 0,
    "弃修": 0,
    "缺考": 0,
    "缓考": 0,
    "待录": 0,
  };

  Grade(RegExpMatch match)
      : id = match.group(1)!,
        name = match.group(2)!,
        credit = double.parse(match.group(4)!),
        original = match.group(3)!,
        fivePoint = double.parse(match.group(5)!) {
    hundredPoint = _toHundredPoint[original] ?? int.parse(original);
    fourPoint = fivePoint > 4.0 ? _toFourPoint[fivePoint]! : fivePoint;
    creditIncluded = original != "弃修" && original != "待录" && original != "缓考";
    gpaIncluded = creditIncluded && original != "合格" && original != "不合格";
  }

  /*Grade.fromDingtalkTranscript(Map<String, dynamic> transcript)
      : original = transcript['cj'] as String,
        fivePoint = double.parse(transcript['jd'].toString())
  {
    this.hundredPoint = _toHundredPoint[original] ?? int.parse(original);
    this.fourPoint =
        this.fivePoint > 4.0 ? _toFourPoint[this.fivePoint]! : this.fivePoint;
    this.affectGpa = this.original != "弃修" && this.original != "合格" && this.original != "不合格" && this.original != "待录" && this.original != "缓考";
  }*/

  @override
  toString() {
    return '$original/$fivePoint';
  }
}
