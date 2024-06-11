import 'dart:convert';
import 'dart:io';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/zjuServices/tuple.dart';
import 'package:celechron/model/exams_dto.dart';

import 'package:celechron/model/session.dart';
import 'exceptions.dart';

class AppService {
  Cookie? _wisportalId;
  DatabaseHelper? _db;

  AppService({DatabaseHelper? db}) {
    _db = db;
  }

  set db(DatabaseHelper? db) {
    _db = db;
  }

  Future<bool> login(HttpClient httpClient, Cookie? iPlanetDirectoryPro) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    if (iPlanetDirectoryPro == null) {
      throw ExceptionWithMessage("iPlanetDirectoryPro无效");
    }
    request = await httpClient
        .getUrl(Uri.parse(
            "https://zjuam.zju.edu.cn/cas/login?service=http%3A%2F%2Fappservice.zju.edu.cn%2F"))
        .timeout(const Duration(seconds: 8),
            onTimeout: () => throw ExceptionWithMessage("请求超时"));
    request.followRedirects = false;
    request.cookies.add(iPlanetDirectoryPro);
    response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));
    response.drain();

    request = await httpClient
        .getUrl(Uri.parse(response.headers.value('location') ??
            (throw ExceptionWithMessage("iPlanetDirectoryPro无效"))))
        .timeout(const Duration(seconds: 8),
            onTimeout: () => throw ExceptionWithMessage("请求超时"));
    request.followRedirects = false;
    response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));
    response.drain();

    try {
      _wisportalId = response.cookies
          .firstWhere((element) => element.name == 'wisportalId');
      return true;
    } catch (e) {
      throw ExceptionWithMessage("无法获取wisportalId");
    }
  }

  void logout() {
    _wisportalId = null;
  }

  Future<String> getTranscript(HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient.postUrl(Uri.parse(
        "http://appservice.zju.edu.cn/zju-smartcampus/zdydjw/api/kkqk_cxXscjxx"));
    request.cookies.add(_wisportalId!);
    response = await request.close();

    var cjcxJson = RegExp('list":(.*?)},"')
        .firstMatch(await response.transform(utf8.decoder).join())
        ?.group(1);
    if (cjcxJson == null) throw ExceptionWithMessage("wisportalId无效");
    return cjcxJson;
  }

  Future<String> getSemesters(HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient.postUrl(Uri.parse(
        "http://appservice.zju.edu.cn/zju-smartcampus/zdydjw/api/kbdy_cxXnxq"));
    request.cookies.add(_wisportalId!);
    response = await request.close();

    var xnxqJson = RegExp('list":(.*?)}},"')
        .firstMatch(await response.transform(utf8.decoder).join())
        ?.group(1);
    if (xnxqJson == null) throw ExceptionWithMessage("wisportalId无效");
    return xnxqJson;
  }

  Future<Tuple<Exception?, Iterable<ExamDto>>> getExamsDto(
      HttpClient httpClient, String xn, String xq) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      if (_wisportalId == null) throw ExceptionWithMessage("未登录");
      request = await httpClient
          .postUrl(Uri.parse(
              "http://appservice.zju.edu.cn/zju-smartcampus/zdydjw/api/kkqk_cxXsksxx"))
          .timeout(const Duration(seconds: 5),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_wisportalId!);
      request.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.add(utf8.encode('xn=$xn&xq=$xq'));
      response = await request.close().timeout(const Duration(seconds: 5),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      var examJson = RegExp('list":(.*?)},"')
          .firstMatch(await response.transform(utf8.decoder).join())
          ?.group(1);
      if (examJson == null) throw ExceptionWithMessage("Cookie无效或参数错误");

      var examDtos =
          (jsonDecode(examJson) as List<dynamic>).map((e) => ExamDto(e));

      _db?.setCachedWebPage('appService_examDto_$xn-$xq', examJson);
      return Tuple(null, examDtos);
    } catch (e) {
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      return Tuple(
          exception,
          (jsonDecode((_db?.getCachedWebPage('appService_examDto_$xn-$xq') ??
                  '[]')) as List<dynamic>)
              .map((e) => ExamDto(e)));
    }
  }

  // 这个API用了些Trick————只要输入的学年和学期不合法，就会返回一个包含所有学期课程的课表
  // 如果哪天不行了，就还是按照传统的学年+学期传参老老实实爬吧
  // 修复API返回的课表中的括号不是中文字符的问题
  Future<Tuple<Exception?, Iterable<Session>>> getTimetable(
      HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      if (_wisportalId == null) throw ExceptionWithMessage("未登录");
      request = await httpClient
          .postUrl(Uri.parse(
              "http://appservice.zju.edu.cn/zju-smartcampus/zdydjw/api/kbdy_cxXsZKbxx"))
          .timeout(const Duration(seconds: 5),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_wisportalId!);
      request.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.add(utf8.encode('xn=0&xq=0'));
      response = await request.close().timeout(const Duration(seconds: 5),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      var courseJson = RegExp('"kblist":(.*?),"jxk')
          .firstMatch(await response.transform(utf8.decoder).join())
          ?.group(1);
      if (courseJson == null) throw ExceptionWithMessage("无法解析");

      var sessions = (jsonDecode(courseJson) as List<dynamic>)
          .where((e) => e['kcid'] != null)
          .map((e) => Session(e));
      _db?.setCachedWebPage('appService_Timetable', courseJson);
      return Tuple(null, sessions);
    } catch (e) {
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      return Tuple(
          exception,
          (jsonDecode((_db?.getCachedWebPage('appService_Timetable') ?? '[]'))
                  as List<dynamic>)
              .where((e) => e['kcid'] != null)
              .map((e) => Session(e)));
    }
  }
}
