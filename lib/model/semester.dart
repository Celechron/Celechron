import 'package:celechron/model/exams_dto.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/utils/gpa_helper.dart';
import 'package:celechron/utils/json_utils.dart';
import 'package:celechron/utils/list_ext.dart';
import 'package:celechron/services/diagnostic_log_service.dart';
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

  void mergePartialFrom(Semester incoming) {
    // 用于部分刷新失败时补充新数据；空或不完整对象不得替换已有课程安排。
    Course? matchingCourse(Course incomingCourse) {
      for (final existing in _courses.values) {
        if (incomingCourse.id != null && existing.id == incomingCourse.id) {
          return existing;
        }
        if (existing.name == incomingCourse.name) return existing;
      }
      return null;
    }

    for (final entry in incoming.courses.entries) {
      final existing = matchingCourse(entry.value);
      if (existing == null) {
        _courses[entry.key] = entry.value;
        continue;
      }
      for (final session in entry.value.sessions) {
        existing.completeSession(session);
      }
      if (entry.value.grade != null) {
        existing.completeGrade(entry.value.grade!);
      }
      for (final exam in entry.value.exams) {
        final duplicate = existing.exams.any((current) =>
            current.id == exam.id &&
            current.type == exam.type &&
            current.time.isNotEmpty &&
            exam.time.isNotEmpty &&
            current.time.first == exam.time.first);
        if (!duplicate) existing.exams.add(exam);
      }
    }
    for (final session in incoming.sessions) {
      final duplicate = _sessions.any((existing) =>
          existing.id == session.id &&
          existing.dayOfWeek == session.dayOfWeek &&
          existing.time.join(',') == session.time.join(',') &&
          existing.location == session.location);
      if (!duplicate) _sessions.add(session);
    }
    for (final grade in incoming.grades) {
      final duplicate = _grades.any((existing) =>
          existing.id == grade.id && existing.original == grade.original);
      if (!duplicate) _grades.add(grade);
    }
    for (final exam in incoming.exams) {
      final duplicate = _exams.any((existing) =>
          existing.id == exam.id &&
          existing.type == exam.type &&
          existing.time.isNotEmpty &&
          exam.time.isNotEmpty &&
          existing.time.first == exam.time.first);
      if (!duplicate) _exams.add(exam);
    }
    calculateGPA();
  }

  // 上半学期课表
  List<List<Session>> get firstHalfTimetable {
    return _sessions
        .where((e) => e.firstHalf && e.confirmed && e.showOnTimetable)
        .fold(<List<Session>>[[], [], [], [], [], [], [], []], (p, e) {
      p[e.dayOfWeek].add(e);
      return p;
    });
  }

  // 下半学期课表
  List<List<Session>> get secondHalfTimetable {
    return _sessions
        .where((e) => e.secondHalf && e.confirmed && e.showOnTimetable)
        .fold(<List<Session>>[[], [], [], [], [], [], [], []], (p, e) {
      p[e.dayOfWeek].add(e);
      return p;
    });
  }

  double get firstHalfSessionCount {
    return _sessions
        .where((e) => e.firstHalf && e.confirmed && e.showOnTimetable)
        .fold(
            0.0,
            (p, e) =>
                p +
                (e.time.length) * ((e.oddWeek ? 1 : 0) + (e.evenWeek ? 1 : 0)));
  }

  double get secondHalfSessionCount {
    return _sessions
        .where((e) => e.secondHalf && e.confirmed && e.showOnTimetable)
        .fold(
            0.0,
            (p, e) =>
                p +
                (e.time.length) * ((e.oddWeek ? 1 : 0) + (e.evenWeek ? 1 : 0)));
  }

  List<Period> get periods {
    List<Period> periods = [];
    for (var session in _sessions) {
      // 自定义单双周的课程在后面处理（目前均为研究生课）
      if (session.customRepeat) {
        continue;
      }
      // 常规单双周的课程（目前均为本科生课）
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
                startTime: day.add(
                    _sessionToTime[session.time.first].firstOrNull ??
                        Duration.zero),
                endTime: day.add(_sessionToTime[session.time.last].lastOrNull ??
                    Duration.zero));
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
                startTime: day.add(
                    _sessionToTime[session.time.first].firstOrNull ??
                        Duration.zero),
                endTime: day.add(_sessionToTime[session.time.last].lastOrNull ??
                    Duration.zero));
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
              startTime: day.add(
                  _sessionToTime[session.time.first].firstOrNull ??
                      Duration.zero),
              endTime: day.add(_sessionToTime[session.time.last].lastOrNull ??
                  Duration.zero),
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
              startTime: day.add(
                  _sessionToTime[session.time.first].firstOrNull ??
                      Duration.zero),
              endTime: day.add(_sessionToTime[session.time.last].lastOrNull ??
                  Duration.zero),
            );
            periods.add(period);
          }
        }
      }
    }
    // 放假不调休的课直接去掉
    periods = periods
        .where((e) => !_holidays.containsKey(
            DateTime(e.startTime.year, e.startTime.month, e.startTime.day)))
        .toList();
    // 调休的课，调整时间
    for (var period in periods) {
      var originalDay = DateTime(
          period.startTime.year, period.startTime.month, period.startTime.day);
      if (_exchanges.containsKey(originalDay)) {
        var exchangedDay = _exchanges[DateTime(period.startTime.year,
            period.startTime.month, period.startTime.day)]!;
        period.startTime =
            period.startTime.add(exchangedDay.difference(originalDay));
        period.endTime =
            period.endTime.add(exchangedDay.difference(originalDay));
      }
    }
    // 自定义第几周上课的课程，在这里处理
    for (var session in _sessions) {
      if (session.customRepeat) {
        for (var week in session.customRepeatWeeks) {
          // (week - 1) ~/ 8 : 判断是上半学期还是下半学期。例如，第8周是上半学期。
          // 1 - week % 2 : 判断是单周还是双周。例如，第8周是双周。
          // session.dayOfWeek : 星期X上课
          // (week - 1) ~/ 2 + 1 : 这是（秋/冬）（单/双）周的第几个星期X。例如，第8周的周二是双周的第4个周二， 第7周的周二是单周的第4个周二。

          // 课程的第几周上课，如果超过16周，就在第16周最后一天的基础上计算。不要问为什么有17周18周的课，我只能说世界之大无奇不有。
          DateTime day;
          if (week > 16) {
            day = _dayOfWeekToDays.last.last.last.last
                .add(Duration(days: (week - 17) * 7 + session.dayOfWeek));
          } else {
            day = _dayOfWeekToDays[(week - 1) ~/ 8][1 - week % 2]
                [session.dayOfWeek][(week - 1) % 8 ~/ 2];
          }
          var period = Period(
              uid:
                  '${session.id}${session.dayOfWeek}${session.time.first}$week',
              fromUid: session.id,
              type: PeriodType.classes,
              description: "教师: ${session.teacher}",
              location: session.location ?? "未知",
              summary: session.name,
              startTime: day.add(
                  _sessionToTime.at(session.time.first)?.firstOrNull ??
                      Duration.zero),
              endTime: day.add(
                  _sessionToTime.at(session.time.last)?.lastOrNull ??
                      Duration.zero));
          periods.add(period);
        }
      }
    }
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
    // 因此本科课程以“学期 + 课程名”归组，再由 Course 合并重复安排。
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
        _courses.addEntries(
            [MapEntry(key, Course.fromUgrsSessionWithoutID(session))]);
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
        _courses.addEntries([MapEntry(key, Course.fromGrsGrade(grade))]);
      } else {
        _courses.addEntries([MapEntry(key, Course.fromUgrsGrade(grade))]);
      }
    }
  }

  void addZjuCalendar(Map<String, dynamic> json) {
    final startEnd = (asDynamicList(json['startEnd']) ?? const [])
        .map(asString)
        .whereType<String>()
        .map(asDateTime)
        .whereType<DateTime>()
        .toList();
    if (startEnd.length != 4) {
      throw const FormatException('校历缺少四个有效的学期起止日期');
    }

    final sessionToTime = <List<Duration>>[];
    for (final rawPeriod in asDynamicList(json['sessionTime']) ?? const []) {
      final period = <Duration>[];
      for (final rawTime in asDynamicList(rawPeriod) ?? const []) {
        final parts = (asString(rawTime) ?? '').split(':');
        if (parts.length < 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          period.add(Duration(hours: hour, minutes: minute));
        }
      }
      sessionToTime.add(period);
    }
    if (sessionToTime.isEmpty ||
        sessionToTime.every((period) => period.isEmpty)) {
      throw const FormatException('校历缺少有效的节次时间');
    }

    final holidays = <DateTime, String>{};
    for (final entry in (asStringMap(json['holiday']) ?? const {}).entries) {
      final date = asDateTime(entry.key);
      final name = asString(entry.value);
      if (date != null && name != null) holidays[date] = name;
    }
    final exchanges = <DateTime, DateTime>{};
    for (final key in (asStringMap(json['exchange']) ?? const {}).keys) {
      if (key.length < 16) continue;
      final first = asDateTime(key.substring(0, 8));
      final second = asDateTime(key.substring(8, 16));
      if (first != null && second != null) {
        exchanges[first] = second;
        exchanges[second] = first;
      }
    }

    _sessionToTime = sessionToTime;
    _holidays = holidays;
    _exchanges = exchanges;
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
      _dayOfWeekToDays[0][oddEvenWeek][weekday++].add(day);
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
      _dayOfWeekToDays[1][oddEvenWeek][weekday++].add(day);
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

  factory Semester.fromJson(Map<String, dynamic> json) {
    final semester =
        Semester(asString(json['name']) ?? DateTime.now().toIso8601String());

    final courses = asStringMap(json['courses']) ?? const {};
    for (final entry in courses.entries) {
      final courseMap = asStringMap(entry.value);
      if (courseMap == null) continue;
      try {
        semester._courses[entry.key] = Course.fromJson(courseMap);
      } on Object catch (error, stackTrace) {
        DiagnosticLogService.instance.record(
          level: CelechronLogLevel.warning,
          module: '本地学期缓存',
          operation: 'parseCourse',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    for (final rawExam in asDynamicList(json['exams']) ?? const []) {
      final examMap = asStringMap(rawExam);
      if (examMap == null) continue;
      try {
        final exam = Exam.fromJson(examMap);
        if (exam.time.length >= 2) semester._exams.add(exam);
      } on Object catch (error, stackTrace) {
        DiagnosticLogService.instance.record(
          level: CelechronLogLevel.warning,
          module: '本地学期缓存',
          operation: 'parseExam',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    for (final rawSession in asDynamicList(json['sessions']) ?? const []) {
      final sessionMap = asStringMap(rawSession);
      if (sessionMap == null) continue;
      try {
        final session = Session.fromJson(sessionMap);
        if (session.time.isNotEmpty) semester._sessions.add(session);
      } on Object catch (error, stackTrace) {
        DiagnosticLogService.instance.record(
          level: CelechronLogLevel.warning,
          module: '本地学期缓存',
          operation: 'parseSession',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    for (final rawGrade in asDynamicList(json['grades']) ?? const []) {
      final gradeMap = asStringMap(rawGrade);
      if (gradeMap == null) continue;
      try {
        final grade = Grade.fromJson(gradeMap);
        if (grade.id.isNotEmpty) semester._grades.add(grade);
      } on Object catch (error, stackTrace) {
        DiagnosticLogService.instance.record(
          level: CelechronLogLevel.warning,
          module: '本地学期缓存',
          operation: 'parseGrade',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    semester.gpa = (asDynamicList(json['gpa']) ?? const [])
        .map(asDouble)
        .whereType<double>()
        .toList();
    if (semester.gpa.length == 3) semester.gpa.insert(2, 0);
    if (semester.gpa.length != 4) {
      semester.gpa = [0.0, 0.0, 0.0, 0.0];
    }
    semester.credits = asDouble(json['credits']) ?? 0.0;

    final sessionTimes = <List<Duration>>[];
    for (final rawPeriod in asDynamicList(json['sessionToTime']) ?? const []) {
      sessionTimes.add((asDynamicList(rawPeriod) ?? const [])
          .map(asInt)
          .whereType<int>()
          .map((minutes) => Duration(minutes: minutes))
          .toList());
    }
    if (sessionTimes.isNotEmpty) semester._sessionToTime = sessionTimes;

    final calendar = <List<List<List<DateTime>>>>[];
    for (final rawHalf in asDynamicList(json['dayOfWeekToDays']) ?? const []) {
      final half = <List<List<DateTime>>>[];
      for (final rawOddEven in asDynamicList(rawHalf) ?? const []) {
        final oddEven = <List<DateTime>>[];
        for (final rawWeekday in asDynamicList(rawOddEven) ?? const []) {
          oddEven.add((asDynamicList(rawWeekday) ?? const [])
              .map(asString)
              .whereType<String>()
              .map(asDateTime)
              .whereType<DateTime>()
              .toList());
        }
        half.add(oddEven);
      }
      calendar.add(half);
    }
    if (calendar.length == 2) semester._dayOfWeekToDays = calendar;

    semester._holidays = {};
    for (final entry in (asStringMap(json['holidays']) ?? const {}).entries) {
      final date = asDateTime(entry.key);
      final name = asString(entry.value);
      if (date != null && name != null) semester._holidays[date] = name;
    }
    semester._exchanges = {};
    for (final entry in (asStringMap(json['exchanges']) ?? const {}).entries) {
      final from = asDateTime(entry.key);
      final to = asDateTime(entry.value);
      if (from != null && to != null) semester._exchanges[from] = to;
    }
    return semester;
  }
}
