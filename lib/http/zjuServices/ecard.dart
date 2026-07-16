import 'dart:io';

import 'exceptions.dart';
import 'response_utils.dart';

class ECard {
  static Future<String> getSynjonesAuth(
      HttpClient httpClient, Cookie? iPlanetDirectoryPro) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    List<Cookie> cookies = [];
    if (iPlanetDirectoryPro == null) {
      throw AuthenticationExpiredException("校园卡：统一身份认证凭据无效");
    }
    request = await httpClient
        .getUrl(Uri.parse(
            "https://elife.zju.edu.cn/berserker-auth/cas/oauth2?resultUrl=https://elife.zju.edu.cn/plat-pc"))
        .timeout(const Duration(seconds: 8),
            onTimeout: () => throw ExceptionWithMessage("请求超时"));
    request.followRedirects = false;
    cookies.add(iPlanetDirectoryPro);
    request.cookies.addAll(cookies);
    response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));

    // synjones-auth 可能出现在任意一跳 Location 中；每跳必须先收集
    // 当前响应 Cookie，再访问相对地址解析后的下一跳。
    var current = Uri.parse(
        "https://elife.zju.edu.cn/berserker-auth/cas/oauth2?resultUrl=https://elife.zju.edu.cn/plat-pc");
    for (var redirectCount = 0; redirectCount < 10; redirectCount++) {
      if (response.statusCode != 301 && response.statusCode != 302) {
        final body = await readResponseBody(response, context: '校园卡登录');
        throw AuthenticationExpiredException(
            "校园卡登录失败；HTTP ${response.statusCode}"
            "；Content-Type ${response.headers.value(HttpHeaders.contentTypeHeader) ?? '<缺失>'}"
            "；响应摘要：${responseSummary(body)}");
      }

      var location = response.headers.value('location');
      if (location == null) {
        await response.drain();
        throw AuthenticationExpiredException(
            "校园卡登录失败；HTTP ${response.statusCode}；Location 缺失");
      }
      var synjonesAuth =
          RegExp(r'synjones-auth=(.*?)(?:&|$)').firstMatch(location)?.group(1);
      if (synjonesAuth != null) {
        await response.drain();
        return synjonesAuth;
      }

      await response.drain();
      current = current.resolve(location);
      request = await httpClient.getUrl(current).timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.followRedirects = false;
      cookies.addAll(response.cookies);
      request.cookies.addAll(cookies);
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
    }
    throw ExceptionWithMessage("校园卡登录失败：重定向次数过多");
  }

  static Future<String> getAccount(
      HttpClient httpClient, String synjonesAuth) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient
        .getUrl(Uri.parse(
            "https://elife.zju.edu.cn/berserker-app/ykt/tsm/getCampusCards"))
        .timeout(const Duration(seconds: 8),
            onTimeout: () => throw ExceptionWithMessage("请求超时"));
    request.headers.add("Synjones-Auth", "Bearer $synjonesAuth");
    request.followRedirects = false;
    response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));

    var accountJson =
        await readResponseText(response, context: '校园卡账户接口', expectJson: true);
    final payload = decodeJsonMap(accountJson,
        context: '校园卡账户接口；HTTP ${response.statusCode}');
    final data = asStringMap(payload['data']);
    final cardList = asDynamicList(data?['card']) ?? const [];
    // Card list is a List<Map<String, dynamic>> object, which may contain multiple cards.
    // Select the card which has the highest balance.
    // The account number is stored in the 'account' field.
    // The balance is stored in the 'db_balance' field.
    final cards = cardList
        .map(asStringMap)
        .whereType<Map<String, dynamic>>()
        .where((card) => asString(card['account'])?.isNotEmpty == true)
        .toList();
    if (cards.isEmpty) {
      throw ExceptionWithMessage(
          '校园卡账户接口：未返回有效卡片；响应摘要：${responseSummary(accountJson)}');
    }
    cards.sort((a, b) => (asDouble(b['db_balance']) ?? 0.0)
        .compareTo(asDouble(a['db_balance']) ?? 0.0));
    return asString(cards.first['account'])!;
  }

  static Future<String> getBarcode(
      HttpClient httpClient, String synjonesAuth, String eCardAccount) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient
        .getUrl(Uri.parse(
            "https://elife.zju.edu.cn/berserker-app/ykt/tsm/batchGetBarCodeGet?account=$eCardAccount&payacc=%23%23%23&paytype=1&synAccessSource=app"))
        .timeout(const Duration(seconds: 8),
            onTimeout: () => throw ExceptionWithMessage("请求超时1"));
    request.headers.add("synjones-auth", "bearer $synjonesAuth");
    request.followRedirects = false;
    response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));

    var barcodeJson =
        await readResponseText(response, context: '校园卡付款码接口', expectJson: true);
    final payload = decodeJsonMap(barcodeJson,
        context: '校园卡付款码接口；HTTP ${response.statusCode}');
    final data = asStringMap(payload['data']);
    final barcodes = asDynamicList(data?['barcode']) ?? const [];
    final barcode = barcodes.isEmpty ? null : asString(barcodes.first);
    if (barcode == null || barcode.isEmpty) {
      throw ExceptionWithMessage(
          '校园卡付款码接口：未返回有效付款码；响应摘要：${responseSummary(barcodeJson)}');
    }
    return barcode;
  }
}
