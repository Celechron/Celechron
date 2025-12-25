import 'dart:async';
import 'dart:io';

import 'zjuServices/exceptions.dart';

/// Centralized error handling for HTTP operations.
/// This module provides utilities to:
/// 1. Handle timeouts consistently
/// 2. Convert Errors to Exceptions for proper handling
/// 3. Normalize error messages across different error types
class HttpErrorHandler {
  /// Wraps an async operation with timeout and comprehensive error handling.
  /// 
  /// This function:
  /// - Applies a timeout to the operation via the .timeout() method
  /// - Converts SocketException to ExceptionWithMessage("网络错误")
  /// - Converts any Error types to ExceptionWithMessage
  /// - Allows Exceptions to bubble up as-is
  static Future<T> handleWithTimeout<T>(
    Future<T> Function() operation, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      return await operation().timeout(
        timeout,
        onTimeout: () => throw ExceptionWithMessage("请求超时"),
      );
    } on SocketException {
      throw ExceptionWithMessage("网络错误");
    } on Error catch (error) {
      // Convert Dart Error types (StateError, ArgumentError, etc.) to Exception
      throw ExceptionWithMessage("内部错误: ${error.toString()}");
    }
    // Let other Exceptions bubble up naturally
  }

  /// Wraps an async operation with error normalization only (no timeout).
  /// 
  /// Use this when timeout is handled elsewhere or not needed.
  static Future<T> handleErrors<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on SocketException {
      throw ExceptionWithMessage("网络错误");
    } on Error catch (error) {
      throw ExceptionWithMessage("内部错误: ${error.toString()}");
    }
  }
}
