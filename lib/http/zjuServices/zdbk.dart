import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:celechron/utils/tuple.dart';
import 'package:flutter/foundation.dart';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/calendar_config_parser.dart'
    show isFutureSemester;
import 'package:celechron/utils/gpa_helper.dart';
import 'package:celechron/model/grade.dart';
import 'package:celechron/model/session.dart';
import 'package:celechron/model/exams_dto.dart';
import 'package:celechron/design/captcha_input.dart';
import 'package:celechron/utils/global.dart';
import 'package:celechron/services/diagnostic_log_service.dart';
import 'exceptions.dart';
import 'response_utils.dart';

/// 本科教务网客户端；统一管理 CAS 业务会话、并发限流与按接口缓存降级。
class Zdbk {
  Cookie? _jSessionId;
  Cookie? _route;
  Cookie? _iPlanetDirectoryPro;
  String? _captcha;
  DatabaseHelper? _db;
  Future<bool>? _loginFuture;
  int _sessionGeneration = 0;
  bool _siteBusy = false;
  final List<Completer<void>> _siteWaiters = [];
  DateTime? _lastSiteRequestAt;
  bool _throttledDuringAction = false;

  /// 相邻两个教务请求的最小间隔。教务网按滑动窗口限频（HTTP 921/922）：
  /// 实测约 170 ms 一发时第 6~7 个请求开始被拒，issue #181 实测 0.9 s 稳定。
  static const Duration _baseRequestGap = Duration(milliseconds: 1000);

  /// 本次运行中触发过限频后放宽的间隔，避免同一窗口内再次撞墙。
  static const Duration _throttledRequestGap = Duration(milliseconds: 2000);

  /// 被限频后依次等待的时长；等待期间占住队列，其他请求不会插队。
  static const List<Duration> _throttleBackoffs = [
    Duration(seconds: 3),
    Duration(seconds: 6),
  ];
  Duration _requestGap = _baseRequestGap;

  set db(DatabaseHelper? db) {
    _db = db;
  }

  DateTime? get practiceScoresCacheUpdatedAt {
    final value = _db?.getCachedWebPage('zdbk_practiceScores_timestamp');
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  Future<bool> login(HttpClient httpClient, Cookie? iPlanetDirectoryPro) async {
    if (iPlanetDirectoryPro == null) {
      throw AuthenticationExpiredException("教务网：统一身份认证凭据无效");
    }
    _iPlanetDirectoryPro = iPlanetDirectoryPro;
    // 同一客户端只建立一套 JSESSIONID/route，避免并发 CAS 回调互相覆盖。
    final pending = _loginFuture;
    if (pending != null) return await pending;
    final login = _doLogin(httpClient, iPlanetDirectoryPro);
    _loginFuture = login;
    try {
      return await login;
    } finally {
      if (identical(_loginFuture, login)) _loginFuture = null;
    }
  }

  Future<bool> _doLogin(
      HttpClient httpClient, Cookie iPlanetDirectoryPro) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    _captcha = null;
    _jSessionId = null;
    _route = null;
    // 第一步用统一认证 Cookie 换取 service 跳转；第二步访问跳转地址，
    // 业务站才会签发必须成对使用的 JSESSIONID 与 route。
    request = await httpClient
        .getUrl(Uri.parse(
            "https://zjuam.zju.edu.cn/cas/login?service=https%3A%2F%2Fzdbk.zju.edu.cn%2Fjwglxt%2Fxtgl%2Flogin_ssologin.html"))
        .timeout(const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout());
    request.followRedirects = false;
    request.cookies.add(iPlanetDirectoryPro);
    response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw requestTimeout());
    final firstBody = await readResponseBody(response, context: '教务网 CAS 登录');

    var stLocation = response.headers.value('location');
    if (!response.isRedirect || stLocation == null) {
      throw AuthenticationExpiredException(
          "教务网登录：统一身份认证凭据无效；HTTP ${response.statusCode}"
          "；Location ${stLocation ?? '<缺失>'}"
          "；响应摘要：${responseSummary(firstBody)}");
    } else if (stLocation.startsWith("http://")) {
      stLocation = stLocation.replaceFirst("http://", "https://");
    }
    request = await httpClient.getUrl(Uri.parse(stLocation)).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw requestTimeout());
    request.followRedirects = false;
    response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw requestTimeout());
    final secondBody = await readResponseBody(response, context: '教务网登录');
    if (response.statusCode == HttpStatus.unauthorized ||
        response.statusCode == HttpStatus.forbidden ||
        bodyIndicatesAuthenticationFailure(secondBody)) {
      throw AuthenticationExpiredException(
          "教务网登录态失效；HTTP ${response.statusCode}"
          "；Location ${response.headers.value(HttpHeaders.locationHeader) ?? '<缺失>'}"
          "；响应摘要：${responseSummary(secondBody)}");
    }
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw ExceptionWithMessage("教务网登录失败；HTTP ${response.statusCode}"
          "；Content-Type ${response.headers.value(HttpHeaders.contentTypeHeader) ?? '<缺失>'}"
          "；响应摘要：${responseSummary(secondBody)}");
    }

    if (response.cookies.any((element) => element.name == 'JSESSIONID')) {
      _jSessionId = response.cookies
          .firstWhere((element) => element.name == 'JSESSIONID');
    } else {
      throw ExceptionWithMessage(
          "教务网登录无法获取 JSESSIONID；HTTP ${response.statusCode}"
          "；响应摘要：${responseSummary(secondBody)}");
    }

    if (response.cookies.any((element) => element.name == 'route')) {
      _route =
          response.cookies.firstWhere((element) => element.name == 'route');
    } else {
      throw ExceptionWithMessage("教务网登录无法获取 route；HTTP ${response.statusCode}"
          "；响应摘要：${responseSummary(secondBody)}");
    }

    _sessionGeneration++;
    return true;
  }

  void logout() {
    _jSessionId = null;
    _route = null;
    _iPlanetDirectoryPro = null;
    _captcha = null;
  }

  void _validateResponse(HttpClientResponse response, String responseText,
      {required String context,
      required Uri requestUri,
      bool expectJson = true,
      bool relogged = false,
      bool retried = false}) {
    // 教务网用 9xx 非标准状态码表示限频（921 "请求过于频繁"、922 并发被拒等），
    // 由 _withSitePermit 统一退避重试
    if (response.statusCode >= 900 && response.statusCode <= 999) {
      _throttledDuringAction = true;
    }
    try {
      validateResponse(
        response: response,
        body: responseText,
        context: context,
        expectJson: expectJson,
        requestUri: requestUri,
        relogged: relogged,
        retried: retried,
      );
    } on AuthenticationExpiredException catch (error) {
      throw SessionExpiredException(
        shortErrorText(error),
        details: detailedErrorText(error),
        originalError: error,
        stackTrace: error.stackTrace,
      );
    }
  }

  Future<void> _relogin(HttpClient httpClient) async {
    final iPlanetDirectoryPro = _iPlanetDirectoryPro;
    if (iPlanetDirectoryPro == null) {
      throw LoginExpiredException("教务网会话已过期，请重新登录");
    }
    await login(httpClient, iPlanetDirectoryPro);
  }

  Future<T> _withAutoRelogin<T>(HttpClient httpClient,
      Future<T> Function(bool relogged, bool retried) requestFactory) {
    return _withSitePermit(
      () => _withAutoReloginUnlocked(httpClient, requestFactory),
    );
  }

  Future<T> _withAutoReloginUnlocked<T>(HttpClient httpClient,
      Future<T> Function(bool relogged, bool retried) requestFactory) async {
    var relogged = false;
    for (var i = 0; i < 2; i++) {
      var generation = _sessionGeneration;
      var reloginAttempted = false;
      try {
        if (_jSessionId == null || _route == null) {
          reloginAttempted = true;
          await _relogin(httpClient);
          relogged = true;
          generation = _sessionGeneration;
        }
        return await requestFactory(relogged, i > 0);
      } on AuthenticationExpiredException catch (error) {
        if (i == 1 || reloginAttempted) {
          throw LoginExpiredException(
            "教务网会话已过期，请手动重新登录",
            details: detailedErrorText(error),
            originalError: error,
          );
        }
        // 若其它并发请求已更新会话，本请求直接复用，避免重复登录。
        if (_sessionGeneration == generation) {
          await _relogin(httpClient);
          relogged = true;
        }
      }
    }
    throw LoginExpiredException("教务网会话已过期，请手动重新登录");
  }

  /// 教务站请求严格串行（FIFO）且两次请求间至少隔 [_requestGap]。
  ///
  /// 原先允许 3 个并发且无间隔，一次刷新十余个请求挤在 1~2 秒内，
  /// 必然触发教务网限频（921）或首批并发被拒（922），随后整块落缓存。
  /// 被限频时在持有队列的情况下退避重试，退避期间不会有别的请求插队。
  Future<T> _withSitePermit<T>(Future<T> Function() action) async {
    while (_siteBusy) {
      final waiter = Completer<void>();
      _siteWaiters.add(waiter);
      await waiter.future;
    }
    _siteBusy = true;
    try {
      for (var attempt = 0;; attempt++) {
        final last = _lastSiteRequestAt;
        if (last != null) {
          final elapsed = DateTime.now().difference(last);
          if (elapsed < _requestGap) {
            await Future.delayed(_requestGap - elapsed);
          }
        }
        _throttledDuringAction = false;
        _lastSiteRequestAt = DateTime.now();
        final result = await action();
        if (!_throttledDuringAction || attempt >= _throttleBackoffs.length) {
          return result;
        }
        _requestGap = _throttledRequestGap;
        final backoff = _throttleBackoffs[attempt];
        DiagnosticLogService.instance.record(
          level: CelechronLogLevel.warning,
          module: '教务网',
          operation: 'rateLimitBackoff',
          retried: true,
          message: '教务网限频，${backoff.inSeconds} 秒后重试'
              '（第 ${attempt + 1} 次），之后请求间隔放宽到 '
              '${_requestGap.inMilliseconds} ms',
        );
        await Future.delayed(backoff);
        _lastSiteRequestAt = null;
      }
    } finally {
      _siteBusy = false;
      if (_siteWaiters.isNotEmpty) {
        _siteWaiters.removeAt(0).complete();
      }
    }
  }

  _CachedList _cachedList(String cacheKey, String context) {
    // 缓存内容必须重新走与实时响应相同的解析器；损坏缓存视为不可用。
    final cached = _db?.getCachedWebPage(cacheKey);
    if (cached == null || cached.trim().isEmpty) {
      return const _CachedList([], false);
    }
    try {
      final cachedAt = _db?.getCachedWebPage('${cacheKey}_timestamp') ?? '<未知>';
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: context,
        operation: 'readCache',
        cacheUsed: true,
        message: '使用缓存；缓存时间=$cachedAt',
      );
      return _CachedList(
        decodeJsonList(cached, context: context),
        true,
        cachedAt: cachedAt,
      );
    } on Object catch (error, stackTrace) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: context,
        operation: 'readCache',
        cacheUsed: false,
        error: error,
        stackTrace: stackTrace,
      );
      return const _CachedList([], false);
    }
  }

  void _writeCache(String cacheKey, String value) {
    unawaited(Future.wait([
      _db?.setCachedWebPage(cacheKey, value) ?? Future<void>.value(),
      _db?.setCachedWebPage(
            '${cacheKey}_timestamp',
            DateTime.now().toUtc().toIso8601String(),
          ) ??
          Future<void>.value(),
    ]));
  }

  Exception _cacheAwareException(
    Exception exception,
    _CachedList cache,
    String context,
  ) {
    // 返回缓存时仍保留实时异常，并用降级标记告知上层不要清空旧数据。
    if (!cache.used) return exception;
    return CachedDataException(
      '$context：实时请求失败，已使用缓存',
      details: [
        '缓存时间：${cache.cachedAt ?? '<未知>'}',
        detailedErrorText(exception),
      ].join('\n'),
      originalError: exception,
      stackTrace:
          exception is ExceptionWithMessage ? exception.stackTrace : null,
    );
  }

  List<Grade> _parseGrades(Object? raw, String context, {bool major = false}) {
    final items = asDynamicList(raw) ?? const [];
    final grades = <Grade>[];
    for (var index = 0; index < items.length; index++) {
      final item = asStringMap(items[index]);
      if (item == null) {
        if (kDebugMode) {
          debugPrint('$context：跳过第 ${index + 1} 条成绩，条目不是对象');
        }
        continue;
      }
      try {
        final grade = major ? Grade.fromMajor(item) : Grade(item);
        grades.add(grade);
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
              '$context：跳过第 ${index + 1} 条成绩：${error.runtimeType}: $error\n$stackTrace');
        }
      }
    }
    return grades;
  }

  List<Session> _parseSessions(Object? raw, String context) {
    final items = asDynamicList(raw) ?? const [];
    final sessions = <Session>[];
    for (var index = 0; index < items.length; index++) {
      final item = asStringMap(items[index]);
      if (item == null ||
          item['kcb'] == null ||
          asString(item['sfyjskc']) == '1') {
        continue;
      }
      try {
        sessions.add(Session.fromZdbk(item));
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
              '$context：跳过第 ${index + 1} 条课程：${error.runtimeType}: $error\n$stackTrace');
        }
      }
    }
    return sessions;
  }

  List<ExamDto> _parseExams(Object? raw, String context) {
    final items = asDynamicList(raw) ?? const [];
    final exams = <ExamDto>[];
    for (var index = 0; index < items.length; index++) {
      final item = asStringMap(items[index]);
      if (item == null) continue;
      try {
        exams.add(ExamDto.fromZdbk(item));
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
              '$context：跳过第 ${index + 1} 条考试：${error.runtimeType}: $error\n$stackTrace');
        }
      }
    }
    return exams;
  }

  Future<Tuple<Exception?, Tuple<List<double>, String>>> getMajorGrade(
      HttpClient httpClient) async {
    return await _withAutoRelogin(httpClient, (relogged, retried) async {
      late HttpClientRequest request;
      late HttpClientResponse response;
      final uri = Uri.parse(
          "https://zdbk.zju.edu.cn/jwglxt/zycjtj/xszgkc_cxXsZgkcIndex.html?doType=query&queryModel.showCount=5000");

      try {
        request = await httpClient.postUrl(uri).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout());
        request.headers
          ..add("Referer",
              "https://zdbk.zju.edu.cn/jwglxt/xtgl/index_initMenu.html")
          ..set('Connection', 'close')
          ..add('User-Agent',
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36')
          ..add('Accept', 'application/json, text/javascript, */*; q=0.01')
          ..add('X-Requested-With', 'XMLHttpRequest');
        request.cookies.add(_jSessionId!);
        request.cookies.add(_route!);
        request.followRedirects = false;
        response = await request.close().timeout(const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout());

        var responseText =
            await readResponseBody(response, context: '教务网主修成绩接口');
        const context = '教务网主修成绩接口';
        _validateResponse(response, responseText,
            context: context,
            requestUri: uri,
            relogged: relogged,
            retried: retried);
        final payload = decodeJsonMap(responseText,
            context: '$context；HTTP ${response.statusCode}');
        final items = asDynamicList(payload['items']);
        if (items == null) {
          throw ExceptionWithMessage(
              '$context：缺少 items 数组；HTTP ${response.statusCode}'
              '；响应摘要：${responseSummary(responseText)}');
        }
        final grades = _parseGrades(items, context, major: true);
        var majorGpa = GpaHelper.calculateGpa(grades);
        _writeCache('zdbk_MajorGrade', jsonEncode(items));
        return Tuple(
            null, Tuple([majorGpa.item1[0], majorGpa.item2], responseText));
      } on Object catch (error, stackTrace) {
        if (error is AuthenticationExpiredException) rethrow;
        final exception = exceptionFrom(error,
            context: '教务网主修成绩接口',
            requestUri: uri,
            relogged: relogged,
            retried: retried,
            stackTrace: stackTrace);
        final cachedItems = _cachedList('zdbk_MajorGrade', '教务网主修成绩缓存');
        final grades = _parseGrades(cachedItems.data, '教务网主修成绩缓存', major: true);
        var majorGpa = GpaHelper.calculateGpa(grades);
        return Tuple(
            _cacheAwareException(exception, cachedItems, '教务网主修成绩'),
            Tuple([majorGpa.item1[0], majorGpa.item2],
                '{"items":${jsonEncode(cachedItems.data)},"limit":0}'));
      }
    });
  }

  Future<Tuple<Exception?, Iterable<Grade>>> getTranscript(
      HttpClient httpClient) async {
    return await _withAutoRelogin(httpClient, (relogged, retried) async {
      late HttpClientRequest request;
      late HttpClientResponse response;
      final uri = Uri.parse(
          "https://zdbk.zju.edu.cn/jwglxt/cxdy/xscjcx_cxXscjIndex.html?doType=query&queryModel.showCount=5000");

      try {
        request = await httpClient.postUrl(uri).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout());
        request.headers
          ..add("Referer",
              "https://zdbk.zju.edu.cn/jwglxt/xtgl/index_initMenu.html")
          ..set('Connection', 'close')
          ..add('User-Agent',
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36')
          ..add('Accept', 'application/json, text/javascript, */*; q=0.01')
          ..add('X-Requested-With', 'XMLHttpRequest');
        request.cookies.add(_jSessionId!);
        request.cookies.add(_route!);
        request.followRedirects = false;
        response = await request.close().timeout(const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout());

        var responseText = await readResponseBody(response, context: '教务网成绩接口');
        const context = '教务网成绩接口';
        _validateResponse(response, responseText,
            context: context,
            requestUri: uri,
            relogged: relogged,
            retried: retried);
        final payload = decodeJsonMap(responseText,
            context: '$context；HTTP ${response.statusCode}');
        final items = asDynamicList(payload['items']);
        if (items == null) {
          throw ExceptionWithMessage(
              '$context：缺少 items 数组；HTTP ${response.statusCode}'
              '；响应摘要：${responseSummary(responseText)}');
        }
        final grades = _parseGrades(items, context);
        _writeCache('zdbk_Transcript', jsonEncode(items));
        return Tuple(null, grades);
      } on Object catch (error, stackTrace) {
        if (error is AuthenticationExpiredException) rethrow;
        final exception = exceptionFrom(error,
            context: '教务网成绩接口',
            requestUri: uri,
            relogged: relogged,
            retried: retried,
            stackTrace: stackTrace);
        final cached = _cachedList('zdbk_Transcript', '教务网成绩缓存');
        return Tuple(
          _cacheAwareException(exception, cached, '教务网成绩'),
          _parseGrades(cached.data, '教务网成绩缓存'),
        );
      }
    });
  }

  static String _localDayStamp(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  /// 缓存是否写于学年 [year]（如 2024-2025）结束之后；学年中途写入的缓存可能不完整。
  static bool _cachedAfterAcademicYear(String? cachedAt, String year) {
    final endYear = int.tryParse(year.length >= 9 ? year.substring(5, 9) : '');
    final at = cachedAt == null ? null : DateTime.tryParse(cachedAt);
    if (endYear == null || at == null) return false;
    return at.isAfter(DateTime.utc(endYear, DateTime.august, 1));
  }

  /// [preferCache] 用于已结束的学年：其课表不会再变，有学年结束后写入的
  /// 非空缓存就直接使用，不再请求教务网，以减少触发限频的请求数。
  Future<Tuple<Exception?, Iterable<Session>>> getTimetable(
      HttpClient httpClient, String year, String semester,
      {bool preferCache = false}) async {
    final cacheKey = 'zdbk_Timetable$year$semester';
    final emptyStampKey = '${cacheKey}_emptyOn';
    final isFuture =
        isFutureSemester('$year-${semester.substring(0, 1)}', DateTime.now());

    if (preferCache) {
      final cached = _cachedList(cacheKey, '教务网课表缓存（学年 $year，学期 $semester）');
      if (cached.data.isNotEmpty &&
          _cachedAfterAcademicYear(cached.cachedAt, year)) {
        return Tuple(null, _parseSessions(cached.data, '教务网课表缓存'));
      }
    }
    // 未开学的学期当天已确认为空就不再重复请求；当前学期不受此限，
    // 选课期间随时可能出新课
    if (isFuture &&
        _db?.getCachedWebPage(emptyStampKey) ==
            _localDayStamp(DateTime.now())) {
      DiagnosticLogService.instance.record(
        module: '课表',
        operation: 'skipKnownEmpty',
        message: '$year $semester 尚未开学且今天已确认为空，本次跳过',
      );
      return Tuple(null, <Session>[]);
    }

    return await _withAutoRelogin(httpClient, (relogged, retried) async {
      late HttpClientRequest request;
      late HttpClientResponse response;
      final uri =
          Uri.parse("https://zdbk.zju.edu.cn/jwglxt/kbcx/xskbcx_cxXsKb.html");

      try {
        for (var i = 0; i < 3; i++) {
          request = await httpClient.postUrl(uri).timeout(
              const Duration(seconds: 8),
              onTimeout: () => throw requestTimeout());
          request.headers
            ..add("Referer",
                "https://zdbk.zju.edu.cn/jwglxt/xtgl/index_initMenu.html")
            ..set('Connection', 'close')
            ..add('User-Agent',
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36')
            ..add('Accept', 'application/json, text/javascript, */*; q=0.01')
            ..add('X-Requested-With', 'XMLHttpRequest');
          request.cookies.add(_jSessionId!);
          request.cookies.add(_route!);
          request.followRedirects = false;
          request.headers.contentType = ContentType(
              'application', 'x-www-form-urlencoded',
              charset: 'utf-8');
          request.add(
              utf8.encode('xnm=$year&xqm=$semester&captcha_value=$_captcha'));
          response = await request.close().timeout(const Duration(seconds: 8),
              onTimeout: () => throw requestTimeout());

          var responseText =
              await readResponseBody(response, context: '教务网课表接口');
          final context = '教务网课表接口（学年 $year，学期 $semester，请求类型 课表）';
          _validateResponse(response, responseText,
              context: context,
              requestUri: uri,
              relogged: relogged,
              retried: retried);

          if (responseText.contains("captcha_error")) {
            _captcha = null;
            if (GlobalStatus.isFirstScreenReq) {
              throw ExceptionWithMessage("需要验证码");
            }
            var imageBytes = await getCaptcha(httpClient);
            var captcha = await ImageCodePortal.show(
                imageBytes: imageBytes,
                onRefresh: () async {
                  return await getCaptcha(httpClient);
                });
            if (captcha == null) {
              throw ExceptionWithMessage("验证码未填写");
            }
            _captcha = captcha.trim();
            continue;
          }

          final List<dynamic> items;
          if (responseText.trim() == "null") {
            items = const [];
          } else {
            final payload = decodeJsonMap(responseText,
                context: '$context；HTTP ${response.statusCode}');
            final kbList = asDynamicList(payload['kbList']);
            if (kbList == null) {
              throw ExceptionWithMessage(
                  '$context：缺少 kbList 数组；HTTP ${response.statusCode}'
                  '；响应摘要：${responseSummary(responseText)}');
            }
            items = kbList;
          }

          // 选课/筛课期间教务网会 HTTP 200 但返回 0 行（issue #174）。
          // 空结果不写缓存，有上次的非空课表就沿用，避免课表被一次刷新清空
          if (items.isEmpty) {
            if (isFuture) {
              await _db?.setCachedWebPage(
                  emptyStampKey, _localDayStamp(DateTime.now()));
            }
            final cached = _cachedList(cacheKey, '$context 缓存');
            if (cached.data.isNotEmpty) {
              DiagnosticLogService.instance.record(
                level: CelechronLogLevel.warning,
                module: '课表',
                operation: 'emptyResponse',
                cacheUsed: true,
                message: '$context：返回 0 行（选课期间常见），沿用上次的课表'
                    '（${cached.data.length} 条，缓存时间 ${cached.cachedAt}）',
              );
              return Tuple(null, _parseSessions(cached.data, '$context 缓存'));
            }
            return Tuple(null, <Session>[]);
          }

          final sessions = _parseSessions(items, context);
          _writeCache(cacheKey, jsonEncode(items));
          return Tuple(null, sessions);
        }
        throw ExceptionWithMessage("验证码识别失败");
      } on Object catch (error, stackTrace) {
        if (error is AuthenticationExpiredException) rethrow;
        final context = '教务网课表接口（学年 $year，学期 $semester，请求类型 课表）';
        final exception = exceptionFrom(error,
            context: context,
            requestUri: uri,
            relogged: relogged,
            retried: retried,
            stackTrace: stackTrace);
        final cached =
            _cachedList('zdbk_Timetable$year$semester', '$context 缓存');
        return Tuple(
          _cacheAwareException(exception, cached, context),
          _parseSessions(cached.data, '$context 缓存'),
        );
      }
    });
  }

  Future<Tuple<Exception?, Iterable<ExamDto>>> getExamsDto(
      HttpClient httpClient) async {
    return await _withAutoRelogin(httpClient, (relogged, retried) async {
      late HttpClientRequest request;
      late HttpClientResponse response;
      final uri = Uri.parse(
          "https://zdbk.zju.edu.cn/jwglxt/xskscx/kscx_cxXsgrksIndex.html?doType=query&queryModel.showCount=5000");

      try {
        request = await httpClient.postUrl(uri).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout());
        request.headers
          ..add("Referer",
              "https://zdbk.zju.edu.cn/jwglxt/xtgl/index_initMenu.html")
          ..set('Connection', 'close')
          ..add('User-Agent',
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36')
          ..add('Accept', 'application/json, text/javascript, */*; q=0.01')
          ..add('X-Requested-With', 'XMLHttpRequest');
        request.cookies.add(_jSessionId!);
        request.cookies.add(_route!);
        request.followRedirects = false;
        response = await request.close().timeout(const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout());

        var responseText = await readResponseBody(response, context: '教务网考试接口');
        const context = '教务网考试接口（请求类型 考试）';
        _validateResponse(response, responseText,
            context: context,
            requestUri: uri,
            relogged: relogged,
            retried: retried);
        final payload = decodeJsonMap(responseText,
            context: '$context；HTTP ${response.statusCode}');
        final items = asDynamicList(payload['items']);
        if (items == null) {
          throw ExceptionWithMessage(
              '$context：缺少 items 数组；HTTP ${response.statusCode}'
              '；响应摘要：${responseSummary(responseText)}');
        }
        final exams = _parseExams(items, context);
        _writeCache('zdbk_exams', jsonEncode(items));
        return Tuple(null, exams);
      } on Object catch (error, stackTrace) {
        if (error is AuthenticationExpiredException) rethrow;
        final exception = exceptionFrom(error,
            context: '教务网考试接口（请求类型 考试）',
            requestUri: uri,
            relogged: relogged,
            retried: retried,
            stackTrace: stackTrace);
        final cached = _cachedList('zdbk_exams', '教务网考试缓存');
        return Tuple(
          _cacheAwareException(exception, cached, '教务网考试'),
          _parseExams(cached.data, '教务网考试缓存'),
        );
      }
    });
  }

  Future<Tuple<Exception?, Map<String, double>>> getPracticeScores(
      HttpClient httpClient, String studentId) async {
    return await _withAutoRelogin(httpClient, (relogged, retried) async {
      late HttpClientRequest request;
      late HttpClientResponse response;
      final uri = Uri.parse(
          "https://zdbk.zju.edu.cn/jwglxt/dessktgl/dessktcx_cxDessktcxIndex.html?gnmkdm=N108001&layout=default&su=$studentId");

      try {
        request = await httpClient.getUrl(uri).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout());
        request.headers
          ..add("Referer",
              "https://zdbk.zju.edu.cn/jwglxt/xtgl/index_initMenu.html")
          ..set('Connection', 'close')
          ..add('User-Agent',
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36')
          ..add('Accept',
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
        request.cookies.add(_jSessionId!);
        request.cookies.add(_route!);
        request.followRedirects = false;
        response = await request.close().timeout(const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout());

        var html = await readResponseBody(response, context: '教务网实践分接口');
        _validateResponse(response, html,
            context: '教务网实践分接口（学号 $studentId，请求类型 实践分）',
            requestUri: uri,
            expectJson: false,
            relogged: relogged,
            retried: retried);

        _writeCache("zdbk_practiceScores", html);

        var scores = <String, double>{
          'pt2': 0.0,
          'pt3': 0.0,
          'pt4': 0.0,
        };

        var rowPattern = RegExp(
            r'<tr>.*?<td[^>]*>.*?</td>.*?<td[^>]*>(.*?)</td>.*?<td[^>]*>(.*?)</td>.*?</tr>',
            dotAll: true);
        var matches = rowPattern.allMatches(html);

        for (var match in matches) {
          var type = match.group(1)?.trim();
          var scoreStr = match.group(2)?.trim();
          if (type == null || scoreStr == null) continue;

          final score = double.tryParse(scoreStr);
          if (score == null) continue;

          if (type.contains('第二课堂')) {
            scores['pt2'] = score;
          } else if (type.contains('第三课堂')) {
            scores['pt3'] = score;
          } else if (type.contains('第四课堂')) {
            scores['pt4'] = score;
          }
        }

        if (scores['pt2'] == 0.0 &&
            scores['pt3'] == 0.0 &&
            scores['pt4'] == 0.0) {
          var altPattern = RegExp(
              r'<td[^>]*>第二课堂</td>.*?<td[^>]*>([0-9.]+)</td>',
              dotAll: true);
          var pt2Match = altPattern.firstMatch(html);
          if (pt2Match != null) {
            scores['pt2'] = double.tryParse(pt2Match.group(1) ?? '0') ?? 0.0;
          }

          altPattern = RegExp(r'<td[^>]*>第三课堂</td>.*?<td[^>]*>([0-9.]+)</td>',
              dotAll: true);
          var pt3Match = altPattern.firstMatch(html);
          if (pt3Match != null) {
            scores['pt3'] = double.tryParse(pt3Match.group(1) ?? '0') ?? 0.0;
          }

          altPattern = RegExp(r'<td[^>]*>第四课堂</td>.*?<td[^>]*>([0-9.]+)</td>',
              dotAll: true);
          var pt4Match = altPattern.firstMatch(html);
          if (pt4Match != null) {
            scores['pt4'] = double.tryParse(pt4Match.group(1) ?? '0') ?? 0.0;
          }
        }

        return Tuple(null, scores);
      } on Object catch (error, stackTrace) {
        if (error is AuthenticationExpiredException) rethrow;

        final exception = exceptionFrom(error,
            context: '教务网实践分接口（学号 $studentId，请求类型 实践分）',
            requestUri: uri,
            relogged: relogged,
            retried: retried,
            stackTrace: stackTrace);

        var cachedHtml = _db?.getCachedWebPage("zdbk_practiceScores");
        if (cachedHtml != null) {
          try {
            var scores = <String, double>{
              'pt2': 0.0,
              'pt3': 0.0,
              'pt4': 0.0,
            };
            var altPattern = RegExp(
                r'<td[^>]*>第二课堂</td>.*?<td[^>]*>([0-9.]+)</td>',
                dotAll: true);
            var pt2Match = altPattern.firstMatch(cachedHtml);
            if (pt2Match != null) {
              scores['pt2'] = double.tryParse(pt2Match.group(1) ?? '0') ?? 0.0;
            }

            altPattern = RegExp(r'<td[^>]*>第三课堂</td>.*?<td[^>]*>([0-9.]+)</td>',
                dotAll: true);
            var pt3Match = altPattern.firstMatch(cachedHtml);
            if (pt3Match != null) {
              scores['pt3'] = double.tryParse(pt3Match.group(1) ?? '0') ?? 0.0;
            }

            altPattern = RegExp(r'<td[^>]*>第四课堂</td>.*?<td[^>]*>([0-9.]+)</td>',
                dotAll: true);
            var pt4Match = altPattern.firstMatch(cachedHtml);
            if (pt4Match != null) {
              scores['pt4'] = double.tryParse(pt4Match.group(1) ?? '0') ?? 0.0;
            }
            final cachedException = CachedDataException(
              '教务网实践分：实时请求失败，已使用缓存',
              details: detailedErrorText(exception),
              originalError: exception,
            );
            return Tuple(cachedException, scores);
          } on Object catch (cacheError, cacheStackTrace) {
            DiagnosticLogService.instance.record(
              level: CelechronLogLevel.warning,
              module: '教务网实践分',
              operation: 'readCache',
              cacheUsed: false,
              error: cacheError,
              stackTrace: cacheStackTrace,
            );
          }
        }
        return Tuple(exception, {'pt2': 0.0, 'pt3': 0.0, 'pt4': 0.0});
      }
    });
  }

  Future<Uint8List> getCaptcha(HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    if (_jSessionId == null || _route == null) {
      throw ExceptionWithMessage("未登录");
    }
    request = await httpClient
        .getUrl(Uri.parse(
            "https://zdbk.zju.edu.cn/jwglxt/kaptcha?time=${DateTime.now().millisecondsSinceEpoch}"))
        .timeout(const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout());
    request.cookies.add(_jSessionId!);
    request.cookies.add(_route!);
    request.followRedirects = false;
    response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw requestTimeout());
    var bytes = await consolidateHttpClientResponseBytes(response);
    final contentType =
        response.headers.value(HttpHeaders.contentTypeHeader) ?? '<缺失>';
    final location = response.headers.value(HttpHeaders.locationHeader);
    if (response.isRedirect ||
        response.statusCode == HttpStatus.unauthorized ||
        response.statusCode == HttpStatus.forbidden) {
      throw AuthenticationExpiredException(
          '教务网验证码接口：登录态已失效；HTTP ${response.statusCode}'
          '${location == null ? '' : '；Location $location'}');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        !contentType.toLowerCase().startsWith('image/')) {
      final body = utf8.decode(bytes, allowMalformed: true);
      throw ExceptionWithMessage('教务网验证码接口返回异常；HTTP ${response.statusCode}'
          '；Content-Type $contentType'
          '${location == null ? '' : '；Location $location'}'
          '；响应摘要：${responseSummary(body)}');
    }
    return bytes;
  }

  Future<String> solveCaptcha(HttpClient httpClient) async {
    throw UnimplementedError("验证码识别功能未开发");
  }
}

class _CachedList {
  final List<dynamic> data;
  final bool used;
  final String? cachedAt;

  const _CachedList(this.data, this.used, {this.cachedAt});
}
