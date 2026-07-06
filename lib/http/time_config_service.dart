import 'dart:io';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/http/calendar_config_parser.dart';
import 'package:celechron/http/data_source_status.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/http/zjuServices/response_utils.dart';
import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:celechron/utils/tuple.dart';
import 'package:flutter/foundation.dart';

/// 获取并校验学期校历；远程不可用时按“同学期缓存、推算配置”顺序降级。
class TimeConfigService {
  static const _lastValidCacheKey = 'timeConfig_lastValid';

  DatabaseHelper? _db;

  set db(DatabaseHelper? db) {
    _db = db;
  }

  Future<Tuple3<Exception?, String?, DataSourceStatus>> getConfig(
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
        // 未发布与网络故障分开记录；前者是未来学期的正常状态。
        final fallback = _fallbackConfig(semesterId, context);
        DiagnosticLogService.instance.record(
          level: CelechronLogLevel.warning,
          module: '校历',
          operation: semesterId,
          requestUri: uri,
          statusCode: response.statusCode,
          contentType: contentType,
          cacheUsed: fallback.status == DataSourceStatus.cache,
          message: '远程配置未发布，${fallback.status.label}；'
              '缓存时间=${fallback.cachedAt ?? '<无>'}',
        );
        return Tuple3(
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
          fallback.config,
          fallback.status,
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
        // 精确学期缓存用于恢复本学期；最后有效配置只提供节次时间模板。
        _db?.setCachedWebPage('timeConfig_$semesterId', body) ??
            Future<void>.value(),
        _db?.setCachedWebPage(_lastValidCacheKey, body) ?? Future<void>.value(),
        _db?.setCachedWebPage(
              'timeConfig_timestamp_$semesterId',
              DateTime.now().toUtc().toIso8601String(),
            ) ??
            Future<void>.value(),
      ]);
      DiagnosticLogService.instance.record(
        module: '校历',
        operation: semesterId,
        requestUri: uri,
        statusCode: response.statusCode,
        contentType: contentType,
        message: DataSourceStatus.live.label,
      );
      return Tuple3(null, body, DataSourceStatus.live);
    } on Object catch (error, stackTrace) {
      final fallback = _fallbackConfig(semesterId, context);
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: '校历',
        operation: semesterId,
        requestUri: uri,
        cacheUsed: fallback.status == DataSourceStatus.cache,
        message: '实时请求失败，${fallback.status.label}；'
            '缓存时间=${fallback.cachedAt ?? '<无>'}',
        error: error,
        stackTrace: stackTrace,
      );
      return Tuple3(
        exceptionFrom(
          error,
          context: context,
          requestUri: uri,
          stackTrace: stackTrace,
        ),
        fallback.config,
        fallback.status,
      );
    }
  }

  _CalendarFallback _fallbackConfig(String semesterId, String context) {
    // 精确缓存优先，因为其中的日期和调休只适用于对应学期。
    final exactCache = _db?.getCachedWebPage('timeConfig_$semesterId');
    if (exactCache != null) {
      try {
        decodeAndValidateCalendarConfig(
          exactCache,
          context: '$context 本地缓存',
        );
        return _CalendarFallback(
          exactCache,
          DataSourceStatus.cache,
          cachedAt: _db?.getCachedWebPage('timeConfig_timestamp_$semesterId'),
        );
      } on Object catch (error, stackTrace) {
        DiagnosticLogService.instance.record(
          level: CelechronLogLevel.warning,
          module: '校历',
          operation: 'readExactCache',
          cacheUsed: false,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    // 其它学期缓存不能复用日期，只提取经过校验的 sessionTime。
    Map<String, dynamic>? template;
    final lastValid = _db?.getCachedWebPage(_lastValidCacheKey);
    if (lastValid != null) {
      try {
        template = decodeAndValidateCalendarConfig(
          lastValid,
          context: '$context 上一份有效缓存',
        );
      } on Object catch (error, stackTrace) {
        DiagnosticLogService.instance.record(
          level: CelechronLogLevel.warning,
          module: '校历',
          operation: 'readTemplateCache',
          cacheUsed: false,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return _CalendarFallback(
      buildSafeDefaultCalendarConfig(
        semesterId,
        template: template,
      ),
      DataSourceStatus.fallback,
    );
  }
}

class _CalendarFallback {
  final String config;
  final DataSourceStatus status;
  final String? cachedAt;

  const _CalendarFallback(this.config, this.status, {this.cachedAt});
}
