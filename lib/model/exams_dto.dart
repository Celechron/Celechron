import 'exam.dart';
import 'package:celechron/utils/json_utils.dart';

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
  /*ExamDto(Map<String, dynamic> json)
      : id = json['xkkh'] as String,
        name =
            (json['kcmc'] as String).replaceAll('(', '（').replaceAll(')', '）'),
        credit = double.parse(json['xkxf'] as String) {
    exams = Exam.parseExams(json, id, name);
  }*/

  factory ExamDto.fromZdbk(Map<String, dynamic> json) {
    final id = asString(json['xkkh']);
    if (id == null || id.isEmpty) {
      throw const FormatException('考试条目缺少选课课号 xkkh');
    }
    final dto = ExamDto.empty()
      ..id = id
      ..name = (asString(json['kcmc']) ?? '未知课程')
          .replaceAll('(', '（')
          .replaceAll(')', '）')
      ..credit = asDouble(json['xf']) ?? 0.0;
    dto.exams = Exam.parseExamsFromZdbk(json, dto.id, dto.name);
    return dto;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'credit': credit,
        'exams': exams,
      };

  ExamDto.fromJson(Map<String, dynamic> json)
      : id = asString(json['id']) ?? '',
        name = asString(json['name']) ?? '未知课程',
        credit = asDouble(json['credit']) ?? 0.0,
        exams = (asDynamicList(json['exams']) ?? const [])
            .map(asStringMap)
            .whereType<Map<String, dynamic>>()
            .map(Exam.fromJson)
            .toList();
}
