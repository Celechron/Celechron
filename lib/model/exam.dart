import 'package:celechron/utils/timehelper.dart';

class Exam {
  String id;
  String name;
  ExamType type;

  // 第一个元素是开始时间，第二个元素是结束时间
  late List<DateTime> time;
  String? location;
  String? seat;

  Exam._fromExam(this.id, this.name, Map<String, dynamic> examList, this.type) {
    switch (type) {
      case ExamType.midterm:
        time = TimeHelper.parseExamDateTime(examList['qzkssj']);
        location = examList['qzksdd'];
        seat = examList['qzzwxh'];
        break;
      case ExamType.finalExam:
        time = TimeHelper.parseExamDateTime(examList['qmkssj']);
        location = examList['qmksdd'];
        seat = examList['zwxh'];
        break;
    }
  }

  static List<Exam> parseExams(
      Map<String, dynamic> json, String id, String name) {
    var exams = <Exam>[];
    if (json.containsKey("qzkssj"))
      exams.add(Exam._fromExam(id, name, json, ExamType.midterm));
    if (json.containsKey("qmkssj"))
      exams.add(Exam._fromExam(id, name, json, ExamType.finalExam));
    return exams;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'time': time.map((e) => e.toIso8601String()).toList(),
        'location': location,
        'seat': seat,
      };

  Exam.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        type = ExamType.values[json['type']],
        time = (json['time'] as List).map((e) => DateTime.parse(e)).toList(),
        location = json['location'],
        seat = json['seat'];

  get chineseTime => TimeHelper.chineseTime(time[0], time[1]);

  get chineseDate => TimeHelper.chineseDay(time[0]);
}

enum ExamType { midterm, finalExam }
