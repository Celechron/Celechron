import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'exceptions.dart';

class ECard {
  static Future<String> getSynjonesAuth(HttpClient httpClient, Cookie? iPlanetDirectoryPro) async {

    late HttpClientRequest request;
    late HttpClientResponse response;

    List<Cookie> cookies = [];
    if (iPlanetDirectoryPro == null) {
      throw ExceptionWithMessage("iPlanetDirectoryPro无效");
    }
    request = await httpClient
        .getUrl(Uri.parse(
        "https://ecard.zju.edu.cn/berserker-auth/cas/oauth2?resultUrl=https://ecard.zju.edu.cn/plat-pc"))
        .timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));
    request.followRedirects = false;
    cookies.add(iPlanetDirectoryPro);
    request.cookies.addAll(cookies);
    response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));

    while(true) {
      if (response.statusCode != 301 && response.statusCode != 302) {
        throw ExceptionWithMessage("iPlanetDirectoryPro无效");
      }

      var location = response.headers.value('location');
      if(location == null) {
        (throw ExceptionWithMessage("iPlanetDirectoryPro无效"));
      }
      var synjonesAuth = RegExp(r'synjones-auth=(.*?)(?:&|$)').firstMatch(location)?.group(1);
      if (synjonesAuth != null) {
        return synjonesAuth;
      }

      request = await httpClient
          .getUrl(Uri.parse(location))
          .timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.followRedirects = false;
      cookies.addAll(response.cookies);
      request.cookies.addAll(cookies);
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      response.drain();
    }
  }

  static Future<String> getAccount(HttpClient httpClient, String synjonesAuth) async {

    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient
        .getUrl(Uri.parse("https://ecard.zju.edu.cn/berserker-app/ykt/tsm/getCampusCards"))
        .timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));
    request.headers.add("Synjones-Auth", "Bearer $synjonesAuth");
    response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));

    var accountJson = await response.transform(utf8.decoder).join();
    var account = jsonDecode(accountJson)['data']['card'][0]['account'];
    return account;
  }

  static Future<String> getBarcode(HttpClient httpClient, String synjonesAuth, String eCardAccount) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient
        .getUrl(Uri.parse("https://ecard.zju.edu.cn/berserker-app/ykt/tsm/getBarCode?account=$eCardAccount&payacc=001&paytype=1&synAccessSource=app"))
        .timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时1"));
    request.headers.add("synjones-auth", "bearer $synjonesAuth");
    response = await request.close();
        //.timeout(const Duration(seconds: 8),
        //onTimeout: () => throw ExceptionWithMessage("请求超时2"));

    var barcodeJson = await response.transform(utf8.decoder).join();
    var barcode = jsonDecode(barcodeJson)['data']['barcode'][0];
    return barcode;
  }
}
