import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'diagnostic_log_service.dart';

/// 按账号对前台、后台及 isolate 间的刷新做单飞协调。
class RefreshCoordinator {
  static const _staleAfter = Duration(minutes: 10);
  static const _foregroundWait = Duration(seconds: 60);
  static final Map<String, Future<Object?>> _inProcessRefreshes = {};

  static Future<T> run<T>({
    required String account,
    required RefreshOrigin origin,
    required String refreshId,
    required Future<T> Function() action,
    required T busyResult,
  }) async {
    // 锁键使用账号哈希，避免锁文件名泄露明文账号。
    final key = sha256.convert(utf8.encode(account)).toString();
    final pending = _inProcessRefreshes[key];
    if (pending != null) return await pending as T;

    final future = _runWithFileLock(
      key: key,
      origin: origin,
      refreshId: refreshId,
      action: action,
      busyResult: busyResult,
    );
    _inProcessRefreshes[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inProcessRefreshes[key], future)) {
        _inProcessRefreshes.remove(key);
      }
    }
  }

  static Future<T> _runWithFileLock<T>({
    required String key,
    required RefreshOrigin origin,
    required String refreshId,
    required Future<T> Function() action,
    required T busyResult,
  }) async {
    File? lockFile;
    try {
      lockFile = await _lockFile(key);
      final deadline = DateTime.now().add(_foregroundWait);
      // 后台刷新不等待；前台可短暂等待正在进行的同账号任务。
      while (!await _tryAcquire(lockFile, refreshId, origin)) {
        if (origin == RefreshOrigin.background ||
            DateTime.now().isAfter(deadline)) {
          DiagnosticLogService.instance.record(
            level: CelechronLogLevel.warning,
            module: 'refresh',
            operation: 'singleFlight',
            message: '同一账号已有刷新任务，本次${origin.name}刷新已跳过',
          );
          return busyResult;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } on Object catch (error, stackTrace) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: 'refresh',
        operation: 'singleFlight',
        message: '跨 isolate 刷新锁不可用，已退化为进程内单飞',
        error: error,
        stackTrace: stackTrace,
      );
      return await action();
    }

    try {
      return await action();
    } finally {
      await _releaseIfOwned(lockFile, refreshId);
    }
  }

  static Future<File> _lockFile(String key) async {
    final lockDirectory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'celechron_refresh_locks',
    );
    await lockDirectory.create(recursive: true);
    return File(
      '${lockDirectory.path}${Platform.pathSeparator}'
      'scholar-${key.substring(0, 16)}.lock',
    );
  }

  static Future<bool> _tryAcquire(
    File file,
    String refreshId,
    RefreshOrigin origin,
  ) async {
    try {
      await file.create(exclusive: true);
      await file.writeAsString(
        jsonEncode({
          'refreshId': refreshId,
          'origin': origin.name,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
      return true;
    } on FileSystemException {
      if (!await file.exists()) return false;
      try {
        // 进程异常退出会遗留锁文件，超过时限后才允许其它任务接管。
        final modified = await file.lastModified();
        if (DateTime.now().difference(modified) > _staleAfter) {
          await file.delete();
        }
      } on FileSystemException {
        // 另一个 isolate 正在更新锁文件，下一轮重试。
      }
      return false;
    }
  }

  static Future<void> _releaseIfOwned(File file, String refreshId) async {
    // refreshId 是所有权凭据；无法确认归属时宁可保留到过期也不误删。
    try {
      if (!await file.exists()) return;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['refreshId'] == refreshId) {
        await file.delete();
      }
    } on FileSystemException {
      // 锁已被其它 isolate 清理。
    } on FormatException {
      // 不删除无法确认所有权的锁。
    }
  }
}
