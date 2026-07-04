import 'dart:async';
import 'dart:io';

import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:flutter/foundation.dart';

const refreshErrorDetailMarker = '\n<<<CELECHRON_ERROR_DETAIL>>>\n';
const refreshDegradedMarker = '<<<CELECHRON_DEGRADED>>>';

String degradedRefreshText(String message, {String? details}) {
  final safeMessage = redactSensitive(message);
  final safeDetails = details == null || details.isEmpty
      ? ''
      : '$refreshErrorDetailMarker${redactSensitive(details)}';
  return '$refreshDegradedMarker$safeMessage$safeDetails';
}

bool isDegradedRefreshText(Object? error) =>
    error?.toString().startsWith(refreshDegradedMarker) == true;

class LoginException implements Exception {
  final dynamic message;

  LoginException([this.message]);

  @override
  String toString() {
    Object? message = this.message;
    if (message == null) return "Exception";
    return this.message.toString();
  }
}

class ExceptionWithMessage implements Exception {
  final Object message;
  final String? details;
  final Object? originalError;
  final StackTrace? stackTrace;

  ExceptionWithMessage(
    this.message, {
    this.details,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final safeMessage = redactSensitive(message.toString());
    final safeDetails = details == null ? null : redactSensitive(details!);
    if (safeDetails == null || safeDetails.isEmpty) return safeMessage;
    return '$safeMessage$refreshErrorDetailMarker$safeDetails';
  }
}

/// 表示服务端明确要求重新认证，而不是普通的网络或解析错误。
class AuthenticationExpiredException extends ExceptionWithMessage {
  AuthenticationExpiredException(
    super.message, {
    super.details,
    super.originalError,
    super.stackTrace,
  });
}

class LoginExpiredException extends AuthenticationExpiredException {
  LoginExpiredException(
    super.message, {
    super.details,
    super.originalError,
    super.stackTrace,
  });
}

class CalendarConfigUnavailableException extends ExceptionWithMessage {
  CalendarConfigUnavailableException({
    required String details,
    Object? originalError,
    StackTrace? stackTrace,
  }) : super(
          '当前学期校历配置暂未发布',
          details: details,
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

class CachedDataException extends ExceptionWithMessage {
  CachedDataException(
    super.message, {
    super.details,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() => degradedRefreshText(
        message.toString(),
        details: details,
      );
}

Exception requestTimeout([String message = '请求超时']) {
  return TimeoutException(message);
}

String shortErrorText(Object? error) {
  final text =
      (error?.toString() ?? '未知错误').replaceFirst(refreshDegradedMarker, '');
  return text.split(refreshErrorDetailMarker).first.trim();
}

String detailedErrorText(Object? error) {
  final text = error?.toString() ?? '未知错误';
  final markerIndex = text.indexOf(refreshErrorDetailMarker);
  if (markerIndex < 0) return shortErrorText(text);
  return text.substring(markerIndex + refreshErrorDetailMarker.length).trim();
}

String sanitizedRequestUri(Uri? uri) {
  if (uri == null) return '<未知 URI>';
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
  ).toString();
}

String redactSensitive(String value) {
  var result = value;
  result = result.replaceAllMapped(
    RegExp(
      r'(authorization|proxy-authorization|cookie|set-cookie)'
      r'\s*[:=]\s*[^\r\n]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}=<已隐藏>',
  );
  result = result.replaceAllMapped(
    RegExp(
      r'(password|passwd|token|ticket|synjones-auth|'
      r'iplanetdirectorypro|jsessionid)'
      r'\s*[:=]\s*[^;,\s]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}=<已隐藏>',
  );
  result = result.replaceAllMapped(
    RegExp(r'https?://[^\s]+'),
    (match) {
      final uri = Uri.tryParse(match.group(0) ?? '');
      return uri == null ? '<已隐藏 URL>' : sanitizedRequestUri(uri);
    },
  );
  return result;
}

Exception exceptionFrom(
  Object error, {
  String? context,
  Uri? requestUri,
  bool relogged = false,
  bool retried = false,
  StackTrace? stackTrace,
}) {
  DiagnosticLogService.instance.record(
    level: CelechronLogLevel.error,
    module: context ?? 'unknown',
    operation: 'exception',
    requestUri: requestUri,
    relogged: relogged,
    retried: retried,
    error: error,
    stackTrace: stackTrace,
  );
  if (kDebugMode && stackTrace != null) {
    debugPrint(
        '$context：${error.runtimeType}: ${redactSensitive(error.toString())}\n$stackTrace');
  }
  if (error is LoginExpiredException) return error;
  if (error is AuthenticationExpiredException) return error;

  final type = error.runtimeType.toString();
  final originalMessage = redactSensitive(error.toString());
  final prefix = context == null ? '' : '$context：';
  final String userMessage;
  if (error is SocketException) {
    userMessage = '$prefix网络连接失败';
  } else if (error is TimeoutException) {
    userMessage = '$prefix请求超时';
  } else if (error is StateError) {
    userMessage = '$prefix请求状态异常';
  } else if (error is FormatException) {
    userMessage = '$prefix返回数据格式异常';
  } else if (error is ExceptionWithMessage) {
    userMessage = '$prefix${shortErrorText(error)}';
  } else {
    userMessage = '$prefix请求失败';
  }

  final existingDetails = error is ExceptionWithMessage ? error.details : null;
  final details = [
    '接口：${context ?? '<未知>'}',
    '请求：${sanitizedRequestUri(requestUri)}',
    '原始异常类型：$type',
    '原始异常消息：$originalMessage',
    '执行过重新登录：${relogged ? '是' : '否'}',
    '执行过重试：${retried ? '是' : '否'}',
    if (existingDetails != null && existingDetails.isNotEmpty) existingDetails,
  ].join('\n');

  return ExceptionWithMessage(
    userMessage,
    details: details,
    originalError: error,
    stackTrace: stackTrace,
  );
}
