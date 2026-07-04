import 'dart:convert';
import 'dart:io';
import 'package:celechron/utils/tuple.dart';
import 'package:flutter/foundation.dart';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/utils/gpa_helper.dart';
import 'package:celechron/model/grade.dart';
import 'package:celechron/model/session.dart';
import 'package:celechron/model/exams_dto.dart';
import 'package:celechron/design/captcha_input.dart';
import 'package:celechron/utils/global.dart';
import 'exceptions.dart';
import 'response_utils.dart';

// 定义一个特定的会话过期异常，方便上层捕获重试
class SessionExpiredException extends LoginExpiredException {
  SessionExpiredException(
    super.message, {
    super.details,
    super.originalError,
    super.stackTrace,
  });
}

class Zdbk {
  Cookie? _jSessionId;
  Cookie? _route;
  Cookie? _iPlanetDirectoryPro; // 新增：保存登录凭据
  String? _captcha;
  DatabaseHelper? _db;
  Future<bool>? _loginFuture;
  int _sessionGeneration = 0;

  set db(DatabaseHelper? db) {
    _db = db;
  }

  Future<bool> login(HttpClient httpClient, Cookie? iPlanetDirectoryPro) async {
    if (iPlanetDirectoryPro == null) {
      throw AuthenticationExpiredException("教务网：统一身份认证凭据无效");
    }
    _iPlanetDirectoryPro = iPlanetDirectoryPro;
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
    _captcha = null;
    _iPlanetDirectoryPro = null;
  }

  void _validateResponse(HttpClientResponse response, String responseText,
      {required String context,
      required Uri requestUri,
      bool expectJson = true,
      bool relogged = false,
      bool retried = false}) {
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
    if (_iPlanetDirectoryPro == null) {
      throw ExceptionWithMessage("会话已过期，请重新登录");
    }
    await login(httpClient, _iPlanetDirectoryPro);
  }

  Future<T> _withAutoRelogin<T>(HttpClient httpClient,
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
        if (_sessionGeneration == generation) {
          await _relogin(httpClient);
          relogged = true;
        }
      }
    }
    throw LoginExpiredException("教务网会话已过期，请手动重新登录");
  }

  List<dynamic> _cachedList(String cacheKey, String context) {
    final cached = _db?.getCachedWebPage(cacheKey);
    if (cached == null || cached.trim().isEmpty) return [];
    try {
      return decodeJsonList(cached, context: context);
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('$context 读取失败：${error.runtimeType}: $error\n$stackTrace');
      }
      return [];
    }
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
        _db?.setCachedWebPage('zdbk_MajorGrade', jsonEncode(items));
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
        final grades = _parseGrades(cachedItems, '教务网主修成绩缓存', major: true);
        var majorGpa = GpaHelper.calculateGpa(grades);
        return Tuple(
            exception,
            Tuple([majorGpa.item1[0], majorGpa.item2],
                '{"items":${jsonEncode(cachedItems)},"limit":0}'));
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
        _db?.setCachedWebPage('zdbk_Transcript', jsonEncode(items));
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
        return Tuple(exception, _parseGrades(cached, '教务网成绩缓存'));
      }
    });
  }

  Future<Tuple<Exception?, Iterable<Session>>> getTimetable(
      HttpClient httpClient, String year, String semester) async {
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
          request.headers.contentType = ContentType(
              'application', 'x-www-form-urlencoded',
              charset: 'utf-8');
          request.add(
              utf8.encode('xnm=$year&xqm=$semester&captcha_value=$_captcha'));
          request.followRedirects = false;
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

          if (responseText.trim() == "null") return Tuple(null, <Session>[]);
          final payload = decodeJsonMap(responseText,
              context: '$context；HTTP ${response.statusCode}');
          final items = asDynamicList(payload['kbList']);
          if (items == null) {
            throw ExceptionWithMessage(
                '$context：缺少 kbList 数组；HTTP ${response.statusCode}'
                '；响应摘要：${responseSummary(responseText)}');
          }
          final sessions = _parseSessions(items, context);
          _db?.setCachedWebPage(
              'zdbk_Timetable$year$semester', jsonEncode(items));
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
        return Tuple(exception, _parseSessions(cached, '$context 缓存'));
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
        _db?.setCachedWebPage('zdbk_exams', jsonEncode(items));
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
        return Tuple(exception, _parseExams(cached, '教务网考试缓存'));
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

        _db?.setCachedWebPage("zdbk_practiceScores", html);

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

          double? score;
          try {
            score = double.tryParse(scoreStr);
          } catch (_) {
            continue;
          }
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
            return Tuple(exception, scores);
          } catch (_) {}
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
