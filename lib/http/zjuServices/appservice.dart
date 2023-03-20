import 'dart:convert';
import 'dart:io';

import 'exceptions.dart';

class AppService {
  Cookie? _wisportalId;

  Future<bool> login(HttpClient httpClient, Cookie iPlanetDirectoryPro) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient.getUrl(Uri.parse(
        "https://zjuam.zju.edu.cn/cas/login?service=http%3A%2F%2Fappservice.zju.edu.cn%2F"));
    request.followRedirects = false;
    request.cookies.add(iPlanetDirectoryPro);
    response = await request.close();
    response.drain();

    request = await httpClient.getUrl(Uri.parse(
        response.headers.value('location') ??
            (throw CookieInvalidException("iPlanetDirectoryPro无效"))));
    request.followRedirects = false;
    response = await request.close();
    response.drain();

    try {
      _wisportalId = response.cookies
          .firstWhere((element) => element.name == 'wisportalId');
      return true;
    } catch (e) {
      throw CookieInvalidException("无法获取wisportalId");
    }
  }

  void logout() {
    _wisportalId = null;
  }

  Future<String> getTranscriptJson(HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient.postUrl(Uri.parse(
        "http://appservice.zju.edu.cn/zju-smartcampus/zdydjw/api/kkqk_cxXscjxx"));
    request.cookies.add(_wisportalId!);
    response = await request.close();

    var cjcxJson = RegExp('list":(.*?)},"')
        .firstMatch(await response.transform(utf8.decoder).join())
        ?.group(1);
    if (cjcxJson == null) throw CookieInvalidException("wisportalId无效");
    return cjcxJson;
  }

  Future<String> getSemestersJson(HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient.postUrl(Uri.parse(
        "http://appservice.zju.edu.cn/zju-smartcampus/zdydjw/api/kbdy_cxXnxq"));
    request.cookies.add(_wisportalId!);
    response = await request.close();

    var xnxqJson = RegExp('list":(.*?)}},"')
        .firstMatch(await response.transform(utf8.decoder).join())
        ?.group(1);
    if (xnxqJson == null) throw CookieInvalidException("wisportalId无效");
    return xnxqJson;
  }

  Future<String> getExamJson(HttpClient httpClient, String xn, String xq) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient.postUrl(Uri.parse(
        "http://appservice.zju.edu.cn/zju-smartcampus/zdydjw/api/kkqk_cxXsksxx"));
    request.cookies.add(_wisportalId!);
    request.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    request.add(utf8.encode('xn=$xn&xq=$xq'));
    response = await request.close();

    var examJson = RegExp('list":(.*?)},"')
        .firstMatch(await response.transform(utf8.decoder).join())
        ?.group(1);
    if (examJson == null) throw CookieInvalidException("wisportalId无效");
    return examJson;
  }

  Future<String> getTimetableJson(HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient.postUrl(Uri.parse(
        "http://appservice.zju.edu.cn/zju-smartcampus/zdydjw/api/kbdy_cxXsZKbxx"));
    request.cookies.add(_wisportalId!);
    request.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    request.add(utf8.encode('xn=2&xq='));
    response = await request.close();

    var courseJson = RegExp('"kblist":(.*?),"jxk')
        .firstMatch(await response.transform(utf8.decoder).join())
        ?.group(1);
    if (courseJson == null) throw CookieInvalidException("wisportalId无效");
    return courseJson;
  }
}
