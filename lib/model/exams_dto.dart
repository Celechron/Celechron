import 'exam.dart';

class ExamDto {
  String id;
  String name;
  double credit;
  late List<Exam> exams;

  // only used for ugrs
  String get semesterId => id.length > 12 ? id.substring(1, 12) : "研究生请勿使用此函数";

  ExamDto.empty()
      : id = "",
        name = "",
        credit = 0,
        exams = [];

  // 第一个元素是开始时间，第二个元素是结束时间
  ExamDto(Map<String, dynamic> json)
      : id = json['xkkh'] as String,
        name =
            (json['kcmc'] as String).replaceAll('(', '（').replaceAll(')', '）'),
        credit = double.parse(json['xkxf'] as String) {
    exams = Exam.parseExams(json, id, name);
  }

  ExamDto.fromZdbk(Map<String, dynamic> json)
      : id = json['xkkh'] as String,
        name =
            (json['kcmc'] as String).replaceAll('(', '（').replaceAll(')', '）'),
        credit = double.parse(json['xf'] as String) {
    exams = Exam.parseExamsFromZdbk(json, id, name);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'credit': credit,
        'exams': exams,
      };

  ExamDto.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        credit = json['credit'],
        exams = (json['exams'] as List).map((e) => Exam.fromJson(e)).toList();
}
