import 'package:celechron/model/practice_score_item.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/page/scholar/practice_score/practice_score_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

PracticeScoreItem item({
  required int id,
  required int categoryId,
  bool approved = true,
}) =>
    PracticeScoreItem(
      id: id,
      categoryId: categoryId,
      categoryName: switch (categoryId) {
        1 => '第二课堂',
        2 => '第三课堂',
        _ => '第四课堂',
      },
      projectName: '虚构项目 $id',
      projectType: '志愿服务',
      qualityType: '社会责任',
      score: 1,
      statusValue: approved ? 5 : 3,
      statusLabel: approved ? '审核通过' : '待学校审核',
      approved: approved,
      deleted: false,
      role: '项目成员',
      remark: '虚构情况说明',
      activityStart: DateTime(2026, 1, 1, 8),
      activityEnd: DateTime(2026, 1, 1, 10),
      updatedAt: DateTime(2026, 1, 2, 12),
    );

Scholar liveScholar() {
  final scholar = Scholar()
    ..pt2 = 1
    ..pt3 = 1
    ..pt4 = 1
    ..practiceScoreItems = [
      item(id: 1, categoryId: 1),
      item(id: 2, categoryId: 2, approved: false),
      item(id: 3, categoryId: 3),
    ]
    ..practiceDataSource = PracticeDataSource.sztzLive
    ..practiceUpdatedAt = DateTime(2026, 1, 2, 12)
    ..practiceDetailsAvailable = true
    ..practiceDetailsStale = false
    ..isPracticeScoresGet = true;
  return scholar;
}

Widget summaryApp(Scholar scholar) => CupertinoApp(
      home: CupertinoPageScaffold(
        child: Center(child: PracticeScoreColumns(scholar: scholar)),
      ),
    );

void main() {
  for (final entry in const {
    1: '第二课堂项目',
    2: '第三课堂项目',
    3: '第四课堂项目',
  }.entries) {
    testWidgets('点击${entry.key}类课分进入对应明细页', (tester) async {
      await tester.pumpWidget(summaryApp(liveScholar()));
      await tester.tap(
        find.byKey(ValueKey('practice-score-category-${entry.key}')),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    });
  }

  testWidgets('待学校审核项目显示但明确未计入总分，并可进入详情', (tester) async {
    final scholar = liveScholar();
    await tester.pumpWidget(
      CupertinoApp(
        home: PracticeScorePage(scholar: scholar, categoryId: 2),
      ),
    );
    expect(find.text('待学校审核 · 未计入总分'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('practice-item-2')));
    await tester.pumpAndSettle();
    expect(find.text('实践项目详情'), findsOneWidget);
    expect(find.text('虚构项目 2'), findsOneWidget);
  });

  testWidgets('仅有 ZDBK 汇总时显示暂无项目明细', (tester) async {
    final scholar = Scholar()
      ..pt2 = 2.5
      ..practiceDataSource = PracticeDataSource.zdbkLive
      ..practiceUpdatedAt = DateTime(2026, 1, 2)
      ..practiceDetailsAvailable = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: PracticeScorePage(scholar: scholar, categoryId: 1),
      ),
    );
    expect(
      find.text('当前仅获取到教务网旧实践分汇总，暂无素质拓展平台项目明细。'),
      findsOneWidget,
    );
  });
}
