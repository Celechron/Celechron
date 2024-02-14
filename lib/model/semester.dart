import 'package:celechron/model/exams_dto.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/utils/gpa_helper.dart';
import 'package:celechron/utils/utils.dart';
import 'course.dart';
import 'exam.dart';
import 'grade.dart';
import 'session.dart';

class Semester {
  // 学期名称
  final String name;
  final Map<String, Course> _courses;
  final List<Exam> _exams;
  final List<Grade> _grades;
  final List<Session> _sessions;

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
    [],
    [],
    [],
    [],
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

  // GPA, 四个数据依次为五分制、四分制（4.3 分制）、原始的四分制、百分制
  List<double> gpa = [0.0, 0.0, 0.0, 0.0];
  double credits = 0.0;

  Semester(this.name)
      : _courses = {},
        _exams = [],
        _grades = [],
        _sessions = [];

  String get firstHalfName {
    return name.substring(9, 10);
  }

  String get secondHalfName {
    return name.substring(10, 11);
  }

  // 课程数据
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
  List<Session> get sessions => _sessions;

  // 上半学期课表
  List<List<Session>> get firstHalfTimetable {
    return _sessions
        .where((e) => e.firstHalf && e.confirmed)
        .fold(<List<Session>>[[], [], [], [], [], [], [], []], (p, e) {
      p[e.dayOfWeek].add(e);
      return p;
    });
  }

  // 下半学期课表
  List<List<Session>> get secondHalfTimetable {
    return _sessions
        .where((e) => e.secondHalf && e.confirmed)
        .fold(<List<Session>>[[], [], [], [], [], [], [], []], (p, e) {
      p[e.dayOfWeek].add(e);
      return p;
    });
  }

  double get firstHalfSessionCount {
    return _sessions.where((e) => e.firstHalf && e.confirmed).fold(
        0.0,
        (p, e) =>
            p + (e.time.length) * ((e.oddWeek ? 1 : 0) + (e.evenWeek ? 1 : 0)));
  }

  double get secondHalfSessionCount {
    return _sessions.where((e) => e.secondHalf && e.confirmed).fold(
        0.0,
        (p, e) =>
            p + (e.time.length) * ((e.oddWeek ? 1 : 0) + (e.evenWeek ? 1 : 0)));
  }

  List<Period> get periods {
    List<Period> periods = [];
    for (var session in _sessions) {
        if (session.firstHalf) {
          if (session.oddWeek) {
            for (var day in _dayOfWeekToDays[0][0][session.dayOfWeek]) {
              var period = Period(
                  uid: '${session.id}${session.dayOfWeek}${session.time.first}',
                  fromUid: session.id,
                  type: PeriodType.classes,
                  description: "教师: ${session.teacher}",
                  location: session.location ?? "未知",
                  summary: session.name,
                  startTime: day.add(_sessionToTime[session.time.first].firstOrNull ?? Duration.zero),
                  endTime: day.add(_sessionToTime[session.time.last].lastOrNull ?? Duration.zero));
              periods.add(period);
            }
          }
          if (session.evenWeek) {
            for (var day in _dayOfWeekToDays[0][1][session.dayOfWeek]) {
              var period = Period(
                  uid: '${session.id}${session.dayOfWeek}${session.time.first}',
                  fromUid: session.id,
                  type: PeriodType.classes,
                  description: "教师: ${session.teacher}",
                  location: session.location ?? "未知",
                  summary: session.name,
                  startTime: day.add(_sessionToTime[session.time.first].firstOrNull ?? Duration.zero),
                  endTime: day.add(_sessionToTime[session.time.last].lastOrNull ?? Duration.zero));
              periods.add(period);
            }
          }
        }
        if (session.secondHalf) {
          if (session.oddWeek) {
            for (var day in _dayOfWeekToDays[1][0][session.dayOfWeek]) {
              var period = Period(
                uid: '${session.id}${session.dayOfWeek}${session.time.first}',
                fromUid: session.id,
                type: PeriodType.classes,
                description: "教师: ${session.teacher}",
                location: session.location ?? "未知",
                summary: session.name,
                startTime: day.add(_sessionToTime[session.time.first].firstOrNull ?? Duration.zero),
                endTime: day.add(_sessionToTime[session.time.last].lastOrNull ?? Duration.zero),
              );
              periods.add(period);
            }
          }
          if (session.evenWeek) {
            for (var day in _dayOfWeekToDays[1][1][session.dayOfWeek]) {
              var period = Period(
                uid: '${session.id}${session.dayOfWeek}${session.time.first}',
                fromUid: session.id,
                type: PeriodType.classes,
                description: "教师: ${session.teacher}",
                location: session.location ?? "未知",
                summary: session.name,
                startTime: day.add(_sessionToTime[session.time.first].firstOrNull ?? Duration.zero),
                endTime: day.add(_sessionToTime[session.time.last].lastOrNull ?? Duration.zero),
              );
              periods.add(period);
            }
          }
        }
    }
    periods = periods
        .where((e) => !_holidays.containsKey(
            DateTime(e.startTime.year, e.startTime.month, e.startTime.day)))
        .toList();
    for (var exam in _exams) {
      var period = Period(
          type: PeriodType.test,
          fromUid: exam.id,
          description:
              "${exam.name} - ${exam.type == ExamType.finalExam ? "期末考试" : "期中考试"}\n座位号：${exam.seat}",
          location: exam.location ?? "未知",
          summary: exam.name,
          startTime: exam.time[0],
          endTime: exam.time[1]);
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

  void addSession(Session session, String semesterId, [bool isGrs = false]) {
    // 由于ZDBK不给课号，Session的id初始值为null，不能直接拿来用！
    var key = '$semesterId${session.name}';
    if (_courses.containsKey(key)) {
      // 坑爹的API，有时同一节课会出现两次，必须鉴别是否重复。
      if (_courses[key]!.completeSession(session)) {
        _sessions.add(session);
      }
    } else {
      _sessions.add(session);
      if (isGrs) {
        _courses.addEntries([MapEntry(key, Course.fromGrsSession(session))]);
      } else {
        _courses
            .addEntries([MapEntry(key, Course.fromUgrsSessionWithoutID(session))]);
      }
    }
  }

  void addExam(ExamDto examDto) {
    addExamWithSemester(examDto, examDto.semesterId);
  }

  void addExamWithSemester(ExamDto examDto, String semesterId) {
    // 有的课没有考试，但是能查到考试信息，其考试时间为null。
    _exams.addAll(examDto.exams);
    var key = '$semesterId${examDto.name}';
    if (_courses.containsKey(key)) {
      _courses[key]!.completeExam(examDto);
    } else {
      _courses.addEntries([MapEntry(key, Course.fromExam(examDto))]);
    }
  }

  void addGrade(Grade grade) {
    addGradeWithSemester(grade, grade.semesterId);
  }

  void addGradeWithSemester(Grade grade, String semesterId,
      [bool isGrs = false]) {
    _grades.add(grade);
    var key = '$semesterId${grade.name}';
    if (_courses.containsKey(key)) {
      _courses[key]!.completeGrade(grade);
    } else {
      if (isGrs) {
        _courses.addEntries([MapEntry(key, Course.fromGrsGradeWithoutID(grade))]);
      } else {
        _courses.addEntries([MapEntry(key, Course.fromUgrsGrade(grade))]);
      }
    }
  }

  void addZjuCalendar(Map<String, dynamic> json) {
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
    _holidays = (json['holiday'] as Map)
        .map((k, v) => MapEntry(DateTime.parse(k as String), v as String));
    _exchanges = (json['exchange'] as Map).map((k, v) => MapEntry(
        DateTime.parse((k as String).substring(0, 8)),
        DateTime.parse((k).substring(8, 16))));
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
    var result = GpaHelper.calculateGpa(_grades);
    gpa = result.item1;
    credits = result.item2;
    _grades.sort((a, b) => b.hundredPoint.compareTo(a.hundredPoint));
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
      'holidays': _holidays.map((k, v) => MapEntry(k.toIso8601String(), v)),
      'exchanges': _exchanges
          .map((k, v) => MapEntry(k.toIso8601String(), v.toIso8601String())),
    };
  }

  Semester.fromJson(Map<String, dynamic> json)
      : name = json['name'] ?? DateTime.now().toIso8601String(),
        _courses = ((json['courses'] ?? {}) as Map).map((k, v) =>
            MapEntry(k as String, Course.fromJson(v as Map<String, dynamic>))),
        _exams = ((json['exams'] ?? []) as List)
            .map((e) => Exam.fromJson(e))
            .toList(),
        _sessions = ((json['sessions'] ?? []) as List)
            .map((e) => Session.fromJson(e))
            .toList(),
        _grades = ((json['grades'] ?? []) as List)
            .map((e) => Grade.fromJson(e))
            .toList(),
        gpa = ((json['gpa'] ?? []) as List).map((e) => e as double).toList(),
        credits = json['credits'] ?? 0.0,
        _sessionToTime = ((json['sessionToTime'] ?? []) as List)
            .map((e) =>
                (e as List).map((e) => Duration(minutes: e as int)).toList())
            .toList(),
        _dayOfWeekToDays = ((json['dayOfWeekToDays'] ?? []) as List)
            .map((e) => (e as List)
                .map((e) => (e as List)
                    .map((e) => (e as List)
                        .map((e) => DateTime.parse(e as String))
                        .toList())
                    .toList())
                .toList())
            .toList(),
        _holidays = ((json['holidays'] ?? {}) as Map)
            .map((k, v) => MapEntry(DateTime.parse(k as String), v as String)),
        _exchanges = ((json['exchanges'] ?? {}) as Map).map((k, v) => MapEntry(
            DateTime.parse(k as String), DateTime.parse(v as String))) {
    if (gpa.length == 3) {
      gpa.insert(2, 0);
    }
  }
}
