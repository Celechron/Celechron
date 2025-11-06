import 'dart:convert';
import 'dart:io';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/model/session.dart';
import 'package:celechron/model/exams_dto.dart';
import 'package:celechron/model/exam.dart';
import 'package:celechron/model/grade.dart';
import 'package:intl/intl.dart';
import 'package:quiver/time.dart';

class GrsNew {
  String? _token;
  // ignore: unused_field
  DatabaseHelper? _db;

  set db(DatabaseHelper? db) {
    _db = db;
  }

  Future<void> login(HttpClient httpClient, Cookie? ssoCookie) async {
    late HttpClientRequest req;
    late HttpClientResponse res;

    if (ssoCookie == null) {
      throw ExceptionWithMessage("Invalid ssoCookie");
    }

    req = await httpClient
        .getUrl(Uri.parse(
            "https://zjuam.zju.edu.cn/cas/login?service=https%3A%2F%2Fyjsy.zju.edu.cn%2F"))
        .timeout(const Duration(seconds: 8),
            onTimeout: () => throw ExceptionWithMessage("request timeout"));
    req.followRedirects = false;
    req.cookies.add(ssoCookie);
    res = await req.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("request timeout"));
    res.drain();

    final headerLoc = res.headers.value("location");
    if (headerLoc == null) {
      throw ExceptionWithMessage("Invalid location header");
    }
    final ticketLoc = headerLoc.indexOf("ticket=");
    if (ticketLoc < 0) {
      throw ExceptionWithMessage("Invalid location header");
    }
    final ticket = headerLoc.substring(ticketLoc + 7);

    req = await httpClient
        .getUrl(Uri.parse(
            "https://yjsy.zju.edu.cn/dataapi/sys/cas/client/validateLogin?ticket=$ticket&service=https:%2F%2Fyjsy.zju.edu.cn%2F"))
        .timeout(const Duration(seconds: 8),
            onTimeout: () => throw ExceptionWithMessage("request timeout"));
    res = await req.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("request timeout"));
    final loginJson = await res.transform(utf8.decoder).join();

    // parse loginJson body
    final loginInfo = jsonDecode(loginJson) as Map<String, dynamic>;
    if (loginInfo["success"] != true) {
      throw ExceptionWithMessage("Invalid login info");
    }
    final loginResult = loginInfo["result"] as Map<String, dynamic>;
    _token = loginResult["token"] as String?;
    if (_token == null) {
      throw ExceptionWithMessage("Invalid token");
    }
  }

  void logout() {
    _token = null;
  }

  Future<Tuple<Exception?, Iterable<Grade>>> getGrade(
      HttpClient httpClient) async {
    /*
    不需要参数，但是注意是post
     */
    late HttpClientRequest req;
    late HttpClientResponse res;
    try {
      if (_token == null) {
        throw ExceptionWithMessage("not logged in");
      }
      req = await httpClient
          .postUrl(Uri.parse(
              "https://yjsy.zju.edu.cn/dataapi/py/pyXsxk/queryXsxkByXnxqXs"))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("request timeout"));
      req.headers.add("X-Access-Token", _token!);
      res = await req.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("request timeout"));
      final resultJson = await res.transform(utf8.decoder).join();
      final result = jsonDecode(resultJson) as Map<String, dynamic>;
      if (result["success"] != true) {
        throw ExceptionWithMessage('获取成绩api错误，错误信息为 ${result["message"]}');
      }

      final rawGrades = (result["result"]?["xxjhnList"] as List?) ?? [];
      if (rawGrades.isEmpty) {
        return Tuple(null, <Grade>[]);
      }
      List<Grade> grades = [];

      for (var rawGradeDyn in rawGrades) {
        var rawGrade = rawGradeDyn as Map<String, dynamic>;
        // TODO: 增加额外的需要跳过的课程
        if (rawGrade["xkztMc"] == "未处理") {
          continue;
        }
        var newGrade = Grade.empty();
        //这里使用的id和其他的不一样，直接使用sjddBz字段，
        // e.g.: 2023-2024学年冬学期<br/>班级编号xxxxx
        newGrade.id =
            rawGrade["sjddBz"] == null ? "" : rawGrade["sjddBz"] as String;
        newGrade.name = rawGrade["kcmc"] as String;
        newGrade.credit = rawGrade["xf"] as double;

        if (rawGrade["bz"] != null) {
          var comments = rawGrade["bz"] as String;
          if (comments.contains("线上") ||
              comments.contains("录播") ||
              comments.contains("直播")) {
            newGrade.isOnline = true;
          } else {
            newGrade.isOnline = false;
          }
        } else {
          newGrade.isOnline = false;
        }
        newGrade.fivePoint = 0.0;
        newGrade.fourPoint = 0.0;
        newGrade.fourPointLegacy = 0.0;
        newGrade.hundredPoint =
            rawGrade["zf"] == null ? 0 : (rawGrade["zf"] as double).toInt();
        newGrade.major = true;
        // 研究生应该没法算gpa吧
        newGrade.gpaIncluded = false;
        newGrade.creditIncluded = true;
        grades.add(newGrade);
      }
      return Tuple(null, grades);
    } catch (e) {
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      return Tuple(exception, []);
    }
  }

  Future<Tuple<Exception?, Iterable<ExamDto>>> getExamsDto(
      HttpClient httpClient, int year, int semester) async {
    /*
    * 11 srping-summer
    * 12 autum-winter
     */
    late HttpClientRequest req;
    late HttpClientResponse res;
    try {
      if (_token == null) {
        throw ExceptionWithMessage("not logged in");
      }

      req = await httpClient
          .getUrl(Uri.parse(
              "https://yjsy.zju.edu.cn/dataapi/py/pyKsxsxx/queryPageByXs?dm=py_grks&mode=2&role=1&column=createTime&order=desc&queryMode=1&field=id,,kcbh,kcmc,rq,ksTime,xn,xq_dictText,ksdd,zwh&pageNo=1&pageSize=100&xn=$year&xq=$semester"))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("request timeout"));
      req.headers.add("X-Access-Token", _token!);
      res = await req.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("request timeout"));
      final resultJson = await res.transform(utf8.decoder).join();
      final result = jsonDecode(resultJson) as Map<String, dynamic>;
      if (result["success"] != true) {
        throw ExceptionWithMessage("获取考试api错误，错误信息为 ${result["message"]}");
      }

      final rawExams = result["result"] as List<dynamic>;
      List<ExamDto> exams = [];
      // 这个破库不支持yyyyMMdd格式的表示，必须有分隔符
      final formatter = DateFormat('yyyy-MM-dd');

      for (var rawExamDyn in rawExams) {
        var rawExam = rawExamDyn as Map<String, dynamic>;
        // yjsy系统奇怪的bug，加一个特判
        if (rawExam["xn"] as String != year.toString()) {
          continue;
        }
        var newExamDto = ExamDto.empty();
        var newExam = Exam.empty();
        newExam.id = (rawExam["kcbh"] as String).substring(0, 7);
        newExam.name = rawExam["kcmc"] as String;
        newExam.type = ExamType.finalExam;
        newExam.location = (rawExam["mc"] as String?) ?? "未知地点";
        newExam.seat = (rawExam["zwh"] as int).toString();
        int day = (rawExam["rq"] as int?) ?? 19700101;
        int start = (rawExam["kssj"] as int?) ?? 800;
        int end = (rawExam["jssj"] as int?) ?? 2200;
        String dayFromat =
            '${day.toString().substring(0, 4)}-${day.toString().substring(4, 6)}-${day.toString().substring(6, 8)}';
        DateTime dayTime = formatter.parse(dayFromat);
        DateTime startTime =
            dayTime.add(anHour * (start ~/ 100) + aMinute * (start % 100));
        DateTime endTime =
            dayTime.add(anHour * (end ~/ 100) + aMinute * (end % 100));
        newExam.time = [startTime, endTime];
        newExamDto.id = (rawExam["kcbh"] as String).substring(0, 7);
        newExamDto.name = rawExam["kcmc"] as String;
        newExamDto.credit = 0;
        newExamDto.exams.add(newExam);

        exams.add(newExamDto);
      }
      return Tuple(null, exams);
    } catch (e) {
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      return Tuple(exception, []);
    }
  }

  // Helper method to map semester code to semester name
  String _getSemesterName(int semester) {
    // 11: spring, 15: spring-summer -> "春夏学期"
    // 12: summer, 13: autumn, 14: winter, 16: autumn-winter -> "秋冬学期"
    if (semester == 11 || semester == 15) {
      return "春夏学期";
    } else {
      return "秋冬学期";
    }
  }

  /// 根据课程列表 sessions，通过研究生教务系统课程详情 API 补全每门课程的学分、上课方式（线上/线下）、课程类型等详细信息。
  /// 
  /// 参数说明：
  /// [httpClient] - Dart 的 HttpClient 实例，用于发起 API 请求。
  /// [year] - 学年（如 2023），等同于 API 参数 xns。
  /// [semester] - 学期代码，Semester 枚举值（11/12/13/14/15/16），等同于 API 参数 pkxq。
  /// [sessions] - 课程 Session 对象列表，需要补全详细信息的课程列表。
  /// 
  /// 用法示例：
  ///   await _fetchCourseDetails(httpClient, 2023, 13, sessions);
  ///
  /// 注意：必须先登录获取 _token，否则不会进行任何操作。
  Future<void> _fetchCourseDetails(
      HttpClient httpClient,
      int year,
      int semester,
      List<Session> sessions) async {
    if (_token == null) return;

    // 将 sessions 按课程 id 归类，以便批量更新同一课程可能出现的多条 session 信息
    Map<String, List<Session>> sessionsByCourse = {};
    for (var session in sessions) {
      if (session.id != null) {
        sessionsByCourse.putIfAbsent(session.id!, () => []).add(session);
      }
    }

    String semesterName = _getSemesterName(semester);
    await Future.wait(sessionsByCourse.entries.map((entry) async {
      String sessionId = entry.key;
      List<Session> courseSessions = entry.value;
      String? teacherId = courseSessions.first.teacherId;

      // 没有教师信息的不查（课表 API 异常情况下可出现）
      if (teacherId == null || teacherId.isEmpty) return;

      try {
        // Build URL with parameters
        // 对应研究生教务系统的查询全校开课情况接口
        String url = "https://yjsy.zju.edu.cn/dataapi/py/pyKcbj/queryKcbjDetailInfoPage?";
        url += "&xns=$year";
        url += "&xqMc=${Uri.encodeComponent(semesterName)}"; // 学期名称
        url += "&kcbh=${Uri.encodeComponent(sessionId)}"; // 课程ID
        url += "&kcmc=${Uri.encodeComponent(courseSessions.first.name)}"; // 课程名称
        url += "&zjjsJzgId=${Uri.encodeComponent(teacherId)}"; // 教师ID
        var req = await httpClient
            .getUrl(Uri.parse(url))
            .timeout(const Duration(seconds: 8),
                onTimeout: () => throw ExceptionWithMessage("request timeout"));
        req.headers.add("X-Access-Token", _token!);
        var res = await req.close().timeout(const Duration(seconds: 8),
            onTimeout: () => throw ExceptionWithMessage("request timeout"));

        final resultJson = await res.transform(utf8.decoder).join();
        final result = jsonDecode(resultJson) as Map<String, dynamic>;
        if (result["success"] == true) {
          final records = result["result"]?["records"] as List?;
          if (records != null && records.isNotEmpty) {
            var detail = records[0] as Map<String, dynamic>;

            // 抓取学分
            if (detail["xf"] != null) {
              double creditValue = (detail["xf"] as num).toDouble();
              for (var session in courseSessions) {
                session.credit = creditValue;
              }
            }

            // 抓取是否线上课程
            if (detail["bz"] != null) {
              String comments = detail["bz"] as String;
              bool isOnline = comments.contains("线上") ||
                  comments.contains("录播") ||
                  comments.contains("直播");
              for (var session in courseSessions) {
                session.online = isOnline;
              }
            }

            // 抓取课程类型（专业学位课、公共学位课、专业必修课、公共必修课、专业选修课、公共选修课）
            if (detail["kcxzDm_dictText"] != null) {
              String courseType = detail["kcxzDm_dictText"] as String;
              for (var session in courseSessions) {
                session.type = courseType;
              }
            }
          }
        }
      } catch (e) {
        // 若接口访问或解包异常，课程信息维持原值，不做抛出
      }
    }));
  }

  Future<Tuple<Exception?, Iterable<Session>>> getTimetable(
      HttpClient httpClient, int year, int semester) async {
    /*
     * semester:
     * 11: spring
     * 12: summer
     * 13: autumn
     * 14: winter
     * 15: spring-summer
     * 16: autumn-winter
     */
    late HttpClientRequest req;
    late HttpClientResponse res;
    try {
      if (_token == null) {
        throw ExceptionWithMessage("not logged in");
      }

      req = await httpClient
          .getUrl(Uri.parse(
              "https://yjsy.zju.edu.cn/dataapi/py/pyKcbj/queryXskbByLoginUser?xn=$year&pkxq=$semester"))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("request timeout"));
      req.headers.add("X-Access-Token", _token!);
      res = await req.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("request timeout"));
      final resultJson = await res.transform(utf8.decoder).join();

      final result = jsonDecode(resultJson) as Map<String, dynamic>;
      if (result["success"] != true) {
        throw ExceptionWithMessage("获取课程api错误，错误信息为 ${result["message"]}");
      }

      Map<String, dynamic> defaultMap = {};
      final kcbMap = result["result"] as Map<String, dynamic>;
      final dayWithClasses = kcbMap["kcbMap"] as Map<String, dynamic>;

      List<Session> sessions = [];
      for (int i = 1; i <= 7; ++i) {
        var classesThisDay =
            (dayWithClasses["$i"] ?? defaultMap) as Map<String, dynamic>;
        Map<String, Session> sessionThisDay = {};
        for (int j = 1; j <= 15; ++j) {
          var wrapper =
              (classesThisDay["$j"] ?? defaultMap) as Map<String, dynamic>;
          var classesThisPeriod =
              (wrapper["pyKcbjSjddVOList"] ?? []) as List<dynamic>;

          for (var rawClassDyn in classesThisPeriod) {
            try {
              var rawClass = rawClassDyn as Map<String, dynamic>;
              String classId = rawClass["bjbh"] as String;
              String sessionId = classId.substring(0, 7);

              if (sessionThisDay.containsKey(classId)) {
                sessionThisDay[classId]!.time.add(j);
                continue;
              }
              // TODO: 增加还需要跳过的课程，"12"=未处理
              if (rawClass["xkzt"] == "12") {
                continue;
              }

              int classSemester = int.parse(rawClass["pkxq"] ?? "$semester");
              var newSession = Session.empty();
              newSession.id = sessionId;
              newSession.name = rawClass["kcmc"] as String;
              newSession.teacher = rawClass["xm"] as String;
              newSession.teacherId = rawClass["jzgId"] as String?;
              newSession.location = rawClass["cdmc"] as String?;
              newSession.confirmed = true;
              newSession.dayOfWeek = i;
              newSession.time = [j];

              if (semester == 11 || semester == 13) {
                newSession.firstHalf = true;
              } else {
                newSession.secondHalf = true;
              }
              if (classSemester == 15 || classSemester == 16) {
                newSession.firstHalf = newSession.secondHalf = true;
              }

              // 研究生教务系统的课表在改版之后就是依托答辩，哪个没脑子的能想出来把调休的课单独列出来？
              // 课表和狗皮膏药一样完全读不懂，“秋冬1,2,4,5,6,7,8,9,10,11,12,13,14,15,16周上课”这玩意儿是给人看的？
              String weekExtra = rawClass["zc"] as String;
              weekExtra = weekExtra.replaceAll(RegExp(r"[^\d,]"), "");
              List<int> weekExtraList =
                  weekExtra.split(",").map(int.parse).toList();

              newSession.customRepeat = true;
              newSession.customRepeatWeeks = weekExtraList;

              var threshold =
                  (newSession.firstHalf && newSession.secondHalf) ? 8 : 4;
              if (weekExtraList.length > threshold) {
                newSession.oddWeek = newSession.evenWeek = true;
              } else {
                int oddWeekCount =
                    weekExtraList.where((e) => e % 2 == 1).length;
                if (oddWeekCount > weekExtraList.length / 2) {
                  newSession.oddWeek = true;
                } else {
                  newSession.evenWeek = true;
                }
              }

              sessionThisDay[classId] = newSession;
            } finally {
              // log here?
            }
          }
        }

        sessions.addAll(sessionThisDay.values);
      }

      // Fetch course details for each unique course
      await _fetchCourseDetails(httpClient, year, semester, sessions);

      return Tuple(null, sessions);
    } catch (e) {
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      return Tuple(exception, []);
    }
  }
}

void main() async {
  // const str = "https://yjsy.zju.edu.cn/?ticket=ST-399";
  // int ticketLoc = str.indexOf("ticket=");
  // print(str.substring(ticketLoc + 7, 2));
}
