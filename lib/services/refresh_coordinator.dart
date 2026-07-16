import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'diagnostic_log_service.dart';

typedef RefreshClock = DateTime Function();
typedef RefreshRetryWait = Future<void> Function();

/// 文件系统协调后端：账号锁用于 isolate 间互斥，前台租约用于让后台任务让行。
class RefreshCoordinationStore {
  static const defaultStaleAfter = Duration(seconds: 30);
  static const defaultForegroundLeaseDuration = Duration(seconds: 30);
  static const defaultLockHeartbeatInterval = Duration(seconds: 5);

  final Directory directory;
  final Duration staleAfter;
  final Duration foregroundLeaseDuration;
  final Duration lockHeartbeatInterval;
  final String foregroundLeaseOwnerId;
  final RefreshClock _now;
  final RefreshRetryWait _waitBeforeRetry;

  RefreshCoordinationStore({
    Directory? directory,
    this.staleAfter = defaultStaleAfter,
    this.foregroundLeaseDuration = defaultForegroundLeaseDuration,
    this.lockHeartbeatInterval = defaultLockHeartbeatInterval,
    String? foregroundLeaseOwnerId,
    RefreshClock? now,
    RefreshRetryWait? waitBeforeRetry,
  })  : directory = directory ??
            Directory(
              '${Directory.systemTemp.path}${Platform.pathSeparator}'
              'celechron_refresh_locks',
            ),
        foregroundLeaseOwnerId = foregroundLeaseOwnerId ??
            '$pid-${DateTime.now().microsecondsSinceEpoch}',
        _now = now ?? DateTime.now,
        _waitBeforeRetry = waitBeforeRetry ??
            (() => Future<void>.delayed(const Duration(milliseconds: 100)));

  File get foregroundLeaseFile => File(
        '${directory.path}${Platform.pathSeparator}foreground.lease',
      );

  File lockFile(String key) => File(
        '${directory.path}${Platform.pathSeparator}'
        'scholar-${key.substring(0, 16)}.lock',
      );

  Future<void> waitBeforeRetry() => _waitBeforeRetry();

  Future<void> setForegroundActive(bool active) async {
    await directory.create(recursive: true);
    final file = foregroundLeaseFile;
    if (active) {
      await file.writeAsString(
        jsonEncode({
          'ownerId': foregroundLeaseOwnerId,
          'processId': pid,
          'updatedAt': _now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
      return;
    }

    try {
      if (!await file.exists()) return;
      final observed = await file.readAsString();
      final decoded = jsonDecode(observed);
      if (decoded is Map && decoded['ownerId'] == foregroundLeaseOwnerId) {
        await _deleteIfUnchanged(file, observed);
      }
    } on FileSystemException {
      // 另一个进程或 isolate 已更新/移除租约。
    } on FormatException {
      // 无法确认所有者时交给短租约自然过期，避免误删新前台租约。
    }
  }

  Future<bool> hasActiveForeground() async {
    final file = foregroundLeaseFile;
    if (!await file.exists()) return false;

    String? observed;
    DateTime? updatedAt;
    try {
      observed = await file.readAsString();
      final decoded = jsonDecode(observed);
      if (decoded is Map) {
        updatedAt = DateTime.tryParse(decoded['updatedAt']?.toString() ?? '');
      }
    } on FileSystemException {
      return false;
    } on FormatException {
      // 写入中的短暂不完整内容按文件时间判断，避免错误启动后台任务。
    }

    updatedAt ??= await file.lastModified();
    final age = _now().toUtc().difference(updatedAt.toUtc());
    if (age <= foregroundLeaseDuration) return true;

    if (observed != null) {
      await _deleteIfUnchanged(file, observed);
    }
    return false;
  }

  Future<File?> tryAcquire({
    required String key,
    required String refreshId,
    required RefreshOrigin origin,
  }) async {
    await directory.create(recursive: true);
    final file = lockFile(key);
    var created = false;
    try {
      await file.create(exclusive: true);
      created = true;
      await file.writeAsString(
        jsonEncode({
          'refreshId': refreshId,
          'origin': origin.name,
          'processId': pid,
          'createdAt': _now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
      await file.setLastModified(_now());
      return file;
    } on FileSystemException {
      if (created) {
        try {
          await file.delete();
        } on FileSystemException {
          // 交给过期恢复处理。
        }
        rethrow;
      }
      if (!await file.exists()) return null;
      await _removeIfStale(file);
      return null;
    }
  }

  Future<void> renewIfOwned(File file, String refreshId) async {
    try {
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map && decoded['refreshId'] == refreshId) {
        await file.setLastModified(_now());
      }
    } on FileSystemException {
      // 锁已释放或被安全恢复。
    } on FormatException {
      // 不更新无法确认所有权的锁。
    }
  }

  Future<void> releaseIfOwned(File file, String refreshId) async {
    try {
      if (!await file.exists()) return;
      final observed = await file.readAsString();
      final decoded = jsonDecode(observed);
      if (decoded is Map && decoded['refreshId'] == refreshId) {
        await _deleteIfUnchanged(file, observed);
      }
    } on FileSystemException {
      // 锁已被其它 isolate 清理。
    } on FormatException {
      // 不删除无法确认所有权的锁。
    }
  }

  Future<void> _removeIfStale(File file) async {
    try {
      final observed = await file.readAsString();
      final modified = await file.lastModified();
      if (_now().difference(modified) <= staleAfter) return;
      if (await file.readAsString() != observed) return;
      if (await file.lastModified() != modified) return;
      await file.delete();
      DiagnosticLogService.instance.record(
        module: 'refresh',
        operation: 'staleLockRemoved',
        message: '已清理超过心跳期限的遗留刷新锁',
      );
    } on FileSystemException {
      // 另一个 isolate 正在更新或释放锁。
    }
  }

  Future<void> _deleteIfUnchanged(File file, String observed) async {
    if (!await file.exists()) return;
    if (await file.readAsString() == observed) {
      await file.delete();
    }
  }
}

class _InProcessFlight {
  final Future<Object?> future;
  final RefreshOrigin origin;
  final String ownerRefreshId;

  const _InProcessFlight(this.future, this.origin, this.ownerRefreshId);
}

/// 进程内相同操作共享 Future；同账号不同操作及 isolate 间的任务按账号串行。
class RefreshCoordinator {
  static const foregroundHeartbeatInterval = Duration(seconds: 10);

  static final RefreshCoordinationStore _defaultStore =
      RefreshCoordinationStore();
  static final Map<String, _InProcessFlight> _inProcessFlights = {};
  static final Map<String, Future<void>> _accountTails = {};
  static Future<void> _foregroundLeaseQueue = Future<void>.value();
  static bool? _foregroundActive;

  static Future<void> setForegroundActive(bool active) {
    final update = _foregroundLeaseQueue.then((_) async {
      try {
        await _defaultStore.setForegroundActive(active);
        if (_foregroundActive != active) {
          _foregroundActive = active;
          DiagnosticLogService.instance.record(
            module: 'refresh',
            operation: active ? 'foregroundActive' : 'foregroundInactive',
            message: active ? 'App 已进入前台' : 'App 已离开前台',
            origin: RefreshOrigin.foreground,
          );
        }
      } on Object catch (error, stackTrace) {
        DiagnosticLogService.instance.record(
          level: CelechronLogLevel.warning,
          module: 'refresh',
          operation: 'foregroundLease',
          message: active ? '无法建立前台刷新租约' : '无法释放前台刷新租约',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
    _foregroundLeaseQueue = update;
    return update;
  }

  static Future<bool> shouldYieldBackground({
    @visibleForTesting RefreshCoordinationStore? coordinationStore,
  }) {
    return _hasActiveForeground(coordinationStore ?? _defaultStore);
  }

  static Future<T> run<T>({
    required String account,
    required String operation,
    required RefreshOrigin origin,
    required String refreshId,
    required Future<T> Function() action,
    T Function()? backgroundYieldResult,
    @visibleForTesting RefreshCoordinationStore? coordinationStore,
  }) {
    final store = coordinationStore ?? _defaultStore;
    if (origin == RefreshOrigin.background && backgroundYieldResult != null) {
      return _runBackground(
        account: account,
        operation: operation,
        origin: origin,
        refreshId: refreshId,
        action: action,
        backgroundYieldResult: backgroundYieldResult,
        store: store,
      );
    }
    return _runInProcess(
      account: account,
      operation: operation,
      origin: origin,
      refreshId: refreshId,
      action: action,
      backgroundYieldResult: backgroundYieldResult,
      store: store,
    );
  }

  static Future<T> _runBackground<T>({
    required String account,
    required String operation,
    required RefreshOrigin origin,
    required String refreshId,
    required Future<T> Function() action,
    required T Function() backgroundYieldResult,
    required RefreshCoordinationStore store,
  }) async {
    if (await _hasActiveForeground(store)) {
      return _yieldBackground(backgroundYieldResult);
    }
    return _runInProcess(
      account: account,
      operation: operation,
      origin: origin,
      refreshId: refreshId,
      action: action,
      backgroundYieldResult: backgroundYieldResult,
      store: store,
    );
  }

  static Future<T> _runInProcess<T>({
    required String account,
    required String operation,
    required RefreshOrigin origin,
    required String refreshId,
    required Future<T> Function() action,
    required T Function()? backgroundYieldResult,
    required RefreshCoordinationStore store,
  }) {
    // 锁键使用账号哈希，避免锁文件名泄露明文账号。
    final accountKey = sha256.convert(utf8.encode(account)).toString();
    final flightKey = '$accountKey:$operation';
    final pending = _inProcessFlights[flightKey];
    if (pending != null) {
      if (origin == RefreshOrigin.background &&
          pending.origin != RefreshOrigin.background &&
          backgroundYieldResult != null) {
        return Future<T>.value(_yieldBackground(backgroundYieldResult));
      }
      DiagnosticLogService.instance.record(
        module: 'refresh',
        operation: 'shareFlight',
        message: '同账号同操作已共享正在执行的 Future',
        relatedRefreshId: pending.ownerRefreshId,
        origin: origin,
      );
      return pending.future as Future<T>;
    }

    // 同一账号的不同操作（例如登录后刷新）必须串行，但不能互相复用结果；
    // 相同操作则直接复用上面的同一个 Future。
    final hasPreviousOperation = _accountTails.containsKey(accountKey);
    final previous = _accountTails[accountKey] ?? Future<void>.value();
    if (hasPreviousOperation) {
      DiagnosticLogService.instance.record(
        module: 'refresh',
        operation: 'queueOperation',
        message: '同账号不同操作已按顺序等待',
        origin: origin,
      );
    }
    final rawFuture = previous.then(
      (_) => _runWithFileLock(
        key: accountKey,
        origin: origin,
        refreshId: refreshId,
        action: action,
        backgroundYieldResult: backgroundYieldResult,
        store: store,
      ),
    );

    late final Future<T> flight;
    flight = rawFuture.whenComplete(() {
      if (identical(_inProcessFlights[flightKey]?.future, flight)) {
        _inProcessFlights.remove(flightKey);
      }
    });
    _inProcessFlights[flightKey] = _InProcessFlight(flight, origin, refreshId);

    // 队尾吞掉前一操作的异常，只负责唤醒下一项；实际异常仍由 flight
    // 原样传给所有调用者。
    final tail = flight.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    late final Future<void> trackedTail;
    trackedTail = tail.whenComplete(() {
      if (identical(_accountTails[accountKey], trackedTail)) {
        _accountTails.remove(accountKey);
      }
    });
    _accountTails[accountKey] = trackedTail;
    return flight;
  }

  static Future<T> _runWithFileLock<T>({
    required String key,
    required RefreshOrigin origin,
    required String refreshId,
    required Future<T> Function() action,
    required T Function()? backgroundYieldResult,
    required RefreshCoordinationStore store,
  }) async {
    File? lockFile;
    var waitLogged = false;
    try {
      while (lockFile == null) {
        lockFile = await store.tryAcquire(
          key: key,
          refreshId: refreshId,
          origin: origin,
        );
        if (lockFile == null) {
          if (!waitLogged) {
            waitLogged = true;
            DiagnosticLogService.instance.record(
              module: 'refresh',
              operation: 'lockWait',
              message: '正在等待同账号跨 isolate 刷新锁',
              origin: origin,
            );
          }
          if (origin == RefreshOrigin.background &&
              backgroundYieldResult != null) {
            return _yieldBackground(backgroundYieldResult);
          }
          await store.waitBeforeRetry();
        }
      }
      DiagnosticLogService.instance.record(
        module: 'refresh',
        operation: 'lockAcquired',
        message: waitLogged ? '等待后已获取刷新锁' : '已获取刷新锁',
        origin: origin,
      );
    } on Object catch (error, stackTrace) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: 'refresh',
        operation: 'singleFlight',
        message: '跨 isolate 刷新锁不可用，已退化为进程内单飞',
        error: error,
        stackTrace: stackTrace,
      );
      if (origin == RefreshOrigin.background && backgroundYieldResult != null) {
        return _yieldBackground(backgroundYieldResult);
      }
      return action();
    }

    Timer? heartbeat;
    Future<void> renewLock() async {
      try {
        await store.renewIfOwned(lockFile!, refreshId);
      } on Object catch (error, stackTrace) {
        DiagnosticLogService.instance.record(
          level: CelechronLogLevel.warning,
          module: 'refresh',
          operation: 'lockHeartbeat',
          message: '刷新锁心跳更新失败',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    Future<void>? activeRenewal;
    if (store.lockHeartbeatInterval > Duration.zero) {
      heartbeat = Timer.periodic(store.lockHeartbeatInterval, (_) {
        if (activeRenewal != null) return;
        late final Future<void> renewal;
        renewal = renewLock().whenComplete(() {
          if (identical(activeRenewal, renewal)) activeRenewal = null;
        });
        activeRenewal = renewal;
        unawaited(renewal);
      });
    }

    try {
      if (origin == RefreshOrigin.background &&
          backgroundYieldResult != null &&
          await _hasActiveForeground(store)) {
        return _yieldBackground(backgroundYieldResult);
      }
      return await action();
    } finally {
      heartbeat?.cancel();
      await activeRenewal;
      try {
        await store.releaseIfOwned(lockFile, refreshId);
        if (!await lockFile.exists()) {
          DiagnosticLogService.instance.record(
            module: 'refresh',
            operation: 'lockReleased',
            message: '已释放刷新锁',
            origin: origin,
          );
        }
      } on Object catch (error, stackTrace) {
        DiagnosticLogService.instance.record(
          level: CelechronLogLevel.warning,
          module: 'refresh',
          operation: 'releaseLock',
          message: '刷新锁释放失败，将等待过期恢复',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  static Future<bool> _hasActiveForeground(
      RefreshCoordinationStore store) async {
    try {
      return await store.hasActiveForeground();
    } on Object catch (error, stackTrace) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.warning,
        module: 'refresh',
        operation: 'foregroundLease',
        message: '无法读取前台刷新租约',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  static T _yieldBackground<T>(T Function() result) {
    DiagnosticLogService.instance.record(
      module: 'refresh',
      operation: 'backgroundYield',
      message: '后台刷新检测到活跃前台或同账号任务，已正常让行',
      origin: RefreshOrigin.background,
    );
    return result();
  }
}
