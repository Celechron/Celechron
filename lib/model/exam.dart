import 'package:celechron/utils/time_helper.dart';

class Exam {
  String id;
  String name;
  ExamType type;

  // 第一个元素是开始时间，第二个元素是结束时间
  late List<DateTime> time;
  String? location;
  String? seat;

  Exam.empty()
      : id = "",
        name = "",
        type = ExamType.finalExam,
        time = [];

  /*Exam._fromAppService(
      this.id, this.name, Map<String, dynamic> json, this.type) {
    switch (type) {
      case ExamType.midterm:
        time = TimeHelper.parseExamDateTime(json['qzkssj']);
        location = json['qzksdd'];
        seat = json['qzzwxh'];
        break;
      case ExamType.finalExam:
        time = TimeHelper.parseExamDateTime(json['qmkssj']);
        location = json['qmksdd'];
        seat = json['zwxh'];
        break;
    }
  }*/

  /*static List<Exam> parseExams(
      Map<String, dynamic> json, String id, String name) {
    var exams = <Exam>[];
    if (json.containsKey("qzkssj")) {
      exams.add(Exam._fromAppService(id, name, json, ExamType.midterm));
    }
    if (json.containsKey("qmkssj")) {
      exams.add(Exam._fromAppService(id, name, json, ExamType.finalExam));
    }
    return exams;
  }*/

  Exam._fromZdbk(this.id, this.name, Map<String, dynamic> json, this.type) {
    switch (type) {
      case ExamType.midterm:
        time = TimeHelper.parseExamDateTime(json['qzkssj']);
        location = json['qzjsmc'];
        seat = json['qzzwxh'];
        break;
      case ExamType.finalExam:
        time = TimeHelper.parseExamDateTime(json['kssj']);
        location = json['jsmc'];
        seat = json['zwxh'];
        break;
    }
  }

  static List<Exam> parseExamsFromZdbk(
      Map<String, dynamic> json, String id, String name) {
    var exams = <Exam>[];
    if (json.containsKey("qzkssj")) {
      exams.add(Exam._fromZdbk(id, name, json, ExamType.midterm));
    }
    if (json.containsKey("kssj")) {
      exams.add(Exam._fromZdbk(id, name, json, ExamType.finalExam));
    }
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

  get chineseDate => '${time[0].month}月${time[0].day}日';
}

enum ExamType { midterm, finalExam }
