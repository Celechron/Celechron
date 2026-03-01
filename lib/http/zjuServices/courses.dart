// This implementation is adapted from the project "login-ZJU" by 5dbwat4(https://github.com/5dbwat4/login-ZJU) under the MIT License.
// See: https://github.com/5dbwat4/login-ZJU/blob/main/src/utils/fetch-with-cookie.ts

import 'dart:convert';
import 'dart:io';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:celechron/model/todo.dart';

class Courses {
  DatabaseHelper? _db;
  Cookie? _session;
  Cookie? _iPlanetDirectoryPro; // ← 新增这一行，保存登录凭据

  set db(DatabaseHelper? db) {
    _db = db;
  }

  Future<Tuple<Exception?, List<Todo>>> getTodo(HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      if (_session == null) {
        // ===== 改动：不再直接报错，而是尝试重新登录 =====
        if (_iPlanetDirectoryPro != null) {
          await login(httpClient, _iPlanetDirectoryPro);
        } else {
          throw ExceptionWithMessage("未登录");
        }
      }
      request = await httpClient
          .getUrl(Uri.parse("https://courses.zju.edu.cn/api/todos"))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_session!);
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      var body = await response.transform(utf8.decoder).join();

      // 检查返回内容是否是登录页面（说明session过期了）
      if (body.contains("cas/login") || body.contains("统一身份认证")) {
        // session过期了，尝试重新登录
        _session = null;
        if (_iPlanetDirectoryPro != null) {
          await login(httpClient, _iPlanetDirectoryPro);
          // 重新请求
          request = await httpClient
              .getUrl(Uri.parse("https://courses.zju.edu.cn/api/todos"))
              .timeout(const Duration(seconds: 8),
                  onTimeout: () => throw ExceptionWithMessage("请求超时"));
          request.cookies.add(_session!);
          response = await request.close().timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
          body = await response.transform(utf8.decoder).join();
        }
      }

      _db?.setCachedWebPage("courses_todo", body);

      return Tuple(null,
          Todo.getAllFromCourses((jsonDecode(body) as Map<String, dynamic>)));
    } catch (e) {
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      // 出错了也不怕，返回缓存数据，用户看不到报错
      var todos = Todo.getAllFromCourses(
          (jsonDecode(_db?.getCachedWebPage("courses_todo") ?? '{}')));
      return Tuple(exception, todos);
    }
  }

  Future<bool> login(HttpClient httpClient, Cookie? iPlanetDirectoryPro) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    if (iPlanetDirectoryPro == null) {
      throw ExceptionWithMessage("iPlanetDirectoryPro无效");
    }

    _iPlanetDirectoryPro = iPlanetDirectoryPro; // ← 新增：保存凭据以便自动重登

    var cookies = <Cookie>[iPlanetDirectoryPro];

    Future<void> getWithCookies(String url) async {
      request = await httpClient.getUrl(Uri.parse(url)).timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.followRedirects = false;
      request.cookies.addAll(cookies);
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      cookies.addAll(response.cookies);
      response.drain();
      if (response.isRedirect) {
        if (response.headers.value(HttpHeaders.locationHeader)! ==
            ("https://courses.zju.edu.cn/user/index")) {
          _session =
              response.cookies.firstWhere((cookie) => cookie.name == "session");
          return;
        }
        return await getWithCookies(
            response.headers.value(HttpHeaders.locationHeader) as String);
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
  }
}
