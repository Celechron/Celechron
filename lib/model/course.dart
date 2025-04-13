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

  bool? online = false; // only used for grs

  String get realId {
    if (id == null) return '未知';
    var matchClass = RegExp(r'(\(.*\)-.*?)-.*').firstMatch(id!);
    var key = matchClass?.group(1);
    key ??= id!.length < 22 ? id : id!.substring(0, 22);
    return key ?? '未知';
  }

  Course.fromExam(ExamDto examDto) {
    id = examDto.id;
    name = examDto.name;
    credit = examDto.credit;
    confirmed = true;
    exams.addAll(examDto.exams);
  }

  // used for grs
  Course.fromGrsSession(Session session) {
    id = session.id;
    name = session.name;
    confirmed = session.confirmed;
    teacher = session.teacher;
    sessions.add(session);
  }
  // used for zdbk
  Course.fromUgrsSessionWithoutID(Session session) {
    name = session.name;
    confirmed = session.confirmed;
    teacher = session.teacher;
    sessions.add(session);
  }

  Course.fromUgrsGrade(Grade this.grade)
      : id = grade.id,
        name = grade.name,
        confirmed = true,
        credit = grade.credit;

  // used for grs
  // grs的获取课表接口和获取成绩接口拿到的id不同，一切id以课表接口为准
  Course.fromGrsGrade(Grade this.grade)
      : id = grade.id,
        name = grade.name,
        confirmed = true,
        online = grade.isOnline,
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
    for (var e in sessions) {
      e.id = id;
    }
  }

  bool completeSession(Session session) {
    // 如果调用了这个函数，则表明该Course对象不是基于Session创建的。
    // 然而，通过成绩创建的Course可能没有id，因此我们这里判断下id是否为空，为空则使用sessioin中带的id
    id ??= session.id;
    session.id = id;
    teacher ??= session.teacher;
    if (sessions.any((e) =>
        e.dayOfWeek == session.dayOfWeek &&
        e.oddWeek == session.oddWeek &&
        e.evenWeek == session.evenWeek &&
        e.location == session.location &&
        e.time.contains(session.time.first))) {
      // 观察到修改过某短学期上课周数的长学期课程出现秋+冬两个session
      // 合并学期类型
      var currentSession = sessions.firstWhere((e) =>
          e.dayOfWeek == session.dayOfWeek &&
          e.oddWeek == session.oddWeek &&
          e.evenWeek == session.evenWeek &&
          e.location == session.location &&
          e.time.contains(session.time.first));
      currentSession.firstHalf = currentSession.firstHalf || session.firstHalf;
      currentSession.secondHalf = currentSession.secondHalf || session.secondHalf;
      return false;
    }
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
      //used for grs
      if (online == true && session.location == null) {
        session.location = "线上";
      }
      sessions.add(session);
      return true;
    }
  }

  void completeGrade(Grade grade) {
    credit = grade.credit;
    this.grade = grade;
    // used for grs online course
    if (grade.isOnline == true && sessions.every((e) => e.location == null)) {
      for (var e in sessions) {
        e.location = "线上";
      }
      online = true;
    }
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
        grade = json['grade'] == null
            ? null
            : Grade.fromJson(json['grade'] as Map<String, dynamic>),
        teacher = json['teacher'] as String?,
        sessions = (json['sessions'] as List<dynamic>)
            .map((e) => Session.fromJson(e as Map<String, dynamic>))
            .toList(),
        exams = (json['exams'] as List<dynamic>)
            .map((e) => Exam.fromJson(e as Map<String, dynamic>))
            .toList();
}
