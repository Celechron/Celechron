import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:celechron/services/refresh_coordinator.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

late RefreshCoordinationStore testStore;

Future<T> runFlight<T>({
  required String account,
  String operation = 'refresh',
  RefreshOrigin origin = RefreshOrigin.foreground,
  required Future<T> Function() action,
  T Function()? backgroundYieldResult,
  RefreshCoordinationStore? coordinationStore,
}) {
  return RefreshCoordinator.run(
    account: 'refresh-coordinator-test-$account',
    operation: operation,
    origin: origin,
    refreshId: '$account-$operation',
    action: action,
    backgroundYieldResult: backgroundYieldResult,
    coordinationStore: coordinationStore ?? testStore,
  );
}

String accountKey(String account) =>
    sha256.convert(utf8.encode('refresh-coordinator-test-$account')).toString();

void main() {
  late Directory testDirectory;

  setUp(() async {
    testDirectory =
        await Directory.systemTemp.createTemp('celechron-refresh-test-');
    testStore = RefreshCoordinationStore(
      directory: testDirectory,
      foregroundLeaseOwnerId: 'test-foreground',
      lockHeartbeatInterval: Duration.zero,
      waitBeforeRetry: () => Future<void>.value(),
    );
  });

  tearDown(() async {
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test('同账号并发刷新只执行一次且两个调用者共享成功结果', () async {
    final started = Completer<void>();
    final resultGate = Completer<List<String?>>();
    final expected = <String?>[null, null];
    var actionCalls = 0;

    Future<List<String?>> action() {
      actionCalls++;
      started.complete();
      return resultGate.future;
    }

    final startupRefresh = runFlight(
      account: 'same-account-success',
      action: action,
    );
    await started.future;
    final manualRefresh = runFlight(
      account: 'same-account-success',
      action: action,
    );

    expect(identical(startupRefresh, manualRefresh), isTrue);
    expect(actionCalls, 1);

    resultGate.complete(expected);
    expect(await startupRefresh, same(expected));
    expect(await manualRefresh, same(expected));
  });

  test('同账号共享任务返回相同失败结果', () async {
    final started = Completer<void>();
    final resultGate = Completer<List<String?>>();
    final expected = <String?>['成绩查询失败'];
    var actionCalls = 0;

    Future<List<String?>> action() {
      actionCalls++;
      started.complete();
      return resultGate.future;
    }

    final first = runFlight(account: 'same-account-failure', action: action);
    await started.future;
    final second = runFlight(account: 'same-account-failure', action: action);
    resultGate.complete(expected);

    expect(await first, same(expected));
    expect(await second, same(expected));
    expect(actionCalls, 1);
  });

  test('异常会传给所有调用者并清理 flight', () async {
    final started = Completer<void>();
    final errorGate = Completer<List<String?>>();
    var actionCalls = 0;

    Future<List<String?>> failingAction() {
      actionCalls++;
      started.complete();
      return errorGate.future;
    }

    final first =
        runFlight(account: 'exception-cleanup', action: failingAction);
    await started.future;
    final second =
        runFlight(account: 'exception-cleanup', action: failingAction);
    final firstExpectation = expectLater(
      first,
      throwsA(isA<StateError>()
          .having((error) => error.message, 'message', 'boom')),
    );
    final secondExpectation = expectLater(
      second,
      throwsA(isA<StateError>()
          .having((error) => error.message, 'message', 'boom')),
    );

    errorGate.completeError(StateError('boom'));
    await Future.wait([firstExpectation, secondExpectation]);
    expect(
      await testStore.lockFile(accountKey('exception-cleanup')).exists(),
      isFalse,
    );

    final recovered = await runFlight(
      account: 'exception-cleanup',
      action: () async {
        actionCalls++;
        return <String?>[null];
      },
    );
    expect(recovered, <String?>[null]);
    expect(actionCalls, 2);
  });

  test('不同账号的刷新互不阻塞', () async {
    final firstStarted = Completer<void>();
    final secondStarted = Completer<void>();
    final firstGate = Completer<List<String?>>();
    final secondGate = Completer<List<String?>>();

    final first = runFlight(
      account: 'parallel-a',
      action: () {
        firstStarted.complete();
        return firstGate.future;
      },
    );
    final second = runFlight(
      account: 'parallel-b',
      action: () {
        secondStarted.complete();
        return secondGate.future;
      },
    );

    await Future.wait([firstStarted.future, secondStarted.future]);
    firstGate.complete(<String?>[null]);
    secondGate.complete(<String?>[null]);
    await Future.wait([first, second]);
  });

  test('启动自动刷新未完成时手动刷新不会产生 skipped 或 degraded', () async {
    final startupStarted = Completer<void>();
    final startupGate = Completer<List<String?>>();
    var startupCalls = 0;
    var manualActionCalls = 0;

    final startup = runFlight(
      account: 'startup-manual',
      action: () {
        startupCalls++;
        startupStarted.complete();
        return startupGate.future;
      },
    );
    await startupStarted.future;
    final manual = runFlight<List<String?>>(
      account: 'startup-manual',
      action: () async {
        manualActionCalls++;
        return <String?>['不应执行'];
      },
    );

    startupGate.complete(<String?>[null, null]);
    final startupResult = await startup;
    final manualResult = await manual;

    expect(startupCalls, 1);
    expect(manualActionCalls, 0);
    expect(manualResult, same(startupResult));
    expect(
      manualResult.whereType<String>(),
      isNot(contains(predicate<String>(isDegradedRefreshText))),
    );
    expect(manualResult.whereType<String>().join(), isNot(contains('已跳过')));
  });

  test('研究生账号慢初始化期间的手动刷新加入现有任务', () async {
    final initializationStarted = Completer<void>();
    final initializationGate = Completer<void>();
    var bottomRefreshCalls = 0;
    var laterActionCalls = 0;

    final startup = runFlight(
      account: 'graduate-2200000000',
      action: () async {
        bottomRefreshCalls++;
        initializationStarted.complete();
        await initializationGate.future;
        return <String?>[null, null, null, null, null, null, null];
      },
    );
    await initializationStarted.future;
    final manual = runFlight<List<String?>>(
      account: 'graduate-2200000000',
      action: () async {
        laterActionCalls++;
        return <String?>['不应执行'];
      },
    );

    expect(identical(startup, manual), isTrue);
    initializationGate.complete();
    expect(await manual, everyElement(isNull));
    expect(await startup, everyElement(isNull));
    expect(bottomRefreshCalls, 1);
    expect(laterActionCalls, 0);
  });

  test('同账号登录与刷新不共享错误类型结果而是依次执行', () async {
    final loginStarted = Completer<void>();
    final loginGate = Completer<List<String?>>();
    final refreshStarted = Completer<void>();

    final login = runFlight(
      account: 'login-then-refresh',
      operation: 'login',
      action: () {
        loginStarted.complete();
        return loginGate.future;
      },
    );
    await loginStarted.future;
    final refresh = runFlight(
      account: 'login-then-refresh',
      action: () async {
        refreshStarted.complete();
        return <String?>[null, null];
      },
    );

    var refreshHasStarted = false;
    unawaited(refreshStarted.future.then((_) => refreshHasStarted = true));
    await Future<void>.delayed(Duration.zero);
    expect(refreshHasStarted, isFalse);

    loginGate.complete(<String?>[null]);
    expect(await login, <String?>[null]);
    await refreshStarted.future;
    expect(await refresh, <String?>[null, null]);
  });

  test('后台任务遇到活跃前台租约时正常让行', () async {
    await testStore.setForegroundActive(true);
    var actionCalls = 0;
    var yieldCalls = 0;

    final result = await runFlight<List<String?>>(
      account: 'background-yields-to-foreground',
      origin: RefreshOrigin.background,
      action: () async {
        actionCalls++;
        return <String?>['不应执行'];
      },
      backgroundYieldResult: () {
        yieldCalls++;
        return <String?>[];
      },
    );

    expect(result, isEmpty);
    expect(actionCalls, 0);
    expect(yieldCalls, 1);
  });

  test('后台任务遇到跨 isolate 忙锁时立即安全让行', () async {
    final key = accountKey('background-yields-to-lock');
    final heldLock = await testStore.tryAcquire(
      key: key,
      refreshId: 'other-foreground',
      origin: RefreshOrigin.foreground,
    );
    expect(heldLock, isNotNull);
    var actionCalls = 0;

    final result = await runFlight<List<String?>>(
      account: 'background-yields-to-lock',
      origin: RefreshOrigin.background,
      action: () async {
        actionCalls++;
        return <String?>['不应执行'];
      },
      backgroundYieldResult: () => <String?>[],
    );

    expect(result, isEmpty);
    expect(actionCalls, 0);
    await testStore.releaseIfOwned(heldLock!, 'other-foreground');
  });

  test('前台遇到后台锁只等待实际释放且不返回降级', () async {
    final retryRequested = Completer<void>();
    final retryAllowed = Completer<void>();
    final waiterStore = RefreshCoordinationStore(
      directory: testDirectory,
      foregroundLeaseOwnerId: 'foreground-waiter',
      lockHeartbeatInterval: Duration.zero,
      waitBeforeRetry: () {
        if (!retryRequested.isCompleted) retryRequested.complete();
        return retryAllowed.future;
      },
    );
    final key = accountKey('foreground-waits-for-background');
    final heldLock = await testStore.tryAcquire(
      key: key,
      refreshId: 'running-background',
      origin: RefreshOrigin.background,
    );
    expect(heldLock, isNotNull);
    var actionCalls = 0;

    final foreground = runFlight<List<String?>>(
      account: 'foreground-waits-for-background',
      coordinationStore: waiterStore,
      action: () async {
        actionCalls++;
        return <String?>[null];
      },
    );
    await retryRequested.future;
    await testStore.releaseIfOwned(heldLock!, 'running-background');
    retryAllowed.complete();

    final result = await foreground;
    expect(result, <String?>[null]);
    expect(actionCalls, 1);
    expect(result.whereType<String>().any(isDegradedRefreshText), isFalse);
  });

  test('跨 isolate 锁在任务正常完成后释放', () async {
    final result = await runFlight<List<String?>>(
      account: 'normal-lock-release',
      action: () async => <String?>[null],
    );

    expect(result, <String?>[null]);
    expect(
      await testStore.lockFile(accountKey('normal-lock-release')).exists(),
      isFalse,
    );
  });

  test('遗留锁过期后恢复且旧所有者不能删除新锁', () async {
    var now = DateTime.now().toUtc();
    final staleStore = RefreshCoordinationStore(
      directory: testDirectory,
      foregroundLeaseOwnerId: 'stale-owner',
      lockHeartbeatInterval: Duration.zero,
      now: () => now,
    );
    const key = '0123456789abcdef-stale-lock';
    final staleLock = await staleStore.tryAcquire(
      key: key,
      refreshId: 'old-refresh',
      origin: RefreshOrigin.background,
    );
    expect(staleLock, isNotNull);

    now = now.add(const Duration(seconds: 31));
    expect(
      await staleStore.tryAcquire(
        key: key,
        refreshId: 'new-refresh',
        origin: RefreshOrigin.foreground,
      ),
      isNull,
    );
    final recoveredLock = await staleStore.tryAcquire(
      key: key,
      refreshId: 'new-refresh',
      origin: RefreshOrigin.foreground,
    );
    expect(recoveredLock, isNotNull);

    await staleStore.releaseIfOwned(staleLock!, 'old-refresh');
    expect(await recoveredLock!.exists(), isTrue);
    await staleStore.releaseIfOwned(recoveredLock, 'new-refresh');
  });

  test('锁心跳防止仍在运行的长任务被当成遗留锁', () async {
    var now = DateTime.now().toUtc();
    final heartbeatStore = RefreshCoordinationStore(
      directory: testDirectory,
      staleAfter: const Duration(minutes: 10),
      foregroundLeaseOwnerId: 'heartbeat-owner',
      lockHeartbeatInterval: Duration.zero,
      now: () => now,
    );
    const key = 'fedcba9876543210-heartbeat';
    final lock = await heartbeatStore.tryAcquire(
      key: key,
      refreshId: 'live-refresh',
      origin: RefreshOrigin.foreground,
    );
    expect(lock, isNotNull);

    now = now.add(const Duration(minutes: 9));
    await heartbeatStore.renewIfOwned(lock!, 'live-refresh');
    now = now.add(const Duration(minutes: 2));
    expect(
      await heartbeatStore.tryAcquire(
        key: key,
        refreshId: 'competing-refresh',
        origin: RefreshOrigin.foreground,
      ),
      isNull,
    );
    expect(await lock.exists(), isTrue);
    await heartbeatStore.releaseIfOwned(lock, 'live-refresh');
  });
}
