import 'exam.dart';
import 'grade.dart';
import 'session.dart';

class Course {
  late String id;
  late String name;
  late bool confirmed;
  late double credit;

  Grade? grade;
  String? teacher;

  List<Session> sessions = [];
  List<Exam> exams = [];

  Course.fromExam(this.id, this.name, this.credit, List<Exam> examList) {
    confirmed = true;
    exams.addAll(examList);
  }

  Course.fromSession(Session session) {
    id = session.id;
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

  static bool completeExam(Course course, List<Exam> exam, double credit) {
    course.credit = credit;
    course.exams.addAll(exam);
    return true;
  }

  static bool completeSession(Course course, Session session) {
    course.teacher = session.teacher;
    if (course.sessions.any((e) =>
        e.day == session.day &&
        e.oddWeek == session.oddWeek &&
        e.evenWeek == session.evenWeek &&
        e.location == session.location &&
        (e.time.last + 1 == session.time.first))) {
      var incompleteSession = course.sessions.firstWhere((e) =>
          e.day == session.day &&
          e.oddWeek == session.oddWeek &&
          e.evenWeek == session.evenWeek &&
          e.location == session.location &&
          (e.time.last + 1 == session.time.first));
      incompleteSession.time.addAll(session.time);
      return true;
    } else {
      course.sessions.add(session);
      return false;
    }
  }

  static bool completeGrade(Course course, Grade grade) {
    course.credit = grade.credit;
    course.grade = grade;
    return true;
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
      : id = json['id'] as String,
        name = json['name'] as String,
        confirmed = json['confirmed'] as bool,
        credit = json['credit'] as double,
        grade = json['grade'] == null ? null : Grade.fromJson(json['grade'] as Map<String, dynamic>),
        teacher = json['teacher'] as String?,
        sessions = (json['sessions'] as List<dynamic>).map((e) => Session.fromJson(e as Map<String, dynamic>)).toList(),
        exams = (json['exams'] as List<dynamic>).map((e) => Exam.fromJson(e as Map<String, dynamic>)).toList();
}
