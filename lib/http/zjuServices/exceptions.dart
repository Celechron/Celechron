class LoginException implements Exception {
  final dynamic message;

  LoginException([this.message]);

  @override
  String toString() {
    Object? message = this.message;
    if (message == null) return "Exception";
    return "Exception: $message";
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