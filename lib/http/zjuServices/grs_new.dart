import 'dart:convert';
import 'dart:io';

import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/http/zjuServices/tuple.dart';
import 'package:celechron/model/session.dart';

class GrsNew {
  String? _token;

  Future<void> login(HttpClient httpClient, Cookie? ssoCookie) async {
    late HttpClientRequest req;
    late HttpClientResponse res;

    if (ssoCookie == null) {
      throw ExceptionWithMessage("Invalid ssoCookie");
    }

    req = await httpClient
        .getUrl(Uri.parse(
        "https://zjuam.zju.edu.cn/cas/login?service=https%3A%2F%2Fyjsy.zju.edu.cn%2F"))
        .timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("request timeout"));
    req.followRedirects = false;
    req.cookies.add(ssoCookie);
    res = await req.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("request timeout"));
    res.drain();

    final headerLoc = res.headers.value("location");
    if (headerLoc == null) {
      throw ExceptionWithMessage("Invalid location header");
    }
    final ticketLoc = headerLoc.indexOf("ticket=");
    if (ticketLoc < 0) {
      throw ExceptionWithMessage("Invalid location header");
    }
    final ticket = headerLoc.substring(ticketLoc + 7);

    req = await httpClient
        .getUrl(Uri.parse(
        "https://yjsy.zju.edu.cn/dataapi/sys/cas/client/validateLogin?ticket=${ticket}&service=https:%2F%2Fyjsy.zju.edu.cn%2F"))
        .timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("request timeout"));
    res = await req.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("request timeout"));
    final loginJson = await res.transform(utf8.decoder).join();

    // parse loginJson body
    final loginInfo = jsonDecode(loginJson) as Map<String, dynamic>;
    if (loginInfo["success"] != true) {
      throw ExceptionWithMessage("Invalid login info");
    }
    final loginResult = loginInfo["result"] as Map<String, dynamic>;
    _token = loginResult["token"] as String?;
    if (_token == null) {
      throw ExceptionWithMessage("Invalid token");
    }
  }

  void logout() {
    _token = null;
  }

  Future<Tuple<Exception?, Iterable<Session>>> getTimetable(
      HttpClient httpClient, int year, int semester) async {
    /*
     * semester:
     * 11: spring
     * 12: summer
     * 13: autumn
     * 14: winter
     * 15: spring-summer
     * 16: autumn-winter
     */
    late HttpClientRequest req;
    late HttpClientResponse res;
    try {
      if (_token == null) {
        throw ExceptionWithMessage("not logged in");
      }

      req = await httpClient.getUrl(Uri.parse(
          "https://yjsy.zju.edu.cn/dataapi/py/pyKcbj/queryXskbByLoginUser?xn=$year&pkxq=$semester"))
          .timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("request timeout"));
      req.headers.add("X-Access-Token", _token!);
      res = await req.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("request timeout"));
      final resultJson = await res.transform(utf8.decoder).join();

      final result = jsonDecode(resultJson) as Map<String, dynamic>;
      if (result["success"] != true) {
        throw ExceptionWithMessage("Invalid login info");
      }

      Map<String, dynamic> defaultMap = {};
      final dayWithClasses = result["result"] as Map<String, dynamic>;
      List<Session> sessions = [];
      for (int i = 1; i <= 7; ++i) {
        var classesThisDay = (dayWithClasses["$i"] ?? defaultMap) as Map<String, dynamic>;
        Map<String, Session> sessionThisDay = {};
        for (int j = 1; j <= 15; ++j) {
          var wrapper = (classesThisDay["$j"] ?? defaultMap) as Map<String, dynamic>;
          var classesThisPeriod = (wrapper["pyKcbjSjddVOList"] ?? []) as List<dynamic>;

          for (var rawClassDyn in classesThisPeriod) {
            try {
              var rawClass = rawClassDyn as Map<String, dynamic>;
              String classId = rawClass["bjbh"] as String;
              String sessionId = classId.substring(0, 6);

              if (sessionThisDay.containsKey(classId)) {
                sessionThisDay[classId]!.time.add(j);
                continue;
              }

              int classSemester = int.parse(rawClass["pkxq"] ?? "$semester");
              var newSession = Session.empty();
              newSession.id = sessionId;
              newSession.grsClass = true;
              newSession.name = rawClass["kcmc"] as String;
              newSession.teacher = "";
              newSession.location = rawClass["cdmc"] as String?;
              newSession.confirmed = true;
              newSession.dayOfWeek = i;
              newSession.time = [j];
              if (semester == 11 || semester == 13) {
                newSession.firstHalf = true;
              } else {
                newSession.secondHalf = true;
              }
              if (classSemester == 15 || classSemester == 16) {
                newSession.firstHalf = newSession.secondHalf = true;
              }
              // TODO: dsz
              newSession.oddWeek = newSession.evenWeek = true;

              sessionThisDay[classId] = newSession;
            }
            finally {
              // log here?
            }
          }
        }

        sessions.addAll(sessionThisDay.values);
      }

      return Tuple(null, sessions);
    }
    catch (e, s) {
      print(e);
      print(s);
      return Tuple(null, []);
    }
    finally {}
  }
}

void main() async {
  const str = "https://yjsy.zju.edu.cn/?ticket=ST-399";
  int ticketLoc = str.indexOf("ticket=");
  print(str.substring(ticketLoc + 7, 2));
}
