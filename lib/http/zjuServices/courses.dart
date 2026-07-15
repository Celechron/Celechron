// This implementation is adapted from the project "login-ZJU" by 5dbwat4(https://github.com/5dbwat4/login-ZJU) under the MIT License.
// See: https://github.com/5dbwat4/login-ZJU/blob/main/src/utils/fetch-with-cookie.ts

import 'dart:convert';
import 'dart:io';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/model/todo.dart';

class Courses {
  static final Uri _todoUri = Uri.parse("https://courses.zju.edu.cn/api/todos");

  DatabaseHelper? _db;
  Cookie? _session;
  Cookie? _iPlanetDirectoryPro;

  set db(DatabaseHelper? db) {
    _db = db;
  }

  Future<Tuple<Exception?, List<Todo>>> getTodo(HttpClient httpClient) async {
    try {
      await _ensureSession(httpClient);
      var body = await _requestTodo(httpClient);

      if (_isLoginPage(body)) {
        _session = null;
        await _ensureSession(httpClient);
        body = await _requestTodo(httpClient);
      }
      if (_isLoginPage(body)) {
        throw ExceptionWithMessage("未登录");
      }

      final todosJson = jsonDecode(body) as Map<String, dynamic>;
      _db?.setCachedWebPage("courses_todo", body);

      return Tuple(null, Todo.getAllFromCourses(todosJson));
    } catch (e) {
      var exception = _toException(e);
      return Tuple(exception, _getCachedTodos());
    }
  }

  Future<bool> login(HttpClient httpClient, Cookie? iPlanetDirectoryPro) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    if (iPlanetDirectoryPro == null) {
      throw ExceptionWithMessage("iPlanetDirectoryPro无效");
    }

    _session = null;
    _iPlanetDirectoryPro = iPlanetDirectoryPro;

    var cookies = <Cookie>[iPlanetDirectoryPro];

    Future<void> getWithCookies(String url) async {
      request = await httpClient.getUrl(Uri.parse(url)).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw ExceptionWithMessage("请求超时"),
          );
      request.followRedirects = false;
      request.cookies.addAll(cookies);
      response = await request.close().timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw ExceptionWithMessage("请求超时"),
          );
      cookies.addAll(response.cookies);
      response.drain();
      if (response.isRedirect) {
        if (response.headers.value(HttpHeaders.locationHeader)! ==
            ("https://courses.zju.edu.cn/user/index")) {
          _session = response.cookies.firstWhere(
            (cookie) => cookie.name == "session",
          );
          return;
        }
        return await getWithCookies(
          response.headers.value(HttpHeaders.locationHeader) as String,
        );
      }
    }

    await getWithCookies("https://courses.zju.edu.cn/user/index");
    if (_session == null) {
      throw ExceptionWithMessage("无法获取session");
    }

    return true;
  }

  void logout() {
    _session = null;
    _iPlanetDirectoryPro = null;
  }

  Future<void> _ensureSession(HttpClient httpClient) async {
    if (_session != null) return;

    if (_iPlanetDirectoryPro == null) {
      throw ExceptionWithMessage("未登录");
    }
    await login(httpClient, _iPlanetDirectoryPro);
  }

  Future<String> _requestTodo(HttpClient httpClient) async {
    final request = await httpClient.getUrl(_todoUri).timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"),
        );
    request.cookies.add(_session!);
    final response = await request.close().timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"),
        );

    return await response.transform(utf8.decoder).join();
  }

  bool _isLoginPage(String body) {
    return body.contains("cas/login") || body.contains("统一身份认证");
  }

  List<Todo> _getCachedTodos() {
    try {
      final cached = _db?.getCachedWebPage("courses_todo");
      if (cached == null) return [];

      return Todo.getAllFromCourses(jsonDecode(cached) as Map<String, dynamic>);
    } catch (_) {
      return [];
    }
  }

  Exception _toException(Object error) {
    if (error is SocketException) return ExceptionWithMessage("网络错误");
    if (error is Exception) return error;
    return ExceptionWithMessage(error.toString());
  }
}
