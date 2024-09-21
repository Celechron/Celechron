import 'dart:convert';
import 'dart:io';

import 'exceptions.dart';

class ZjuAm {

  static Future<Cookie?> getSsoCookie(
      HttpClient httpClient, String username, String password) async {

    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      request =
      await httpClient.getUrl(Uri.parse('https://zjuam.zju.edu.cn/cas/login'))
          .timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.followRedirects = false;
      response = await request.close().timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      var cookies = response.cookies;
      var body = await response.transform(utf8.decoder).join();
      var execution =
      RegExp(r'name="execution" value="(.*?)"').firstMatch(body)?.group(1);
      if (execution == null) {
        throw LoginException('无法获取execution');
      }

      request = await httpClient
          .getUrl(Uri.parse('https://zjuam.zju.edu.cn/cas/v2/getPubKey'))
          .timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.addAll(cookies);
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      cookies.addAll(response.cookies);
      body = await response.transform(utf8.decoder).join();
      var modulusStr = RegExp(r'"modulus":"(.*?)"').firstMatch(body)?.group(1);
      var exponentStr = RegExp(r'"exponent":"(.*?)"').firstMatch(body)?.group(
          1);
      if (modulusStr == null || exponentStr == null) {
        throw LoginException('无法获取RSA公钥');
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
      }
      catch (e) {
        throw LoginException("密码不合法");
      }

      request = await httpClient
          .postUrl(Uri.parse('https://zjuam.zju.edu.cn/cas/login')).timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.followRedirects = false;
      request.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.cookies.addAll(cookies);
      request.add(utf8.encode(
          'username=$username&password=$pwdEnc&execution=$execution&_eventId=submit&rememberMe=true'));
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      response.drain();
      if (response.cookies.any((element) =>
      element.name == 'iPlanetDirectoryPro')) {
        return response.cookies
            .firstWhere((element) => element.name == 'iPlanetDirectoryPro');
      } else {
        throw LoginException("学号或密码错误");
      }
    } on SocketException {
      throw ExceptionWithMessage('网络错误');
    }
  }
}
