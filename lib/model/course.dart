import 'package:celechron/model/exams_dto.dart';

import 'exam.dart';
import 'grade.dart';
import 'session.dart';

class Course {
  String? id;
  late String name;
  late bool confirmed;
  double credit = 0.0;

  Grade? grade;
  String? teacher;

  List<Session> sessions = [];
  List<Exam> exams = [];

  Course.fromExam(ExamDto examDto) {
    id = examDto.id;
    name = examDto.name;
    credit = examDto.credit;
    confirmed = true;
    exams.addAll(examDto.exams);
  }

  Course.fromSession(Session session) {
    name = session.name;
    confirmed = session.confirmed;
    teacher = session.teacher;
    sessions.add(session);
  }

  Course.fromGrade(Grade this.grade)
      : id = grade.id,
        name = grade.name,
        confirmed = true,
        credit = grade.credit;

  /*Course.fromDingtalkTranscript(Map<String ,dynamic> transcript)
      : name = transcript['kcmc'] as String,
        credit = double.parse(transcript['xf'] as String),
        confirmed = true
  {
    grade = Grade.fromDingtalkTranscript(transcript);
    if (transcript.containsKey('xq')) {
      var semester = transcript['xq'] as String;
      firstHalf = semester.contains("秋") || semester.contains("春");
      secondHalf = semester.contains("冬") || semester.contains("夏");
    } else {
      firstHalf = false;
      secondHalf = false;
    }
  }*/

  void completeExam(ExamDto examDto) {
    credit = examDto.credit;
    exams.addAll(examDto.exams);
    // 如果调用了这个函数，则表明该Course对象可能是基于Session创建的。因此，id可能为null，必须补全。
    id ??= examDto.id;
    for (var e in sessions) { e.id = id; }
  }

  bool completeSession(Session session) {
    // 如果调用了这个函数，则表明该Course对象不是基于Session创建的。因此，其id不可能为null。
    session.id = id;
    teacher ??= session.teacher;
    if (sessions.any((e) =>
        e.dayOfWeek == session.dayOfWeek &&
        e.oddWeek == session.oddWeek &&
        e.evenWeek == session.evenWeek &&
        e.location == session.location &&
        e.time.contains(session.time.first))) return false;
    if (sessions.any((e) =>
        e.dayOfWeek == session.dayOfWeek &&
        e.oddWeek == session.oddWeek &&
        e.evenWeek == session.evenWeek &&
        e.location == session.location &&
        (e.time.last + 1 == session.time.first))) {
      var incompleteSession = sessions.firstWhere((e) =>
          e.dayOfWeek == session.dayOfWeek &&
          e.oddWeek == session.oddWeek &&
          e.evenWeek == session.evenWeek &&
          e.location == session.location &&
          (e.time.last + 1 == session.time.first));
      incompleteSession.time.addAll(session.time);
      return false;
    } else {
      sessions.add(session);
      return true;
    }
  }

  void completeGrade(Grade grade) {
    credit = grade.credit;
    this.grade = grade;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'confirmed': confirmed,
      'credit': credit,
      'grade': grade?.toJson(),
      'teacher': teacher,
      'sessions': sessions.map((e) => e.toJson()).toList(),
      'exams': exams.map((e) => e.toJson()).toList(),
    };
  }

  Course.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String?,
        name = json['name'] as String,
        confirmed = json['confirmed'] as bool,
        credit = json['credit'] as double,
        grade = json['grade'] == null ? null : Grade.fromJson(json['grade'] as Map<String, dynamic>),
        teacher = json['teacher'] as String?,
        sessions = (json['sessions'] as List<dynamic>).map((e) => Session.fromJson(e as Map<String, dynamic>)).toList(),
        exams = (json['exams'] as List<dynamic>).map((e) => Exam.fromJson(e as Map<String, dynamic>)).toList();
}
