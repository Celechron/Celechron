import 'package:celechron/utils/time_helper.dart';
import 'package:celechron/utils/json_utils.dart';

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
        time = TimeHelper.parseExamDateTime(asString(json['qzkssj']) ?? '');
        location = asString(json['qzjsmc']);
        seat = asString(json['qzzwxh']);
        break;
      case ExamType.finalExam:
        time = TimeHelper.parseExamDateTime(asString(json['kssj']) ?? '');
        location = asString(json['jsmc']);
        seat = asString(json['zwxh']);
        break;
    }
  }

  static List<Exam> parseExamsFromZdbk(
      Map<String, dynamic> json, String id, String name) {
    var exams = <Exam>[];
    if (asString(json["qzkssj"])?.isNotEmpty == true) {
      try {
        exams.add(Exam._fromZdbk(id, name, json, ExamType.midterm));
      } catch (_) {}
    }
    if (asString(json["kssj"])?.isNotEmpty == true) {
      try {
        exams.add(Exam._fromZdbk(id, name, json, ExamType.finalExam));
      } catch (_) {}
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
      : id = asString(json['id']) ?? '',
        name = asString(json['name']) ?? '未知课程',
        type = _examTypeFromJson(json['type']),
        time = (asDynamicList(json['time']) ?? const [])
            .map(asString)
            .whereType<String>()
            .map(DateTime.tryParse)
            .whereType<DateTime>()
            .toList(),
        location = asString(json['location']),
        seat = asString(json['seat']);

  get chineseTime => TimeHelper.chineseTime(time[0], time[1]);

  get chineseDate => TimeHelper.chineseDay(time[0]).replaceAll(" ", "");
}

ExamType _examTypeFromJson(Object? value) {
  final index = asInt(value);
  if (index == null || index < 0 || index >= ExamType.values.length) {
    return ExamType.finalExam;
  }
  return ExamType.values[index];
}

enum ExamType { midterm, finalExam }
