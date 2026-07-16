import 'package:celechron/page/option/diagnostic_log_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'diagnostic_log_fixture.dart';

Widget testApp({Brightness brightness = Brightness.light}) {
  return CupertinoApp(
    theme: CupertinoThemeData(brightness: brightness),
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(500, 1000),
        textScaler: TextScaler.linear(1.3),
      ),
      child: DiagnosticLogPage(
        version: '1.2.0',
        initialLogText: buildLatestDiagnosticFixture(),
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
}
