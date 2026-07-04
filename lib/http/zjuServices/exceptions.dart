import 'dart:async';
import 'dart:io';

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

  ExceptionWithMessage(this.message);

  @override
  String toString() {
    Object? message = this.message;
    return "$message";
  }
}

/// 表示服务端明确要求重新认证，而不是普通的网络或解析错误。
class AuthenticationExpiredException extends ExceptionWithMessage {
  AuthenticationExpiredException(super.message);
}

Exception exceptionFrom(Object error, {String? context}) {
  if (error is SocketException) {
    return ExceptionWithMessage(
        "${context == null ? '' : '$context：'}网络错误：${error.message}");
  }
  if (error is TimeoutException) {
    return ExceptionWithMessage(
        "${context == null ? '' : '$context：'}请求超时");
  }
  if (error is Exception) {
    return error;
  }
  return ExceptionWithMessage(
      "${context == null ? '' : '$context：'}${error.runtimeType}：$error");
}
