// This implementation is adapted from the project "login-ZJU" by 5dbwat4(https://github.com/5dbwat4/login-ZJU) under the MIT License.
// See: https://github.com/5dbwat4/login-ZJU/blob/main/src/utils/fetch-with-cookie.ts

import 'dart:convert';
import 'dart:io';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/model/todo.dart';

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

  Future<Tuple<Exception?, List<Todo>>> getTodo(HttpClient httpClient) async {
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
      _db?.setCachedWebPage("courses_todo", body);
      return Tuple(null, Todo.getAllFromCourses(data));
    } on Object catch (error, stackTrace) {
      final exception = exceptionFrom(
        error,
        context: '学在浙大作业',
        requestUri: _todoUri,
        stackTrace: stackTrace,
      );
      final todos = _readCachedTodos();
      return Tuple(exception, todos);
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

  List<Todo> _readCachedTodos() {
    final cached = _db?.getCachedWebPage("courses_todo");
    if (cached == null || cached.trim().isEmpty) return [];
    try {
      return Todo.getAllFromCourses(decodeJsonMap(cached, context: '学在浙大作业缓存'));
    } catch (_) {
      return [];
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
      HttpClient httpClient, Cookie iPlanetDirectoryPro) async {
    _session = null;
    var cookies = <Cookie>[iPlanetDirectoryPro];
    var current = Uri.parse("https://courses.zju.edu.cn/user/index");

    for (var redirectCount = 0; redirectCount < 10; redirectCount++) {
      final request = await httpClient.getUrl(current).timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw requestTimeout());
      request.followRedirects = false;
      request.cookies.addAll(cookies);
      final response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw requestTimeout());
      cookies.addAll(response.cookies);
      final body = await readResponseBody(response, context: '学在浙大登录');

      for (final cookie in response.cookies) {
        if (cookie.name == "session") _session = cookie;
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      final redirectTarget =
          location == null ? null : current.resolve(location);
      if (_session != null &&
          ((!isHttpRedirectStatus(response.statusCode) &&
                  current.host == 'courses.zju.edu.cn') ||
              (redirectTarget?.host == 'courses.zju.edu.cn' &&
                  redirectTarget?.path == '/user/index'))) {
        return true;
      }

      if (isHttpRedirectStatus(response.statusCode)) {
        if (location == null || location.trim().isEmpty) {
          throw ExceptionWithMessage(
              '学在浙大登录：HTTP ${response.statusCode} 跳转但缺少 Location');
        }
        current = redirectTarget!;
        continue;
      }
      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden ||
          bodyIndicatesAuthenticationFailure(body)) {
        throw AuthenticationExpiredException(
            '学在浙大登录态失效；HTTP ${response.statusCode}'
            '；响应摘要：${responseSummary(body)}');
      }
      throw ExceptionWithMessage('学在浙大登录失败；HTTP ${response.statusCode}'
          '；Content-Type ${response.headers.value(HttpHeaders.contentTypeHeader) ?? '<缺失>'}'
          '；响应摘要：${responseSummary(body)}');
    }

    throw ExceptionWithMessage("学在浙大登录失败：重定向次数过多");
  }

  void logout() {
    _session = null;
    _iPlanetDirectoryPro = null;
  }
}
