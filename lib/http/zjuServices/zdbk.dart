import 'dart:convert';
import 'dart:io';
import 'package:celechron/http/zjuServices/tuple.dart';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/grade.dart';
import 'package:celechron/utils/gpa_helper.dart';
import 'package:celechron/model/session.dart';
import '../../model/exams_dto.dart';
import 'exceptions.dart';

class Zdbk {
  Cookie? _jSessionId;
  Cookie? _route;
  DatabaseHelper? _db;

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
            "https://zjuam.zju.edu.cn/cas/login?service=http%3A%2F%2Fzdbk.zju.edu.cn%2Fjwglxt%2Fxtgl%2Flogin_ssologin.html"))
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

    if (response.cookies.any((element) => element.name == 'JSESSIONID')) {
      _jSessionId = response.cookies
          .firstWhere((element) => element.name == 'JSESSIONID');
    } else {
      throw ExceptionWithMessage("无法获取JSESSIONID");
    }

    if (response.cookies.any((element) => element.name == 'route')) {
      _route =
          response.cookies.firstWhere((element) => element.name == 'route');
    } else {
      throw ExceptionWithMessage("无法获取route");
    }

    return true;
  }

  void logout() {
    _jSessionId = null;
    _route = null;
  }

  Future<Tuple<Exception?, List<double>>> getMajorGrade(
      HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      if (_jSessionId == null || _route == null) {
        throw ExceptionWithMessage("未登录");
      }
      request = await httpClient
          .postUrl(Uri.parse(
              "http://zdbk.zju.edu.cn/jwglxt/zycjtj/xszgkc_cxXsZgkcIndex.html?doType=query&queryModel.showCount=5000"))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_jSessionId!);
      request.cookies.add(_route!);
      request.followRedirects = false;
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      var transcriptJson = RegExp('(?<="items":)\\[(.*?)\\](?=,"limit")')
          .firstMatch(await response.transform(utf8.decoder).join())
          ?.group(0);
      if (transcriptJson == null) throw ExceptionWithMessage("无法解析");

      var grades = (jsonDecode(transcriptJson) as List<dynamic>)
          .where((e) => e['xkkh'] != null)
          .map((e) => Grade(e));
      var majorGpa = GpaHelper.calculateGpa(grades);
      _db?.setCachedWebPage('zdbk_MajorGrade', transcriptJson);
      return Tuple(null, [majorGpa.item1[0], majorGpa.item2]);
    } catch (e) {
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      var grades = (jsonDecode(_db?.getCachedWebPage('zdbk_MajorGrade') ?? '[]')
              as List<dynamic>)
          .where((e) => e['xkkh'] != null)
          .map((e) => Grade(e));
      var majorGpa = GpaHelper.calculateGpa(grades);
      return Tuple(exception, [majorGpa.item1[0], majorGpa.item2]);
    }
  }

  Future<Tuple<Exception?, Iterable<Grade>>> getTranscript(
      HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      if (_jSessionId == null || _route == null) {
        throw ExceptionWithMessage("未登录");
      }
      request = await httpClient
          .postUrl(Uri.parse(
              "http://zdbk.zju.edu.cn/jwglxt/cxdy/xscjcx_cxXscjIndex.html?doType=query&queryModel.showCount=5000"))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_jSessionId!);
      request.cookies.add(_route!);
      request.followRedirects = false;
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      var transcriptJson = RegExp('(?<="items":)\\[(.*?)\\](?=,"limit")')
          .firstMatch(await response.transform(utf8.decoder).join())
          ?.group(0);
      if (transcriptJson == null) throw ExceptionWithMessage("无法解析");

      var grades = (jsonDecode(transcriptJson) as List<dynamic>)
          .where((e) => e['xkkh'] != null)
          .map((e) => Grade(e));
      _db?.setCachedWebPage('zdbk_Transcript', transcriptJson);
      return Tuple(null, grades);
    } catch (e) {
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      return Tuple(
          exception,
          (jsonDecode((_db?.getCachedWebPage('zdbk_Transcript') ?? '[]'))
                  as List<dynamic>)
              .where((e) => e['xkkh'] != null)
              .map((e) => Grade(e)));
    }
  }

  Future<Tuple<Exception?, Iterable<Session>>> getTimetable(
      HttpClient httpClient, String year, String semester) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      if (_jSessionId == null || _route == null) {
        throw ExceptionWithMessage("未登录");
      }
      request = await httpClient
          .postUrl(Uri.parse(
              "http://zdbk.zju.edu.cn/jwglxt/kbcx/xskbcx_cxXsKb.html"))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_jSessionId!);
      request.cookies.add(_route!);
      request.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.add(utf8.encode('xnm=$year&xqm=$semester'));
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      var html = await response.transform(utf8.decoder).join();
      var timetableJson = RegExp('(?<="kbList":)\\[(.*?)\\](?=,"xh")')
          .firstMatch(html)
          ?.group(0);
      if (timetableJson == null) throw ExceptionWithMessage("无法解析");

      var sessions = (jsonDecode(timetableJson) as List<dynamic>)
          .where((e) => e['kcb'] != null)
          .map((e) => Session.fromZdbk(e));
      _db?.setCachedWebPage('zdbk_Timetable$year$semester', timetableJson);
      return Tuple(null, sessions);
    } catch (e) {
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      return Tuple(
          exception,
          (jsonDecode((_db?.getCachedWebPage('zdbk_Timetable$year$semester') ?? '[]'))
                  as List<dynamic>)
              .where((e) => e['kcb'] != null)
              .map((e) => Session.fromZdbk(e)));
    }
  }

  Future<Tuple<Exception?, Iterable<ExamDto>>> getExamsDto(
      HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      if (_jSessionId == null || _route == null) {
        throw ExceptionWithMessage("未登录");
      }
      request = await httpClient
          .postUrl(Uri.parse(
          "http://zdbk.zju.edu.cn/jwglxt/xskscx/kscx_cxXsgrksIndex.html?doType=query&queryModel.showCount=5000"))
          .timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_jSessionId!);
      request.cookies.add(_route!);
      request.followRedirects = false;
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      var transcriptJson = RegExp('(?<="items":)\\[(.*?)\\](?=,"limit")')
          .firstMatch(await response.transform(utf8.decoder).join())
          ?.group(0);
      if (transcriptJson == null) throw ExceptionWithMessage("无法解析");

      var exams = (jsonDecode(transcriptJson) as List<dynamic>)
          .where((e) => e['xkkh'] != null)
          .map((e) => ExamDto.fromZdbk(e));
      _db?.setCachedWebPage('zdbk_exams', transcriptJson);
      return Tuple(null, exams);
    } catch (e) {
      var exception =
      e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      return Tuple(
          exception,
          (jsonDecode((_db?.getCachedWebPage('zdbk_exams') ?? '[]'))
          as List<dynamic>)
              .where((e) => e['xkkh'] != null)
              .map((e) => ExamDto.fromZdbk(e)));
    }
  }
}
