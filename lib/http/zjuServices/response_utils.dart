import 'dart:convert';
import 'dart:io';

import 'package:celechron/utils/json_utils.dart';

import 'exceptions.dart';

export 'package:celechron/utils/json_utils.dart';

String responseSummary(String body, {int maxLength = 240}) {
  final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.isEmpty) return '<空响应>';
  return compact.length <= maxLength
      ? compact
      : '${compact.substring(0, maxLength)}…';
}

bool _looksLikeHtml(String body) {
  final normalized = body.trimLeft().toLowerCase();
  return normalized.startsWith('<!doctype html') ||
      normalized.startsWith('<html') ||
      normalized.contains('<body') ||
      normalized.contains('<form');
}

bool bodyIndicatesAuthenticationFailure(String body) {
  final normalized = body.toLowerCase();
  return normalized.contains('cas/login') ||
      normalized.contains('login_ssologin') ||
      normalized.contains('统一身份认证') ||
      normalized.contains('未登录') ||
      normalized.contains('请先登录') ||
      normalized.contains('登录已失效') ||
      normalized.contains('认证失败') ||
      normalized.contains('unauthorized') ||
      normalized.contains('authserver') ||
      (normalized.contains('name="username"') &&
          normalized.contains('name="password"')) ||
      normalized.contains('"kickout":1') ||
      normalized.contains('"kickout":"1"') ||
      normalized.contains('kickout=1');
}

bool jsonIndicatesAuthenticationFailure(Map<String, dynamic> json) {
  if (asInt(json['kickout']) == 1) return true;
  final code = asInt(json['code']) ?? asInt(json['status']);
  final success = asBool(json['success']);
  final message = [
    asString(json['message']),
    asString(json['msg']),
    asString(json['error']),
  ].whereType<String>().join(' ').toLowerCase();
  final authenticationMessage = message.contains('token') ||
      message.contains('登录') ||
      message.contains('认证') ||
      message.contains('过期') ||
      message.contains('unauthorized') ||
      message.contains('kickout');
  final failed = code == HttpStatus.unauthorized ||
      code == HttpStatus.forbidden ||
      (authenticationMessage &&
          (success == false ||
              (code != null && code != HttpStatus.ok)));
  if (failed) return true;
  for (final key in const ['result', 'data']) {
    final nested = asStringMap(json[key]);
    if (nested != null && asInt(nested['kickout']) == 1) return true;
  }
  return false;
}

void validateResponse({
  required HttpClientResponse response,
  required String body,
  required String context,
  bool expectJson = false,
  bool allowEmpty = false,
}) {
  final status = response.statusCode;
  final location = response.headers.value(HttpHeaders.locationHeader);
  final contentType =
      response.headers.value(HttpHeaders.contentTypeHeader) ?? '<缺失>';
  final details =
      '$context；HTTP $status；Content-Type $contentType'
      '${location == null ? '' : '；Location $location'}';

  if (status == HttpStatus.unauthorized || status == HttpStatus.forbidden) {
    throw AuthenticationExpiredException(
        '$details；登录态已失效；响应摘要：${responseSummary(body)}');
  }
  if (response.isRedirect || (status >= 300 && status < 400)) {
    final target = location ?? '<缺失>';
    if (bodyIndicatesAuthenticationFailure(target) ||
        bodyIndicatesAuthenticationFailure(body)) {
      throw AuthenticationExpiredException(
          '$details；登录态已失效，接口重定向到 $target');
    }
    throw ExceptionWithMessage('$details；接口发生未预期跳转到 $target');
  }
  if (status < 200 || status >= 300) {
    throw ExceptionWithMessage(
        '$details；请求失败；响应摘要：${responseSummary(body)}');
  }
  if (body.trim().isEmpty && !allowEmpty) {
    throw ExceptionWithMessage('$details；接口返回空响应');
  }
  if (bodyIndicatesAuthenticationFailure(body)) {
    throw AuthenticationExpiredException(
        '$details；返回内容表明登录态已失效；响应摘要：${responseSummary(body)}');
  }
  if (expectJson && _looksLikeHtml(body)) {
    throw ExceptionWithMessage(
        '$details；期望 JSON，但接口返回 HTML；响应摘要：${responseSummary(body)}');
  }
  if (expectJson &&
      !contentType.toLowerCase().contains('json') &&
      !body.trimLeft().startsWith('{') &&
      !body.trimLeft().startsWith('[') &&
      body.trim() != 'null') {
    throw ExceptionWithMessage(
        '$details；期望 JSON，但响应类型或内容不符；响应摘要：${responseSummary(body)}');
  }
}

Future<String> readResponseText(
  HttpClientResponse response, {
  required String context,
  bool expectJson = false,
  bool allowEmpty = false,
}) async {
  final body = await readResponseBody(response, context: context);
  validateResponse(
    response: response,
    body: body,
    context: context,
    expectJson: expectJson,
    allowEmpty: allowEmpty,
  );
  return body;
}

Future<String> readResponseBody(
  HttpClientResponse response, {
  required String context,
}) {
  return response.transform(utf8.decoder).join().timeout(
      const Duration(seconds: 8),
      onTimeout: () =>
          throw ExceptionWithMessage('$context：读取响应内容超时'));
}

Object? decodeJsonValue(String body, {required String context}) {
  if (body.trim().isEmpty) {
    throw ExceptionWithMessage('$context；无法解析 JSON：响应为空');
  }
  if (_looksLikeHtml(body)) {
    if (bodyIndicatesAuthenticationFailure(body)) {
      throw AuthenticationExpiredException(
          '$context；登录态已失效，返回了 HTML 登录页；响应摘要：${responseSummary(body)}');
    }
    throw ExceptionWithMessage(
        '$context；无法解析 JSON：返回了 HTML；响应摘要：${responseSummary(body)}');
  }
  try {
    return jsonDecode(body);
  } on FormatException catch (error) {
    throw ExceptionWithMessage(
        '$context；JSON 格式错误：${error.message}；响应摘要：${responseSummary(body)}');
  }
}

Map<String, dynamic> decodeJsonMap(String body, {required String context}) {
  final decoded = decodeJsonValue(body, context: context);
  final map = asStringMap(decoded);
  if (map == null) {
    throw ExceptionWithMessage(
        '$context；JSON 顶层应为对象，实际为 ${decoded.runtimeType}；响应摘要：${responseSummary(body)}');
  }
  return map;
}

List<dynamic> decodeJsonList(String body, {required String context}) {
  final decoded = decodeJsonValue(body, context: context);
  final list = asDynamicList(decoded);
  if (list == null) {
    throw ExceptionWithMessage(
        '$context；JSON 顶层应为数组，实际为 ${decoded.runtimeType}；响应摘要：${responseSummary(body)}');
  }
  return list;
}
