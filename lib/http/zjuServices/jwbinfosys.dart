import 'dart:io';
import 'package:celechron/http/zjuServices/tuple.dart';

import '../../database/database_helper.dart';
import '../../model/grade.dart';
import 'package:get/get.dart';
import 'exceptions.dart';
import 'package:fast_gbk/fast_gbk.dart';

class JwbInfoSys {
  Cookie? _aspNetSessionId;
  final DatabaseHelper _db = Get.find<DatabaseHelper>(tag: 'db');

  Future<bool> login(HttpClient httpClient, Cookie? iPlanetDirectoryPro) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    if(iPlanetDirectoryPro == null) {
      throw ExceptionWithMessage("iPlanetDirectoryPro无效");
    }
    request = await httpClient.getUrl(Uri.parse(
        "https://zjuam.zju.edu.cn/cas/login?service=http://jwbinfosys.zju.edu.cn/default2.aspx")).timeout(const Duration(seconds: 8), onTimeout: () => throw ExceptionWithMessage("请求超时"));
    request.followRedirects = false;
    request.cookies.add(iPlanetDirectoryPro);
    response = await request.close().timeout(const Duration(seconds: 8), onTimeout: () => throw ExceptionWithMessage("请求超时"));
    response.drain();

    request = await httpClient.getUrl(Uri.parse(
        response.headers.value('location') ??
            (throw ExceptionWithMessage("iPlanetDirectoryPro无效")))).timeout(const Duration(seconds: 8), onTimeout: () => throw ExceptionWithMessage("请求超时"));
    request.followRedirects = false;
    response = await request.close().timeout(const Duration(seconds: 8), onTimeout: () => throw ExceptionWithMessage("请求超时"));
    response.drain();

    if (response.cookies
        .any((element) => element.name == 'ASP.NET_SessionId')) {
      _aspNetSessionId = response.cookies
          .firstWhere((element) => element.name == 'ASP.NET_SessionId');
    } else {
      throw ExceptionWithMessage("无法获取ASP.NET_SessionId");
    }

    return true;
  }

  void logout() {
    _aspNetSessionId = null;
  }

  Future<Tuple<Exception?,List<double>>> getMajorGrade(
      HttpClient httpClient, String username) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      if(_aspNetSessionId == null) throw ExceptionWithMessage("未登录");
      request = await httpClient.getUrl(
          Uri.parse("http://jwbinfosys.zju.edu.cn/xscj_zg.aspx?xh=$username"))
          .timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_aspNetSessionId!);
      request.followRedirects = false;
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      if (response.statusCode != HttpStatus.ok) {
        throw ExceptionWithMessage("教务网炸了");
      }
      var html = await response.transform(gbk.decoder).join();

      var majorGradeAndGpa = [double.parse(
          RegExp(r'平均绩点=([0-9.]+)').firstMatch(html)?.group(1) ?? "0.00"), double.parse(
          RegExp(r'总学分=([0-9.]+)').firstMatch(html)?.group(1) ?? "0.00")];
      _db.setCachedWebPage('jwbInfoSys_MajorGrade', html);
      return Tuple(null, majorGradeAndGpa);

    } catch (e) {
      var exception = e is SocketException
          ? ExceptionWithMessage("网络错误") : e as Exception;
      return Tuple(exception, [
        double.parse(
            RegExp(r'平均绩点=([0-9.]+)').firstMatch(
                _db.getCachedWebPage('jwbInfoSys_MajorGrade') ?? "")?.group(1) ??
                "0.00"),
        double.parse(
            RegExp(r'总学分=([0-9.]+)').firstMatch(
                _db.getCachedWebPage('jwbInfoSys_MajorGrade') ?? "")?.group(1) ??
                "0.00")
      ]);
    }
  }

  Future<Tuple<Exception?,Iterable<Grade>>> getTranscript(
      HttpClient httpClient, String username) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      if(_aspNetSessionId == null) throw ExceptionWithMessage("未登录");
      request = await httpClient
          .getUrl(Uri.parse("http://jwbinfosys.zju.edu.cn/xscj.aspx?xh=")).timeout(
              const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_aspNetSessionId!);
      request.followRedirects = false;
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      var html = await response.transform(gbk.decoder).join();
      var viewState =
          RegExp(r'"__VIEWSTATE" value="(.*?)"').firstMatch(html)?.group(1);
      if (viewState == null) throw ExceptionWithMessage("无法获取__VIEWSTATE");

      request = await httpClient.postUrl(
          Uri.parse("http://jwbinfosys.zju.edu.cn/xscj.aspx?xh=$username")).timeout(
              const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_aspNetSessionId!);
      request.followRedirects = false;
      request.headers.contentType = ContentType(
          'application', 'x-www-form-urlencoded',
          charset: 'gb2312');
      request.add(gbk.encode(
          '__VIEWSTATE=${Uri.encodeComponent(viewState)}&Button2=%D4%DA%D0%A3%D1%A7%CF%B0%B3%C9%BC%A8%B2%E9%D1%AF'));
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      if (response.statusCode != HttpStatus.ok) {
        throw ExceptionWithMessage("教务网炸了");
      }

      html = await response.transform(gbk.decoder).join();
      var grades = RegExp(
              r'<td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>&nbsp;</td>')
          .allMatches(html)
          .map((e) => Grade([
                e.group(1)!,
                e.group(2)!,
                e.group(3)!,
                e.group(4)!,
                e.group(5)!
              ]));
      _db.setCachedWebPage('jwbInfoSys_Transcript', html);
      return Tuple(null, grades);
    } catch (e) {
      var exception = e is SocketException
          ? ExceptionWithMessage("网络错误") : e as Exception;
      return Tuple(exception, RegExp(
          r'<td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>(.*?)</td><td>&nbsp;</td>')
          .allMatches(_db.getCachedWebPage('jwbInfoSys_Transcript') ?? "")
          .map((e) => Grade([
        e.group(1)!,
        e.group(2)!,
        e.group(3)!,
        e.group(4)!,
        e.group(5)!
      ])));
    }
  }
}
