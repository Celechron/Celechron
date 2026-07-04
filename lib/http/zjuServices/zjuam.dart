import 'dart:convert';
import 'dart:io';

import 'exceptions.dart';
import 'response_utils.dart';

class ZjuAm {
  static final Map<String, Future<Cookie?>> _pendingLogins = {};

  static Future<Cookie?> getSsoCookie(
      HttpClient httpClient, String username, String password) async {
    final pending = _pendingLogins[username];
    if (pending != null) return await pending;

    final login = _getSsoCookie(httpClient, username, password);
    _pendingLogins[username] = login;
    try {
      return await login;
    } finally {
      if (identical(_pendingLogins[username], login)) {
        _pendingLogins.remove(username);
      }
    }
  }

  static Future<Cookie?> _getSsoCookie(
      HttpClient httpClient, String username, String password) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      request = await httpClient
          .getUrl(Uri.parse('https://zjuam.zju.edu.cn/cas/login'))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.followRedirects = false;
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      var cookies = List<Cookie>.from(response.cookies);
      var body =
          await readResponseBody(response, context: '统一身份认证登录页');
      final loginLocation =
          response.headers.value(HttpHeaders.locationHeader);
      if (response.statusCode != HttpStatus.ok) {
        throw LoginException(
            '统一身份认证登录页请求失败；HTTP ${response.statusCode}'
            '${loginLocation == null ? '' : '；Location $loginLocation'}'
            '；响应摘要：${responseSummary(body)}');
      }
      var execution =
          RegExp(r'name="execution" value="(.*?)"').firstMatch(body)?.group(1);
      if (execution == null) {
        throw LoginException(
            '统一身份认证登录页无法获取 execution；HTTP ${response.statusCode}'
            '；响应摘要：${responseSummary(body)}');
      }

      request = await httpClient
          .getUrl(Uri.parse('https://zjuam.zju.edu.cn/cas/v2/getPubKey'))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.followRedirects = false;
      request.cookies.addAll(cookies);
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      cookies.addAll(response.cookies);
      body = await readResponseText(response,
          context: '统一身份认证 RSA 公钥', expectJson: true);
      final publicKey = decodeJsonMap(body,
          context: '统一身份认证 RSA 公钥；HTTP ${response.statusCode}');
      var modulusStr = asString(publicKey['modulus']);
      var exponentStr = asString(publicKey['exponent']);
      if (modulusStr == null || exponentStr == null) {
        throw LoginException(
            '统一身份认证 RSA 公钥字段缺失；响应摘要：${responseSummary(body)}');
      }

      late String pwdEnc;
      try {
        var modInt = BigInt.parse(modulusStr, radix: 16);
        var expInt = BigInt.parse(exponentStr, radix: 16);
        var pwdInt = BigInt.parse(
            utf8.encode(password).map((e) => e.toRadixString(16)).join(),
            radix: 16);
        var pwdEncInt = pwdInt.modPow(expInt, modInt);
        pwdEnc = pwdEncInt.toRadixString(16).padLeft(128, '0');
      } catch (e) {
        throw LoginException("密码不合法");
      }

      request = await httpClient
          .postUrl(Uri.parse('https://zjuam.zju.edu.cn/cas/login'))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.followRedirects = false;
      request.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.cookies.addAll(cookies);
      request.add(utf8.encode(Uri(queryParameters: {
        'username': username,
        'password': pwdEnc,
        'execution': execution,
        '_eventId': 'submit',
        'rememberMe': 'true',
      }).query));
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      body = await readResponseBody(response, context: '统一身份认证登录提交');

      if (response.cookies
          .any((element) => element.name == 'iPlanetDirectoryPro')) {
        return response.cookies
            .firstWhere((element) => element.name == 'iPlanetDirectoryPro');
      } else {
        final location =
            response.headers.value(HttpHeaders.locationHeader);
        throw LoginException(
            "统一身份认证失败，学号或密码错误，或认证会话已失效"
            "；HTTP ${response.statusCode}"
            "${location == null ? '' : '；Location $location'}"
            "；响应摘要：${responseSummary(body)}");
      }
    } catch (error) {
      throw exceptionFrom(error, context: '统一身份认证');
    }
  }
}
