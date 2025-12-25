import 'dart:async';
import 'dart:io';

import 'zjuServices/exceptions.dart';

/// Centralized error handling for HTTP operations.
/// This module provides utilities to:
/// 1. Convert Errors to Exceptions for proper handling
/// 2. Normalize error messages across different error types
class HttpErrorHandler {
  /// Wraps an async operation with error normalization.
  /// 
  /// Converts errors consistently:
  /// - Converts SocketException to ExceptionWithMessage("网络错误")
  /// - Converts any Error types to ExceptionWithMessage
  /// - Allows Exceptions to bubble up as-is
  ///
  /// Type parameters:
  /// - `T`: The return type of the operation
  ///
  /// Parameters:
  /// - `operation`: An async function to execute with error handling
  ///
  /// Returns: The result of the operation
  /// Throws: ExceptionWithMessage for network and internal errors
  static Future<T> handleErrors<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on SocketException {
      throw ExceptionWithMessage("网络错误");
    } on Error catch (error) {
      throw ExceptionWithMessage("内部错误: ${error.toString()}");
    }
  }

  /// Converts a caught error to an Exception safely.
  /// Use this in catch blocks that return Tuple<Exception?, Data>
  static Exception toException(dynamic e) {
    if (e is Exception) return e;
    if (e is Error) return ExceptionWithMessage("内部错误: ${e.toString()}");
    return ExceptionWithMessage(e.toString());
  }
}
