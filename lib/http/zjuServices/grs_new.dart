import 'dart:convert';
import 'dart:io';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/exam.dart';
import 'package:celechron/model/exams_dto.dart';
import 'package:celechron/model/grade.dart';
import 'package:celechron/model/session.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:flutter/foundation.dart';

import 'exceptions.dart';
import 'response_utils.dart';

/// 研究生院接口客户端；CAS ticket 校验成功后以 X-Access-Token 访问业务 API。
class GrsNew {
  String? _token;
  Cookie? _ssoCookie;
  Future<void>? _loginFuture;
  // ignore: unused_field
  DatabaseHelper? _db;

  set db(DatabaseHelper? db) {
    _db = db;
  }

  Future<void> login(HttpClient httpClient, Cookie? ssoCookie) async {
    if (ssoCookie == null) {
      throw AuthenticationExpiredException("研究生院：统一身份认证凭据无效");
    }
    _ssoCookie = ssoCookie;

    // 登录单飞可避免并发 CAS ticket 校验生成多个互相替代的 token。
    final pending = _loginFuture;
    if (pending != null) {
      await pending;
      return;
    }
    final login = _doLogin(httpClient, ssoCookie);
    _loginFuture = login;
    try {
      await login;
    } finally {
      if (identical(_loginFuture, login)) _loginFuture = null;
    }
  }

  Future<void> _doLogin(HttpClient httpClient, Cookie ssoCookie) async {
    _token = null;
    final casUri = Uri.parse(
        "https://zjuam.zju.edu.cn/cas/login?service=https%3A%2F%2Fyjsy.zju.edu.cn%2F");
    final request = await httpClient.getUrl(casUri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw requestTimeout());
    request.followRedirects = false;
    request.cookies.add(ssoCookie);
    final response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw requestTimeout());
    final body = await readResponseBody(response, context: '研究生院 CAS 登录');
    final location = response.headers.value(HttpHeaders.locationHeader);

    if (!response.isRedirect || location == null) {
      throw AuthenticationExpiredException(
          '研究生院登录：未获得 CAS ticket；HTTP ${response.statusCode}'
          '；Content-Type ${response.headers.value(HttpHeaders.contentTypeHeader) ?? '<缺失>'}'
          '${location == null ? '' : '；Location $location'}'
          '；响应摘要：${responseSummary(body)}');
    }
    final ticketUri = casUri.resolve(location);
    final ticket = ticketUri.queryParameters['ticket'];
    if (ticket == null || ticket.isEmpty) {
      throw AuthenticationExpiredException(
          '研究生院登录：Location 中缺少 ticket；HTTP ${response.statusCode}'
          '；Location $location；响应摘要：${responseSummary(body)}');
    }

    // CAS Location 中的 ticket 必须立即交给研究生院校验接口换取业务 token。
    final validateUri = Uri.https(
      'yjsy.zju.edu.cn',
      '/dataapi/sys/cas/client/validateLogin',
      {
        'ticket': ticket,
        'service': 'https://yjsy.zju.edu.cn/',
      },
    );
    final validateRequest = await httpClient.getUrl(validateUri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw requestTimeout());
    validateRequest.followRedirects = false;
    final validateResponse = await validateRequest.close().timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw requestTimeout());
    final loginJson = await readResponseText(
      validateResponse,
      context: '研究生院 CAS 校验接口',
      expectJson: true,
      requestUri: validateUri,
    );
    final loginInfo = decodeJsonMap(loginJson,
        context: '研究生院 CAS 校验接口；HTTP ${validateResponse.statusCode}');
    if (jsonIndicatesAuthenticationFailure(loginInfo) ||
        asBool(loginInfo["success"]) != true) {
      throw AuthenticationExpiredException(
          '研究生院登录认证失败；HTTP ${validateResponse.statusCode}'
          '；错误信息 ${asString(loginInfo["message"]) ?? '<缺失>'}'
          '；响应摘要：${responseSummary(loginJson)}');
    }
    final loginResult = asStringMap(loginInfo["result"]);
    final token = asString(loginResult?["token"]);
    if (token == null || token.isEmpty) {
      throw AuthenticationExpiredException(
          '研究生院登录成功响应缺少 token；HTTP ${validateResponse.statusCode}'
          '；响应摘要：${responseSummary(loginJson)}');
    }
    _token = token;
  }

  void logout() {
    _token = null;
    _ssoCookie = null;
  }

  Future<void> _relogin(HttpClient httpClient) async {
    final cookie = _ssoCookie;
    if (cookie == null) {
      throw AuthenticationExpiredException("研究生院登录态已失效，请重新登录");
    }
    await login(httpClient, cookie);
  }

  Future<Map<String, dynamic>> _fetchApi(
    HttpClient httpClient,
    Uri uri, {
    required String context,
    bool post = false,
  }) async {
    // 每个请求最多自动重登一次；第二次认证失败交由上层提示手动登录。
    var relogged = false;

    Future<HttpClientRequest> requestFactory() async {
      final request = post
          ? await httpClient.postUrl(uri).timeout(
                const Duration(seconds: 8),
                onTimeout: () => throw requestTimeout(),
              )
          : await httpClient.getUrl(uri).timeout(
                const Duration(seconds: 8),
                onTimeout: () => throw requestTimeout(),
              );
      request.followRedirects = false;
      return request;
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      String? requestToken;
      try {
        if (_token == null) {
          await _relogin(httpClient);
          relogged = true;
        }
        requestToken = _token!;
        final request = await requestFactory();
        request.headers.add("X-Access-Token", requestToken);
        final response = await request.close().timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout());
        final body = await readResponseText(
          response,
          context: context,
          expectJson: true,
          requestUri: uri,
          relogged: relogged,
          retried: attempt > 0,
        );
        final result = decodeJsonMap(body,
            context: '$context；HTTP ${response.statusCode}');
        if (_isTokenExpired(result)) {
          throw LoginExpiredException(
            '$context：token 已过期',
            details: [
              '接口：$context',
              '请求：${sanitizedRequestUri(uri)}',
              'HTTP 状态码：${response.statusCode}',
              '执行过重新登录：${relogged ? '是' : '否'}',
              '执行过重试：${attempt > 0 ? '是' : '否'}',
              '响应摘要：${responseSummary(body)}',
            ].join('\n'),
          );
        }
        return result;
      } on AuthenticationExpiredException catch (error) {
        // 其它并发请求可能已完成重登；直接用新 token 重试，避免再次登录
        // 使刚签发的 token 失效。
        if (_token != null && _token != requestToken && attempt == 0) {
          continue;
        }
        _token = null;
        if (attempt == 0 && !relogged) {
          await _relogin(httpClient);
          relogged = true;
          continue;
        }
        throw LoginExpiredException(
          '$context：自动重登失败，请手动重新登录',
          details: detailedErrorText(error),
          originalError: error,
        );
      }
    }
    throw LoginExpiredException('$context：登录态已失效，请手动重新登录');
  }

  bool _isTokenExpired(Map<String, dynamic> result) {
    if (jsonIndicatesAuthenticationFailure(result)) return true;
    // 研究生院在 token 过期时也可能只返回 success=false、code=500。
    final code = asInt(result['code']);
    return asBool(result['success']) == false &&
        (code == HttpStatus.unauthorized || code == 500);
  }

  void _requireSuccess(Map<String, dynamic> result, String context) {
    if (asBool(result["success"]) == true) return;
    final message =
        asString(result["message"]) ?? asString(result["msg"]) ?? '服务端未提供错误信息';
    throw ExceptionWithMessage(
        '$context：接口返回失败；code=${asString(result["code"]) ?? '<缺失>'}'
        '；message=$message；响应摘要：${responseSummary(jsonEncode(result))}');
  }

  Future<Tuple<Exception?, Iterable<Grade>>> getGrade(
      HttpClient httpClient) async {
    const context = '研究生院成绩接口（请求类型 成绩）';
    final uri = Uri.parse(
        "https://yjsy.zju.edu.cn/dataapi/py/pyXsxk/queryXsxkByXnxqXs");
    try {
      final result = await _fetchApi(
        httpClient,
        uri,
        context: context,
        post: true,
      );
      _requireSuccess(result, context);
      return Tuple(null, _parseGrades(result, context));
    } on Object catch (error, stackTrace) {
      return Tuple(
          exceptionFrom(error,
              context: context, requestUri: uri, stackTrace: stackTrace),
          <Grade>[]);
    }
  }

  List<Grade> _parseGrades(Map<String, dynamic> result, String context) {
    final resultMap = asStringMap(result["result"]);
    final rawGrades = asDynamicList(resultMap?["xxjhnList"]) ?? const [];
    final grades = <Grade>[];

    for (var index = 0; index < rawGrades.length; index++) {
      final rawGrade = asStringMap(rawGrades[index]);
      if (rawGrade == null || asString(rawGrade["xkztMc"]) == "未处理") {
        continue;
      }
      try {
        final id = asString(rawGrade["sjddBz"]);
        if (id == null || id.isEmpty) {
          throw const FormatException('缺少学期/班级标识 sjddBz');
        }
        final comments = asString(rawGrade["bz"]) ?? '';
        final newGrade = Grade.empty()
          ..id = id
          ..name = asString(rawGrade["kcmc"]) ?? '未知课程'
          ..credit = asDouble(rawGrade["xf"]) ?? 0.0
          ..original = asString(rawGrade["zf"]) ?? ''
          ..fivePoint = 0.0
          ..fourPoint = 0.0
          ..fourPointLegacy = 0.0
          ..hundredPoint = asInt(rawGrade["zf"]) ?? 0
          ..major = true
          ..gpaIncluded = false
          ..creditIncluded = true
          ..isOnline = comments.contains("线上") ||
              comments.contains("录播") ||
              comments.contains("直播");
        grades.add(newGrade);
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
              '$context：跳过第 ${index + 1} 条成绩：${error.runtimeType}: $error\n$stackTrace');
        }
      }
    }
    return grades;
  }

  Future<Tuple<Exception?, Iterable<ExamDto>>> getExamsDto(
      HttpClient httpClient, int year, int semester) async {
    final context = '研究生院考试接口（学年 $year，学期 $semester，请求类型 考试）';
    final uri =
        Uri.parse("https://yjsy.zju.edu.cn/dataapi/py/pyKsxsxx/queryPageByXs"
            "?dm=py_grks&mode=2&role=1&column=createTime&order=desc"
            "&queryMode=1&field=id,,kcbh,kcmc,rq,ksTime,xn,xq_dictText,ksdd,zwh"
            "&pageNo=1&pageSize=100&xn=$year&xq=$semester");
    try {
      final result = await _fetchApi(httpClient, uri, context: context);
      _requireSuccess(result, context);
      return Tuple(null, _parseExams(result, year, context));
    } on Object catch (error, stackTrace) {
      return Tuple(
          exceptionFrom(error,
              context: context, requestUri: uri, stackTrace: stackTrace),
          <ExamDto>[]);
    }
  }

  List<ExamDto> _parseExams(
      Map<String, dynamic> result, int year, String context) {
    final directResult = asDynamicList(result["result"]);
    final resultMap = asStringMap(result["result"]);
    final rawExams =
        directResult ?? asDynamicList(resultMap?["records"]) ?? const [];
    final exams = <ExamDto>[];

    for (var index = 0; index < rawExams.length; index++) {
      final rawExam = asStringMap(rawExams[index]);
      if (rawExam == null) continue;
      try {
        if (asString(rawExam["xn"]) != year.toString()) continue;
        final courseCode = asString(rawExam["kcbh"]);
        if (courseCode == null || courseCode.length < 7) {
          throw const FormatException('缺少有效课程编号 kcbh');
        }
        final name = asString(rawExam["kcmc"]) ?? '未知课程';
        final day = _parseExamDay(rawExam["rq"]);
        final combinedTimes = RegExp(r'\d{1,2}\s*:\s*\d{2}')
            .allMatches(asString(rawExam["ksTime"]) ?? '')
            .map((match) => match.group(0))
            .whereType<String>()
            .toList();
        final start = _parseClock(
            rawExam["kssj"] ??
                (combinedTimes.isEmpty ? null : combinedTimes.first),
            fallback: 800);
        final end = _parseClock(
            rawExam["jssj"] ??
                (combinedTimes.length < 2 ? null : combinedTimes[1]),
            fallback: 2200);
        if (day == null) throw const FormatException('考试日期 rq 无效');

        final exam = Exam.empty()
          ..id = courseCode.substring(0, 7)
          ..name = name
          ..type = ExamType.finalExam
          ..location =
              asString(rawExam["mc"]) ?? asString(rawExam["ksdd"]) ?? "未知地点"
          ..seat = asString(rawExam["zwh"])
          ..time = [
            day.add(Duration(hours: start.$1, minutes: start.$2)),
            day.add(Duration(hours: end.$1, minutes: end.$2)),
          ];
        final dto = ExamDto.empty()
          ..id = exam.id
          ..name = name
          ..credit = 0.0
          ..exams.add(exam);
        exams.add(dto);
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
              '$context：跳过第 ${index + 1} 条考试：${error.runtimeType}: $error\n$stackTrace');
        }
      }
    }
    return exams;
  }

  DateTime? _parseExamDay(Object? value) {
    final digits = asString(value)?.replaceAll(RegExp(r'\D'), '');
    if (digits == null || digits.length < 8) return null;
    final raw = digits.substring(0, 8);
    return DateTime.tryParse(
        '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}');
  }

  (int, int) _parseClock(Object? value, {required int fallback}) {
    final text = asString(value) ?? '';
    final clockMatch = RegExp(r'(\d{1,2})\s*:\s*(\d{2})').firstMatch(text);
    if (clockMatch != null) {
      final hour = int.tryParse(clockMatch.group(1) ?? '');
      final minute = int.tryParse(clockMatch.group(2) ?? '');
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour <= 23 &&
          minute >= 0 &&
          minute <= 59) {
        return (hour, minute);
      }
    }
    final numeric = asInt(value) ?? fallback;
    final hour = numeric ~/ 100;
    final minute = numeric % 100;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return (fallback ~/ 100, fallback % 100);
    }
    return (hour, minute);
  }

  Future<void> _fetchCourseDetails(HttpClient httpClient, int year,
      int semester, List<Session> sessions) async {
    final sessionsByCourse = <String, List<Session>>{};
    for (final session in sessions) {
      final id = session.id;
      if (id != null && id.isNotEmpty) {
        sessionsByCourse.putIfAbsent(id, () => []).add(session);
      }
    }

    final semesterName = (semester == 11 || semester == 15) ? "春夏学期" : "秋冬学期";
    await Future.wait(sessionsByCourse.entries.map((entry) async {
      final courseSessions = entry.value;
      final teacherId = courseSessions.first.teacherId;
      if (teacherId == null || teacherId.isEmpty) return;
      final context = '研究生院课程详情接口（学年 $year，学期 $semester，课程 ${entry.key}）';
      try {
        final uri = Uri.https(
          'yjsy.zju.edu.cn',
          '/dataapi/py/pyKcbj/queryKcbjDetailInfoPage',
          {
            'xns': year.toString(),
            'xqMc': semesterName,
            'kcbh': entry.key,
            'kcmc': courseSessions.first.name,
            'zjjsJzgId': teacherId,
          },
        );
        final result = await _fetchApi(httpClient, uri, context: context);
        _requireSuccess(result, context);
        _applyCourseDetails(result, courseSessions, context);
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
              '$context：保留课表中的原始字段：${error.runtimeType}: $error\n$stackTrace');
        }
      }
    }));
  }

  void _applyCourseDetails(Map<String, dynamic> result,
      List<Session> courseSessions, String context) {
    final resultMap = asStringMap(result["result"]);
    final records = asDynamicList(resultMap?["records"]);
    if (records == null || records.isEmpty) return;
    final detail = asStringMap(records.first);
    if (detail == null) {
      debugPrint('$context：详情 records[0] 不是对象');
      return;
    }

    final credit = asDouble(detail["xf"]);
    final comments = asString(detail["bz"]);
    final courseType = asString(detail["kcxzDm_dictText"]);
    for (final session in courseSessions) {
      if (credit != null) session.credit = credit;
      if (comments != null) {
        session.online = comments.contains("线上") ||
            comments.contains("录播") ||
            comments.contains("直播");
      }
      if (courseType != null) session.type = courseType;
    }
  }

  Future<Tuple<Exception?, Iterable<Session>>> getTimetable(
      HttpClient httpClient, int year, int semester) async {
    final context = '研究生院课表接口（学年 $year，学期 $semester，请求类型 课表）';
    final uri = Uri.parse(
        "https://yjsy.zju.edu.cn/dataapi/py/pyKcbj/queryXskbByLoginUser"
        "?xn=$year&pkxq=$semester");
    try {
      final result = await _fetchApi(httpClient, uri, context: context);
      _requireSuccess(result, context);
      final sessions = _parseTimetable(result, semester, context);
      await _fetchCourseDetails(httpClient, year, semester, sessions);
      return Tuple(null, sessions);
    } on Object catch (error, stackTrace) {
      return Tuple(
          exceptionFrom(error,
              context: context, requestUri: uri, stackTrace: stackTrace),
          <Session>[]);
    }
  }

  List<Session> _parseTimetable(
      Map<String, dynamic> result, int semester, String context) {
    final resultMap = asStringMap(result["result"]);
    final dayWithClasses = asStringMap(resultMap?["kcbMap"]);
    if (dayWithClasses == null) {
      throw ExceptionWithMessage('$context：返回数据缺少 result.kcbMap 对象');
    }

    final sessions = <Session>[];
    for (var day = 1; day <= 7; day++) {
      final classesThisDay = asStringMap(dayWithClasses["$day"]);
      if (classesThisDay == null) continue;
      final sessionsThisDay = <String, Session>{};
      for (var period = 1; period <= 15; period++) {
        final wrapper = asStringMap(classesThisDay["$period"]);
        final classes = asDynamicList(wrapper?["pyKcbjSjddVOList"]) ?? const [];
        for (var index = 0; index < classes.length; index++) {
          final rawClass = asStringMap(classes[index]);
          if (rawClass == null) continue;
          try {
            final classId = asString(rawClass["bjbh"]);
            if (classId == null || classId.length < 7) {
              throw const FormatException('缺少有效班级编号 bjbh');
            }
            final existing = sessionsThisDay[classId];
            if (existing != null) {
              if (!existing.time.contains(period)) existing.time.add(period);
              continue;
            }
            if (asString(rawClass["xkzt"]) == "12") continue;

            final classSemester = asInt(rawClass["pkxq"]) ?? semester;
            final session = Session.empty()
              ..id = classId.substring(0, 7)
              ..name = asString(rawClass["kcmc"]) ?? '未知课程'
              ..teacher = asString(rawClass["xm"]) ?? '未知教师'
              ..teacherId = asString(rawClass["jzgId"])
              ..location = asString(rawClass["cdmc"])
              ..confirmed = true
              ..dayOfWeek = day
              ..time = [period];

            if (semester == 11 || semester == 13) {
              session.firstHalf = true;
            } else {
              session.secondHalf = true;
            }
            if (classSemester == 15 || classSemester == 16) {
              session.firstHalf = session.secondHalf = true;
            }

            final weeks = _parseWeeks(asString(rawClass["zc"]) ?? '');
            if (weeks.isEmpty) {
              session.oddWeek = session.evenWeek = true;
            } else {
              session
                ..customRepeat = true
                ..customRepeatWeeks = weeks;
              final threshold =
                  (session.firstHalf && session.secondHalf) ? 8 : 4;
              if (weeks.length > threshold) {
                session.oddWeek = session.evenWeek = true;
              } else {
                final oddCount = weeks.where((week) => week.isOdd).length;
                if (oddCount > weeks.length / 2) {
                  session.oddWeek = true;
                } else {
                  session.evenWeek = true;
                }
              }
            }
            sessionsThisDay[classId] = session;
          } on Object catch (error, stackTrace) {
            if (kDebugMode) {
              debugPrint('$context：跳过星期 $day 第 $period 节的第 ${index + 1} 条课程：'
                  '${error.runtimeType}: $error\n$stackTrace');
            }
          }
        }
      }
      sessions.addAll(sessionsThisDay.values);
    }
    return sessions;
  }

  List<int> _parseWeeks(String raw) {
    final weeks = <int>{};
    final rangePattern = RegExp(r'(\d+)\s*[-~至]\s*(\d+)');
    for (final match in rangePattern.allMatches(raw)) {
      final start = int.tryParse(match.group(1) ?? '');
      final end = int.tryParse(match.group(2) ?? '');
      if (start == null || end == null || start > end || end > 30) continue;
      weeks.addAll(List<int>.generate(end - start + 1, (i) => start + i));
    }
    final withoutRanges = raw.replaceAll(rangePattern, ' ');
    for (final match in RegExp(r'\d+').allMatches(withoutRanges)) {
      final week = int.tryParse(match.group(0) ?? '');
      if (week != null && week > 0 && week <= 30) weeks.add(week);
    }
    final result = weeks.toList()..sort();
    return result;
  }
}
