import 'dart:convert';
import 'dart:io';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/utils/tuple.dart';

class Sztz {
  DatabaseHelper? _db;
  Cookie? _session;

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
            "https://zjuam.zju.edu.cn/cas/login?service=https://sztz.zju.edu.cn/dekt/"))
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

    var cookies = <Cookie>[iPlanetDirectoryPro];
    Future<void> followRedirects(String url) async {
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
        var location = response.headers.value(HttpHeaders.locationHeader);
        if (location != null) {
          if (location.startsWith("http://")) {
            location = location.replaceFirst("http://", "https://");
          }
          return await followRedirects(location);
        }
      }
      // 尝试获取 session cookie
      if (response.cookies.any((cookie) => cookie.name == "session")) {
        _session = response.cookies.firstWhere((cookie) => cookie.name == "session");
      }
    }

    await followRedirects(stLocation);
    if (_session == null) {
      throw ExceptionWithMessage("无法获取session");
    }

    return true;
  }

  Future<Tuple<Exception?, Map<String, double>>> getMyInfo(
      HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      if (_session == null) {
        throw ExceptionWithMessage("未登录");
      }
      request = await httpClient
          .getUrl(Uri.parse(
              "https://sztz.zju.edu.cn/dekt/student/home/getMyInfo"))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_session!);
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      var body = await response.transform(utf8.decoder).join();
      _db?.setCachedWebPage("sztz_myInfo", body);

      try {
        var jsonResponse = jsonDecode(body) as Map<String, dynamic>;
        if (jsonResponse['code'] == 0 && jsonResponse['extend'] != null) {
          var extend = jsonResponse['extend'];
          if (extend is Map<String, dynamic> && extend['myInfo'] != null) {
            var myInfo = extend['myInfo'];
            if (myInfo is Map<String, dynamic>) {
              var scores = <String, double>{
                'dektJf': (myInfo['dektJf'] as num?)?.toDouble() ?? 0.0,
                'dsktJf': (myInfo['dsktJf'] as num?)?.toDouble() ?? 0.0,
                'dsiktJf': (myInfo['dsiktJf'] as num?)?.toDouble() ?? 0.0,
              };
              return Tuple(null, scores);
            }
          }
        }
      } catch (e) {
        // 解析失败，返回默认值
        return Tuple(
            ExceptionWithMessage("解析响应失败: $e"),
            {'dektJf': 0.0, 'dsktJf': 0.0, 'dsiktJf': 0.0});
      }
      // 如果响应格式不对，返回默认值
      return Tuple(
          ExceptionWithMessage("无法获取实践学分信息"),
          {'dektJf': 0.0, 'dsktJf': 0.0, 'dsiktJf': 0.0});
    } catch (e) {
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      // 尝试从缓存读取
      var cachedBody = _db?.getCachedWebPage("sztz_myInfo");
      if (cachedBody != null) {
        try {
          var jsonResponse = jsonDecode(cachedBody) as Map<String, dynamic>;
          if (jsonResponse['code'] == 0 && jsonResponse['extend'] != null) {
            var extend = jsonResponse['extend'];
            if (extend is Map<String, dynamic> && extend['myInfo'] != null) {
              var myInfo = extend['myInfo'];
              if (myInfo is Map<String, dynamic>) {
                var scores = <String, double>{
                  'dektJf': (myInfo['dektJf'] as num?)?.toDouble() ?? 0.0,
                  'dsktJf': (myInfo['dsktJf'] as num?)?.toDouble() ?? 0.0,
                  'dsiktJf': (myInfo['dsiktJf'] as num?)?.toDouble() ?? 0.0,
                };
                return Tuple(exception, scores);
              }
            }
          }
        } catch (_) {
          // 缓存解析失败，返回默认值
        }
      }
      return Tuple(exception, {'dektJf': 0.0, 'dsktJf': 0.0, 'dsiktJf': 0.0});
    }
  }

  void logout() {
    _session = null;
  }
}

