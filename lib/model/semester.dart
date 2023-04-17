import 'package:celechron/model/exams_dto.dart';
import 'package:celechron/model/period.dart';
import '../utils/utils.dart';
import 'course.dart';
import 'exam.dart';
import 'grade.dart';
import 'session.dart';

class Semester {
  // 学期名称
  final String name;
  final Map<String, Course> _courses;
  final List<Exam> _exams;
  final List<Session> _sessions;
  final List<Grade> _grades;

  // 第几节课 => 时间
  // 例如，对于第六节课，_sessionToTime[6].first = 13:25, _sessionToTime[6].last = 14:10
  // 注意，此处不想让index从0开始，因为不喜欢
  List<List<Duration>> _sessionToTime = [
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    []
  ];

  // 星期几 => 日期，_dayOfWeekToDays.first为上半学期，_dayOfWeekToDays.last为下半学期
  // _dayOfWeekToDays.first.first为单周，_dayOfWeekToDays.first.last为双周
  // _dayOfWeekToDays.first.first[1]为单周周一的所有日期
  // 注意，此处不想让index从0开始，因为不喜欢
  List<List<List<List<DateTime>>>> _dayOfWeekToDays = [
    [
      /*上半学期*/
      /*单周日期*/ [[], [], [], [], [], [], [], []],
      /*双周日期*/ [[], [], [], [], [], [], [], []]
    ],
    [
      /*下半学期*/
      /*单周日期*/ [[], [], [], [], [], [], [], []],
      /*双周日期*/ [[], [], [], [], [], [], [], []]
    ]
  ];
  Map<DateTime, String> _holidays = {};
  Map<DateTime, DateTime> _exchanges = {};

  // GPA, 三个数据依次为五分制，四分制，百分制
  List<double> gpa = [0.0, 0.0, 0.0];
  double credits = 0.0;

  Semester(this.name)
      : _courses = {},
        _exams = [],
        _sessions = [],
        _grades = [];

  String get firstHalfName {
    return name.substring(9, 10);
  }

  String get secondHalfName {
    return name.substring(10, 11);
  }

  // 科目列表
  Map<String, Course> get courses {
    return _courses;
  }

  int get courseCount {
    return _courses.length;
  }

  int get examCount {
    return _exams.length;
  }

  double get courseCredit {
    return _courses.values.fold(0.0, (p, e) => p + e.credit);
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
  List<List<Session>> get firstHalfTimetable {
    return _sessions.where((e) => e.firstHalf && e.confirmed).fold(<List<Session>>[[], [], [], [], [], [], [], []], (p, e) {
      p[e.day].add(e);
      return p;
    });
  }

  // 下半学期课表
  List<List<Session>> get secondHalfTimetable {
    return _sessions.where((e) => e.secondHalf && e.confirmed).fold(<List<Session>>[[], [], [], [], [], [], [], []], (p, e) {
      p[e.day].add(e);
      return p;
    });
  }

  double get firstHalfSessionCount {
    return _sessions.where((e) => e.firstHalf && e.confirmed).fold(
        0.0,
        (p, e) =>
            p +
            (e.time.length) * ((e.oddWeek ? 1 : 0) + (e.evenWeek ? 1 : 0)));
  }

  double get secondHalfSessionCount {
    return _sessions.where((e) => e.secondHalf && e.confirmed).fold(
        0.0,
            (p, e) =>
        p +
            (e.time.length) * ((e.oddWeek ? 1 : 0) + (e.evenWeek ? 1 : 0)));
  }

  List<Period> get periods {
    List<Period> periods = [];
    for (var session in _sessions) {
      if (session.firstHalf) {
        if (session.evenWeek) {
          for (var day in _dayOfWeekToDays[0][0][session.day]) {
            var period = Period(
                periodType: PeriodType.classes,
                description: "教师: ${session.teacher}",
                location: session.location ?? "未知",
                summary: session.name,
                startTime: day.add(_sessionToTime[session.time.first].first),
                endTime: day.add(_sessionToTime[session.time.last].last)
            );
            periods.add(period);
          }
        }
        if (session.oddWeek) {
          for (var day in _dayOfWeekToDays[0][1][session.day]) {
            var period = Period(
                periodType: PeriodType.classes,
                description: "教师: ${session.teacher}",
                location: session.location ?? "未知",
                summary: session.name,
                startTime: day.add(_sessionToTime[session.time.first].first),
                endTime: day.add(_sessionToTime[session.time.last].last)
            );
            periods.add(period);
          }
        }
      }
      if (session.secondHalf) {
        if (session.evenWeek) {
          for (var day in _dayOfWeekToDays[1][0][session.day]) {
            var period = Period(
                periodType: PeriodType.classes,
                description: "教师: ${session.teacher}",
                location: session.location ?? "未知",
                summary: session.name,
                startTime: day.add(_sessionToTime[session.time.first].first),
                endTime: day.add(_sessionToTime[session.time.last].last),
            );
            periods.add(period);
          }
        }
        if (session.oddWeek) {
          for (var day in _dayOfWeekToDays[1][1][session.day]) {
            var period = Period(
                periodType: PeriodType.classes,
                description: "教师: ${session.teacher}",
                location: session.location ?? "未知",
                summary: session.name,
                startTime: day.add(_sessionToTime[session.time.first].first),
                endTime: day.add(_sessionToTime[session.time.last].last),
            );
            periods.add(period);
          }
        }
      }
    }
    periods = periods.where((e) => !_holidays.containsKey(DateTime(e.startTime.year, e.startTime.month, e.startTime.day))).toList();
    for (var exam in _exams) {
      var period = Period(
          periodType: PeriodType.test,
          description: "${exam.name} - ${exam.type == ExamType.finalExam ? "期末考试" : "期中考试"}",
          location: exam.location ?? "未知",
          summary: exam.name,
          startTime: exam.time[0],
          endTime: exam.time[1]
      );
      periods.add(period);
    }
    return periods;
  }

  DateTime get firstDay {
    try {
      return _dayOfWeekToDays.first.first[1].first;
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime get lastDay {
    try {
      return _dayOfWeekToDays.last.last.last.last;
    } catch (e) {
      return DateTime.now();
    }
  }

  void addSession(Session session) {
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

  void addExam(ExamDto examDto) {
    // 有的课没有考试但是能查到考试项
    _exams.addAll(examDto.exams);
    var courseId = examDto.id;
    if (_courses.containsKey(courseId)) {
      Course.completeExam(_courses[courseId]!, examDto);
    } else {
      _courses.addEntries(
          [MapEntry(courseId, Course.fromExam(examDto))]);
    }
  }

  void addGrade(Grade grade) {
    _grades.add(grade);
    var courseKey = grade.id;
    if (_courses.containsKey(courseKey)) {
      Course.completeGrade(_courses[courseKey]!, grade);
    } else {
      _courses.addEntries([MapEntry(courseKey, Course.fromGrade(grade))]);
    }
  }

  void addTimeInfo(Map<String, dynamic> json) {
    List<DateTime> startEnd = (json['startEnd'] as List)
        .map((e) => DateTime.parse(e as String))
        .toList();
    _sessionToTime = (json['sessionTime'] as List)
        .map((e) => (e as List)
            .map((e) => Duration(
                hours: int.parse((e as String).substring(0, 2)),
                minutes: int.parse((e).substring(3, 5))))
            .toList())
        .toList();
    _holidays = (json['holiday'] as Map).map((k, v) =>
        MapEntry(DateTime.parse(k as String), v as String));
    _exchanges = (json['exchange'] as Map).map((k, v) =>
        MapEntry(DateTime.parse((k as String).substring(0,8)), DateTime.parse((k).substring(8,16))));
    _dayOfWeekToDays = [
      [
        /*上半学期*/
        /*单周日期*/ [[], [], [], [], [], [], [], []],
        /*双周日期*/ [[], [], [], [], [], [], [], []]
      ],
      [
        /*下半学期*/
        /*单周日期*/ [[], [], [], [], [], [], [], []],
        /*双周日期*/ [[], [], [], [], [], [], [], []]
      ]
    ];
    // 上半学期
    var weekday = startEnd[0].weekday;
    var oddEvenWeek = 0;
    for (DateTime day = startEnd[0];
        !day.isAfter(startEnd[1]);
        day = day.add(const Duration(days: 1))) {
      _dayOfWeekToDays[0][oddEvenWeek][weekday++].add(_exchanges[day] ?? day);
      if (weekday == 8) {
        weekday = 1;
        oddEvenWeek = 1 - oddEvenWeek;
      }
    }
    weekday = startEnd[2].weekday;
    oddEvenWeek = 0;
    for (DateTime day = startEnd[2];
        !day.isAfter(startEnd[3]);
        day = day.add(const Duration(days: 1))) {
      _dayOfWeekToDays[1][oddEvenWeek][weekday++].add(_exchanges[day] ?? day);
      if (weekday == 8) {
        weekday = 1;
        oddEvenWeek = 1 - oddEvenWeek;
      }
    }
  }

  void calculateGPA() {
    gpa = Grade.calculateGpa(_grades);
    _grades.sort((a, b) => b.hundredPoint.compareTo(a.hundredPoint));
    credits = _grades.fold<double>(0.0, (p, e) => p + e.effectiveCredit);
  }

  void sortExams() {
    // 考试按开始时间排序
    _exams.sort((a, b) => a.time.first.compareTo(b.time.first));
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'courses': _courses,
      'exams': _exams,
      'sessions': _sessions,
      'grades': _grades,
      'gpa': gpa,
      'credits': credits,
      'sessionToTime': _sessionToTime
          .map((e) => e.map((e) => e.inMinutes).toList())
          .toList(),
      'dayOfWeekToDays': _dayOfWeekToDays
          .map((e) => e
              .map((e) => e
                  .map((e) => e.map((e) => e.toIso8601String()).toList())
                  .toList())
              .toList())
          .toList(),
      'holidays': _holidays
          .map((k, v) => MapEntry(k.toIso8601String(), v)),
      'exchanges': _exchanges
          .map((k, v) => MapEntry(k.toIso8601String(), v.toIso8601String())),
    };
  }

  Semester.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        _courses = (json['courses'] as Map).map((k, v) =>
            MapEntry(k as String, Course.fromJson(v as Map<String, dynamic>))),
        _exams = (json['exams'] as List).map((e) => Exam.fromJson(e)).toList(),
        _sessions =
            (json['sessions'] as List).map((e) => Session.fromJson(e)).toList(),
        _grades =
            (json['grades'] as List).map((e) => Grade.fromJson(e)).toList(),
        gpa = (json['gpa'] as List).map((e) => e as double).toList(),
        credits = json['credits'],
        _sessionToTime = (json['sessionToTime'] as List)
            .map((e) =>
                (e as List).map((e) => Duration(minutes: e as int)).toList())
            .toList(),
        _dayOfWeekToDays = (json['dayOfWeekToDays'] as List)
            .map((e) => (e as List)
                .map((e) => (e as List)
                    .map((e) => (e as List)
                        .map((e) => DateTime.parse(e as String))
                        .toList())
                    .toList())
                .toList())
            .toList(),
        _holidays = ((json['holidays'] ?? {}) as Map).map((k, v) => MapEntry(DateTime.parse(k as String), v as String)),
        _exchanges = ((json['exchanges'] ?? {}) as Map).map((k, v) => MapEntry(DateTime.parse(k as String), DateTime.parse(v as String)));
}
