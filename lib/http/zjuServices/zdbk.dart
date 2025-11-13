import 'dart:convert';
import 'dart:io';
import 'package:celechron/utils/tuple.dart';

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
            "https://zjuam.zju.edu.cn/cas/login?service=https%3A%2F%2Fzdbk.zju.edu.cn%2Fjwglxt%2Fxtgl%2Flogin_ssologin.html"))
        .timeout(const Duration(seconds: 8),
            onTimeout: () => throw ExceptionWithMessage("请求超时"));
    request.followRedirects = false;
    request.cookies.add(iPlanetDirectoryPro);
    response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));
    response.drain();

    var stLocation = response.headers.value('location');
    if (stLocation == null) {
      throw ExceptionWithMessage("iPlanetDirectoryPro无效");
    } else if (stLocation.startsWith("http://")) {
      stLocation = stLocation.replaceFirst("http://", "https://");
    }
    request = await httpClient.getUrl(Uri.parse(stLocation)).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));
    request.followRedirects = false;
    response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));
    response.drain();

    if (response.cookies.any((element) =>
        element.name == 'JSESSIONID' && element.path == '/jwglxt')) {
      _jSessionId = response.cookies.firstWhere((element) =>
          element.name == 'JSESSIONID' && element.path == '/jwglxt');
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

  Future<Tuple<Exception?, Tuple<List<double>, String>>> getMajorGrade(
      HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      if (_jSessionId == null || _route == null) {
        throw ExceptionWithMessage("未登录");
      }
      request = await httpClient
          .postUrl(Uri.parse(
              "https://zdbk.zju.edu.cn/jwglxt/zycjtj/xszgkc_cxXsZgkcIndex.html?doType=query&queryModel.showCount=5000"))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_jSessionId!);
      request.cookies.add(_route!);
      request.followRedirects = false;
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      var responseText = await response.transform(utf8.decoder).join();
      var transcriptJson = RegExp('(?<="items":)\\[(.*?)\\](?=,"limit")')
          .firstMatch(responseText)
          ?.group(0);
      if (transcriptJson == null) throw ExceptionWithMessage("无法解析");

      // 创建成绩对象并标记为主修课程
      var grades = (jsonDecode(transcriptJson) as List<dynamic>)
          .where((e) => e['xkkh'] != null)
          .map((e) {
        var grade = Grade(e);
        grade.major = true; // 标记为主修课程
        return grade;
      });
      var majorGpa = GpaHelper.calculateGpa(grades);
      _db?.setCachedWebPage('zdbk_MajorGrade', transcriptJson);
      return Tuple(
          null, Tuple([majorGpa.item1[0], majorGpa.item2], responseText));
    } catch (e) {
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      var cachedJson = _db?.getCachedWebPage('zdbk_MajorGrade') ?? '[]';
      var grades = (jsonDecode(cachedJson) as List<dynamic>)
          .where((e) => e['xkkh'] != null)
          .map((e) {
        var grade = Grade(e);
        grade.major = true; // 标记为主修课程
        return grade;
      });
      var majorGpa = GpaHelper.calculateGpa(grades);
      return Tuple(
          exception,
          Tuple([majorGpa.item1[0], majorGpa.item2],
              '{"items":$cachedJson,"limit":0}'));
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
              "https://zdbk.zju.edu.cn/jwglxt/cxdy/xscjcx_cxXscjIndex.html?doType=query&queryModel.showCount=5000"))
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
              "https://zdbk.zju.edu.cn/jwglxt/kbcx/xskbcx_cxXsKb.html"))
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
          (jsonDecode((_db?.getCachedWebPage('zdbk_Timetable$year$semester') ??
                  '[]')) as List<dynamic>)
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
              "https://zdbk.zju.edu.cn/jwglxt/xskscx/kscx_cxXsgrksIndex.html?doType=query&queryModel.showCount=5000"))
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

  Future<Tuple<Exception?, Map<String, double>>> getPracticeScores(
      HttpClient httpClient, String studentId) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      if (_jSessionId == null || _route == null) {
        throw ExceptionWithMessage("未登录");
      }
      request = await httpClient
          .getUrl(Uri.parse(
              "https://zdbk.zju.edu.cn/jwglxt/dessktgl/dessktcx_cxDessktcxIndex.html?gnmkdm=N108001&layout=default&su=$studentId"))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_jSessionId!);
      request.cookies.add(_route!);
      request.followRedirects = false;
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      var html = await response.transform(utf8.decoder).join();
      _db?.setCachedWebPage("zdbk_practiceScores", html);

      // Parse HTML to extract scores from table
      // Look for table rows with 第二课堂, 第三课堂, 第四课堂
      var scores = <String, double>{
        'pt2': 0.0,
        'pt3': 0.0,
        'pt4': 0.0,
      };

      // Match table rows: <tr>...</tr> containing the classroom types
      var rowPattern = RegExp(
          r'<tr>.*?<td[^>]*>.*?</td>.*?<td[^>]*>(.*?)</td>.*?<td[^>]*>(.*?)</td>.*?</tr>',
          dotAll: true);
      var matches = rowPattern.allMatches(html);

      for (var match in matches) {
        var type = match.group(1)?.trim();
        var scoreStr = match.group(2)?.trim();
        if (type == null || scoreStr == null) continue;

        double? score;
        try {
          score = double.tryParse(scoreStr);
        } catch (_) {
          continue;
        }
        if (score == null) continue;

        if (type.contains('第二课堂')) {
          scores['pt2'] = score;
        } else if (type.contains('第三课堂')) {
          scores['pt3'] = score;
        } else if (type.contains('第四课堂')) {
          scores['pt4'] = score;
        }
      }

      // If we didn't find any scores, try alternative pattern
      if (scores['pt2'] == 0.0 && scores['pt3'] == 0.0 && scores['pt4'] == 0.0) {
        // Try matching rows more directly
        var altPattern = RegExp(
            r'<td[^>]*>第二课堂</td>.*?<td[^>]*>([0-9.]+)</td>',
            dotAll: true);
        var pt2Match = altPattern.firstMatch(html);
        if (pt2Match != null) {
          scores['pt2'] = double.tryParse(pt2Match.group(1) ?? '0') ?? 0.0;
        }

        altPattern = RegExp(r'<td[^>]*>第三课堂</td>.*?<td[^>]*>([0-9.]+)</td>',
            dotAll: true);
        var pt3Match = altPattern.firstMatch(html);
        if (pt3Match != null) {
          scores['pt3'] = double.tryParse(pt3Match.group(1) ?? '0') ?? 0.0;
        }

        altPattern = RegExp(r'<td[^>]*>第四课堂</td>.*?<td[^>]*>([0-9.]+)</td>',
            dotAll: true);
        var pt4Match = altPattern.firstMatch(html);
        if (pt4Match != null) {
          scores['pt4'] = double.tryParse(pt4Match.group(1) ?? '0') ?? 0.0;
        }
      }

      return Tuple(null, scores);
    } catch (e) {
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      // Try to parse from cache
      var cachedHtml = _db?.getCachedWebPage("zdbk_practiceScores");
      if (cachedHtml != null) {
        try {
          var scores = <String, double>{
            'pt2': 0.0,
            'pt3': 0.0,
            'pt4': 0.0,
          };

          var altPattern = RegExp(
              r'<td[^>]*>第二课堂</td>.*?<td[^>]*>([0-9.]+)</td>',
              dotAll: true);
          var pt2Match = altPattern.firstMatch(cachedHtml);
          if (pt2Match != null) {
            scores['pt2'] = double.tryParse(pt2Match.group(1) ?? '0') ?? 0.0;
          }

          altPattern = RegExp(r'<td[^>]*>第三课堂</td>.*?<td[^>]*>([0-9.]+)</td>',
              dotAll: true);
          var pt3Match = altPattern.firstMatch(cachedHtml);
          if (pt3Match != null) {
            scores['pt3'] = double.tryParse(pt3Match.group(1) ?? '0') ?? 0.0;
          }

          altPattern = RegExp(r'<td[^>]*>第四课堂</td>.*?<td[^>]*>([0-9.]+)</td>',
              dotAll: true);
          var pt4Match = altPattern.firstMatch(cachedHtml);
          if (pt4Match != null) {
            scores['pt4'] = double.tryParse(pt4Match.group(1) ?? '0') ?? 0.0;
          }

          return Tuple(exception, scores);
        } catch (_) {
          // Cache parsing failed
        }
      }
      return Tuple(exception, {'pt2': 0.0, 'pt3': 0.0, 'pt4': 0.0});
    }
  }
}
