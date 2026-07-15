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
  Cookie? _ssoCookie;
  Future<void>? _reloginFuture;
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

    _token = null;
    _ssoCookie = ssoCookie;

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
    _ssoCookie = null;
    _reloginFuture = null;
  }

  Future<void> _relogin(HttpClient httpClient) async {
    final ssoCookie = _ssoCookie;
    if (ssoCookie == null) {
      throw ExceptionWithMessage("会话已过期，请重新登录");
    }

    final future = _reloginFuture ??= _doRelogin(
      httpClient,
      ssoCookie,
    );
    try {
      await future;
    } finally {
      if (identical(_reloginFuture, future)) {
        _reloginFuture = null;
      }
    }
  }

  Future<void> _doRelogin(HttpClient httpClient, Cookie ssoCookie) async {
    _token = null;
    await login(httpClient, ssoCookie);
  }

  bool _isTokenExpired(Map<String, dynamic> result) {
    if (result["success"] == false) {
      String msg = (result["message"] ?? "").toString().toLowerCase();
      if (msg.contains("token") ||
          msg.contains("登录") ||
          msg.contains("unauthorized") ||
          msg.contains("认证") ||
          msg.contains("过期")) {
        return true;
      }
      // 研究生教务系统在token过期时返回code 401或500
      var code = result["code"];
      if (code == 401 || code == 500) {
        return true;
      }
    }
    return false;
  }

  Future<void> _ensureToken(HttpClient httpClient) async {
    if (_token != null) return;

    if (_ssoCookie != null) {
      await _relogin(httpClient);
      return;
    }

    throw ExceptionWithMessage("not logged in");
  }

  Future<Map<String, dynamic>> _requestJsonWithToken(
    HttpClient httpClient,
    Uri uri, {
    String method = 'GET',
  }) async {
    await _ensureToken(httpClient);
    var result = await _requestJson(httpClient, uri, method: method);
    if (!_isTokenExpired(result)) return result;

    await _relogin(httpClient);
    return await _requestJson(httpClient, uri, method: method);
  }

  Future<Map<String, dynamic>> _requestJson(
    HttpClient httpClient,
    Uri uri, {
    String method = 'GET',
  }) async {
    final request = await (method.toUpperCase() == 'POST'
            ? httpClient.postUrl(uri)
            : httpClient.getUrl(uri))
        .timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw ExceptionWithMessage("request timeout"),
    );
    request.headers.add("X-Access-Token", _token!);
    final response = await request.close().timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("request timeout"),
        );
    final resultJson = await response.transform(utf8.decoder).join();

    return jsonDecode(resultJson) as Map<String, dynamic>;
  }

  Future<Tuple<Exception?, Iterable<Grade>>> getGrade(
      HttpClient httpClient) async {
    try {
      final result = await _requestJsonWithToken(
        httpClient,
        Uri.parse(
            "https://yjsy.zju.edu.cn/dataapi/py/pyXsxk/queryXsxkByXnxqXs"),
        method: 'POST',
      );

      if (result["success"] != true) {
        throw ExceptionWithMessage('获取成绩api错误，错误信息为 ${result["message"]}');
      }

      return _parseGrades(result);
    } catch (e) {
      var exception = _toException(e);
      return Tuple(exception, []);
    }
  }

  Tuple<Exception?, Iterable<Grade>> _parseGrades(Map<String, dynamic> result) {
    final rawGrades = (result["result"]?["xxjhnList"] as List?) ?? [];
    if (rawGrades.isEmpty) {
      return Tuple(null, <Grade>[]);
    }
    List<Grade> grades = [];

    for (var rawGradeDyn in rawGrades) {
      var rawGrade = rawGradeDyn as Map<String, dynamic>;
      if (rawGrade["xkztMc"] == "未处理") {
        continue;
      }
      var newGrade = Grade.empty();
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
      newGrade.gpaIncluded = false;
      newGrade.creditIncluded = true;
      grades.add(newGrade);
    }
    return Tuple(null, grades);
  }

  Future<Tuple<Exception?, Iterable<ExamDto>>> getExamsDto(
      HttpClient httpClient, int year, int semester) async {
    try {
      final result = await _requestJsonWithToken(
        httpClient,
        Uri.parse(
            "https://yjsy.zju.edu.cn/dataapi/py/pyKsxsxx/queryPageByXs?dm=py_grks&mode=2&role=1&column=createTime&order=desc&queryMode=1&field=id,,kcbh,kcmc,rq,ksTime,xn,xq_dictText,ksdd,zwh&pageNo=1&pageSize=100&xn=$year&xq=$semester"),
      );

      if (result["success"] != true) {
        throw ExceptionWithMessage("获取考试api错误，错误信息为 ${result["message"]}");
      }

      return _parseExams(result, year);
    } catch (e) {
      var exception = _toException(e);
      return Tuple(exception, []);
    }
  }

  Tuple<Exception?, Iterable<ExamDto>> _parseExams(
      Map<String, dynamic> result, int year) {
    final rawExams = result["result"] as List<dynamic>;
    List<ExamDto> exams = [];
    final formatter = DateFormat('yyyy-MM-dd');

    for (var rawExamDyn in rawExams) {
      var rawExam = rawExamDyn as Map<String, dynamic>;
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
  }

  // Helper method to map semester code to semester name
  String _getSemesterName(int semester) {
    if (semester == 11 || semester == 15) {
      return "春夏学期";
    } else {
      return "秋冬学期";
    }
  }

  Future<void> _fetchCourseDetails(HttpClient httpClient, int year,
      int semester, List<Session> sessions) async {
    if (_token == null) return;

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

      if (teacherId == null || teacherId.isEmpty) return;

      try {
        String url =
            "https://yjsy.zju.edu.cn/dataapi/py/pyKcbj/queryKcbjDetailInfoPage?";
        url += "&xns=$year";
        url += "&xqMc=${Uri.encodeComponent(semesterName)}";
        url += "&kcbh=${Uri.encodeComponent(sessionId)}";
        url += "&kcmc=${Uri.encodeComponent(courseSessions.first.name)}";
        url += "&zjjsJzgId=${Uri.encodeComponent(teacherId)}";
        final result = await _requestJsonWithToken(httpClient, Uri.parse(url));

        if (result["success"] == true) {
          _applyCourseDetails(result, courseSessions);
        }
      } catch (e) {
        // 若接口访问或解包异常，课程信息维持原值，不做抛出
      }
    }));
  }

  void _applyCourseDetails(
      Map<String, dynamic> result, List<Session> courseSessions) {
    final records = result["result"]?["records"] as List?;
    if (records != null && records.isNotEmpty) {
      var detail = records[0] as Map<String, dynamic>;

      if (detail["xf"] != null) {
        double creditValue = (detail["xf"] as num).toDouble();
        for (var session in courseSessions) {
          session.credit = creditValue;
        }
      }

      if (detail["bz"] != null) {
        String comments = detail["bz"] as String;
        bool isOnline = comments.contains("线上") ||
            comments.contains("录播") ||
            comments.contains("直播");
        for (var session in courseSessions) {
          session.online = isOnline;
        }
      }

      if (detail["kcxzDm_dictText"] != null) {
        String courseType = detail["kcxzDm_dictText"] as String;
        for (var session in courseSessions) {
          session.type = courseType;
        }
      }
    }
  }

  Future<Tuple<Exception?, Iterable<Session>>> getTimetable(
      HttpClient httpClient, int year, int semester) async {
    try {
      final result = await _requestJsonWithToken(
        httpClient,
        Uri.parse(
            "https://yjsy.zju.edu.cn/dataapi/py/pyKcbj/queryXskbByLoginUser?xn=$year&pkxq=$semester"),
      );

      if (result["success"] != true) {
        throw ExceptionWithMessage("获取课程api错误，错误信息为 ${result["message"]}");
      }

      return _parseTimetable(httpClient, result, year, semester);
    } catch (e) {
      var exception = _toException(e);
      return Tuple(exception, []);
    }
  }

  Future<Tuple<Exception?, Iterable<Session>>> _parseTimetable(
      HttpClient httpClient,
      Map<String, dynamic> result,
      int year,
      int semester) async {
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
              int oddWeekCount = weekExtraList.where((e) => e % 2 == 1).length;
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

    await _fetchCourseDetails(httpClient, year, semester, sessions);

    return Tuple(null, sessions);
  }

  Exception _toException(Object error) {
    if (error is SocketException) return ExceptionWithMessage("网络错误");
    if (error is Exception) return error;
    return ExceptionWithMessage(error.toString());
  }
}
