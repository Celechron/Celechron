import 'dart:convert';
import 'dart:io';

import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:celechron/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'exceptions.dart';
import 'response_utils.dart';

/// 统一身份认证入口，负责共享 SSO Cookie 及按 service 签发的一次性回调。
class ZjuAm {
  static const _secureStorage = FlutterSecureStorage();
  static final Map<String, Future<Cookie?>> _pendingLogins = {};

  static Future<Cookie?> getSsoCookie(
      HttpClient httpClient, String username, String password) async {
    // 同一账号共享一次登录任务，避免并发提交密码和互相覆盖缓存。
    final pending = _pendingLogins[username];
    if (pending != null) return await pending;

    final login = _getOrCreateSsoCookie(httpClient, username, password);
    _pendingLogins[username] = login;
    try {
      return await login;
    } finally {
      if (identical(_pendingLogins[username], login)) {
        _pendingLogins.remove(username);
      }
    }
  }

  static Future<Cookie?> _getOrCreateSsoCookie(
      HttpClient httpClient, String username, String password) async {
    // 缓存命中仍需向 CAS 验证；失效值先清除，再执行完整登录。
    final cached = await _readCachedSsoCookie(username);
    if (cached != null && await _isCachedSsoCookieValid(httpClient, cached)) {
      return cached;
    }
    await clearCachedSsoCookie(username);
    final cookie = await _getSsoCookie(httpClient, username, password);
    if (cookie != null) {
      await _saveSsoCookie(username, cookie);
    }
    return cookie;
  }

  static String _cookieStorageKey(String username) =>
      'zju_sso_cookie_$username';

  static Future<Cookie?> _readCachedSsoCookie(String username) async {
    try {
      final raw = await _secureStorage.read(
        key: _cookieStorageKey(username),
        iOptions: secureStorageIOSOptions,
      );
      if (raw == null) return null;
      final data = decodeJsonMap(raw, context: '统一身份认证共享登录态缓存');
      final value = asString(data['value']);
      final savedAt = asDateTime(data['savedAt']);
      if (value == null ||
          value.isEmpty ||
          savedAt == null ||
          DateTime.now().difference(savedAt) > const Duration(hours: 12)) {
        return null;
      }
      return Cookie('iPlanetDirectoryPro', value)
        ..domain = 'zju.edu.cn'
        ..path = '/';
    } on Object catch (error, stackTrace) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: '统一身份认证',
        operation: 'readSharedSsoCache',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static Future<void> _saveSsoCookie(String username, Cookie cookie) async {
    await _secureStorage.write(
      key: _cookieStorageKey(username),
      value: jsonEncode({
        'value': cookie.value,
        'savedAt': DateTime.now().toIso8601String(),
      }),
      iOptions: secureStorageIOSOptions,
    );
  }

  static Future<void> clearCachedSsoCookie(String username) {
    return _secureStorage.delete(
      key: _cookieStorageKey(username),
      iOptions: secureStorageIOSOptions,
    );
  }

  /// Requests a fresh, single-use CAS service ticket and returns only its
  /// callback URI. The URI must be consumed immediately and never persisted.
  static Future<Uri> getServiceCallback(
    HttpClient httpClient,
    Cookie iPlanetDirectoryPro,
    Uri service,
  ) async {
    final uri = buildServiceLoginUri(service);
    final startedAt = DateTime.now();
    try {
      final request = await httpClient.getUrl(uri).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout('CAS service 请求超时'),
          );
      request.followRedirects = false;
      request.cookies.add(
        Cookie(iPlanetDirectoryPro.name, iPlanetDirectoryPro.value),
      );
      final response = await request.close().timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout('CAS service 响应超时'),
          );
      final location = response.headers.value(HttpHeaders.locationHeader);
      final statusCode = response.statusCode;
      final contentType = response.headers.value(HttpHeaders.contentTypeHeader);
      await response.drain<void>();
      DiagnosticLogService.instance.record(
        module: '素质拓展登录',
        operation: 'casService',
        requestUri: uri,
        statusCode: statusCode,
        contentType: contentType,
        durationMs: DateTime.now().difference(startedAt).inMilliseconds,
        message: 'CAS service ticket 响应已读取',
      );
      if (!isHttpRedirectStatus(statusCode) ||
          location == null ||
          location.isEmpty) {
        throw AuthenticationExpiredException(
          'CAS 未返回素质拓展 service 回调；HTTP $statusCode',
        );
      }
      final callback = uri.resolve(location);
      final ticket = callback.queryParameters['ticket'];
      final validTarget = callback.scheme == service.scheme &&
          callback.host == service.host &&
          callback.port == service.port &&
          callback.path == service.path;
      if (!validTarget || ticket == null || ticket.isEmpty) {
        throw AuthenticationExpiredException('CAS 返回的素质拓展 service 回调无效');
      }
      return callback;
    } on Object catch (error, stackTrace) {
      throw exceptionFrom(
        error,
        context: '素质拓展登录',
        requestUri: uri,
        stackTrace: stackTrace,
      );
    }
  }

  @visibleForTesting
  static Uri buildServiceLoginUri(Uri service) => Uri.https(
        'zjuam.zju.edu.cn',
        '/cas/login',
        {'service': service.toString()},
      );

  static Future<bool> _isCachedSsoCookieValid(
      HttpClient httpClient, Cookie cookie) async {
    // 验证请求只检查 CAS 是否能签发 ticket；ticket 本身不会被保存或消费。
    final uri = Uri.parse(
        'https://zjuam.zju.edu.cn/cas/login?service=https%3A%2F%2Fyjsy.zju.edu.cn%2F');
    try {
      final request = await httpClient.getUrl(uri).timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw requestTimeout());
      request.followRedirects = false;
      request.cookies.add(cookie);
      final response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw requestTimeout());
      await response.drain();
      final location = response.headers.value(HttpHeaders.locationHeader);
      return isHttpRedirectStatus(response.statusCode) &&
          location != null &&
          Uri.tryParse(location)?.queryParameters['ticket']?.isNotEmpty == true;
    } on Object catch (error, stackTrace) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: '统一身份认证',
        operation: 'validateSharedSsoCache',
        requestUri: uri,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  static Future<Cookie?> _getSsoCookie(
      HttpClient httpClient, String username, String password) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      // execution 与初始 Cookie 属于同一次 CAS 表单会话，必须先取登录页。
      request = await httpClient
          .getUrl(Uri.parse('https://zjuam.zju.edu.cn/cas/login'))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw requestTimeout());
      request.followRedirects = false;
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw requestTimeout());

      var cookies = List<Cookie>.from(response.cookies);
      var body = await readResponseBody(response, context: '统一身份认证登录页');
      final loginLocation = response.headers.value(HttpHeaders.locationHeader);
      if (response.statusCode != HttpStatus.ok) {
        throw LoginException('统一身份认证登录页请求失败；HTTP ${response.statusCode}'
            '${loginLocation == null ? '' : '；Location $loginLocation'}'
            '；响应摘要：${responseSummary(body)}');
      }
      var execution =
          RegExp(r'name="execution" value="(.*?)"').firstMatch(body)?.group(1);
      if (execution == null) {
        throw LoginException(
            '统一身份认证登录页无法获取 execution；HTTP ${response.statusCode}'
            '；响应摘要：${responseSummary(body)}');
      }

      // 公钥请求沿用登录页 Cookie，随后才可加密密码并提交 execution。
      request = await httpClient
          .getUrl(Uri.parse('https://zjuam.zju.edu.cn/cas/v2/getPubKey'))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw requestTimeout());
      request.followRedirects = false;
      request.cookies.addAll(cookies);
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw requestTimeout());

      cookies.addAll(response.cookies);
      body = await readResponseText(
        response,
        context: '统一身份认证 RSA 公钥',
        expectJson: true,
        requestUri: Uri.parse('https://zjuam.zju.edu.cn/cas/v2/getPubKey'),
      );
      final publicKey = decodeJsonMap(body,
          context: '统一身份认证 RSA 公钥；HTTP ${response.statusCode}');
      var modulusStr = asString(publicKey['modulus']);
      var exponentStr = asString(publicKey['exponent']);
      if (modulusStr == null || exponentStr == null) {
        throw LoginException('统一身份认证 RSA 公钥字段缺失；响应摘要：${responseSummary(body)}');
      }

      late String pwdEnc;
      try {
        var modInt = BigInt.parse(modulusStr, radix: 16);
        var expInt = BigInt.parse(exponentStr, radix: 16);
        var pwdInt = BigInt.parse(
            utf8.encode(password).map((e) => e.toRadixString(16)).join(),
            radix: 16);
        var pwdEncInt = pwdInt.modPow(expInt, modInt);
        pwdEnc = pwdEncInt.toRadixString(16).padLeft(128, '0');
      } on Object catch (error, stackTrace) {
        if (error is Error) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        throw LoginException("密码不合法");
      }

      request = await httpClient
          .postUrl(Uri.parse('https://zjuam.zju.edu.cn/cas/login'))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw requestTimeout());
      request.followRedirects = false;
      request.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.cookies.addAll(cookies);
      request.add(utf8.encode(Uri(queryParameters: {
        'username': username,
        'password': pwdEnc,
        'execution': execution,
        '_eventId': 'submit',
        'rememberMe': 'true',
      }).query));
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw requestTimeout());
      body = await readResponseBody(response, context: '统一身份认证登录提交');

      if (response.cookies
          .any((element) => element.name == 'iPlanetDirectoryPro')) {
        return response.cookies
            .firstWhere((element) => element.name == 'iPlanetDirectoryPro');
      } else {
        final location = response.headers.value(HttpHeaders.locationHeader);
        throw LoginException("统一身份认证失败，学号或密码错误，或认证会话已失效"
            "；HTTP ${response.statusCode}"
            "${location == null ? '' : '；Location $location'}"
            "；响应摘要：${responseSummary(body)}");
      }
    } on Object catch (error, stackTrace) {
      throw exceptionFrom(
        error,
        context: '统一身份认证',
        requestUri: Uri.parse('https://zjuam.zju.edu.cn/cas/login'),
        stackTrace: stackTrace,
      );
    }
  }
}
