import 'dart:convert';
import 'dart:io';

import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:celechron/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'exceptions.dart';
import 'response_utils.dart';

class _ActiveSsoCookie {
  final Cookie cookie;
  final DateTime expiresAt;

  _ActiveSsoCookie(this.cookie, this.expiresAt);
}

class _SsoLoginKey {
  final HttpClient httpClient;
  final String username;

  const _SsoLoginKey(this.httpClient, this.username);

  @override
  bool operator ==(Object other) =>
      other is _SsoLoginKey &&
      identical(httpClient, other.httpClient) &&
      username == other.username;

  @override
  int get hashCode => Object.hash(identityHashCode(httpClient), username);
}

/// 统一身份认证入口。同一进程内的并发消费者共享一次密码登录，
/// 但不再从持久化存储恢复 iPlanetDirectoryPro。该 Cookie 的服务端寿命和
/// 轮换规则不可靠，1.2 引入的跨启动复用会把已失效值交给所有子站。
class ZjuAm {
  static const _secureStorage = FlutterSecureStorage();
  static const _processCookieLifetime = Duration(minutes: 2);
  static final Map<_SsoLoginKey, Future<Cookie?>> _pendingLogins = {};
  static final Map<_SsoLoginKey, _ActiveSsoCookie> _activeCookies = {};

  static final Uri graduateServiceUri = Uri.parse('https://yjsy.zju.edu.cn/');

  static Future<Cookie?> getSsoCookie(
      HttpClient httpClient, String username, String password) async {
    final key = _SsoLoginKey(httpClient, username);
    final active = _activeSsoCookie(key);
    if (active != null) {
      return active;
    }

    // 同一 HttpClient、同一账号共享一次登录任务；不同客户端保持隔离。
    final pending = _pendingLogins[key];
    if (pending != null) return await pending;

    final login = _createFreshSsoCookie(httpClient, username, password);
    _pendingLogins[key] = login;
    try {
      final cookie = await login;
      if (cookie != null) {
        _activeCookies[key] = _ActiveSsoCookie(
          cookie,
          DateTime.now().add(_processCookieLifetime),
        );
      }
      return cookie;
    } finally {
      if (identical(_pendingLogins[key], login)) {
        _pendingLogins.remove(key);
      }
    }
  }

  static Cookie? _activeSsoCookie(_SsoLoginKey key) {
    final active = _activeCookies[key];
    if (active == null) return null;
    if (DateTime.now().isBefore(active.expiresAt)) {
      return active.cookie;
    }
    _activeCookies.remove(key);
    return null;
  }

  static Future<Cookie?> _createFreshSsoCookie(
      HttpClient httpClient, String username, String password) async {
    // 先删除 1.2 时期留下的值，防止降级后的旧版本再读取。
    await _deleteLegacyCachedSsoCookie(username);
    return _getSsoCookie(httpClient, username, password);
  }

  static String _cookieStorageKey(String username) =>
      'zju_sso_cookie_$username';

  static Future<void> clearCachedSsoCookie(String username) {
    _activeCookies.removeWhere((key, _) => key.username == username);
    return _deleteLegacyCachedSsoCookie(username);
  }

  static Future<void> _deleteLegacyCachedSsoCookie(String username) {
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
    Uri service, {
    String context = 'CAS service 登录',
  }) async {
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
      final body =
          await readResponseBody(response, context: '$context CAS service');
      DiagnosticLogService.instance.record(
        module: context,
        operation: 'casService',
        requestUri: uri,
        statusCode: statusCode,
        contentType: contentType,
        location: location,
        durationMs: DateTime.now().difference(startedAt).inMilliseconds,
        message: 'CAS service ticket 响应已读取',
      );
      if (!isHttpRedirectStatus(statusCode) ||
          location == null ||
          location.isEmpty) {
        final details = 'HTTP $statusCode\n'
            'Content-Type：${contentType ?? '<缺失>'}\n'
            '响应摘要：${responseSummary(body)}';
        // CAS returns its HTTP 200 login page (or an explicit auth status)
        // when the SSO cookie is no longer usable. Other statuses are
        // transport/protocol failures and must not invalidate a good cache.
        if (statusCode == HttpStatus.ok ||
            statusCode == HttpStatus.unauthorized ||
            statusCode == HttpStatus.forbidden) {
          throw AuthenticationExpiredException(
            '$context：未获得 CAS ticket',
            details: details,
          );
        }
        throw ExceptionWithMessage(
          '$context：CAS service 请求失败',
          details: details,
        );
      }
      final callback = uri.resolve(location);
      if (!_isValidServiceCallback(callback, service)) {
        throw ExceptionWithMessage('$context：CAS service 回调无效');
      }
      return callback;
    } on Object catch (error, stackTrace) {
      throw exceptionFrom(
        error,
        context: context,
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

  static bool _isValidServiceCallback(Uri callback, Uri service) {
    final ticket = callback.queryParameters['ticket'];
    return callback.scheme == service.scheme &&
        callback.host == service.host &&
        callback.port == service.port &&
        callback.path == service.path &&
        ticket != null &&
        ticket.isNotEmpty;
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

      final now = DateTime.now();
      final ssoCookies = response.cookies
          .where((cookie) =>
              cookie.name == 'iPlanetDirectoryPro' &&
              cookie.value.isNotEmpty &&
              (cookie.maxAge == null || cookie.maxAge! > 0) &&
              (cookie.expires == null || cookie.expires!.isAfter(now)))
          .toList();
      if (ssoCookies.isNotEmpty) {
        // 取响应中最后一个未过期值，避免前面的删除 Cookie 被误用。
        final cookie = ssoCookies.last;
        if (cookie.domain == null || cookie.domain!.trim().isEmpty) {
          cookie.domain = 'zju.edu.cn';
        }
        if (cookie.path == null || cookie.path!.trim().isEmpty) {
          cookie.path = '/';
        }
        return cookie;
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
