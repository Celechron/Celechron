// This implementation is adapted from the project "login-ZJU" by 5dbwat4(https://github.com/5dbwat4/login-ZJU) under the MIT License.
// See: https://github.com/5dbwat4/login-ZJU/blob/main/src/utils/fetch-with-cookie.ts

import 'dart:convert';
import 'dart:io';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/data_source_status.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/model/todo.dart';
import 'package:flutter/foundation.dart';
import 'response_utils.dart';

class Courses {
  static final Uri _todoUri = Uri.parse("https://courses.zju.edu.cn/api/todos");

  DatabaseHelper? _db;
  Cookie? _session;
  Cookie? _iPlanetDirectoryPro;
  Future<bool>? _loginFuture;

  set db(DatabaseHelper? db) {
    _db = db;
  }

  Future<Tuple3<Exception?, List<Todo>, DataSourceStatus>> getTodo(
      HttpClient httpClient) async {
    try {
      var relogged = false;
      if (_session == null) {
        if (_iPlanetDirectoryPro != null) {
          await login(httpClient, _iPlanetDirectoryPro);
          relogged = true;
        } else {
          throw AuthenticationExpiredException("学在浙大：未登录");
        }
      }
      Map<String, dynamic> data;
      final attemptedSession = _session;
      try {
        data = await _fetchTodo(httpClient, relogged: relogged);
      } on AuthenticationExpiredException catch (firstError) {
        if (_iPlanetDirectoryPro == null || relogged) {
          throw LoginExpiredException(
            "学在浙大：登录态已失效，请手动重新登录",
            details: detailedErrorText(firstError),
          );
        }
        try {
          if (identical(_session, attemptedSession)) {
            _session = null;
            await login(httpClient, _iPlanetDirectoryPro);
          }
          data = await _fetchTodo(
            httpClient,
            relogged: true,
            retried: true,
          );
        } on AuthenticationExpiredException catch (secondError) {
          throw LoginExpiredException(
            "学在浙大：自动重登失败，请手动重新登录",
            details: detailedErrorText(secondError),
            originalError: secondError,
          );
        }
      }
      final body = jsonEncode(data);
      await Future.wait([
        _db?.setCachedWebPage("courses_todo", body) ?? Future<void>.value(),
        _db?.setCachedWebPage(
              "courses_todo_timestamp",
              DateTime.now().toUtc().toIso8601String(),
            ) ??
            Future<void>.value(),
      ]);
      final todos = Todo.getAllFromCourses(data);
      DiagnosticLogService.instance.record(
        module: '学在浙大作业',
        operation: 'fetchTodo',
        requestUri: _todoUri,
        message: '实时成功，${todos.length} 条',
      );
      return Tuple3(null, todos, DataSourceStatus.live);
    } on Object catch (error, stackTrace) {
      final exception = exceptionFrom(
        error,
        context: '学在浙大作业',
        requestUri: _todoUri,
        stackTrace: stackTrace,
      );
      final cached = _readCachedTodos();
      final status =
          cached.used ? DataSourceStatus.cache : DataSourceStatus.unavailable;
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: '学在浙大作业',
        operation: 'fetchTodo',
        requestUri: _todoUri,
        cacheUsed: cached.used,
        message: cached.used
            ? '实时请求失败，使用缓存，${cached.todos.length} 条；'
                '缓存时间=${cached.cachedAt ?? '<未知>'}'
            : '实时请求失败，且没有可用缓存',
        error: error,
        stackTrace: stackTrace,
      );
      return Tuple3(exception, cached.todos, status);
    }
  }

  Future<Map<String, dynamic>> _fetchTodo(
    HttpClient httpClient, {
    bool relogged = false,
    bool retried = false,
  }) async {
    final request = await _createTodoRequest(httpClient);
    final response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw requestTimeout());
    final body = await readResponseText(
      response,
      context: '学在浙大作业接口',
      expectJson: true,
      requestUri: _todoUri,
      relogged: relogged,
      retried: retried,
    );
    final data =
        decodeJsonMap(body, context: '学在浙大作业接口；HTTP ${response.statusCode}');
    if (jsonIndicatesAuthenticationFailure(data)) {
      throw AuthenticationExpiredException(
          '学在浙大作业接口：登录态已失效；HTTP ${response.statusCode}'
          '；响应摘要：${responseSummary(body)}');
    }
    return data;
  }

  Future<HttpClientRequest> _createTodoRequest(HttpClient httpClient) async {
    final request = await httpClient.getUrl(_todoUri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw requestTimeout());
    request.followRedirects = false;
    request.cookies.add(_session!);
    return request;
  }

  _CachedTodos _readCachedTodos() {
    final cached = _db?.getCachedWebPage("courses_todo");
    if (cached == null || cached.trim().isEmpty) {
      return const _CachedTodos([], false);
    }
    try {
      return _CachedTodos(
        Todo.getAllFromCourses(
          decodeJsonMap(cached, context: '学在浙大作业缓存'),
        ),
        true,
        cachedAt: _db?.getCachedWebPage("courses_todo_timestamp"),
      );
    } on Object catch (error, stackTrace) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: '学在浙大作业',
        operation: 'readCache',
        cacheUsed: false,
        error: error,
        stackTrace: stackTrace,
      );
      return const _CachedTodos([], false);
    }
  }

  Future<bool> login(HttpClient httpClient, Cookie? iPlanetDirectoryPro) async {
    if (iPlanetDirectoryPro == null) {
      throw AuthenticationExpiredException("学在浙大：统一身份认证凭据无效");
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
    HttpClient httpClient,
    Cookie iPlanetDirectoryPro,
  ) async {
    _session = null;

    // 简单 CookieJar。
    // 相同 name + domain + path 的 Cookie 会被新值覆盖，
    // 避免重复发送旧 session。
    final cookieJar = <String, Cookie>{};
    final redirectTrace = <String>[];

    bool isExpiredCookie(Cookie cookie) {
      if (cookie.maxAge != null && cookie.maxAge! <= 0) {
        return true;
      }

      final expires = cookie.expires;
      return expires != null && expires.isBefore(DateTime.now());
    }

    String normalizedDomain(Cookie cookie, Uri source) {
      final rawDomain = cookie.domain;

      if (rawDomain == null || rawDomain.trim().isEmpty) {
        // Set-Cookie 没有 Domain 时，将其视为当前响应主机的 Cookie。
        return source.host.toLowerCase();
      }

      return rawDomain.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    }

    String normalizedPath(Cookie cookie) {
      final path = cookie.path;
      if (path == null || path.trim().isEmpty) {
        return '/';
      }
      return path;
    }

    String cookieKey(Cookie cookie, Uri source) {
      return '${cookie.name}|'
          '${normalizedDomain(cookie, source)}|'
          '${normalizedPath(cookie)}';
    }

    void storeCookie(Cookie cookie, Uri source) {
      final key = cookieKey(cookie, source);

      if (isExpiredCookie(cookie)) {
        cookieJar.remove(key);
        return;
      }

      // 保存 Cookie 来源范围，便于后续按照域名和路径筛选。
      if (cookie.domain == null || cookie.domain!.trim().isEmpty) {
        cookie.domain = source.host.toLowerCase();
      }

      if (cookie.path == null || cookie.path!.trim().isEmpty) {
        cookie.path = '/';
      }

      cookieJar[key] = cookie;
    }

    bool cookieMatchesUri(Cookie cookie, Uri uri) {
      if (isExpiredCookie(cookie)) {
        return false;
      }

      if (cookie.secure && uri.scheme != 'https') {
        return false;
      }

      final rawDomain = cookie.domain;
      if (rawDomain == null || rawDomain.trim().isEmpty) {
        return false;
      }

      final domain =
          rawDomain.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), '');

      final host = uri.host.toLowerCase();

      final domainMatches = host == domain || host.endsWith('.$domain');

      if (!domainMatches) {
        return false;
      }

      final path =
          cookie.path == null || cookie.path!.isEmpty ? '/' : cookie.path!;

      return uri.path.startsWith(path);
    }

    List<Cookie> cookiesFor(Uri uri) {
      return cookieJar.values
          .where((cookie) => cookieMatchesUri(cookie, uri))
          .toList();
    }

    String cookieNames(Iterable<Cookie> cookies) {
      final names = cookies.map((cookie) => cookie.name).toSet().toList()
        ..sort();

      return names.isEmpty ? '<无>' : names.join(', ');
    }

    // iPlanetDirectoryPro 的 domain 通常是 zju.edu.cn，
    // 因此可用于 identity、zjuam、courses 等子域。
    storeCookie(
      iPlanetDirectoryPro,
      Uri.parse('https://zjuam.zju.edu.cn/'),
    );

    var current = Uri.parse(
      'https://courses.zju.edu.cn/user/index',
    );

    // Keycloak/CAS 可能经过多次跳转，略微提高上限。
    for (var redirectCount = 0; redirectCount < 15; redirectCount++) {
      final outgoingCookies = cookiesFor(current);

      if (kDebugMode) {
        debugPrint(
          '[Courses.login] '
          'hop=$redirectCount, '
          'request=${sanitizedRequestUri(current)}, '
          '发送Cookie名称=${cookieNames(outgoingCookies)}',
        );
      }
      DiagnosticLogService.instance.record(
        module: '学在浙大登录',
        operation: 'redirectHop',
        requestUri: current,
        message:
            'hop=$redirectCount；发送Cookie名称=${cookieNames(outgoingCookies)}',
      );

      final request = await httpClient.getUrl(current).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout(),
          );

      request.followRedirects = false;
      request.cookies.addAll(outgoingCookies);

      final response = await request.close().timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout(),
          );

      final responseCookies = List<Cookie>.from(response.cookies);

      // 必须在 current 更新前处理当前响应的 Cookie。
      for (final cookie in responseCookies) {
        storeCookie(cookie, current);

        // 只接受 courses.zju.edu.cn 返回的 session，
        // 避免把其他域名的同名 Cookie 当作业务会话。
        if (current.host == 'courses.zju.edu.cn' && cookie.name == 'session') {
          _session = isExpiredCookie(cookie) ? null : cookie;
        }
      }

      final body = await readResponseBody(
        response,
        context: '学在浙大登录',
      );

      final location = response.headers.value(HttpHeaders.locationHeader);

      final redirectTarget =
          location == null ? null : current.resolve(location);

      final traceLine = [
        'hop=$redirectCount',
        '请求=${sanitizedRequestUri(current)}',
        'HTTP=${response.statusCode}',
        'Location=${redirectTarget == null ? '<无>' : sanitizedRequestUri(redirectTarget)}',
        '响应Cookie=${cookieNames(responseCookies)}',
        '已取得session=${_session != null ? '是' : '否'}',
      ].join('；');

      redirectTrace.add(traceLine);

      if (kDebugMode) {
        debugPrint('[Courses.login] $traceLine');
      }
      DiagnosticLogService.instance.record(
        level: isHttpRedirectStatus(response.statusCode)
            ? CelechronLogLevel.debug
            : CelechronLogLevel.info,
        module: '学在浙大登录',
        operation: 'redirectHop',
        requestUri: current,
        statusCode: response.statusCode,
        contentType:
            response.headers.value(HttpHeaders.contentTypeHeader) ?? '<缺失>',
        location: location,
        message:
            'hop=$redirectCount；响应Cookie名称=${cookieNames(responseCookies)}；'
            '已取得session=${_session != null ? '是' : '否'}',
      );

      // 先处理重定向。
      // 关键：必须真正访问 redirectTarget，不能看到下一跳回到 courses
      // 就提前返回登录成功。
      if (isHttpRedirectStatus(response.statusCode)) {
        if (location == null || location.trim().isEmpty) {
          throw ExceptionWithMessage(
            '学在浙大登录：HTTP ${response.statusCode} 跳转但缺少 Location',
            details: redirectTrace.join('\n'),
          );
        }

        current = redirectTarget!;
        continue;
      }

      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden ||
          bodyIndicatesAuthenticationFailure(body)) {
        throw AuthenticationExpiredException(
          '学在浙大登录态失效；HTTP ${response.statusCode}',
          details: [
            ...redirectTrace,
            '响应摘要：${responseSummary(body)}',
          ].join('\n'),
        );
      }

      final successStatus = response.statusCode >= HttpStatus.ok &&
          response.statusCode < HttpStatus.multipleChoices;

      final sessionCanAccessTodo =
          cookiesFor(_todoUri).any((cookie) => cookie.name == 'session');

      // 只有真正完成所有重定向，并成功访问 courses 页面后，
      // 才认定业务登录成功。
      if (successStatus &&
          current.host == 'courses.zju.edu.cn' &&
          _session != null &&
          sessionCanAccessTodo) {
        return true;
      }

      throw ExceptionWithMessage(
        '学在浙大登录失败；HTTP ${response.statusCode}',
        details: [
          ...redirectTrace,
          'Content-Type：'
              '${response.headers.value(HttpHeaders.contentTypeHeader) ?? '<缺失>'}',
          '响应摘要：${responseSummary(body)}',
        ].join('\n'),
      );
    }

    throw ExceptionWithMessage(
      '学在浙大登录失败：重定向次数过多',
      details: redirectTrace.join('\n'),
    );
  }

  void logout() {
    _session = null;
    _iPlanetDirectoryPro = null;
  }
}

class _CachedTodos {
  final List<Todo> todos;
  final bool used;
  final String? cachedAt;

  const _CachedTodos(this.todos, this.used, {this.cachedAt});
}
