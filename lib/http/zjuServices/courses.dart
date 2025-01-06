import 'dart:convert';
import 'dart:io';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/http/zjuServices/tuple.dart';

// See: https://github.com/5dbwat4/login-ZJU/blob/main/src/utils/fetch-with-cookie.ts

class Courses {
  DatabaseHelper? _db;
  Cookie? _session;

  set db(DatabaseHelper? db) {
    _db = db;
  }

  Future<bool> login(HttpClient httpClient, Cookie? iPlanetDirectoryPro) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    if (iPlanetDirectoryPro == null) return false;
    var cookies = <Cookie>[iPlanetDirectoryPro];

    Future<void> getWithCookies(String url) async {
      request = await httpClient.getUrl(Uri.parse(url));
      request.followRedirects = false;
      request.cookies.addAll(cookies);
      response = await request.close();
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
      return false;
    }

    // request = await httpClient
    //     .getUrl(Uri.parse("https://courses.zju.edu.cn/api/todos"));
    // request.cookies.add(_session!);
    // response = await request.close();
    // print(await response.transform(utf8.decoder).join());

    return true;
  }

  void logout() {
    _session = null;
  }

  Future<Tuple<Exception?, List<double>>> getTodo(HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      if (_session == null) {
        throw ExceptionWithMessage("未登录");
      }
      request = await httpClient
          .getUrl(Uri.parse("https://courses.zju.edu.cn/api/todos"))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_session!);
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      var transcriptJson = await response.transform(utf8.decoder).join();

      var todos =
          (jsonDecode(transcriptJson) as Map<dynamic, dynamic>)["todo_list"];
      print(todos);
      // var majorGpa = GpaHelper.calculateGpa(grades);
      // _db?.setCachedWebPage('zdbk_MajorGrade', transcriptJson);
      // return Tuple(null, [majorGpa.item1[0], majorGpa.item2]);
    } catch (e) {
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      // var grades = (jsonDecode(_db?.getCachedWebPage('zdbk_MajorGrade') ?? '[]')
      //         as List<dynamic>)
      //     .where((e) => e['xkkh'] != null)
      //     .map((e) => Grade(e));
      // var majorGpa = GpaHelper.calculateGpa(grades);
      // return Tuple(exception, [majorGpa.item1[0], majorGpa.item2]);
    }
  }
}
