import 'exam.dart';

class ExamDto {
  String id;
  String name;
  double credit;
  List<Exam> exams;

  // 第一个元素是开始时间，第二个元素是结束时间
  ExamDto(Map<String, dynamic> json) :
    id = json['xkkh'] as String,
    name = json['kcmc'] as String,
    credit = double.parse(json['xkxf'] as String),
    exams = Exam.parseExams(json);

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