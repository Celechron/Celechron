import 'package:celechron/http/zjuServices/exceptions.dart';

const _commonRetryableMessages = <String>[
  "connection closed",
  "httpexception",
  "网络错误",
  "未登录",
  "超时",
  "timeout",
  "type 'null'",
  "socketexception",
  "无法获取session",
  "会话已过期",
];

bool shouldRetryAfterLogin(
  Object error, {
  Iterable<String> extraMessages = const [],
}) {
  if (error is SessionExpiredException) return true;

  final message = error.toString().toLowerCase();
  return _commonRetryableMessages
      .followedBy(extraMessages)
      .any(message.contains);
}

Object? getRetryableTupleError(
  Object? result, {
  Iterable<String> extraMessages = const [],
}) {
  try {
    final error = (result as dynamic)?.item1;
    if (error == null) return null;
    return shouldRetryAfterLogin(error, extraMessages: extraMessages)
        ? error
        : null;
  } catch (_) {
    return null;
  }
}
