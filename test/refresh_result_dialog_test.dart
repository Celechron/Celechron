import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:celechron/page/scholar/scholar_view.dart';

void main() {
  Widget testApp(List<String?> results) {
    return CupertinoApp(
      home: Builder(
        builder: (context) => CupertinoButton(
          onPressed: () => showRefreshResultDialog(context, results),
          child: const Text('刷新'),
        ),
      ),
    );
  }

  testWidgets('完整刷新成功后不显示结果弹窗', (tester) async {
    await tester.pumpWidget(testApp([null, null, null]));

    await tester.tap(find.text('刷新'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });

  testWidgets('刷新失败仍显示必要错误且不展示诊断标识', (tester) async {
    await tester.pumpWidget(testApp(['作业查询出错：请求超时']));

    await tester.tap(find.text('刷新'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.textContaining('请求超时'), findsOneWidget);
    expect(find.textContaining('refreshId'), findsNothing);
    expect(find.textContaining('总耗时'), findsNothing);
  });
}
