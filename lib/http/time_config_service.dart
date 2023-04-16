import 'dart:convert';
import 'dart:io';

import 'package:celechron/http/zjuServices/exceptions.dart';

class TimeConfigService {
  static Future<String?> getConfig(
      HttpClient httpClient, String semesterId) async {

    var response = await httpClient
        .getUrl(Uri.parse(
            'https://open-mobile-timeconf-1312007296.cos.ap-shanghai.myqcloud.com/$semesterId.json'))
        .then((request) => request.close()).catchError((e) {
          if (e is SocketException) {
            throw ExceptionWithMessage("网络错误");
          } else {
            throw ExceptionWithMessage("未知错误");
          }
    }).timeout(const Duration(seconds: 5), onTimeout: () => throw ExceptionWithMessage("请求超时"));

    if (response.statusCode == 200) {
      return await response.transform(utf8.decoder).join();
    } else {
      return null;
    }
  }
}
