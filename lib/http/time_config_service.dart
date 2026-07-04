import 'dart:io';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/calendar_config_parser.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/http/zjuServices/response_utils.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:flutter/foundation.dart';

class TimeConfigService {
  static const _lastValidCacheKey = 'timeConfig_lastValid';

  DatabaseHelper? _db;

  set db(DatabaseHelper? db) {
    _db = db;
  }

  Future<Tuple<Exception?, String?>> getConfig(
      HttpClient httpClient, String semesterId) async {
    final key = calendarObjectKeyForSemester(semesterId);
    final uri = calendarConfigUriForSemester(semesterId);
    final context = '校历接口（学年学期 $semesterId，请求类型 配置）';
    if (kDebugMode) {
      debugPrint('校历请求：URL=$uri，OSS Key=$key');
    }

    try {
      final request = await httpClient.getUrl(uri).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout(),
          );
      request.followRedirects = false;
      final response = await request.close().timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw requestTimeout(),
          );
      final body = await readResponseBody(response, context: context);
      final contentType =
          response.headers.value(HttpHeaders.contentTypeHeader) ?? '<缺失>';
      final noSuchKey = response.statusCode == HttpStatus.notFound ||
          body.contains('<Code>NoSuchKey</Code>');

      if (noSuchKey) {
        final fallback = _fallbackConfig(semesterId, context);
        return Tuple(
          CalendarConfigUnavailableException(
            details: [
              '接口：$context',
              '请求：${sanitizedRequestUri(uri)}',
              'OSS Key：$key',
              'HTTP 状态码：${response.statusCode}',
              'Content-Type：$contentType',
              '原始异常类型：NoSuchKey',
              '执行过重新登录：否',
              '执行过重试：否',
              '响应摘要：${responseSummary(body)}',
            ].join('\n'),
          ),
          fallback,
        );
      }

      validateResponse(
        response: response,
        body: body,
        context: context,
        expectJson: true,
        requestUri: uri,
      );
      decodeAndValidateCalendarConfig(
        body,
        context: '$context；HTTP ${response.statusCode}',
      );
      await Future.wait([
        _db?.setCachedWebPage('timeConfig_$semesterId', body) ??
            Future<void>.value(),
        _db?.setCachedWebPage(_lastValidCacheKey, body) ?? Future<void>.value(),
      ]);
      return Tuple(null, body);
    } on Object catch (error, stackTrace) {
      final fallback = _fallbackConfig(semesterId, context);
      return Tuple(
        exceptionFrom(
          error,
          context: context,
          requestUri: uri,
          stackTrace: stackTrace,
        ),
        fallback,
      );
    }
  }

  String _fallbackConfig(String semesterId, String context) {
    final exactCache = _db?.getCachedWebPage('timeConfig_$semesterId');
    if (exactCache != null) {
      try {
        decodeAndValidateCalendarConfig(
          exactCache,
          context: '$context 本地缓存',
        );
        return exactCache;
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('$context：忽略损坏的本地缓存：$error\n$stackTrace');
        }
      }
    }

    Map<String, dynamic>? template;
    final lastValid = _db?.getCachedWebPage(_lastValidCacheKey);
    if (lastValid != null) {
      try {
        template = decodeAndValidateCalendarConfig(
          lastValid,
          context: '$context 上一份有效缓存',
        );
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('$context：忽略损坏的历史缓存：$error\n$stackTrace');
        }
      }
    }
    return buildSafeDefaultCalendarConfig(
      semesterId,
      template: template,
    );
  }
}
