import 'dart:io';
import 'exceptions.dart';
import 'package:fast_gbk/fast_gbk.dart';

class JwbInfoSys {

  Cookie? _aspNetSessionId;

  Future<bool> login(
      HttpClient httpClient, Cookie iPlanetDirectoryPro) async {

    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient
        .getUrl(Uri.parse("https://zjuam.zju.edu.cn/cas/login?service=http://jwbinfosys.zju.edu.cn/default2.aspx"));
    request.followRedirects = false;
    request.cookies.add(iPlanetDirectoryPro);
    response = await request.close();
    response.drain();

    request = await httpClient.getUrl(Uri.parse(response.headers.value('location') ?? (throw ExceptionWithMessage("iPlanetDirectoryPro无效")) ));
    request.followRedirects = false;
    response = await request.close();
    response.drain();

    if (response.cookies.any((element) => element.name == 'ASP.NET_SessionId')) {
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

  Future<String> getMajorGradeHtml(
      HttpClient httpClient, String username) async {

    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient.getUrl(
        Uri.parse(
            "http://jwbinfosys.zju.edu.cn/xscj_zg.aspx?xh=$username"));
    request.cookies.add(_aspNetSessionId!);
    request.followRedirects = false;
    response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      throw ExceptionWithMessage("无法获取主修成绩");
    }
    return await response.transform(gbk.decoder).join();
  }

  Future<String> getTranscriptHtml(HttpClient httpClient, String username) async {

    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient.getUrl(
        Uri.parse("http://jwbinfosys.zju.edu.cn/xscj.aspx?xh="));
    request.cookies.add(_aspNetSessionId!);
    request.followRedirects = false;
    response = await request.close();

    var html = await response.transform(gbk.decoder).join();
    var viewState = RegExp(r'"__VIEWSTATE" value="(.*?)"').firstMatch(html)?.group(1);
    if (viewState == null) throw ExceptionWithMessage("无法获取__VIEWSTATE");

    request = await httpClient.postUrl(
        Uri.parse(
            "http://jwbinfosys.zju.edu.cn/xscj.aspx?xh=$username"));
    request.cookies.add(_aspNetSessionId!);
    request.followRedirects = false;
    request.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded', charset: 'gb2312');
    request.add(gbk.encode('__VIEWSTATE=${Uri.encodeComponent(viewState)}&Button2=%D4%DA%D0%A3%D1%A7%CF%B0%B3%C9%BC%A8%B2%E9%D1%AF'));
    response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      throw ExceptionWithMessage("教务网炸了，无法获取成绩单");
    }
    return await response.transform(gbk.decoder).join();
  }

}
