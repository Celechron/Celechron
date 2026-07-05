import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/http/zjuServices/zjuam.dart';
import 'package:celechron/model/practice_score_item.dart';
import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:celechron/utils/json_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class Sztz {
  static final Uri _serviceUri = Uri.parse('https://sztz.zju.edu.cn/dekt/');
  static final Uri _ctxUri = Uri.parse('https://sztz.zju.edu.cn/dekt/ctx');
  static final Uri _practiceUri =
      Uri.parse('https://sztz.zju.edu.cn/dekt/student/home/getSqjl');
  static const _practiceAccept =
      'text/html,application/xhtml+xml,application/xml;q=0.9,'
      'image/avif,image/webp,image/apng,*/*;q=0.8,'
      'application/signed-exchange;v=b3;q=0.7';

  final String _accountScope;
  final List<_StoredCookie> _cookies = [];
  DatabaseHelper? _db;
  Cookie? _ssoCookie;
  Future<bool>? _loginFuture;
  Future<PracticeScoreSnapshot>? _fetchFuture;
  bool _authenticated = false;
  bool _lastLoginFailed = false;

  Sztz({required String accountScope}) : _accountScope = accountScope;

  set db(DatabaseHelper? db) {
    _db = db;
  }

  Future<bool> login(HttpClient httpClient, Cookie? iPlanetDirectoryPro) async {
    if (iPlanetDirectoryPro == null) {
      throw AuthenticationExpiredException('素质拓展登录：统一身份认证凭据无效');
    }
    final pending = _loginFuture;
    if (pending != null) return pending;

    final login = _doLogin(httpClient, iPlanetDirectoryPro);
    _loginFuture = login;
    try {
      return await login;
    } finally {
      if (identical(_loginFuture, login)) _loginFuture = null;
    }
  }

  Future<bool> _doLogin(
    HttpClient httpClient,
    Cookie iPlanetDirectoryPro,
  ) async {
    _authenticated = false;
    _lastLoginFailed = false;
    _ssoCookie = iPlanetDirectoryPro;
    _storeCookie(
      iPlanetDirectoryPro,
      _serviceUri,
      forcedDomain: 'zju.edu.cn',
    );
    DiagnosticLogService.instance.record(
      module: '素质拓展登录',
      operation: 'casService',
      requestUri: _serviceUri,
      message: '开始申请素质拓展 CAS service ticket',
    );
    try {
      final callback = await ZjuAm.getServiceCallback(
        httpClient,
        iPlanetDirectoryPro,
        _serviceUri,
      );
      await _visitCasCallback(httpClient, callback);
      await _verifyContext(httpClient);
      _authenticated = true;
      DiagnosticLogService.instance.record(
        module: '素质拓展登录',
        operation: 'result',
        requestUri: _ctxUri,
        message: 'ctx 已确认非匿名身份',
      );
      return true;
    } on Object catch (error) {
      _authenticated = false;
      _lastLoginFailed = true;
      if (error is _SztzAuthenticationException) rethrow;
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: '素质拓展登录',
        operation: 'result',
        requestUri: _serviceUri,
        message: 'CAS/ctx 登录失败；异常类型=${error.runtimeType}',
      );
      throw const _SztzAuthenticationException('素质拓展 CAS/ctx 登录未完成');
    }
  }

  Future<void> _visitCasCallback(
    HttpClient httpClient,
    Uri callback,
  ) async {
    final startedAt = DateTime.now();
    final request = await httpClient.getUrl(callback).timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw requestTimeout('素质拓展 CAS 回调请求超时'),
        );
    request.followRedirects = false;
    request.cookies.addAll(
      _requestCookies(callback),
    );
    final response = await request.close().timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw requestTimeout('素质拓展 CAS 回调响应超时'),
        );
    final setCookieNames = _storeResponseCookies(response, callback);
    await _readBody(response, context: '素质拓展 CAS 回调');
    DiagnosticLogService.instance.record(
      module: '素质拓展登录',
      operation: 'redirectHop',
      requestUri: _serviceUri,
      statusCode: response.statusCode,
      contentType: response.headers.value(HttpHeaders.contentTypeHeader),
      durationMs: DateTime.now().difference(startedAt).inMilliseconds,
      message: 'CAS service 回调已完整访问',
    );
    if (response.statusCode != HttpStatus.ok) {
      throw _SztzAuthenticationException(
        '素质拓展 CAS 回调失败；HTTP ${response.statusCode}',
      );
    }
    if (!setCookieNames.contains('SESSION') || !_hasFormalSessionCookie()) {
      throw const _SztzAuthenticationException(
        '素质拓展 CAS 回调未设置正式 SESSION',
      );
    }
  }

  Future<void> _verifyContext(HttpClient httpClient) async {
    if (!_hasFormalSessionCookie()) {
      throw const _SztzAuthenticationException('素质拓展正式 SESSION 缺失');
    }
    final startedAt = DateTime.now();
    final request = await httpClient.postUrl(_ctxUri).timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw requestTimeout('素质拓展 ctx 请求超时'),
        );
    request.followRedirects = false;
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*')
      ..set(
        HttpHeaders.contentTypeHeader,
        'application/x-www-form-urlencoded',
      )
      ..set('Origin', 'https://sztz.zju.edu.cn')
      ..set(HttpHeaders.refererHeader, _serviceUri.toString());
    request.contentLength = 0;
    request.cookies.addAll(_requestCookies(_ctxUri));
    final response = await request.close().timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw requestTimeout('素质拓展 ctx 响应超时'),
        );
    _storeResponseCookies(response, _ctxUri);
    final body = await _readBody(response, context: '素质拓展 ctx');
    DiagnosticLogService.instance.record(
      module: '素质拓展登录',
      operation: 'ctx',
      requestUri: _ctxUri,
      statusCode: response.statusCode,
      contentType: response.headers.value(HttpHeaders.contentTypeHeader),
      durationMs: DateTime.now().difference(startedAt).inMilliseconds,
      message: 'ctx 响应已完整读取',
    );
    if (response.statusCode != HttpStatus.ok ||
        !isAuthenticatedCtxResponse(body) ||
        !_hasFormalSessionCookie()) {
      throw const _SztzAuthenticationException('素质拓展 ctx 返回匿名或无效身份');
    }
  }

  Future<PracticeScoreSnapshot> getPracticeScoreItems(
    HttpClient httpClient, {
    Future<Cookie?> Function()? reauthenticate,
  }) async {
    final pending = _fetchFuture;
    if (pending != null) return pending;
    final fetch = _getPracticeScoreItems(
      httpClient,
      reauthenticate: reauthenticate,
    );
    _fetchFuture = fetch;
    try {
      return await fetch;
    } finally {
      if (identical(_fetchFuture, fetch)) _fetchFuture = null;
    }
  }

  Future<PracticeScoreSnapshot> _getPracticeScoreItems(
    HttpClient httpClient, {
    Future<Cookie?> Function()? reauthenticate,
  }) async {
    Object? liveError;
    StackTrace? liveStackTrace;
    var relogged = false;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        if (_ssoCookie == null) {
          throw const _SztzAuthenticationException('缺少统一身份认证登录态');
        }
        if (!_authenticated) {
          final pendingLogin = _loginFuture;
          if (pendingLogin != null) {
            await pendingLogin;
          } else if (_lastLoginFailed) {
            throw const _SztzAuthenticationException(
              '此前素质拓展 CAS/ctx 登录未完成',
            );
          } else {
            await login(httpClient, _ssoCookie);
          }
        }
        if (!_authenticated) {
          throw const _SztzAuthenticationException('素质拓展身份尚未确认');
        }
        final payload = await _fetchValidPayload(
          httpClient,
          relogged: relogged,
          retried: attempt > 0,
        );
        final rawItems = asDynamicList(payload['data'])!;
        final items = PracticeScoreItem.parseSztzItems(
          rawItems,
          onError: (index, error, stackTrace) {
            DiagnosticLogService.instance.record(
              level: CelechronLogLevel.warning,
              module: '素质拓展实践项目',
              operation: 'parse',
              message: '跳过第 ${index + 1} 条格式异常的实践记录',
              error: error,
              stackTrace: stackTrace,
            );
          },
        );
        final updatedAt = DateTime.now();
        await _writeCache(items, updatedAt);
        final snapshot = PracticeScoreSnapshot.sztz(
          items: items,
          source: PracticeDataSource.sztzLive,
          updatedAt: updatedAt,
          stale: false,
        );
        _logResult(snapshot, cacheUsed: false);
        return snapshot;
      } on _SztzAuthenticationException catch (error, stackTrace) {
        liveError = error;
        liveStackTrace = stackTrace;
        if (attempt > 0 || reauthenticate == null) break;
        try {
          final refreshedCookie = await reauthenticate();
          if (refreshedCookie == null) break;
          await login(httpClient, refreshedCookie);
          relogged = true;
        } on Object catch (error, stackTrace) {
          liveError = error;
          liveStackTrace = stackTrace;
          break;
        }
      } on Object catch (error, stackTrace) {
        liveError = error;
        liveStackTrace = stackTrace;
        break;
      }
    }

    final safeException = exceptionFrom(
      liveError ?? const FormatException('未取得有效业务数据'),
      context: '素质拓展实践项目',
      requestUri: _practiceUri,
      relogged: relogged,
      retried: relogged,
      stackTrace: liveStackTrace,
    );
    final cached = _readCache(errorMessage: shortErrorText(safeException));
    if (cached != null) {
      _logResult(cached, cacheUsed: true);
      return cached;
    }
    DiagnosticLogService.instance.setModuleResult(
      '素质拓展实践项目',
      '实时失败且无可用缓存',
    );
    return PracticeScoreSnapshot(
      items: const [],
      source: PracticeDataSource.unavailable,
      updatedAt: null,
      detailsAvailable: false,
      stale: true,
      errorMessage: shortErrorText(safeException),
    );
  }

  Future<Map<String, dynamic>> _fetchValidPayload(
    HttpClient httpClient, {
    required bool relogged,
    required bool retried,
  }) async {
    final result = await _requestPracticeData(
      httpClient,
      relogged: relogged,
      retried: retried,
    );
    final payload = _decodeBusinessPayload(result);
    if (payload == null) {
      _authenticated = false;
      throw const _SztzAuthenticationException(
        'HTTP 200 但未取得有效素质拓展业务 JSON',
      );
    }

    final totalPages = asInt(payload['totalPages']);
    if (totalPages != null && totalPages > 1) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: '素质拓展实践项目',
        operation: 'parse',
        message: '接口返回多页元数据，但请求未发现分页参数',
      );
    }
    DiagnosticLogService.instance.record(
      module: '素质拓展实践项目',
      operation: 'parse',
      requestUri: _practiceUri,
      relogged: relogged,
      retried: retried,
      message: '[SZTZ] getSqjl 有效 JSON',
    );
    return payload;
  }

  Map<String, dynamic>? _decodeBusinessPayload(_SztzResponse response) {
    if (response.statusCode != HttpStatus.ok || response.body.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(response.body);
      final payload = asStringMap(decoded);
      if (payload == null ||
          payload['success'] != true ||
          asInt(payload['code']) != 0 ||
          payload['data'] is! List) {
        return null;
      }
      return payload;
    } on FormatException {
      return null;
    }
  }

  Future<_SztzResponse> _requestPracticeData(
    HttpClient httpClient, {
    required bool relogged,
    required bool retried,
  }) async {
    if (!_authenticated || !_hasFormalSessionCookie()) {
      throw const _SztzAuthenticationException('素质拓展身份或 SESSION 无效');
    }
    final startedAt = DateTime.now();
    final request = await httpClient.getUrl(_practiceUri).timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw requestTimeout('素质拓展请求超时'),
        );
    request.followRedirects = false;
    request.headers
      ..set(HttpHeaders.acceptHeader, _practiceAccept)
      ..set(HttpHeaders.cacheControlHeader, 'no-cache')
      ..set('Pragma', 'no-cache');
    request.cookies.addAll(_requestCookies(_practiceUri));
    DiagnosticLogService.instance.record(
      module: '素质拓展实践项目',
      operation: 'fetch',
      requestUri: _practiceUri,
      relogged: relogged,
      retried: retried,
      message: '[SZTZ] GET ${DiagnosticLogService.sanitizeUri(_practiceUri)}',
    );

    final response = await request.close().timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw requestTimeout('素质拓展响应超时'),
        );
    _storeResponseCookies(response, _practiceUri);
    final body = await _readBody(response, context: '素质拓展实践项目');
    DiagnosticLogService.instance.record(
      module: '素质拓展实践项目',
      operation: 'fetch',
      requestUri: _practiceUri,
      statusCode: response.statusCode,
      contentType: response.headers.value(HttpHeaders.contentTypeHeader),
      durationMs: DateTime.now().difference(startedAt).inMilliseconds,
      relogged: relogged,
      retried: retried,
      message: '素质拓展响应已完整读取',
    );
    if (_isRedirect(response.statusCode) ||
        response.statusCode == HttpStatus.unauthorized ||
        response.statusCode == HttpStatus.forbidden) {
      _authenticated = false;
      throw _SztzAuthenticationException(
        '素质拓展认证未完成；HTTP ${response.statusCode}',
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      throw ExceptionWithMessage(
        '素质拓展请求失败；HTTP ${response.statusCode}',
      );
    }
    return _SztzResponse(statusCode: response.statusCode, body: body);
  }

  Set<String> _storeResponseCookies(
    HttpClientResponse response,
    Uri origin,
  ) {
    List<Cookie> cookies;
    try {
      cookies = List<Cookie>.from(response.cookies);
    } on Object catch (error) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: '素质拓展登录',
        operation: 'parseCookies',
        requestUri: _withoutQuery(origin),
        message: 'Set-Cookie 解析失败；异常类型=${error.runtimeType}',
      );
      return const {};
    }
    final rawSetCookieHeaders =
        response.headers[HttpHeaders.setCookieHeader] ?? const <String>[];
    for (final cookie in cookies) {
      _storeCookie(
        cookie,
        origin,
        sameSite: _sameSiteFor(cookie.name, rawSetCookieHeaders),
      );
    }
    final names = cookies.map((cookie) => cookie.name).toSet();
    if (names.contains('SESSION')) {
      DiagnosticLogService.instance.record(
        module: '素质拓展登录',
        operation: 'result',
        requestUri: _withoutQuery(origin),
        message: 'Set-Cookie名称=SESSION',
      );
    }
    return names;
  }

  void _storeCookie(
    Cookie cookie,
    Uri origin, {
    String? forcedDomain,
    String? sameSite,
  }) {
    final rawDomain = forcedDomain ?? cookie.domain?.trim();
    final hostOnly = rawDomain == null || rawDomain.isEmpty;
    final domain = (hostOnly ? origin.host : rawDomain)
        .toLowerCase()
        .replaceFirst(RegExp(r'^\.'), '');
    if (origin.host != domain && !origin.host.endsWith('.$domain')) return;
    final path = cookie.path == null || cookie.path!.isEmpty
        ? _defaultCookiePath(origin.path)
        : cookie.path!;
    _cookies.removeWhere((stored) =>
        stored.name == cookie.name &&
        stored.domain == domain &&
        stored.path == path);
    if (cookie.maxAge != null && cookie.maxAge! <= 0) return;
    if (cookie.expires != null && !cookie.expires!.isAfter(DateTime.now())) {
      return;
    }
    _cookies.add(
      _StoredCookie(
        name: cookie.name,
        value: cookie.value,
        domain: domain,
        path: path,
        secure: cookie.secure,
        expires: cookie.expires,
        maxAge: cookie.maxAge,
        createdAt: DateTime.now(),
        hostOnly: hostOnly && forcedDomain == null,
        httpOnly: cookie.httpOnly,
        sameSite: sameSite,
      ),
    );
  }

  List<_StoredCookie> _matchingCookies(Uri uri) {
    final now = DateTime.now();
    _cookies.removeWhere((cookie) => cookie.isExpired(now));
    return _cookies.where((cookie) => cookie.matches(uri)).toList()
      ..sort((a, b) => b.path.length.compareTo(a.path.length));
  }

  List<Cookie> _requestCookies(Uri uri) => _matchingCookies(uri)
      .map((cookie) => Cookie(cookie.name, cookie.value))
      .toList(growable: false);

  bool _hasFormalSessionCookie() => _matchingCookies(_ctxUri).any(
        (cookie) =>
            cookie.name == 'SESSION' &&
            cookie.domain == _ctxUri.host &&
            cookie.path == '/dekt' &&
            cookie.hostOnly &&
            cookie.httpOnly &&
            cookie.sameSite?.toLowerCase() == 'lax',
      );

  Future<String> _readBody(
    HttpClientResponse response, {
    required String context,
  }) =>
      utf8.decoder.bind(response).join().timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw requestTimeout('$context 响应读取超时'),
          );

  static String? _sameSiteFor(
    String cookieName,
    List<String> setCookieHeaders,
  ) {
    for (final header in setCookieHeaders) {
      if (!header
          .trimLeft()
          .toLowerCase()
          .startsWith('${cookieName.toLowerCase()}=')) {
        continue;
      }
      return RegExp(
        r'(?:^|;)\s*SameSite=([^;]+)',
        caseSensitive: false,
      ).firstMatch(header)?.group(1)?.trim();
    }
    return null;
  }

  @visibleForTesting
  static bool isAuthenticatedCtxResponse(String body) {
    try {
      final payload = asStringMap(jsonDecode(body));
      if (payload == null ||
          payload['success'] != true ||
          asInt(payload['code']) != 0) {
        return false;
      }
      final encodedData = asString(payload['data']);
      if (encodedData == null || encodedData.isEmpty) return false;
      final decodedData = utf8.decode(
        base64.decode(base64.normalize(encodedData)),
      );
      final context = asStringMap(jsonDecode(decodedData));
      if (context == null || asBool(context['anonymous']) != false) {
        return false;
      }
      final userId = asString(context['userId'])?.trim();
      if (userId == null ||
          userId.isEmpty ||
          userId.toUpperCase() == 'ANONYMOUS') {
        return false;
      }
      return !_containsAnonymousRole(context['roles']);
    } on Object {
      return false;
    }
  }

  static bool _containsAnonymousRole(Object? roles) {
    if (roles is List) {
      return roles.any(_containsAnonymousRole);
    }
    final map = asStringMap(roles);
    if (map != null) {
      return map.values.any(_containsAnonymousRole);
    }
    final role = asString(roles);
    if (role == null) return false;
    return role
        .split(RegExp(r'[\s,;]+'))
        .any((value) => value.trim() == 'ANONYMOUS_USER_ROLE');
  }

  @visibleForTesting
  static bool cookiePathMatches(String cookiePath, String requestPath) {
    if (requestPath == cookiePath) return true;
    if (!requestPath.startsWith(cookiePath)) return false;
    return cookiePath.endsWith('/') ||
        (requestPath.length > cookiePath.length &&
            requestPath[cookiePath.length] == '/');
  }

  static Uri _withoutQuery(Uri uri) => Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
      );

  Future<void> _writeCache(
      List<PracticeScoreItem> items, DateTime updatedAt) async {
    await _db?.setCachedWebPage(
      _cacheKey,
      jsonEncode({
        'updatedAt': updatedAt.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(growable: false),
      }),
    );
  }

  PracticeScoreSnapshot? _readCache({required String errorMessage}) {
    final raw = _db?.getCachedWebPage(_cacheKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final payload = asStringMap(jsonDecode(raw));
      if (payload == null || payload['items'] is! List) return null;
      final items = <PracticeScoreItem>[];
      for (final rawItem in asDynamicList(payload['items'])!) {
        final item = asStringMap(rawItem);
        if (item == null) continue;
        try {
          final parsed = PracticeScoreItem.fromJson(item);
          if (!parsed.deleted) items.add(parsed);
        } on Object catch (error, stackTrace) {
          DiagnosticLogService.instance.record(
            level: CelechronLogLevel.warning,
            module: '素质拓展实践项目',
            operation: 'readCacheItem',
            message: '跳过一条损坏的实践项目缓存',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      final updatedAt = asDateTime(payload['updatedAt']);
      if (updatedAt == null) return null;
      return PracticeScoreSnapshot.sztz(
        items: items,
        source: PracticeDataSource.sztzCache,
        updatedAt: updatedAt.toLocal(),
        stale: true,
        errorMessage: errorMessage,
      );
    } on Object catch (error, stackTrace) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: '素质拓展实践项目',
        operation: 'readCache',
        cacheUsed: false,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  void _logResult(PracticeScoreSnapshot snapshot, {required bool cacheUsed}) {
    final approved =
        snapshot.items.where((item) => item.countsTowardTotal).length;
    final message = '${cacheUsed ? '缓存成功' : '实时成功'}；'
        '记录 ${snapshot.items.length} 条；审核通过 $approved 条；'
        '二课 ${snapshot.totalFor(1).toStringAsFixed(2)}；'
        '三课 ${snapshot.totalFor(2).toStringAsFixed(2)}；'
        '四课 ${snapshot.totalFor(3).toStringAsFixed(2)}；'
        '数据来源 ${snapshot.source.label}';
    DiagnosticLogService.instance.record(
      module: '素质拓展实践项目',
      operation: 'result',
      requestUri: _practiceUri,
      cacheUsed: cacheUsed,
      message: '[SZTZ] 解析完成；items=${snapshot.items.length}；'
          'approved=$approved；$message',
    );
    DiagnosticLogService.instance.record(
      module: '素质拓展实践项目',
      operation: 'result',
      cacheUsed: cacheUsed,
      message: '[SZTZ] totals：'
          'pt2=${snapshot.totalFor(1).toStringAsFixed(2)}；'
          'pt3=${snapshot.totalFor(2).toStringAsFixed(2)}；'
          'pt4=${snapshot.totalFor(3).toStringAsFixed(2)}',
    );
    DiagnosticLogService.instance.setModuleResult('素质拓展实践项目', message);
  }

  String get _cacheKey {
    final digest = sha256.convert(utf8.encode(_accountScope)).toString();
    return 'sztz_practice_items_v1_$digest';
  }

  void logout() {
    _cookies.clear();
    _ssoCookie = null;
    _loginFuture = null;
    _fetchFuture = null;
    _authenticated = false;
    _lastLoginFailed = false;
  }

  static bool _isRedirect(int statusCode) =>
      statusCode == HttpStatus.movedPermanently ||
      statusCode == HttpStatus.found ||
      statusCode == HttpStatus.seeOther ||
      statusCode == HttpStatus.temporaryRedirect ||
      statusCode == HttpStatus.permanentRedirect;

  static String _defaultCookiePath(String requestPath) {
    if (!requestPath.startsWith('/') || requestPath == '/') return '/';
    final lastSlash = requestPath.lastIndexOf('/');
    return lastSlash <= 0 ? '/' : requestPath.substring(0, lastSlash);
  }
}

class _SztzResponse {
  final int statusCode;
  final String body;

  const _SztzResponse({
    required this.statusCode,
    required this.body,
  });
}

class _StoredCookie {
  final String name;
  final String value;
  final String domain;
  final String path;
  final bool secure;
  final DateTime? expires;
  final int? maxAge;
  final DateTime createdAt;
  final bool hostOnly;
  final bool httpOnly;
  final String? sameSite;

  const _StoredCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    required this.secure,
    required this.expires,
    required this.maxAge,
    required this.createdAt,
    required this.hostOnly,
    required this.httpOnly,
    required this.sameSite,
  });

  bool isExpired(DateTime now) {
    if (expires != null && !expires!.isAfter(now)) return true;
    if (maxAge != null &&
        !createdAt.add(Duration(seconds: maxAge!)).isAfter(now)) {
      return true;
    }
    return false;
  }

  bool matches(Uri uri) {
    if (secure && uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    final domainMatches =
        hostOnly ? host == domain : host == domain || host.endsWith('.$domain');
    if (!domainMatches) return false;
    return Sztz.cookiePathMatches(path, uri.path);
  }
}

class _SztzAuthenticationException implements Exception {
  final String message;

  const _SztzAuthenticationException(this.message);

  @override
  String toString() => message;
}
