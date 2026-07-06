import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:celechron/http/zjuServices/courses.dart';
import 'package:celechron/http/calendar_config_parser.dart';
import 'package:celechron/http/data_source_status.dart';
import 'package:celechron/model/todo.dart';
import 'package:celechron/model/practice_score_item.dart';
import 'package:get/get.dart';

import 'package:celechron/http/spider.dart';
import 'package:celechron/http/time_config_service.dart';
import 'package:celechron/http/zjuServices/grs_new.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/http/zjuServices/response_utils.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/grade.dart';
import 'package:celechron/model/semester.dart';
import 'package:flutter/foundation.dart';
import 'package:celechron/services/diagnostic_log_service.dart';

import 'zjuServices/zjuam.dart';
import 'zjuServices/zdbk.dart';
import 'zjuServices/sztz.dart';

/// 本科完整刷新编排器；各站点共享统一认证，但独立登录、缓存和降级。
class UgrsSpider implements Spider {
  late HttpClient _httpClient; // HTTP 客户端
  late String _username;
  late String _password;
  late Courses _courses;
  late Zdbk _zdbk;
  late Sztz _sztz;
  late GrsNew _grsNew;
  late TimeConfigService _timeConfigService;
  DateTime _lastUpdateTime = DateTime(0);
  bool fetchGrs = false;
  Map<String, double>? _practiceScores;
  bool _isPracticeScoresGet = false;
  PracticeScoreSnapshot _practiceSnapshot = PracticeScoreSnapshot.unavailable;

  Future<List<String?>>? _reloginFuture;
  Future<Cookie?>? _sztzReauthFuture;
  int _loginGeneration = 0;

  UgrsSpider(String username, String password) {
    _httpClient = _createHttpClient();
    _courses = Courses();
    _zdbk = Zdbk();
    _sztz = Sztz(accountScope: username);
    _grsNew = GrsNew();
    _timeConfigService = TimeConfigService();
    _username = username;
    _password = password;
  }

  // 初始化或重置 HttpClient
  HttpClient _createHttpClient() {
    final client = HttpClient();
    client.userAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36 Edg/110.0.1587.63";
    // 强制不保存 Cookies，完全由 Zdbk 手动管理，避免冲突
    // 同时也避免重定向时 HttpClient 自动携带旧 Cookie
    return client;
  }

  @override
  set db(DatabaseHelper? db) {
    _courses.db = db;
    _zdbk.db = db;
    _sztz.db = db;
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
    fetchGrs = false;
    // 所有子站完成本轮登录尝试后才整体替换旧客户端，
    // 避免登录过程中业务请求混用两套连接状态。
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
        {void Function()? onSuccess, bool ignoreError = false}) async {
      try {
        await future.timeout(const Duration(seconds: 8));
        onSuccess?.call();
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
      captureLogin(_courses.login(candidateClient, candidateSsoCookie), "学在浙大"),
      captureLogin(_zdbk.login(candidateClient, candidateSsoCookie), "教务网"),
      captureLogin(_sztz.login(candidateClient, candidateSsoCookie), "素质拓展平台",
          ignoreError: true),
      captureLogin(_grsNew.login(candidateClient, candidateSsoCookie), "研究生院网",
          onSuccess: () {
        fetchGrs = true;
      }, ignoreError: true),
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
    _zdbk.logout();
    _sztz.logout();
    _grsNew.logout();
    _courses.logout();
    _practiceScores = null;
    _isPracticeScoresGet = false;
    _practiceSnapshot = PracticeScoreSnapshot.unavailable;
    _sztzReauthFuture = null;
  }

  Map<String, double>? get practiceScores => _practiceScores;
  bool get isPracticeScoresGet => _isPracticeScoresGet;
  PracticeScoreSnapshot get practiceSnapshot => _practiceSnapshot;

  Future<Cookie?> _reauthenticateSztz() async {
    final pending = _sztzReauthFuture;
    if (pending != null) return pending;
    final future = () async {
      await ZjuAm.clearCachedSsoCookie(_username);
      return ZjuAm.getSsoCookie(_httpClient, _username, _password).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw requestTimeout('素质拓展重新认证超时'),
      );
    }();
    _sztzReauthFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_sztzReauthFuture, future)) {
        _sztzReauthFuture = null;
      }
    }
  }

  void _usePracticeSnapshot(PracticeScoreSnapshot snapshot) {
    _practiceSnapshot = snapshot;
    _isPracticeScoresGet = snapshot.hasAnyData;
    if (snapshot.summary != null) {
      _practiceScores = {
        'pt2': snapshot.totalFor(1),
        'pt3': snapshot.totalFor(2),
        'pt4': snapshot.totalFor(3),
      };
    }
  }

  // 【终极修改】自带最大重试次数的循环重试机制，并正确拦截底层私吞的错误
  Future<T> _fetchWithRetry<T>(Future<T> Function() requestFactory,
      {int maxRetries = 1}) async {
    int attempts = 0;
    while (true) {
      final requestLoginGeneration = _loginGeneration;
      T? fallbackResult;
      try {
        var result = await requestFactory(); // 每次尝试都重新创建底层请求
        fallbackResult = result;

        // 【修正】：将判断和抛出异常分开，防止抛出的异常被安全检查的 catch 吃掉
        bool hasHiddenError = false;
        dynamic hiddenErrorToThrow;

        try {
          dynamic res = result;
          if (res != null && res.item1 != null) {
            String errStr = res.item1.toString().toLowerCase();
            if (errStr.contains("connection closed") ||
                errStr.contains("httpexception") ||
                errStr.contains("网络错误") ||
                errStr.contains("未登录") ||
                errStr.contains("超时") ||
                errStr.contains("timeout") ||
                errStr.contains("type 'null'") ||
                errStr.contains("无法解析") ||
                errStr.contains("wisportalid无效") ||
                errStr.contains("登录态已失效") ||
                errStr.contains("会话已过期") ||
                errStr.contains("token 已过期")) {
              hasHiddenError = true;
              hiddenErrorToThrow = res.item1;
            }
          }
        } on Object catch (error, stackTrace) {
          DiagnosticLogService.instance.record(
            level: CelechronLogLevel.debug,
            module: '本科生刷新',
            operation: 'inspectResult',
            error: error,
            stackTrace: stackTrace,
          );
        }

        // 如果发现了隐藏的错误，在 try-catch 外部将其抛出！
        if (hasHiddenError) {
          throw hiddenErrorToThrow;
        }

        return result; // 如果没有错误，正常返回
      } on Object catch (error, stackTrace) {
        attempts++;
        String errStr = error.toString().toLowerCase(); // 转小写方便匹配

        final alreadyRelogged =
            errStr.contains("执行过重新登录：是") || errStr.contains("手动重新登录");
        final authenticationError = !alreadyRelogged &&
            (error is AuthenticationExpiredException ||
                error is SessionExpiredException ||
                errStr.contains("未登录") ||
                errStr.contains("登录态已失效") ||
                errStr.contains("会话已过期") ||
                errStr.contains("token 已过期") ||
                errStr.contains("wisportalid无效"));
        final transientError = errStr.contains("connection closed") ||
            errStr.contains("timeout") ||
            errStr.contains("超时") ||
            errStr.contains("httpexception") ||
            errStr.contains("网络错误") ||
            errStr.contains("socketexception");
        if (attempts <= maxRetries && authenticationError) {
          // generation 防止多个失败请求同时启动重复的整套登录流程。
          if (_loginGeneration == requestLoginGeneration) {
            final loginErrors = await login();
            if (loginErrors.any((error) => error != null)) rethrow;
          }
          await Future.delayed(const Duration(milliseconds: 300));
          continue;
        }
        if (attempts <= maxRetries && transientError) {
          await Future.delayed(const Duration(milliseconds: 300));
          continue; // 继续下一次尝试
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
    var fetches = <Future<String?>>[];
    List<String> fetchSequence = ['校历', '课表', '考试', '成绩', '主修', '作业', '实践'];

    var outSemesters = <Semester>[];
    var outGrades = <Grade>[];
    var outMajorGrade = <double>[];
    var outSpecialDates = <DateTime, String>{};
    var outTodos = <Todo>[];
    var loginErrorMessages = <String?>[null, null, null];
    var majorCourseIds = <String>{};

    if (DateTime.now().difference(_lastUpdateTime).inMinutes > 15) {
      loginErrorMessages = await login();
    }

    final now = DateTime.now();
    final enrollmentDigits =
        _username.length >= 3 ? _username.substring(1, 3) : '';
    final parsedEnrollmentYear = int.tryParse(enrollmentDigits);
    if (parsedEnrollmentYear == null) {
      return Tuple7(loginErrorMessages, <String?>['无法解析学号中的入学年份：$_username'],
          outSemesters, outGrades, outMajorGrade, outSpecialDates, outTodos);
    }
    var yearEnroll = parsedEnrollmentYear + 2000;
    var yearGraduate = yearEnroll + 7;
    final timetableYearPlan = timetableAcademicYearPlan(
      now: now,
      graduationYearStart: yearGraduate,
    );
    Map<String, int> semesterIndexMap = <String, int>{};
    // 大一开学考的学期是入学的前一学期
    for (var i = 7, j = 0; i >= -1; i--, j++) {
      semesterIndexMap.addEntries(
          [MapEntry('${yearEnroll + i}-${yearEnroll + i + 1}-2', j * 2)]);
      semesterIndexMap.addEntries(
          [MapEntry('${yearEnroll + i}-${yearEnroll + i + 1}-1', j * 2 + 1)]);
      outSemesters.add(Semester('${yearEnroll + i}-${yearEnroll + i + 1}春夏'));
      outSemesters.add(Semester('${yearEnroll + i}-${yearEnroll + i + 1}秋冬'));
    }

    var semesterConfigFetches = <Future<String?>>[];
    var calendarLive = 0;
    var calendarCache = 0;
    var calendarFallback = 0;
    var timetableFetches = <Future<String?>>[];
    var cancelTimetableFetch = false;

    for (final queryAcademicYearStart
        in timetableYearPlan.yearsFrom(yearEnroll)) {
      // normalUpperBound 内保持历史/当前抓取；其后的 probeUpperBound
      // 无条件尝试下一学年，以接口是否有有效数据判断是否开放。
      final isProbeYear = timetableYearPlan.isProbeYear(queryAcademicYearStart);
      final queryAcademicYear =
          '$queryAcademicYearStart-${queryAcademicYearStart + 1}';
      var probeSessionCount = 0;
      var probeHadUnexpectedFailure = false;

      if (isProbeYear) {
        DiagnosticLogService.instance.record(
          module: '课表',
          operation: 'futureProbe',
          message: '正在探测未来学年课表：$queryAcademicYear',
        );
      }

      semesterConfigFetches.add(_timeConfigService
          .getConfig(_httpClient, '$queryAcademicYear-1')
          .then((value) {
        if (!isProbeYear) {
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
          if (isProbeYear) {
            DiagnosticLogService.instance.record(
              level: CelechronLogLevel.warning,
              module: '校历',
              operation: 'futureProbe',
              message: '未来学年校历未发布，已使用现有回退：'
                  '$queryAcademicYear-1',
            );
            return null;
          }
          return degradedRefreshText(
            '校历（$queryAcademicYear-1）：${value.item3.label}',
            details:
                value.item1 == null ? null : detailedErrorText(value.item1),
          );
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
              _describeRefreshFailure(error, stackTrace)));

      semesterConfigFetches.add(_timeConfigService
          .getConfig(_httpClient, '$queryAcademicYear-2')
          .then((value) {
        if (!isProbeYear) {
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
          if (isProbeYear) {
            DiagnosticLogService.instance.record(
              level: CelechronLogLevel.warning,
              module: '校历',
              operation: 'futureProbe',
              message: '未来学年校历未发布，已使用现有回退：'
                  '$queryAcademicYear-2',
            );
            return null;
          }
          return degradedRefreshText(
            '校历（$queryAcademicYear-2）：${value.item3.label}',
            details:
                value.item1 == null ? null : detailedErrorText(value.item1),
          );
        }
        return value.item1?.toString();
      }).catchError((Object error, StackTrace stackTrace) =>
              _describeRefreshFailure(error, stackTrace)));

      Future<String?> handleTimetable(season) async {
        if (cancelTimetableFetch) {
          if (isProbeYear) probeHadUnexpectedFailure = true;
          return Future.value("已取消");
        }
        try {
          var value = await _fetchWithRetry(
              () => _zdbk.getTimetable(_httpClient, queryAcademicYear, season));

          var semKey = season.startsWith('1')
              ? '$queryAcademicYear-1'
              : '$queryAcademicYear-2';
          var sessions = value.item2.toList();
          if (isProbeYear &&
              sessions.isEmpty &&
              isExpectedTimetableProbeMiss(value.item1)) {
            return null;
          }
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
          if (isProbeYear) {
            probeSessionCount += sessions.length;
          }
          if (value.item1.toString().contains("验证码")) {
            cancelTimetableFetch = true;
          }
          if (isProbeYear && isExpectedTimetableProbeMiss(value.item1)) {
            return null;
          }
          if (isProbeYear && value.item1 != null) {
            probeHadUnexpectedFailure = true;
          }
          return Future.value(value.item1?.toString());
        } on Object catch (error, stackTrace) {
          if (isProbeYear && isExpectedTimetableProbeMiss(error)) {
            return null;
          }
          if (isProbeYear) probeHadUnexpectedFailure = true;
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

      if (isProbeYear) {
        timetableFetches.first = timetableFetches.first.then((value) {
          DiagnosticLogService.instance.record(
            level: probeHadUnexpectedFailure
                ? CelechronLogLevel.warning
                : CelechronLogLevel.info,
            module: '课表',
            operation: 'futureProbe',
            message: probeSessionCount > 0
                ? '未来学年课表有数据：$queryAcademicYear，'
                    '条目数：$probeSessionCount'
                : probeHadUnexpectedFailure
                    ? '未来学年课表探测失败：$queryAcademicYear，'
                        '已按现有错误链路上报'
                    : '未来学年课表尚未开放：$queryAcademicYear',
          );
          return value;
        });
      }

      if (fetchGrs && !isProbeYear) {
        // 额外一年只探测本科课表，避免扩大研究生接口原有请求范围。
        timetableFetches.add(_fetchWithRetry(() =>
                _grsNew.getTimetable(_httpClient, queryAcademicYearStart, 13))
            .then((value) {
          for (var e in value.item2) {
            outSemesters[semesterIndexMap['$queryAcademicYear-1']!]
                .addSession(e, '$queryAcademicYear-1', true);
          }
          return value.item1?.toString();
        }).catchError((Object error, StackTrace stackTrace) =>
                _describeRefreshFailure(error, stackTrace)));
        timetableFetches.add(_fetchWithRetry(() =>
                _grsNew.getTimetable(_httpClient, queryAcademicYearStart, 14))
            .then((value) {
          for (var e in value.item2) {
            outSemesters[semesterIndexMap['$queryAcademicYear-1']!]
                .addSession(e, '$queryAcademicYear-1', true);
          }
          return value.item1?.toString();
        }).catchError((Object error, StackTrace stackTrace) =>
                _describeRefreshFailure(error, stackTrace)));
        timetableFetches.add(_fetchWithRetry(() =>
                _grsNew.getTimetable(_httpClient, queryAcademicYearStart, 11))
            .then((value) {
          for (var e in value.item2) {
            outSemesters[semesterIndexMap['$queryAcademicYear-2']!]
                .addSession(e, '$queryAcademicYear-2', true);
          }
          return value.item1?.toString();
        }).catchError((Object error, StackTrace stackTrace) =>
                _describeRefreshFailure(error, stackTrace)));
        timetableFetches.add(_fetchWithRetry(() =>
                _grsNew.getTimetable(_httpClient, queryAcademicYearStart, 12))
            .then((value) {
          for (var e in value.item2) {
            outSemesters[semesterIndexMap['$queryAcademicYear-2']!]
                .addSession(e, '$queryAcademicYear-2', true);
          }
          return value.item1?.toString();
        }).catchError((Object error, StackTrace stackTrace) =>
                _describeRefreshFailure(error, stackTrace)));
        // 研究生课的【考试】
        timetableFetches.add(_fetchWithRetry(() =>
                _grsNew.getExamsDto(_httpClient, queryAcademicYearStart, 12))
            .then((value) {
          for (var e in value.item2) {
            outSemesters[semesterIndexMap['$queryAcademicYear-1']!]
                .addExamWithSemester(e, '$queryAcademicYear-1');
          }
          return value.item1?.toString();
        }).catchError((Object error, StackTrace stackTrace) =>
                _describeRefreshFailure(error, stackTrace)));
        timetableFetches.add(_fetchWithRetry(() =>
                _grsNew.getExamsDto(_httpClient, queryAcademicYearStart, 11))
            .then((value) {
          for (var e in value.item2) {
            outSemesters[semesterIndexMap['$queryAcademicYear-2']!]
                .addExamWithSemester(e, '$queryAcademicYear-2');
          }
          return value.item1?.toString();
        }).catchError((Object error, StackTrace stackTrace) =>
                _describeRefreshFailure(error, stackTrace)));
      }
    }

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
    fetches.add(Future.wait(timetableFetches)
        .then((value) => value.firstWhereOrNull((e) => e != null)));

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
            _describeRefreshFailure(error, stackTrace)));

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
      for (var e in outSemesters) {
        e.calculateGPA();
      }
      return value.item1?.toString();
    }).catchError((Object error, StackTrace stackTrace) =>
            _describeRefreshFailure(error, stackTrace)));

    fetches.add(_fetchWithRetry(() => _zdbk.getMajorGrade(_httpClient))
        .then((value) {
      outMajorGrade.clear();
      outMajorGrade.addAll(value.item2.item1);

      final payload = decodeJsonMap(value.item2.item2, context: '教务网主修成绩响应');
      majorCourseIds = (asDynamicList(payload['items']) ?? const [])
          .map(asStringMap)
          .whereType<Map<String, dynamic>>()
          .map((item) => asString(item['xkkh']))
          .whereType<String>()
          .toSet();

      return value.item1?.toString();
    }).catchError((Object error, StackTrace stackTrace) =>
            _describeRefreshFailure(error, stackTrace)));

    // 作业（学在浙大）- 加上重试包装
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
            _describeRefreshFailure(error, stackTrace)));

    // getSqjl 只负责项目明细；外层计点严格按
    // getMyInfo 网络、getMyInfo 账号缓存、getSqjl 项目合计三级降级。
    fetches.add(() async {
      final snapshot = await _sztz.getPracticeScoreData(
        _httpClient,
        reauthenticate: _reauthenticateSztz,
      );
      if (!snapshot.hasAnyData) {
        // 两个接口都失败时保留上一次快照，不能用零覆盖旧汇总或旧明细。
        return snapshot.summaryErrorMessage ??
            snapshot.errorMessage ??
            '实践数据当前不可用';
      }
      _usePracticeSnapshot(snapshot);

      final degraded = <String>[];
      if (snapshot.source == PracticeDataSource.sztzCache) {
        degraded.add('项目实时请求失败，已使用 getSqjl 项目缓存');
      } else if (snapshot.source == PracticeDataSource.unavailable) {
        degraded.add('getSqjl 项目明细本次不可用，已保留原有明细');
      }
      switch (snapshot.summarySource) {
        case PracticeSummarySource.cachedMyInfo:
          degraded.add('getMyInfo 实时请求失败，已使用账号缓存');
          break;
        case PracticeSummarySource.calculatedFromSqjl:
          degraded.add('getMyInfo 及其缓存不可用，已按 getSqjl 项目合计');
          break;
        case PracticeSummarySource.unavailable:
          degraded.add('外层计点汇总本次不可用，已保留原有汇总');
          break;
        case PracticeSummarySource.networkMyInfo:
        case PracticeSummarySource.legacyPersisted:
          break;
      }
      if (degraded.isEmpty) return null;
      final details = [
        snapshot.errorMessage,
        snapshot.summaryErrorMessage,
      ].whereType<String>().join('；');
      return degradedRefreshText(
        '实践：${degraded.join('；')}',
        details: details.isEmpty ? null : details,
      );
    }());

    var fetchErrorMessages = await Future.wait(fetches).whenComplete(() {
      outSemesters.removeWhere((e) =>
          e.grades.isEmpty &&
          e.sessions.isEmpty &&
          e.exams.isEmpty &&
          e.courses.isEmpty);

      for (var grade in outGrades) {
        if (majorCourseIds.contains(grade.id)) {
          grade.major = true;
        }
      }
    });

    if (fetchErrorMessages.every((e) => e == null)) {
      _lastUpdateTime = DateTime.now();
    }
    for (var i = 0; i < fetchErrorMessages.length; i++) {
      if (fetchErrorMessages[i] != null) {
        final message = fetchErrorMessages[i]!;
        fetchErrorMessages[i] = isDegradedRefreshText(message)
            ? degradedRefreshText(
                '${fetchSequence[i]}：${shortErrorText(message)}',
                details: detailedErrorText(message),
              )
            : '${fetchSequence[i]}查询出错：$message';
      }
      DiagnosticLogService.instance.setModuleResult(
        fetchSequence[i],
        fetchErrorMessages[i] == null
            ? fetchSequence[i] == '校历'
                ? '$calendarLive 个远程成功'
                : fetchSequence[i] == '作业'
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

class MockSpider extends UgrsSpider {
  MockSpider() : super('3200000000', '');

  @override
  Future<List<String?>> login() async {
    await Future.delayed(const Duration(seconds: 4));
    return [null, null];
  }

  @override
  void logout() {}

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
    await Future.delayed(const Duration(seconds: 2));
    return Tuple7(
        [null, null],
        [null, null, null, null, null, null],
        [
          Semester.fromJson(jsonDecode(
              '{"name":"2024-2025春夏","courses":{"(2024-2025-2)-211G0280-0099160-1":{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","confirmed":true,"credit":3.0,"grade":{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","credit":3.0,"original":"95","fivePoint":5.0,"fourPoint":4.3,"fourPointLegacy":4.0,"hundredPoint":95,"gpaIncluded":true,"creditIncluded":true},"teacher":"纪守领","sessions":[{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","teacher":"纪守领","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":false,"day":4,"time":[2,3],"location":"紫金港东1A-401(录播)","grsClass":null},{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","teacher":"纪守领","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":false,"evenWeek":true,"day":4,"time":[1,2,3],"location":"紫金港机房","grsClass":null}],"exams":[{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","type":1,"time":["2021-01-20T15:30:00.000","2021-01-20T17:30:00.000"],"location":"紫金港机房","seat":null}]},"(2024-2025-2)-051F0020-0098350-2":{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","confirmed":true,"credit":3.0,"grade":{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","credit":3.0,"original":"90","fivePoint":4.5,"fourPoint":4.1,"fourPointLegacy":4.0,"hundredPoint":90,"gpaIncluded":true,"creditIncluded":true},"teacher":"符亦文","sessions":[{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","teacher":"符亦文","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[3,4],"location":"紫金港东6-223(网络五边菱)(录播)","grsClass":null},{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","teacher":"符亦文","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":3,"time":[9,10],"location":"紫金港东6-223(网络五边菱)(录播)","grsClass":null}],"exams":[{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","type":1,"time":["2021-01-21T10:30:00.000","2021-01-21T12:30:00.000"],"location":"紫金港西2-105(录播)","seat":"85"}]},"(2024-2025-2)-551E0020-0009771-1":{"id":"(2024-2025-2)-551E0020-0009771-1","name":"中国近现代史纲要","confirmed":true,"credit":3.0,"grade":{"id":"(2024-2025-2)-551E0020-0009771-1","name":"中国近现代史纲要","credit":3.0,"original":"92","fivePoint":4.8,"fourPoint":4.2,"fourPointLegacy":4.0,"hundredPoint":92,"gpaIncluded":true,"creditIncluded":true},"teacher":"甘均先","sessions":[{"id":"(2024-2025-2)-551E0020-0009771-1","name":"中国近现代史纲要","teacher":"甘均先","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[6,7,8],"location":"紫金港东1B-302(录播)","grsClass":null}],"exams":[{"id":"(2024-2025-2)-551E0020-0009771-1","name":"中国近现代史纲要","type":1,"time":["2021-01-21T14:00:00.000","2021-01-21T16:00:00.000"],"location":"紫金港西1-211(录播)","seat":"81"}]},"(2024-2025-2)-821T0150-0082403-1":{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","confirmed":true,"credit":5.0,"grade":{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","credit":5.0,"original":"83","fivePoint":3.9,"fourPoint":3.9,"fourPointLegacy":3.9,"hundredPoint":83,"gpaIncluded":true,"creditIncluded":true},"teacher":"金显","sessions":[{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","teacher":"金显","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[9],"location":"紫金港东2-201(录播.4)","grsClass":null},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","teacher":"金显","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[1,2],"location":"紫金港东2-201(录播.4)","grsClass":null},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","teacher":"金显","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":3,"time":[3,4,5],"location":"紫金港东2-201(录播.4)","grsClass":null}],"exams":[{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","type":0,"time":["2020-11-16T14:00:00.000","2020-11-16T16:00:00.000"],"location":"紫金港西2-304(录播研)","seat":"48"},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","type":1,"time":["2021-01-22T08:00:00.000","2021-01-22T10:00:00.000"],"location":"紫金港西2-304(录播研)","seat":"69"}]},"(2024-2025-2)-081C0130-0094011-2":{"id":"(2024-2025-2)-081C0130-0094011-2","name":"工程图学","confirmed":true,"credit":2.5,"grade":{"id":"(2024-2025-2)-081C0130-0094011-2","name":"工程图学","credit":2.5,"original":"85","fivePoint":3.9,"fourPoint":3.9,"fourPointLegacy":3.9,"hundredPoint":85,"gpaIncluded":true,"creditIncluded":true},"teacher":"费少梅","sessions":[{"id":"(2024-2025-2)-081C0130-0094011-2","name":"工程图学","teacher":"费少梅","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":4,"time":[3,4,5],"location":"紫金港东1B-214(录播.4)","grsClass":null}],"exams":[{"id":"(2024-2025-2)-081C0130-0094011-2","name":"工程图学","type":1,"time":["2021-01-25T10:30:00.000","2021-01-25T12:30:00.000"],"location":"紫金港西1-317(录播)*","seat":"26"}]},"(2024-2025-2)-551E0010-0014323-4":{"id":"(2024-2025-2)-551E0010-0014323-4","name":"思想道德修养与法律基础","confirmed":true,"credit":3.0,"grade":{"id":"(2024-2025-2)-551E0010-0014323-4","name":"思想道德修养与法律基础","credit":3.0,"original":"95","fivePoint":5.0,"fourPoint":4.3,"fourPointLegacy":4.0,"hundredPoint":95,"gpaIncluded":true,"creditIncluded":true},"teacher":"姚明明","sessions":[{"id":"(2024-2025-2)-551E0010-0014323-4","name":"思想道德修养与法律基础","teacher":"姚明明","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":3,"time":[1,2],"location":"紫金港东1B-302(录播)","grsClass":null}],"exams":[{"id":"(2024-2025-2)-551E0010-0014323-4","name":"思想道德修养与法律基础","type":1,"time":["2021-01-25T14:00:00.000","2021-01-25T16:00:00.000"],"location":"紫金港东1A-505(录播研)","seat":"72"}]},"(2024-2025-2)-821T0190-0086207-1":{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","confirmed":true,"credit":3.5,"grade":{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","credit":3.5,"original":"90","fivePoint":4.5,"fourPoint":4.1,"fourPointLegacy":4.0,"hundredPoint":90,"gpaIncluded":true,"creditIncluded":true},"teacher":"汪国军","sessions":[{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","teacher":"汪国军","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[9],"location":"紫金港东2-202(录播.4)","grsClass":null},{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","teacher":"汪国军","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[3,4,5],"location":"紫金港东2-202(录播.4)","grsClass":null}],"exams":[{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","type":0,"time":["2020-11-18T14:00:00.000","2020-11-18T16:00:00.000"],"location":"紫金港西2-104(录播)","seat":"58"},{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","type":1,"time":["2021-01-26T08:00:00.000","2021-01-26T10:00:00.000"],"location":"紫金港西2-104(录播)","seat":"3"}]},"(2024-2025-2)-0113N001-0086337-1":{"id":"(2024-2025-2)-0113N001-0086337-1","name":"公共经济分析导论","confirmed":true,"credit":1.5,"grade":{"id":"(2024-2025-2)-0113N001-0086337-1","name":"公共经济分析导论","credit":1.5,"original":"85","fivePoint":3.9,"fourPoint":3.9,"fourPointLegacy":3.9,"hundredPoint":85,"gpaIncluded":true,"creditIncluded":true},"teacher":"朱柏铭","sessions":[{"id":"(2024-2025-2)-0113N001-0086337-1","name":"公共经济分析导论","teacher":"朱柏铭","confirmed":true,"firstHalf":true,"secondHalf":false,"oddWeek":true,"evenWeek":true,"day":3,"time":[6,7,8],"location":"紫金港东1B-206(录播)#","grsClass":null}],"exams":[]},"(2024-2025-2)-371E0010-0008303-2":{"id":"(2024-2025-2)-371E0010-0008303-2","name":"形势与政策Ⅰ","confirmed":true,"credit":1.0,"grade":null,"teacher":"项淑芳/吴维东","sessions":[{"id":"(2024-2025-2)-371E0010-0008303-2","name":"形势与政策Ⅰ","teacher":"项淑芳/吴维东","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":false,"evenWeek":true,"day":7,"time":[11,12],"location":"紫金港东1B-210(录播.4)#","grsClass":null}],"exams":[]},"(2024-2025-2)-40103200-0087355-1":{"id":"(2024-2025-2)-40103200-0087355-1","name":"无线电测向（初级班）","confirmed":true,"credit":1.0,"grade":{"id":"(2024-2025-2)-40103200-0087355-1","name":"无线电测向（初级班）","credit":1.0,"original":"91","fivePoint":4.5,"fourPoint":4.1,"fourPointLegacy":4.0,"hundredPoint":91,"gpaIncluded":true,"creditIncluded":true},"teacher":"董育平","sessions":[{"id":"(2024-2025-2)-40103200-0087355-1","name":"无线电测向（初级班）","teacher":"董育平","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[6,7],"location":"紫金港田径场（东）","grsClass":null}],"exams":[]},"(2024-2025-2)-41100001-0087355-2":{"id":"(2024-2025-2)-41100001-0087355-2","name":"身体素质课","confirmed":true,"credit":0.0,"grade":null,"teacher":"董育平","sessions":[{"id":"(2024-2025-2)-41100001-0087355-2","name":"身体素质课","teacher":"董育平","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[10],"location":"紫金港东田径场","grsClass":null}],"exams":[]},"(2024-2025-2)-8517N001-0082046-3":{"id":"(2024-2025-2)-8517N001-0082046-3","name":"无线网络应用","confirmed":true,"credit":1.5,"grade":{"id":"(2024-2025-2)-8517N001-0082046-3","name":"无线网络应用","credit":1.5,"original":"97","fivePoint":5.0,"fourPoint":4.3,"fourPointLegacy":4.0,"hundredPoint":97,"gpaIncluded":true,"creditIncluded":true},"teacher":"金心宇/史笑兴","sessions":[{"id":"(2024-2025-2)-8517N001-0082046-3","name":"无线网络应用","teacher":"金心宇/史笑兴","confirmed":true,"firstHalf":true,"secondHalf":false,"oddWeek":true,"evenWeek":true,"day":4,"time":[9,10,11,12,13],"location":"紫金港东4-418","grsClass":null}],"exams":[]}},"exams":[{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","type":1,"time":["2021-01-20T15:30:00.000","2021-01-20T17:30:00.000"],"location":"紫金港机房","seat":null},{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","type":1,"time":["2021-01-21T10:30:00.000","2021-01-21T12:30:00.000"],"location":"紫金港西2-105(录播)","seat":"85"},{"id":"(2024-2025-2)-551E0020-0009771-1","name":"中国近现代史纲要","type":1,"time":["2021-01-21T14:00:00.000","2021-01-21T16:00:00.000"],"location":"紫金港西1-211(录播)","seat":"81"},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","type":0,"time":["2020-11-16T14:00:00.000","2020-11-16T16:00:00.000"],"location":"紫金港西2-304(录播研)","seat":"48"},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","type":1,"time":["2021-01-22T08:00:00.000","2021-01-22T10:00:00.000"],"location":"紫金港西2-304(录播研)","seat":"69"},{"id":"(2024-2025-2)-081C0130-0094011-2","name":"工程图学","type":1,"time":["2021-01-25T10:30:00.000","2021-01-25T12:30:00.000"],"location":"紫金港西1-317(录播)*","seat":"26"},{"id":"(2024-2025-2)-551E0010-0014323-4","name":"思想道德修养与法律基础","type":1,"time":["2021-01-25T14:00:00.000","2021-01-25T16:00:00.000"],"location":"紫金港东1A-505(录播研)","seat":"72"},{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","type":0,"time":["2020-11-18T14:00:00.000","2020-11-18T16:00:00.000"],"location":"紫金港西2-104(录播)","seat":"58"},{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","type":1,"time":["2021-01-26T08:00:00.000","2021-01-26T10:00:00.000"],"location":"紫金港西2-104(录播)","seat":"3"}],"sessions":[{"id":"(2024-2025-2)-551E0020-0009771-1","name":"中国近现代史纲要","teacher":"甘均先","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[6,7,8],"location":"紫金港东1B-302(录播)","grsClass":null},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","teacher":"金显","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[9],"location":"紫金港东2-201(录播.4)","grsClass":null},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","teacher":"金显","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[1,2],"location":"紫金港东2-201(录播.4)","grsClass":null},{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","teacher":"符亦文","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":1,"time":[3,4],"location":"紫金港东6-223(网络五边菱)(录播)","grsClass":null},{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","teacher":"汪国军","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[9],"location":"紫金港东2-202(录播.4)","grsClass":null},{"id":"(2024-2025-2)-41100001-0087355-2","name":"身体素质课","teacher":"董育平","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[10],"location":"紫金港东田径场","grsClass":null},{"id":"(2024-2025-2)-40103200-0087355-1","name":"无线电测向（初级班）","teacher":"董育平","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[6,7],"location":"紫金港田径场（东）","grsClass":null},{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","teacher":"汪国军","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":2,"time":[3,4,5],"location":"紫金港东2-202(录播.4)","grsClass":null},{"id":"(2024-2025-2)-0113N001-0086337-1","name":"公共经济分析导论","teacher":"朱柏铭","confirmed":true,"firstHalf":true,"secondHalf":false,"oddWeek":true,"evenWeek":true,"day":3,"time":[6,7,8],"location":"紫金港东1B-206(录播)#","grsClass":null},{"id":"(2024-2025-2)-551E0010-0014323-4","name":"思想道德修养与法律基础","teacher":"姚明明","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":3,"time":[1,2],"location":"紫金港东1B-302(录播)","grsClass":null},{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","teacher":"符亦文","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":3,"time":[9,10],"location":"紫金港东6-223(网络五边菱)(录播)","grsClass":null},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","teacher":"金显","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":3,"time":[3,4,5],"location":"紫金港东2-201(录播.4)","grsClass":null},{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","teacher":"纪守领","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":false,"day":4,"time":[2,3],"location":"紫金港东1A-401(录播)","grsClass":null},{"id":"(2024-2025-2)-8517N001-0082046-3","name":"无线网络应用","teacher":"金心宇/史笑兴","confirmed":true,"firstHalf":true,"secondHalf":false,"oddWeek":true,"evenWeek":true,"day":4,"time":[9,10,11,12,13],"location":"紫金港东4-418","grsClass":null},{"id":"(2024-2025-2)-081C0130-0094011-2","name":"工程图学","teacher":"费少梅","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":true,"evenWeek":true,"day":4,"time":[3,4,5],"location":"紫金港东1B-214(录播.4)","grsClass":null},{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","teacher":"纪守领","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":false,"evenWeek":true,"day":4,"time":[1,2,3],"location":"紫金港机房","grsClass":null},{"id":"(2024-2025-2)-371E0010-0008303-2","name":"形势与政策Ⅰ","teacher":"项淑芳/吴维东","confirmed":true,"firstHalf":true,"secondHalf":true,"oddWeek":false,"evenWeek":true,"day":7,"time":[11,12],"location":"紫金港东1B-210(录播.4)#","grsClass":null}],"grades":[{"id":"(2024-2025-2)-8517N001-0082046-3","name":"无线网络应用","credit":1.5,"original":"97","fivePoint":5.0,"fourPoint":4.3,"fourPointLegacy":4.0,"hundredPoint":97,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-551E0010-0014323-4","name":"思想道德修养与法律基础","credit":3.0,"original":"95","fivePoint":5.0,"fourPoint":4.3,"fourPointLegacy":4.0,"hundredPoint":95,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-211G0280-0099160-1","name":"C程序设计基础","credit":3.0,"original":"95","fivePoint":5.0,"fourPoint":4.3,"fourPointLegacy":4.0,"hundredPoint":95,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-551E0020-0009771-1","name":"中国近现代史纲要","credit":3.0,"original":"92","fivePoint":4.8,"fourPoint":4.2,"fourPointLegacy":4.0,"hundredPoint":92,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-40103200-0087355-1","name":"无线电测向（初级班）","credit":1.0,"original":"91","fivePoint":4.5,"fourPoint":4.1,"fourPointLegacy":4.0,"hundredPoint":91,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-821T0190-0086207-1","name":"线性代数（甲）","credit":3.5,"original":"90","fivePoint":4.5,"fourPoint":4.1,"fourPointLegacy":4.0,"hundredPoint":90,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-051F0020-0098350-2","name":"大学英语Ⅲ","credit":3.0,"original":"90","fivePoint":4.5,"fourPoint":4.1,"fourPointLegacy":4.0,"hundredPoint":90,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-081C0130-0094011-2","name":"工程图学","credit":2.5,"original":"85","fivePoint":3.9,"fourPoint":3.9,"fourPointLegacy":3.9,"hundredPoint":85,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-0113N001-0086337-1","name":"公共经济分析导论","credit":1.5,"original":"85","fivePoint":3.9,"fourPoint":3.9,"fourPointLegacy":3.9,"hundredPoint":85,"gpaIncluded":true,"creditIncluded":true},{"id":"(2024-2025-2)-821T0150-0082403-1","name":"微积分（甲）Ⅰ","credit":5.0,"original":"83","fivePoint":3.9,"fourPoint":3.9,"fourPointLegacy":3.9,"hundredPoint":83,"gpaIncluded":true,"creditIncluded":true}],"gpa":[4.472222222222222,4.1000000000000005,3.9666666666666663,89.72222222222223],"credits":27.0,"sessionToTime":[[0,0],[480,525],[530,575],[600,645],[650,695],[700,745],[805,850],[855,900],[905,950],[975,1020],[1025,1070],[1130,1175],[1180,1225],[1230,1275],[1280,1325]],"dayOfWeekToDays":[[[[],["2024-02-26T00:00:00.000","2024-03-11T00:00:00.000","2024-03-25T00:00:00.000","2024-04-08T00:00:00.000"],["2024-02-27T00:00:00.000","2024-03-12T00:00:00.000","2024-03-26T00:00:00.000","2024-04-09T00:00:00.000"],["2024-02-28T00:00:00.000","2024-03-13T00:00:00.000","2024-03-27T00:00:00.000","2024-04-10T00:00:00.000"],["2024-02-29T00:00:00.000","2024-03-14T00:00:00.000","2024-03-28T00:00:00.000","2024-04-11T00:00:00.000"],["2024-03-01T00:00:00.000","2024-03-15T00:00:00.000","2024-03-29T00:00:00.000","2024-04-12T00:00:00.000"],["2024-03-02T00:00:00.000","2024-03-16T00:00:00.000","2024-03-30T00:00:00.000","2024-04-13T00:00:00.000"],["2024-03-03T00:00:00.000","2024-03-17T00:00:00.000","2024-03-31T00:00:00.000","2024-04-14T00:00:00.000"]],[[],["2024-03-04T00:00:00.000","2024-03-18T00:00:00.000","2024-04-01T00:00:00.000","2024-04-15T00:00:00.000"],["2024-03-05T00:00:00.000","2024-03-19T00:00:00.000","2024-04-02T00:00:00.000","2024-04-16T00:00:00.000"],["2024-03-06T00:00:00.000","2024-03-20T00:00:00.000","2024-04-03T00:00:00.000","2024-04-17T00:00:00.000"],["2024-03-07T00:00:00.000","2024-03-21T00:00:00.000","2024-04-04T00:00:00.000","2024-04-18T00:00:00.000"],["2024-03-08T00:00:00.000","2024-03-22T00:00:00.000","2024-04-07T00:00:00.000","2024-04-19T00:00:00.000"],["2024-03-09T00:00:00.000","2024-03-23T00:00:00.000","2024-04-06T00:00:00.000","2024-04-20T00:00:00.000"],["2024-03-10T00:00:00.000","2024-03-24T00:00:00.000","2024-04-07T00:00:00.000","2024-04-21T00:00:00.000"]]],[[[],["2024-04-22T00:00:00.000","2024-05-06T00:00:00.000","2024-05-20T00:00:00.000","2024-06-03T00:00:00.000"],["2024-04-23T00:00:00.000","2024-05-07T00:00:00.000","2024-05-21T00:00:00.000","2024-06-04T00:00:00.000"],["2024-04-24T00:00:00.000","2024-05-08T00:00:00.000","2024-05-22T00:00:00.000","2024-06-05T00:00:00.000"],["2024-04-25T00:00:00.000","2024-05-09T00:00:00.000","2024-05-23T00:00:00.000","2024-06-06T00:00:00.000"],["2024-04-26T00:00:00.000","2024-05-10T00:00:00.000","2024-05-24T00:00:00.000","2024-06-07T00:00:00.000"],["2024-04-27T00:00:00.000","2024-05-11T00:00:00.000","2024-05-25T00:00:00.000","2024-06-08T00:00:00.000"],["2024-04-28T00:00:00.000","2024-05-12T00:00:00.000","2024-05-26T00:00:00.000","2024-06-09T00:00:00.000"]],[[],["2024-04-29T00:00:00.000","2024-05-13T00:00:00.000","2024-05-27T00:00:00.000","2024-06-10T00:00:00.000"],["2024-04-30T00:00:00.000","2024-05-14T00:00:00.000","2024-05-28T00:00:00.000","2024-06-11T00:00:00.000"],["2024-05-01T00:00:00.000","2024-05-15T00:00:00.000","2024-05-29T00:00:00.000","2024-06-12T00:00:00.000"],["2024-05-11T00:00:00.000","2024-05-16T00:00:00.000","2024-05-30T00:00:00.000","2024-06-13T00:00:00.000"],["2024-06-17T00:00:00.000","2024-05-17T00:00:00.000","2024-05-31T00:00:00.000","2024-06-14T00:00:00.000"],["2024-05-04T00:00:00.000","2024-05-18T00:00:00.000","2024-06-01T00:00:00.000","2024-06-15T00:00:00.000"],["2024-05-05T00:00:00.000","2024-05-19T00:00:00.000","2024-06-02T00:00:00.000","2024-06-16T00:00:00.000"]]]],"holidays":{"2024-04-04T00:00:00.000":"清明节","2024-05-01T00:00:00.000":"劳动节","2024-06-10T00:00:00.000":"端午节"},"exchanges":{"2024-04-05T00:00:00.000":"2024-04-07T00:00:00.000","2024-05-02T00:00:00.000":"2024-05-11T00:00:00.000","2024-05-03T00:00:00.000":"2024-06-17T00:00:00.000"}}'))
        ],
        (jsonDecode(
                '[ { "id": "(2024-2025-2)-821T0150-0082403-1", "name": "微积分（甲）Ⅰ", "credit": 5.0, "original": "83", "fivePoint": 3.9, "fourPoint": 3.9, "fourPointLegacy": 3.9, "hundredPoint": 83, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-821T0150-0082403-1", "name": "微积分（甲）Ⅰ", "credit": 5.0, "original": "95", "fivePoint": 5.0, "fourPoint": 4.3, "fourPointLegacy": 4.0, "hundredPoint": 95, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-081C0130-0094011-2", "name": "工程图学", "credit": 2.5, "original": "85", "fivePoint": 3.9, "fourPoint": 3.9, "fourPointLegacy": 3.9, "hundredPoint": 85, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-081C0131-0094011-2", "name": "工程图学", "credit": 2.5, "original": "95", "fivePoint": 5.0, "fourPoint": 4.3, "fourPointLegacy": 4.0, "hundredPoint": 95, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-0113N001-0086337-1", "name": "公共经济分析导论", "credit": 1.5, "original": "85", "fivePoint": 3.9, "fourPoint": 3.9, "fourPointLegacy": 3.9, "hundredPoint": 85, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-821T0190-0086207-1", "name": "线性代数（甲）", "credit": 3.5, "original": "90", "fivePoint": 4.5, "fourPoint": 4.1, "fourPointLegacy": 4.0, "hundredPoint": 90, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-051F0020-0098350-2", "name": "大学英语Ⅲ", "credit": 3.0, "original": "90", "fivePoint": 4.5, "fourPoint": 4.1, "fourPointLegacy": 4.0, "hundredPoint": 90, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-40103200-0087355-1", "name": "无线电测向（初级班）", "credit": 1.0, "original": "91", "fivePoint": 4.5, "fourPoint": 4.1, "fourPointLegacy": 4.0, "hundredPoint": 91, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-551E0020-0009771-1", "name": "中国近现代史纲要", "credit": 3.0, "original": "92", "fivePoint": 4.8, "fourPoint": 4.2, "fourPointLegacy": 4.0, "hundredPoint": 92, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-551E0010-0014323-4", "name": "思想道德修养与法律基础", "credit": 3.0, "original": "95", "fivePoint": 5.0, "fourPoint": 4.3, "fourPointLegacy": 4.0, "hundredPoint": 95, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-211G0280-0099160-1", "name": "C程序设计基础", "credit": 3.0, "original": "95", "fivePoint": 5.0, "fourPoint": 4.3, "fourPointLegacy": 4.0, "hundredPoint": 95, "gpaIncluded": true, "creditIncluded": true }, { "id": "(2024-2025-2)-8517N001-0082046-3", "name": "无线网络应用", "credit": 1.5, "original": "97", "fivePoint": 5.0, "fourPoint": 4.3, "fourPointLegacy": 4.0, "hundredPoint": 97, "gpaIncluded": true, "creditIncluded": true } ]'))
            .map(asStringMap)
            .whereType<Map<String, dynamic>>()
            .map(Grade.fromJson)
            .toList(),
        [4.631297709923665, 131.0],
        {},
        Todo.getAllFromCourses((jsonDecode(
            '{"todo_list":[{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T06:00:00Z","id":908844,"is_locked":false,"is_student":true,"prerequisites":[],"title":"Project-资料","type":"homework"},{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T04:50:00Z","id":924799,"is_locked":false,"is_student":true,"prerequisites":[],"title":"实验四","type":"homework"},{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T04:53:00Z","id":924802,"is_locked":false,"is_student":true,"prerequisites":[],"title":"作业三","type":"homework"},{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T05:13:00Z","id":929150,"is_locked":false,"is_student":true,"prerequisites":[],"title":"实验五","type":"homework"},{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T05:18:00Z","id":929152,"is_locked":false,"is_student":true,"prerequisites":[],"title":"实验六","type":"homework"},{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T05:20:00Z","id":929153,"is_locked":false,"is_student":true,"prerequisites":[],"title":"作业四","type":"homework"},{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T05:21:00Z","id":929154,"is_locked":false,"is_student":true,"prerequisites":[],"title":"作业五","type":"homework"},{"course_code":"(2024-2025-1)-21121340-0018181-1A","course_id":74393,"course_name":"计算机网络","course_type":1,"end_time":"2025-02-01T11:50:00Z","id":933292,"is_locked":false,"is_student":true,"prerequisites":[],"title":"期末project-提交通道","type":"homework"},{"course_code":"(2024-2025-1)-21192040-0001038-1A","course_id":74535,"course_name":"量子计算理论基础与软件系统","course_type":1,"end_time":"2025-01-09T15:59:00Z","id":928371,"is_locked":false,"is_student":true,"prerequisites":[],"title":"期末大作业","type":"homework"},{"course_code":"(2024-2025-1)-21121500-0003412-1","course_id":78036,"course_name":"优化基本理论与方法","course_type":1,"end_time":"2025-01-18T15:59:00Z","id":932896,"is_locked":false,"is_student":true,"prerequisites":[],"title":"Final Report","type":"homework"}]}'))));
  }
}
