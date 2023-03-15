import '../../data/course.dart';
import 'exam.dart';
import '../../data/grade.dart';
import 'session.dart';

class Semester {
  // 学期名称
  String name;
  final Map<String, Course> _courses = {};
  final List<Exam> _exams = [];
  final List<Session> _sessions = [];
  final List<Grade> _grades = [];

  double fivePointGpa = 0.0;
  double fourPointGpa = 0.0;
  double hundredPointGpa = 0.0;
  double credits = 0.0;

  Semester(this.name);

  // 科目列表
  get courses {
    return _courses;
  }

  // 考试列表
  List<Exam> get exams {
    return _exams;
  }

  // 成绩列表
  List<Grade> get grades {
    return _grades;
  }

  // 所有课程（几乎没用，绘制课程表是要分学期的，看下面的）
  List<Session> get sessions {
    return _sessions;
  }

  // 上半学期课表
  get firstHalfSessions {
    return _sessions.where((e) => e.firstHalf);
  }

  // 下半学期课表
  get secondHalfSessions {
    return _sessions.where((e) => e.secondHalf);
  }

  void addSession(Map<String, dynamic> json) {
    if (json['kcid'] != null) {
      var session = Session(json);
      var courseKey = session.id;
      if (_courses.containsKey(courseKey)) {
        if (!Course.completeSession(_courses[courseKey]!, session)) {
          _sessions.add(session);
        }
      } else {
        _sessions.add(session);
        _courses.addEntries([MapEntry(courseKey, Course.fromSession(session))]);
      }
    }
  }

  void addExam(Map<String, dynamic> json) {
    // 有的课没有考试但是能查到考试项
    var id = (json['xkkh'] as String);
    var name = json['kcmc'] as String;
    var credit = double.parse(json['xkxf'] as String);

    var examList = Exam.parseExams(id, name, json);
    _exams.addAll(examList);
    if (_courses.containsKey(id)) {
      Course.completeExam(_courses[id]!, examList, credit);
    } else {
      _courses.addEntries(
          [MapEntry(id, Course.fromExam(id, name, credit, examList))]);
    }
  }

  void addGrade(RegExpMatch match) {
    var grade = Grade(match);
    _grades.add(grade);
    var courseKey = grade.id;
    if (_courses.containsKey(courseKey)) {
      Course.completeGrade(_courses[courseKey]!, grade);
    } else {
      _courses.addEntries([MapEntry(courseKey, Course.fromGrade(grade))]);
    }
  }

  void calculateGPA() {
    var affectGpaList = _grades.where((e) => e.gpaIncluded);
    if (affectGpaList.isNotEmpty) {
      // 这个算的是计入GPA的总学分，包括挂科的
      var credits = affectGpaList.fold<double>(0.0, (p, e) => p + e.credit);
      fivePointGpa = affectGpaList.fold<double>(
          0.0, (p, e) => p + e.credit * e.fivePoint) / credits;
      fourPointGpa = affectGpaList.fold<double>(
          0.0, (p, e) => p + e.credit * e.fourPoint) / credits;
      hundredPointGpa = affectGpaList.fold<double>(
          0.0, (p, e) => p + e.credit * e.hundredPoint) / credits;
      // 这个算的是所获学分，不包括挂科的
      this.credits = _grades.fold<double>(
          0.0, (p, e) => p + e.effectiveCredit);
    }
  }

  void sortExams() {
    // 考试按开始时间排序
    _exams.sort((a, b) => a.time.first.compareTo(b.time.first));
  }
}
