import 'dart:async';
import 'dart:io';

import 'package:celechron/http/spider.dart';
import 'package:celechron/http/calendar_config_parser.dart';
import 'package:celechron/http/time_config_service.dart';
import 'package:celechron/http/zjuServices/courses.dart';
import 'package:celechron/http/zjuServices/grs_new.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/model/todo.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/grade.dart';
import 'package:celechron/model/semester.dart';
// import 'zjuServices/appservice.dart';
import 'zjuServices/zjuam.dart';
import 'zjuServices/zdbk.dart';

class GrsSpider implements Spider {
  late HttpClient _httpClient;
  late String _username;
  late String _password;
  // late AppService _appService;
  late Zdbk _zdbk;
  late GrsNew _grsNew;
  late Courses _courses;
  late TimeConfigService _timeConfigService;
  DateTime _lastUpdateTime = DateTime(0);
  Future<List<String?>>? _reloginFuture;
  int _loginGeneration = 0;
  static List<String> fetchSequenceGrs = [
    '校历',
    '课表',
    '本科生课考试',
    '本科生课成绩',
    '研究生课考试',
    '研究生课成绩',
    '作业'
  ];

  GrsSpider(String username, String password) {
    _httpClient = _createHttpClient();
    // _appService = AppService();
    _courses = Courses();
    _zdbk = Zdbk();
    _grsNew = GrsNew();
    _timeConfigService = TimeConfigService();
    _username = username;
    _password = password;
  }

  HttpClient _createHttpClient() {
    final client = HttpClient();
    client.userAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.63";
    return client;
  }

  @override
  set db(DatabaseHelper? db) {
    // _appService.db = db;
    _courses.db = db;
    _zdbk.db = db;
    _grsNew.db = db;
    _timeConfigService.db = db;
  }

  @override
  Future<List<String?>> login() async {
    if (_reloginFuture != null) {
      return await _reloginFuture!;
    }

    _reloginFuture = _doLogin();
    try {
      return await _reloginFuture!;
    } finally {
      _reloginFuture = null;
    }
  }

  Future<List<String?>> _doLogin() async {
    final previousClient = _httpClient;
    final candidateClient = _createHttpClient();

    var loginErrorMessages = <String?>[null];
    final candidateSsoCookie =
        await ZjuAm.getSsoCookie(candidateClient, _username, _password)
            .timeout(const Duration(seconds: 8))
            .catchError((Object error, StackTrace stackTrace) {
      loginErrorMessages[0] = exceptionFrom(
        error,
        context: "无法登录统一身份认证",
        stackTrace: stackTrace,
      ).toString();
      return null;
    });
    if (candidateSsoCookie == null) {
      candidateClient.close(force: true);
      return loginErrorMessages;
    }
    Future<String?> captureLogin(Future<dynamic> future, String serviceName,
        {bool ignoreError = false}) async {
      try {
        await future.timeout(const Duration(seconds: 8));
        return null;
      } on Object catch (error, stackTrace) {
        return ignoreError
            ? null
            : exceptionFrom(
                error,
                context: "无法登录$serviceName",
                stackTrace: stackTrace,
              ).toString();
      }
    }

    loginErrorMessages.addAll(await Future.wait<String?>([
      captureLogin(_grsNew.login(candidateClient, candidateSsoCookie), "研究生院网"),
      captureLogin(_courses.login(candidateClient, candidateSsoCookie), "学在浙大"),
      /* _appService
                    .login(_httpClient, _iPlanetDirectoryPro)
                    // ignore: unnecessary_cast
                    .then<String?>((value) => null)
                    .timeout(const Duration(seconds: 8))
                    .catchError((e) => "无法登录钉钉工作台，$e"), */
      captureLogin(_zdbk.login(candidateClient, candidateSsoCookie), "教务网",
          ignoreError: true),
    ]).then((value) {
      if (value.every((e) => e == null)) _lastUpdateTime = DateTime.now();
      return value;
    }));
    _httpClient = candidateClient;
    _loginGeneration++;
    previousClient.close();
    return loginErrorMessages;
  }

  @override
  void logout() {
    unawaited(ZjuAm.clearCachedSsoCookie(_username));
    _username = "";
    _password = "";
    try {
      _httpClient.close(force: true);
    } catch (_) {}
    // _appService.logout();
    _zdbk.logout();
    _grsNew.logout();
    _courses.logout();
  }

  // ===== 新增开始 =====
  // 自动重试机制：遇到Cookie过期等错误时，自动重新登录再重试
  Future<T> _fetchWithRetry<T>(Future<T> Function() requestFactory,
      {int maxRetries = 1}) async {
    int attempts = 0;
    while (true) {
      final requestLoginGeneration = _loginGeneration;
      try {
        var result = await requestFactory();

        // 检查返回结果中是否隐藏了错误
        bool hasHiddenError = false;
        dynamic hiddenErrorToThrow;
        try {
          dynamic res = result;
          if (res != null && res.item1 != null) {
            String errStr = res.item1.toString().toLowerCase();
            if (errStr.contains("connection closed") ||
                errStr.contains("httpexception") ||
                errStr.contains("请求超时") ||
                errStr.contains("网络错误") ||
                errStr.contains("未登录") ||
                errStr.contains("超时") ||
                errStr.contains("timeout") ||
                errStr.contains("type 'null'") ||
                errStr.contains("iplanetdirectorypro无效") ||
                errStr.contains("会话已过期") ||
                errStr.contains("登录态已失效") ||
                errStr.contains("token 已过期")) {
              hasHiddenError = true;
              hiddenErrorToThrow = res.item1;
            }
          }
        } catch (_) {}

        if (hasHiddenError) {
          throw hiddenErrorToThrow;
        }

        return result;
      } on Object catch (error, stackTrace) {
        attempts++;
        String errStr = error.toString().toLowerCase();

        final alreadyRelogged =
            errStr.contains("执行过重新登录：是") || errStr.contains("手动重新登录");
        final authenticationError = !alreadyRelogged &&
            (error is AuthenticationExpiredException ||
                error is SessionExpiredException ||
                errStr.contains("未登录") ||
                errStr.contains("登录态已失效") ||
                errStr.contains("会话已过期") ||
                errStr.contains("token 已过期") ||
                errStr.contains("iplanetdirectorypro无效"));
        final transientError = errStr.contains("connection closed") ||
            errStr.contains("timeout") ||
            errStr.contains("超时") ||
            errStr.contains("httpexception") ||
            errStr.contains("网络错误") ||
            errStr.contains("socketexception");
        if (attempts <= maxRetries && authenticationError) {
          if (_loginGeneration == requestLoginGeneration) {
            final loginErrors = await login();
            if (loginErrors.any((error) => error != null)) rethrow;
          }
          await Future.delayed(const Duration(milliseconds: 300));
          continue;
        }
        if (attempts <= maxRetries && transientError) {
          await Future.delayed(const Duration(milliseconds: 300));
          continue;
        }
        if (kDebugMode) {
          debugPrint('刷新请求失败：${error.runtimeType}: $error\n$stackTrace');
        }
        rethrow;
      }
    }
  }

  String _describeRefreshFailure(
    Object error,
    StackTrace stackTrace, {
    String? source,
  }) {
    if (kDebugMode) {
      debugPrint(
          '${source ?? '刷新任务'}失败：${error.runtimeType}: ${redactSensitive(error.toString())}\n$stackTrace');
    }
    return source == null ? error.toString() : '$source $error';
  }
  // ===== 新增结束 =====

  // 返回一堆错误信息，如果有的话。看看返回的List是不是空的就知道刷新是否成功。
  @override
  Future<
      Tuple7<
          List<String?>,
          List<String?>,
          List<Semester>,
          List<Grade>,
          List<double>,
          Map<DateTime, String>,
          List<Todo>>> getEverything() async {
    // 返回值初始化
    var outSemesters = <Semester>[];
    var outGrades = <Grade>[];
    var outMajorGrade = <double>[];
    var outSpecialDates = <DateTime, String>{};
    var outTodos = <Todo>[];
    var loginErrorMessages = <String?>[null, null, null];

    // 如果Cookie过期了，就重新登录
    if (DateTime.now().difference(_lastUpdateTime).inMinutes > 15) {
      loginErrorMessages = await login();
    }

    // 建立学期编号与“入学以来第几个学期”的映射。如"2022-2023-1"对应第22年入学同学的第1个学期，即"2022-2023秋冬"。
    var yearNow = DateTime.now().year;
    final enrollmentDigits =
        _username.length >= 3 ? _username.substring(1, 3) : '';
    final parsedEnrollmentYear = int.tryParse(enrollmentDigits);
    if (parsedEnrollmentYear == null) {
      return Tuple7(loginErrorMessages, <String?>['无法解析学号中的入学年份：$_username'],
          outSemesters, outGrades, outMajorGrade, outSpecialDates, outTodos);
    }
    var yearEnroll = parsedEnrollmentYear + 2000;
    // 假设研究生在本科时提前两年选了研究生的课
    yearEnroll -= 2;
    // 岩壁加起来7年+本科2年
    var yearGraduate = yearEnroll + 9;
    Map<String, int> semesterIndexMap = <String, int>{};
    for (var i = 9, j = 0; i >= 0; i--, j++) {
      semesterIndexMap.addEntries(
          [MapEntry('${yearEnroll + i}-${yearEnroll + i + 1}-2', j * 2)]);
      semesterIndexMap.addEntries(
          [MapEntry('${yearEnroll + i}-${yearEnroll + i + 1}-1', j * 2 + 1)]);
      outSemesters.add(Semester('${yearEnroll + i}-${yearEnroll + i + 1}春夏'));
      outSemesters.add(Semester('${yearEnroll + i}-${yearEnroll + i + 1}秋冬'));
    }

    // 查校历（存在CDN上，JSON格式的，内含学期起止日期、单日时间表、放假调休等信息）
    var semesterConfigFetches = <Future<String?>>[];
    // 查课表
    var timetableFetches = <Future<String?>>[];
    var cancelTimetableFetch = false;
    // 查考试（暂时只有研究生使用，本科生是一下子拿完所有的）
    var examFetches = <Future<String?>>[];

    while (yearEnroll <= yearNow && yearEnroll <= yearGraduate) {
      var yearStr = '$yearEnroll-${yearEnroll + 1}';
      semesterConfigFetches.add(_timeConfigService
          .getConfig(_httpClient, '$yearStr-1')
          .then((value) {
        if (value.item2 != null) {
          applyCalendarConfig(
            value.item2!,
            outSemesters[semesterIndexMap['$yearStr-1']!],
            outSpecialDates,
            context: '校历（学年学期 $yearStr-1）',
          );
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
              _describeRefreshFailure(error, stackTrace,
                  source: 'semesterConf($yearStr-1)')));
      semesterConfigFetches.add(_timeConfigService
          .getConfig(_httpClient, '$yearStr-2')
          .then((value) {
        if (value.item2 != null) {
          applyCalendarConfig(
            value.item2!,
            outSemesters[semesterIndexMap['$yearStr-2']!],
            outSpecialDates,
            context: '校历（学年学期 $yearStr-2）',
          );
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
              _describeRefreshFailure(error, stackTrace,
                  source: 'semesterConf($yearStr-2)')));

      // 查考试
      /*examFetches
          .add(_appService.getExamsDto(_httpClient, yearStr, "1").then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap[e.id.substring(1, 12)]!].addExam(e);
        }
        return value.item1?.toString();
      }).catchError((e) => e.toString()));
      examFetches
          .add(_appService.getExamsDto(_httpClient, yearStr, "2").then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap[e.id.substring(1, 12)]!].addExam(e);
        }
        return value.item1?.toString();
      }).catchError((e) => e.toString()));*/

      // 本科生课
      Future<String?> handleTimetable(season) async {
        if (cancelTimetableFetch) {
          return Future.value("已取消");
        }
        try {
          var value = await _fetchWithRetry(
              () => _zdbk.getTimetable(_httpClient, yearStr, season));
          var semKey = season.startsWith('1') ? '$yearStr-1' : '$yearStr-2';
          var sessions = value.item2.toList();
          sessions.sort((a, b) {
            if (a.dayOfWeek != b.dayOfWeek) {
              return a.dayOfWeek.compareTo(b.dayOfWeek);
            } else {
              return a.time.first.compareTo(b.time.first);
            }
          });
          for (var e in sessions) {
            outSemesters[semesterIndexMap[semKey]!].addSession(e, semKey);
          }
          if (value.item1.toString().contains("验证码")) {
            cancelTimetableFetch = true;
          }
          return Future.value(value.item1?.toString());
        } on Object catch (error, stackTrace) {
          return Future.value(
              _describeRefreshFailure(error, stackTrace, source: '课表'));
        }
      }

      for (var season in ['1|秋', '1|冬', '2|春', '2|夏']) {
        if (timetableFetches.isEmpty) {
          timetableFetches.add(handleTimetable(season));
        } else {
          timetableFetches.first = timetableFetches.first.then((value) async {
            var res = await handleTimetable(season);
            return value ?? res;
          });
        }
      }

      // 研究生课
      timetableFetches.add(_fetchWithRetry(
              () => _grsNew.getTimetable(_httpClient, yearEnroll, 13))
          .then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-1']!]
              .addSession(e, '$yearStr-1', true);
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
              _describeRefreshFailure(error, stackTrace,
                  source: 'grsNew($yearStr-1, 13)')));
      timetableFetches.add(_fetchWithRetry(
              () => _grsNew.getTimetable(_httpClient, yearEnroll, 14))
          .then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-1']!]
              .addSession(e, '$yearStr-1', true);
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
              _describeRefreshFailure(error, stackTrace,
                  source: 'grsNew($yearStr-1, 14)')));
      timetableFetches.add(_fetchWithRetry(
              () => _grsNew.getTimetable(_httpClient, yearEnroll, 11))
          .then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-2']!]
              .addSession(e, '$yearStr-2', true);
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
              _describeRefreshFailure(error, stackTrace,
                  source: 'grsNew($yearStr-2, 11)')));
      timetableFetches.add(_fetchWithRetry(
              () => _grsNew.getTimetable(_httpClient, yearEnroll, 12))
          .then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-2']!]
              .addSession(e, '$yearStr-2', true);
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
              _describeRefreshFailure(error, stackTrace,
                  source: 'grsNew($yearStr-2, 12)')));

      // 研究生课考试
      examFetches.add(_fetchWithRetry(
          () => _grsNew.getExamsDto(_httpClient, yearEnroll, 12)).then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-1']!]
              .addExamWithSemester(e, '$yearStr-1');
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
          _describeRefreshFailure(error, stackTrace,
              source: 'grsExam($yearStr-1)')));
      examFetches.add(_fetchWithRetry(
          () => _grsNew.getExamsDto(_httpClient, yearEnroll, 11)).then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$yearStr-2']!]
              .addExamWithSemester(e, '$yearStr-2');
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
          _describeRefreshFailure(error, stackTrace,
              source: 'grsExam($yearStr-2)')));
      yearEnroll++;
    }

    // 把 五个任务分别加入 请求列表 。
    var fetches = <Future<String?>>[];
    // 配置
    fetches.add(Future.wait(semesterConfigFetches)
        .then((value) => value.firstWhereOrNull((e) => e != null)));
    // 课表
    fetches.add(Future.wait(timetableFetches)
        .then((value) => value.firstWhereOrNull((e) => e != null)));

    // 本科生课考试
    fetches.add(_fetchWithRetry(() => _zdbk.getExamsDto(_httpClient))
        .then((value) {
      for (var e in value.item2) {
        try {
          final index = semesterIndexMap[e.semesterId];
          if (index == null) {
            throw FormatException('考试学期不在刷新范围：${e.semesterId}');
          }
          outSemesters[index].addExam(e);
        } on Object catch (error, stackTrace) {
          if (kDebugMode) {
            debugPrint(
                '跳过无法归入学期的考试 ${e.id}：${error.runtimeType}: $error\n$stackTrace');
          }
        }
      }
      return value.item1?.toString();
    }).catchError((Object error, StackTrace stackTrace) =>
            _describeRefreshFailure(error, stackTrace, source: 'zdbkExam')));

    // 查成绩
    fetches.add(_fetchWithRetry(() => _zdbk.getTranscript(_httpClient))
        .then((value) {
      for (var e in value.item2) {
        try {
          final index = semesterIndexMap[e.semesterId];
          if (index == null) {
            throw FormatException('成绩学期不在刷新范围：${e.semesterId}');
          }
          outSemesters[index].addGrade(e);
          outGrades.add(e);
        } on Object catch (error, stackTrace) {
          if (kDebugMode) {
            debugPrint(
                '跳过无法归入学期的成绩 ${e.id}：${error.runtimeType}: $error\n$stackTrace');
          }
        }
      }
      return value.item1?.toString();
    }).catchError((Object error, StackTrace stackTrace) =>
            _describeRefreshFailure(error, stackTrace, source: 'zdbkGrade')));

    // 研究生课考试
    fetches.add(Future.wait(examFetches)
        .then((value) => value.firstWhereOrNull((e) => e != null)));

    // 研究生课成绩
    fetches.add(_fetchWithRetry(() => _grsNew.getGrade(_httpClient))
        .then((value) {
      for (var e in value.item2) {
        try {
          if (e.id.length < 6) throw const FormatException('缺少学期信息');
          final year = int.tryParse(e.id.substring(0, 4));
          if (year == null) throw const FormatException('学年格式无效');
          String semesterStr;
          if (e.id.contains("春学") ||
              e.id.contains("夏学") ||
              e.id.contains("春夏学")) {
            semesterStr = "-2";
          } else if (e.id.contains("秋学") ||
              e.id.contains("冬学") ||
              e.id.contains("秋冬学")) {
            semesterStr = "-1";
          } else {
            throw const FormatException('缺少学期名称');
          }
          final yearStr = '$year-${year + 1}$semesterStr';
          final classId = RegExp(r'班级编号(\d{7})').firstMatch(e.id)?.group(1);
          final index = semesterIndexMap[yearStr];
          if (classId == null || index == null) {
            throw FormatException('班级编号或学期映射缺失：$yearStr');
          }
          e.id = classId;
          outSemesters[index].addGradeWithSemester(e, yearStr, true);
        } on Object catch (error, stackTrace) {
          if (kDebugMode) {
            debugPrint(
                '跳过无法归入学期的研究生成绩 ${e.id}：${error.runtimeType}: $error\n$stackTrace');
          }
        }
      }
      return value.item1?.toString();
    }).catchError((Object error, StackTrace stackTrace) =>
            _describeRefreshFailure(error, stackTrace, source: 'grsGrade')));

    // 学在浙大
    fetches.add(_fetchWithRetry(() => _courses.getTodo(_httpClient))
        .then((value) {
      outTodos.clear();
      outTodos.addAll(value.item2);
      return value.item1?.toString();
    }).catchError((Object error, StackTrace stackTrace) =>
            _describeRefreshFailure(error, stackTrace, source: 'coursesTodo')));

    // await一下，等待所有请求完成。然后，删除不包含考试、成绩、课程的空学期
    var fetchErrorMessages = await Future.wait(fetches).whenComplete(() {
      outSemesters.removeWhere((e) =>
          e.grades.isEmpty &&
          e.sessions.isEmpty &&
          e.exams.isEmpty &&
          e.courses.isEmpty);
    });

    // 检查是否有查询失败的情况
    if (fetchErrorMessages.every((e) => e == null)) {
      _lastUpdateTime = DateTime.now();
    }
    for (var i = 0; i < fetchErrorMessages.length; i++) {
      if (fetchErrorMessages[i] != null) {
        fetchErrorMessages[i] =
            '${fetchSequenceGrs[i]}查询出错：${fetchErrorMessages[i]}';
      }
    }

    for (var semester in outSemesters) {
      var toRemove = semester.courses.keys.toList();
      var toAdd = semester.courses.values
          .map((e) => MapEntry(e.id ?? e.name + e.toString(), e))
          .toList();
      semester.courses.addEntries(toAdd);
      for (var key in toRemove) {
        semester.courses.remove(key);
      }
    }

    return Tuple7(loginErrorMessages, fetchErrorMessages, outSemesters,
        outGrades, outMajorGrade, outSpecialDates, outTodos);
  }
}
