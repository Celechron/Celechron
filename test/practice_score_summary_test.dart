import 'dart:convert';

import 'package:celechron/http/zjuServices/sztz.dart';
import 'package:celechron/model/practice_score_item.dart';
import 'package:celechron/model/scholar.dart';
import 'package:flutter_test/flutter_test.dart';

PracticeScoreItem _item({
  required int id,
  required int categoryId,
  required double score,
}) =>
    PracticeScoreItem(
      id: id,
      categoryId: categoryId,
      categoryName: switch (categoryId) {
        1 => '第二课堂',
        2 => '第三课堂',
        _ => '第四课堂',
      },
      projectName: '测试项目 $id',
      projectType: '测试类别',
      qualityType: '测试素质类别',
      score: score,
      statusValue: 5,
      statusLabel: '审核通过',
      approved: true,
      deleted: false,
      role: null,
      remark: null,
      activityStart: null,
      activityEnd: null,
      updatedAt: DateTime(2026, 7, 1),
    );

PracticeScoreSnapshot _details({
  PracticeDataSource source = PracticeDataSource.sztzLive,
  bool stale = false,
}) =>
    PracticeScoreSnapshot.sztz(
      items: [
        _item(id: 1, categoryId: 1, score: 1),
        _item(id: 2, categoryId: 2, score: 2),
        _item(id: 3, categoryId: 3, score: 3),
      ],
      source: source,
      updatedAt: DateTime(2026, 7, 1),
      stale: stale,
    );

PracticeScoreSummary _myInfoSummary(PracticeSummarySource source) =>
    PracticeScoreSummary(
      dektJf: 3.45,
      dsktJf: 1,
      dsiktJf: 0,
      myPassed: true,
      lyPassed: false,
      source: source,
      updatedAt: DateTime(2026, 7, 2),
      stale: source != PracticeSummarySource.networkMyInfo,
    );

void _applyPractice(Scholar scholar, PracticeScoreSnapshot snapshot) {
  scholar.setScholar(
    const [],
    const [],
    {},
    const [],
    {},
    const [],
    snapshot,
  );
}

void main() {
  group('getMyInfo 数值与状态解析', () {
    for (final entry in <(Object?, double)>[
      (3, 3),
      (3.45, 3.45),
      ('3.450', 3.45),
      (null, 0),
      ('', 0),
    ]) {
      test('dektJf=${entry.$1} 可安全转换', () {
        final summary = PracticeScoreSummary.fromMyInfoJson(
          {
            'dektJf': entry.$1,
            'dsktJf': 1,
            'dsiktJf': 2,
          },
          source: PracticeSummarySource.networkMyInfo,
          updatedAt: DateTime(2026),
        );
        expect(summary.dektJf, entry.$2);
      });
    }

    test('总记点只累加三个 Jf 白名单字段', () {
      final summary = PracticeScoreSummary.fromMyInfoJson(
        {
          'dektJf': '3.450',
          'dsktJf': 1,
          'dsiktJf': 2,
          'dektXf': 100,
          'dektDj': 100,
          'myTg': true,
        },
        source: PracticeSummarySource.networkMyInfo,
        updatedAt: DateTime(2026),
      );
      expect(summary.totalJf, 6.45);
      expect(summary.myPassed, isTrue);
    });

    test('布尔、数字和常见字符串通过状态均可解析', () {
      final summary = PracticeScoreSummary.fromMyInfoJson(
        {
          'dektJf': 1,
          'dsktJf': 0,
          'dsiktJf': 0,
          'myTg': '已通过',
          'lyTg': 0,
        },
        source: PracticeSummarySource.networkMyInfo,
        updatedAt: DateTime(2026),
      );
      expect(summary.myPassed, isTrue);
      expect(summary.lyPassed, isFalse);
    });

    test('全部记点字段缺失或异常值会拒绝解析', () {
      expect(
        () => PracticeScoreSummary.fromMyInfoJson(
          {'myTg': true},
          source: PracticeSummarySource.networkMyInfo,
          updatedAt: DateTime(2026),
        ),
        throwsFormatException,
      );
      expect(
        () => PracticeScoreSummary.fromMyInfoJson(
          {'dektJf': 'not-a-number'},
          source: PracticeSummarySource.networkMyInfo,
          updatedAt: DateTime(2026),
        ),
        throwsFormatException,
      );
    });
  });

  group('汇总三级优先级', () {
    test('两个接口成功时明细来自 getSqjl，汇总来自网络 getMyInfo', () {
      final details = _details();
      final snapshot = PracticeScoreSnapshot.resolve(
        details: details,
        myInfoSummary: _myInfoSummary(PracticeSummarySource.networkMyInfo),
      );
      expect(snapshot.items, same(details.items));
      expect(snapshot.totalFor(1), 3.45);
      expect(snapshot.summarySource, PracticeSummarySource.networkMyInfo);
      expect(snapshot.summary!.toCacheJson(), {
        'dektJf': 3.45,
        'dsktJf': 1.0,
        'dsiktJf': 0.0,
        'myPassed': true,
        'lyPassed': false,
      });
    });

    test('getMyInfo 网络失败但缓存有效时，明细仍用本次 getSqjl', () {
      final snapshot = PracticeScoreSnapshot.resolve(
        details: _details(),
        myInfoSummary: _myInfoSummary(PracticeSummarySource.cachedMyInfo),
        summaryErrorMessage: '网络失败',
      );
      expect(snapshot.items, hasLength(3));
      expect(snapshot.totalFor(1), 3.45);
      expect(snapshot.summarySource, PracticeSummarySource.cachedMyInfo);
    });

    test('getMyInfo 及缓存失败时按 getSqjl 审核通过项目合计', () {
      final snapshot = PracticeScoreSnapshot.resolve(
        details: _details(),
        summaryErrorMessage: '网络与缓存均不可用',
      );
      expect(snapshot.totalFor(1), 1);
      expect(snapshot.totalFor(2), 2);
      expect(snapshot.totalFor(3), 3);
      expect(
        snapshot.summarySource,
        PracticeSummarySource.calculatedFromSqjl,
      );
    });

    test('getSqjl 失败但 getMyInfo 成功时更新汇总并保留旧明细', () {
      final scholar = Scholar()
        ..practiceScoreItems = [_item(id: 9, categoryId: 1, score: 9)]
        ..practiceDataSource = PracticeDataSource.sztzLive
        ..practiceDetailsAvailable = true
        ..pt2 = 9;
      final snapshot = PracticeScoreSnapshot.resolve(
        details: PracticeScoreSnapshot.unavailable,
        myInfoSummary: _myInfoSummary(PracticeSummarySource.networkMyInfo),
      );
      _applyPractice(scholar, snapshot);
      expect(scholar.pt2, 3.45);
      expect(scholar.practiceScoreItems.single.id, 9);
      expect(scholar.practiceDetailsStale, isTrue);
    });

    test('两个接口都失败时不以零覆盖旧数据', () {
      final scholar = Scholar()
        ..pt2 = 8
        ..pt3 = 7
        ..isPracticeScoresGet = true
        ..practiceSummarySource = PracticeSummarySource.cachedMyInfo
        ..practiceScoreItems = [_item(id: 9, categoryId: 1, score: 9)]
        ..practiceDetailsAvailable = true;
      _applyPractice(
        scholar,
        PracticeScoreSnapshot.resolve(
          details: PracticeScoreSnapshot.unavailable,
          summaryErrorMessage: '全部失败',
        ),
      );
      expect([scholar.pt2, scholar.pt3], [8, 7]);
      expect(scholar.practiceScoreItems.single.id, 9);
      expect(scholar.practiceSummarySource, PracticeSummarySource.cachedMyInfo);
    });
  });

  group('响应和缓存隔离', () {
    test('登录页 HTML、错误 code、缺失结构和账号不匹配均无效', () {
      const account = '3000000001';
      expect(
        Sztz.isValidMyInfoResponse(
          '<!doctype html><html><body>login</body></html>',
          accountScope: account,
        ),
        isFalse,
      );
      expect(
        Sztz.isValidMyInfoResponse(
          jsonEncode({'code': 1, 'msg': 'failed'}),
          accountScope: account,
        ),
        isFalse,
      );
      expect(
        Sztz.isValidMyInfoResponse(
          jsonEncode({'code': 0, 'extend': {}}),
          accountScope: account,
        ),
        isFalse,
      );
      expect(
        Sztz.isValidMyInfoResponse(
          jsonEncode({
            'code': 0,
            'extend': {
              'myInfo': {
                'xh': '3000000002',
                'dektJf': 1,
                'dsktJf': 0,
                'dsiktJf': 0,
              },
            },
          }),
          accountScope: account,
        ),
        isFalse,
      );
    });

    test('账号缓存 key 隔离且不包含明文学号', () {
      const first = '3000000001';
      const second = '3000000002';
      final firstKey = Sztz.myInfoCacheKeyForAccount(first);
      final secondKey = Sztz.myInfoCacheKeyForAccount(second);
      expect(firstKey, isNot(secondKey));
      expect(firstKey, isNot(contains(first)));
      expect(secondKey, isNot(contains(second)));
    });

    test('缓存字段不完整时安全判为无效', () {
      expect(
        () => PracticeScoreSummary.fromCacheJson(
          {
            'dektJf': 1,
            'dsktJf': 2,
            'dsiktJf': 3,
          },
          updatedAt: DateTime(2026),
        ),
        throwsFormatException,
      );
    });

    test('持久化正式汇总不会被 getSqjl 项目合计覆盖', () {
      final original = Scholar()
        ..pt2 = 9
        ..pt3 = 8
        ..pt4 = 7
        ..isPracticeScoresGet = true
        ..practiceScoreItems = [_item(id: 1, categoryId: 1, score: 1)]
        ..practiceDataSource = PracticeDataSource.sztzLive
        ..practiceSummarySource = PracticeSummarySource.networkMyInfo
        ..practiceDetailsAvailable = true;
      final restored = Scholar.fromJson(original.toJson());
      expect([restored.pt2, restored.pt3, restored.pt4], [9, 8, 7]);
      expect(
        restored.practiceSummarySource,
        PracticeSummarySource.cachedMyInfo,
      );
    });
  });
}
