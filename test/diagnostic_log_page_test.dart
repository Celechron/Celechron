import 'package:celechron/page/option/diagnostic_log_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'diagnostic_log_fixture.dart';

Widget testApp({
  Brightness brightness = Brightness.light,
  String? logText,
  Future<void> Function()? clearLogs,
}) {
  return CupertinoApp(
    theme: CupertinoThemeData(brightness: brightness),
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(500, 1000),
        textScaler: TextScaler.linear(1.3),
      ),
      child: DiagnosticLogPage(
        version: '1.2.0',
        initialLogText: logText ?? buildLatestDiagnosticFixture(),
        clearLogs: clearLogs,
      ),
    ),
  );
}

void main() {
  testWidgets('默认显示易读报告且分段控件明确可见', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    expect(find.text('易读报告'), findsOneWidget);
    expect(find.text('原始日志'), findsOneWidget);
    expect(find.byKey(const ValueKey('readable-report-page')), findsOneWidget);
    expect(find.text('刷新成功'), findsOneWidget);
    expect(find.textContaining('2026-07-16'), findsWidgets);

    final semantics = tester.getSemantics(
      find.bySemanticsLabel('诊断日志显示模式'),
    );
    expect(semantics.label, contains('诊断日志显示模式'));
  });

  testWidgets('可点击切换到原始日志并保留复制导出能力', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('原始日志'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('raw-log-page')), findsOneWidget);
    expect(find.text('复制完整原始日志'), findsOneWidget);
    expect(find.text('导出并分享 TXT'), findsOneWidget);
    expect(find.text('清空测试日志'), findsOneWidget);
    expect(find.textContaining('refreshId=bg-refresh'), findsOneWidget);
  });

  testWidgets('支持左右滑动切换模式', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    final pages = find.byKey(const ValueKey('diagnostic-mode-pages'));
    await tester.drag(pages, const Offset(-420, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('raw-log-page')), findsOneWidget);

    await tester.drag(pages, const Offset(420, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('readable-report-page')), findsOneWidget);
  });

  testWidgets('技术详情可展开且堆栈保持二次折叠', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    final degradedToggle = find.byKey(
      const ValueKey('toggle-report-fg-degraded'),
    );
    final readableScroll = find.descendant(
      of: find.byKey(const ValueKey('readable-report-page')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      degradedToggle,
      500,
      scrollable: readableScroll,
    );
    await tester.tap(degradedToggle);
    await tester.pumpAndSettle();

    final sessionButton = find.byKey(
      const ValueKey('toggle-issue-fg-degraded-session-922-课表'),
    );
    await tester.ensureVisible(sessionButton);
    await tester.pumpAndSettle();
    await tester.tap(sessionButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('refreshId：fg-degraded'), findsOneWidget);
    expect(find.textContaining('UTC 时间：2026-07-16T'), findsOneWidget);
    expect(find.text('显示堆栈'), findsNothing);

    final parsingTechnicalButton = find.byKey(
      const ValueKey('toggle-issue-fg-degraded-type-error-主修'),
    );
    await tester.ensureVisible(parsingTechnicalButton);
    await tester.pumpAndSettle();
    await tester.tap(parsingTechnicalButton);
    await tester.pumpAndSettle();
    expect(find.text('显示堆栈'), findsOneWidget);
    expect(find.textContaining('zdbk.dart:373'), findsNothing);
    await tester.tap(find.text('显示堆栈'));
    await tester.pumpAndSettle();
    expect(find.textContaining('zdbk.dart:373'), findsOneWidget);
  });

  testWidgets('深色模式和较大字体下页面可渲染', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(testApp(brightness: Brightness.dark));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('刷新成功'), findsOneWidget);
    expect(find.byKey(const ValueKey('module-课表')), findsOneWidget);
  });

  testWidgets('顶层异常显示失败且不显示刷新成功', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final raw = [
      diagnosticLine(
        '2026-07-16T12:30:00.000Z',
        refreshId: 'top-error-widget',
        source: 'foreground',
        module: 'refresh',
        operation: 'start',
      ),
      diagnosticLine(
        '2026-07-16T12:30:00.100Z',
        refreshId: 'top-error-widget',
        source: 'foreground',
        module: 'refresh',
        operation: 'finish',
        level: 'error',
        durationMs: '100',
        exceptionType: 'StateError',
        exception: 'Bad state: boom',
        message: '完整刷新异常结束',
        stack: r'#0 Scholar.refresh (scholar.dart:200)\n#1 main',
      ),
    ].join('\n');

    await tester.pumpWidget(testApp(logText: raw));
    await tester.pumpAndSettle();

    expect(find.text('刷新失败'), findsOneWidget);
    expect(find.text('刷新成功'), findsNothing);
    expect(find.text('刷新执行异常'), findsWidgets);
  });

  testWidgets('共享刷新显示 owner 且不展示未执行模块', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final raw = [
      diagnosticLine(
        '2026-07-16T12:31:00.000Z',
        refreshId: 'shared-widget',
        source: 'foreground',
        module: 'refresh',
        operation: 'start',
      ),
      diagnosticLine(
        '2026-07-16T12:31:00.010Z',
        refreshId: 'shared-widget',
        relatedRefreshId: 'owner-widget',
        source: 'foreground',
        module: 'refresh',
        operation: 'shareFlight',
      ),
      diagnosticLine(
        '2026-07-16T12:31:00.100Z',
        refreshId: 'shared-widget',
        source: 'foreground',
        module: 'refresh',
        operation: 'finish',
      ),
    ].join('\n');

    await tester.pumpWidget(testApp(logText: raw));
    await tester.pumpAndSettle();

    expect(find.text('已共享现有刷新'), findsOneWidget);
    expect(find.textContaining('关联任务：owner-widget'), findsOneWidget);
    expect(find.text('刷新成功'), findsNothing);
    expect(find.byKey(const ValueKey('module-课表')), findsNothing);
    expect(find.text('未执行'), findsNothing);
  });

  testWidgets('清空日志先确认，取消不清理，确认后才清理', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var clearCalls = 0;
    await tester.pumpWidget(testApp(
      clearLogs: () async => clearCalls++,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('原始日志'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('清空测试日志'));
    await tester.pumpAndSettle();
    expect(find.text('确定清空测试日志？'), findsOneWidget);
    expect(find.textContaining('无法在 App 内恢复'), findsOneWidget);
    expect(clearCalls, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(clearCalls, 0);
    expect(find.textContaining('refreshId=bg-refresh'), findsOneWidget);

    await tester.tap(find.text('清空测试日志'));
    await tester.pumpAndSettle();
    final destructive = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, '清空'),
    );
    expect(destructive.isDestructiveAction, isTrue);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '清空'));
    await tester.pumpAndSettle();
    expect(clearCalls, 1);
    expect(find.text('已清空'), findsOneWidget);
  });
}
