import 'dart:io';

import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/http/zjuServices/response_utils.dart';
import 'package:celechron/utils/tuple.dart';

import 'package:celechron/database/database_helper.dart';

class TimeConfigService {
  DatabaseHelper? _db;

  set db(DatabaseHelper? db) {
    _db = db;
  }

  Future<Tuple<Exception?, String?>> getConfig(
      HttpClient httpClient, String semesterId) async {
    try {
      var response = await httpClient
          .getUrl(Uri.parse('http://calendar.celechron.top/$semesterId.json'))
          .then((request) {
            request.followRedirects = false;
            return request.close();
          })
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));

      final context = '校历接口（学年学期 $semesterId，请求类型 配置）';
      final config = await readResponseText(response,
          context: context, expectJson: true);
      decodeJsonMap(config,
          context: '$context；HTTP ${response.statusCode}');
      _db?.setCachedWebPage('timeConfig_$semesterId', config);
      return Tuple(null, config);
    } catch (error) {
      final exception = exceptionFrom(error,
          context: '校历接口（学年学期 $semesterId，请求类型 配置）');
      return Tuple(exception, _db?.getCachedWebPage('timeConfig_$semesterId'));
    }
  }
}
