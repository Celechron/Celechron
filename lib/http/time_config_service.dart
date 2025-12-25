import 'dart:convert';
import 'dart:io';

import 'package:celechron/http/http_error_handler.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
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
      final config = await _getConfigInternal(httpClient, semesterId);
      return Tuple(null, config);
    } catch (e) {
      // Return cached data on any error
      return Tuple(
          HttpErrorHandler.toException(e),
          _db?.getCachedWebPage('timeConfig_$semesterId'));
    }
  }

  Future<String?> _getConfigInternal(
      HttpClient httpClient, String semesterId) async {
    return HttpErrorHandler.handleErrors(() async {
      var response = await httpClient
          .getUrl(Uri.parse('http://calendar.celechron.top/$semesterId.json'))
          .then((request) => request.close())
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));

      if (response.statusCode == 200) {
        var config = await response.transform(utf8.decoder).join();
        _db?.setCachedWebPage('timeConfig_$semesterId', config);
        return config;
      } else {
        return null;
      }
    });
  }
}
