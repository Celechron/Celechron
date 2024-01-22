import 'dart:convert';
import 'dart:io';

import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/http/zjuServices/tuple.dart';
import 'package:get/get.dart';

import 'package:celechron/database/database_helper.dart';

class TimeConfigService {
  final _db = Get.find<DatabaseHelper>(tag: 'db');

  Future<Tuple<Exception?, String?>> getConfig(
      HttpClient httpClient, String semesterId) async {
    try {
      var response = await httpClient
          .getUrl(Uri.parse(
              'https://open-mobile-timeconf-1312007296.cos.ap-shanghai.myqcloud.com/$semesterId.json'))
          .then((request) => request.close())
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));

      if (response.statusCode == 200) {
        var config = await response.transform(utf8.decoder).join();
        _db.setCachedWebPage('timeConfig_$semesterId', config);
        return Tuple(null, config);
      } else {
        return Tuple(null, null);
      }
    } catch (e) {
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      return Tuple(exception, _db.getCachedWebPage('timeConfig_$semesterId'));
    }
  }
}
