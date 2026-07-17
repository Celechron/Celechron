import 'dart:async';
import 'dart:io';

import 'package:celechron/http/retry_helper.dart';
import 'package:celechron/http/spider.dart';
import 'package:celechron/http/calendar_config_parser.dart';
import 'package:celechron/http/data_source_status.dart';
import 'package:celechron/http/time_config_service.dart';
import 'package:celechron/http/zjuServices/courses.dart';
import 'package:celechron/http/zjuServices/grs_new.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/model/todo.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:celechron/services/diagnostic_log_service.dart';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/grade.dart';
import 'package:celechron/model/semester.dart';
// import 'zjuServices/appservice.dart';
import 'zjuServices/zjuam.dart';
import 'zjuServices/zdbk.dart';

/// 研究生完整刷新编排器，同时兼容研究生院课程与已选本科课程。
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
  static const _retryableFetchErrors = <String>[
    "iplanetdirectorypro无效",
    "会话已过期",
    "登录态已失效",
    "token 已过期",
  ];

  /// getEverything 内各顶层抓取任务的标签，与抓取错误列表下标一一对应
  static const List<String> fetchSequenceGrs = [
    '校历',
    '课表',
    '本科生课考试',
    '本科生课成绩',
    '研究生课考试',
    '研究生课成绩',
    '作业'
  ];

  @override
  List<String> get fetchLabels => fetchSequenceGrs;

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
    // TCP/TLS 建连快速失败；已建立连接仍由各接口的总超时兜底。
    client.connectionTimeout = const Duration(seconds: 5);
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

  Future<List<String?>> _doLogin({bool retryOnSsoRejection = true}) async {
    // 候选客户端完成各子站登录后再替换，避免失败登录污染旧会话。
    final previousClient = _httpClient;
    final candidateClient = _createHttpClient();

    var loginErrorMessages = <String?>[null];
    final candidateSsoCookie =
        await ZjuAm.getSsoCookie(candidateClient, _username, _password)
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
        await future;
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

    final serviceErrors = await Future.wait<String?>([
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
    ]);
    loginErrorMessages.addAll(serviceErrors);

    final ssoRejected = serviceErrors.whereType<String>().any((error) {
      final normalized = error.toLowerCase();
      return normalized.contains('未获得 cas ticket') ||
          normalized.contains('登录态失效') ||
          normalized.contains('统一身份认证凭据无效');
    });
    if (retryOnSsoRejection && ssoRejected) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: '研究生登录',
        operation: 'retryFreshSso',
        message: '子站拒绝了本轮 SSO，使用全新密码会话重试一次',
        retried: true,
      );
      candidateClient.close(force: true);
      return _doLogin(retryOnSsoRejection: false);
    }

    if (serviceErrors.every((error) => error == null)) {
      _lastUpdateTime = DateTime.now();
    }
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
    } on Object catch (error, stackTrace) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: '研究生刷新',
        operation: 'closeHttpClient',
        error: error,
        stackTrace: stackTrace,
      );
    }
    // _appService.logout();
    _courses.logout();
    _zdbk.logout();
    _grsNew.logout();
  }

  // 自动重试机制：遇到Cookie过期等错误时，自动重新登录再重试
  Future<T> _fetchWithRetry<T>(Future<T> Function() requestFactory,
      {int maxRetries = 1}) async {
    int attempts = 0;
    while (true) {
      final requestLoginGeneration = _loginGeneration;
      T? fallbackResult;
      try {
        var result = await requestFactory();
        fallbackResult = result;
        final hiddenError = getRetryableTupleError(
          result,
          extraMessages: _retryableFetchErrors,
        );

        if (hiddenError != null) {
          throw hiddenError;
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
          // generation 用来复用其它并发请求刚完成的重新登录。
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
        if (fallbackResult != null) return fallbackResult;
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

  // 返回一堆错误信息，如果有的话。看看返回的List是不是空的就知道刷新是否成功。
  @override
  Future<EverythingTuple> getEverything(
      {void Function(EverythingTuple partial)? onProgress}) async {
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
    final now = DateTime.now();
    var currentAcademicYearStart = academicYearStartFor(now);
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
    var calendarLive = 0;
    var calendarCache = 0;
    var calendarFallback = 0;
    // 查课表
    var timetableFetches = <Future<String?>>[];
    var cancelTimetableFetch = false;
    // 查考试（暂时只有研究生使用，本科生是一下子拿完所有的）
    var examFetches = <Future<String?>>[];

    while (
        yearEnroll <= currentAcademicYearStart && yearEnroll <= yearGraduate) {
      var queryAcademicYear = '$yearEnroll-${yearEnroll + 1}';
      semesterConfigFetches.add(_timeConfigService
          .getConfig(_httpClient, '$queryAcademicYear-1')
          .then((value) {
        switch (value.item3) {
          case DataSourceStatus.live:
            calendarLive++;
          case DataSourceStatus.cache:
            calendarCache++;
          case DataSourceStatus.fallback:
            calendarFallback++;
          case DataSourceStatus.unavailable:
            break;
        }
        if (value.item2 != null) {
          applyCalendarConfig(
            value.item2!,
            outSemesters[semesterIndexMap['$queryAcademicYear-1']!],
            outSpecialDates,
            context: '校历（学年学期 $queryAcademicYear-1）',
          );
        }
        if (value.item3.isDegraded) {
          return degradedRefreshText(
            '校历（$queryAcademicYear-1）：${value.item3.label}',
            details:
                value.item1 == null ? null : detailedErrorText(value.item1),
          );
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
              _describeRefreshFailure(error, stackTrace,
                  source: 'semesterConf($queryAcademicYear-1)')));
      semesterConfigFetches.add(_timeConfigService
          .getConfig(_httpClient, '$queryAcademicYear-2')
          .then((value) {
        switch (value.item3) {
          case DataSourceStatus.live:
            calendarLive++;
          case DataSourceStatus.cache:
            calendarCache++;
          case DataSourceStatus.fallback:
            calendarFallback++;
          case DataSourceStatus.unavailable:
            break;
        }
        if (value.item2 != null) {
          applyCalendarConfig(
            value.item2!,
            outSemesters[semesterIndexMap['$queryAcademicYear-2']!],
            outSpecialDates,
            context: '校历（学年学期 $queryAcademicYear-2）',
          );
        }
        if (value.item3.isDegraded) {
          return degradedRefreshText(
            '校历（$queryAcademicYear-2）：${value.item3.label}',
            details:
                value.item1 == null ? null : detailedErrorText(value.item1),
          );
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
              _describeRefreshFailure(error, stackTrace,
                  source: 'semesterConf($queryAcademicYear-2)')));

      // 查考试
      /*examFetches
          .add(_appService.getExamsDto(_httpClient, queryAcademicYear, "1").then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap[e.id.substring(1, 12)]!].addExam(e);
        }
        return value.item1?.toString();
      }).catchError((e) => e.toString()));
      examFetches
          .add(_appService.getExamsDto(_httpClient, queryAcademicYear, "2").then((value) {
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
              () => _zdbk.getTimetable(_httpClient, queryAcademicYear, season));
          var semKey = season.startsWith('1')
              ? '$queryAcademicYear-1'
              : '$queryAcademicYear-2';
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
          outSemesters[semesterIndexMap['$queryAcademicYear-1']!]
              .addSession(e, '$queryAcademicYear-1', true);
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
              _describeRefreshFailure(error, stackTrace,
                  source: 'grsNew($queryAcademicYear-1, 13)')));
      timetableFetches.add(_fetchWithRetry(
              () => _grsNew.getTimetable(_httpClient, yearEnroll, 14))
          .then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$queryAcademicYear-1']!]
              .addSession(e, '$queryAcademicYear-1', true);
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
              _describeRefreshFailure(error, stackTrace,
                  source: 'grsNew($queryAcademicYear-1, 14)')));
      timetableFetches.add(_fetchWithRetry(
              () => _grsNew.getTimetable(_httpClient, yearEnroll, 11))
          .then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$queryAcademicYear-2']!]
              .addSession(e, '$queryAcademicYear-2', true);
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
              _describeRefreshFailure(error, stackTrace,
                  source: 'grsNew($queryAcademicYear-2, 11)')));
      timetableFetches.add(_fetchWithRetry(
              () => _grsNew.getTimetable(_httpClient, yearEnroll, 12))
          .then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$queryAcademicYear-2']!]
              .addSession(e, '$queryAcademicYear-2', true);
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
              _describeRefreshFailure(error, stackTrace,
                  source: 'grsNew($queryAcademicYear-2, 12)')));

      // 研究生课考试
      examFetches.add(_fetchWithRetry(
          () => _grsNew.getExamsDto(_httpClient, yearEnroll, 12)).then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$queryAcademicYear-1']!]
              .addExamWithSemester(e, '$queryAcademicYear-1');
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
          _describeRefreshFailure(error, stackTrace,
              source: 'grsExam($queryAcademicYear-1)')));
      examFetches.add(_fetchWithRetry(
          () => _grsNew.getExamsDto(_httpClient, yearEnroll, 11)).then((value) {
        for (var e in value.item2) {
          outSemesters[semesterIndexMap['$queryAcademicYear-2']!]
              .addExamWithSemester(e, '$queryAcademicYear-2');
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
          _describeRefreshFailure(error, stackTrace,
              source: 'grsExam($queryAcademicYear-2)')));
      yearEnroll++;
    }

    // 把 五个任务分别加入 请求列表 。
    var fetches = <Future<String?>>[];
    // 配置
    fetches.add(Future.wait(semesterConfigFetches).then((value) {
      final failure = value.firstWhereOrNull(
          (error) => error != null && !isDegradedRefreshText(error));
      if (failure != null) return failure;
      if (calendarCache > 0 || calendarFallback > 0) {
        return degradedRefreshText(
          '校历：$calendarLive 个远程成功，$calendarCache 个缓存降级，'
          '$calendarFallback 个默认配置',
        );
      }
      return null;
    }));
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
          final queryAcademicYear = '$year-${year + 1}$semesterStr';
          final classId = RegExp(r'班级编号(\d{7})').firstMatch(e.id)?.group(1);
          final index = semesterIndexMap[queryAcademicYear];
          if (classId == null || index == null) {
            throw FormatException('班级编号或学期映射缺失：$queryAcademicYear');
          }
          e.id = classId;
          outSemesters[index].addGradeWithSemester(e, queryAcademicYear, true);
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
      if (value.item3 == DataSourceStatus.cache) {
        return degradedRefreshText(
          '作业：使用缓存，${value.item2.length} 条',
          details: value.item1 == null ? null : detailedErrorText(value.item1),
        );
      }
      return value.item1?.toString();
    }).catchError((Object error, StackTrace stackTrace) =>
            _describeRefreshFailure(error, stackTrace, source: 'coursesTodo')));

    // 异步刷新：每完成一个顶层任务就向上层回调一次当前进度。
    // 配置(0)、课表(1)、本科生课考试(2)、本科生课成绩(3)、研究生课考试(4)、
    // 研究生课成绩(5)共同拼出学期数据，全部成功后才暴露学期
    if (onProgress != null) {
      attachEverythingProgress(
          fetches: fetches,
          fetchSequence: fetchSequenceGrs,
          semesterFetchIndices: const [0, 1, 2, 3, 4, 5],
          loginErrorMessages: loginErrorMessages,
          semesters: outSemesters,
          grades: outGrades,
          majorGrade: outMajorGrade,
          specialDates: outSpecialDates,
          todos: outTodos,
          onProgress: onProgress);
    }

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
        final message = fetchErrorMessages[i]!;
        fetchErrorMessages[i] = isDegradedRefreshText(message)
            ? degradedRefreshText(
                '${fetchSequenceGrs[i]}：${shortErrorText(message)}',
                details: detailedErrorText(message),
              )
            : '${fetchSequenceGrs[i]}查询出错：$message';
      }
      DiagnosticLogService.instance.setModuleResult(
        fetchSequenceGrs[i],
        fetchErrorMessages[i] == null
            ? fetchSequenceGrs[i] == '校历'
                ? '$calendarLive 个远程成功'
                : fetchSequenceGrs[i] == '作业'
                    ? '实时成功，${outTodos.length} 条'
                    : '实时成功'
            : isDegradedRefreshText(fetchErrorMessages[i])
                ? shortErrorText(fetchErrorMessages[i])
                : '失败：${shortErrorText(fetchErrorMessages[i])}',
      );
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
