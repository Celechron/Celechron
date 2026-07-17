import 'package:celechron/model/practice_score_item.dart';
import 'package:celechron/model/scholar.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> sztzItem({
  Object id = 101,
  Object? score = 2,
  Object? categoryId = 1,
  String categoryName = '第二课堂',
  Object? statusValue = 5,
  String statusLabel = '审核通过',
  bool deleted = false,
}) =>
    {
      'id': id,
      'jd': score,
      'sfsc': deleted,
      'hdjjygrcdgz': '项目成员',
      'qksm': '虚构测试说明',
      'hdsj': '2026-01-02T08:00:00+08:00',
      'hdjssj': '2026-01-02T10:00:00+08:00',
      'gxsj': '2026-01-03T12:00:00+08:00',
      'cyrshzt': {'value': statusValue, 'label': statusLabel},
      'currentState': {'name': '流程处理中'},
      'xm': {
        'mc': '虚构实践项目',
        'zxfs': 88,
        'zdfs': 99,
        'xmfl': {'id': categoryId, 'mc': categoryName},
        'xmlb': {'mc': '志愿服务'},
        'xmlx': {'mc': '社会责任'},
      },
    };

void main() {
  group('PracticeScoreItem.fromSztzJson', () {
    test('使用外层 jd，不使用项目分数范围', () {
      final item = PracticeScoreItem.fromSztzJson(
        sztzItem(score: '2.25'),
      );
      expect(item.score, 2.25);
      expect(item.score, isNot(88));
      expect(item.score, isNot(99));
    });

    test('value=5 或审核通过字符串均判定通过', () {
      final byValue = PracticeScoreItem.fromSztzJson(
        sztzItem(statusValue: 5, statusLabel: '已结束'),
      );
      final byLabel = PracticeScoreItem.fromSztzJson(
        sztzItem(statusValue: 4, statusLabel: '审核通过'),
      );
      expect(byValue.countsTowardTotal, isTrue);
      expect(byLabel.countsTowardTotal, isTrue);
    });

    test('待审核项目保留但不计入总分', () {
      final item = PracticeScoreItem.fromSztzJson(
        sztzItem(statusValue: 3, statusLabel: '待学校审核'),
      );
      expect(item.statusLabel, '待学校审核');
      expect(item.countsTowardTotal, isFalse);
    });

    test('课堂 id 和中文名称备用分类均正确', () {
      final second = PracticeScoreItem.fromSztzJson(sztzItem(categoryId: 1));
      final third = PracticeScoreItem.fromSztzJson(
        sztzItem(id: 102, categoryId: '2', categoryName: '第三课堂'),
      );
      final fourth = PracticeScoreItem.fromSztzJson(
        sztzItem(id: 103, categoryId: null, categoryName: '第四课堂'),
      );
      expect(
          [second.categoryId, third.categoryId, fourth.categoryId], [1, 2, 3]);
    });

    test('数字字符串和 num 均可解析', () {
      final text =
          PracticeScoreItem.fromSztzJson(sztzItem(id: '201', score: '1.50'));
      final number =
          PracticeScoreItem.fromSztzJson(sztzItem(id: 202, score: 2.5));
      expect(text.id, 201);
      expect(text.score, 1.5);
      expect(number.score, 2.5);
    });

    test('缺失非关键字段仍可解析', () {
      final item = PracticeScoreItem.fromSztzJson({
        'id': 301,
        'jd': 1,
        'cyrshzt': {'value': 5},
        'xm': {
          'xmfl': {'mc': '第二课堂'},
        },
      });
      expect(item.projectName, '未命名项目');
      expect(item.categoryId, 1);
      expect(item.countsTowardTotal, isTrue);
    });
  });

  test('批量解析忽略删除项、异常项并按外层 id 去重', () {
    final errors = <Object>[];
    final items = PracticeScoreItem.parseSztzItems(
      [
        sztzItem(id: 401),
        sztzItem(id: 401, score: 9),
        sztzItem(id: 402, deleted: true),
        {'jd': 1},
      ],
      onError: (_, error, __) => errors.add(error),
    );
    expect(items, hasLength(1));
    expect(items.single.score, 2);
    expect(errors, hasLength(1));
  });

  test('只汇总通过、未删除、有效课堂和非负实际分数', () {
    final items = PracticeScoreItem.parseSztzItems([
      sztzItem(id: 501, score: 1.25, categoryId: 1),
      sztzItem(id: 502, score: 2, categoryId: 2),
      sztzItem(id: 503, score: 3.5, categoryId: 3),
      sztzItem(
        id: 504,
        score: 10,
        categoryId: 1,
        statusValue: 3,
        statusLabel: '待学校审核',
      ),
      sztzItem(id: 505, score: -1, categoryId: 1),
      sztzItem(id: 506, score: 8, categoryId: 9),
    ]);
    expect(PracticeScoreItem.approvedTotals(items), {1: 1.25, 2: 2, 3: 3.5});
  });

  test('toJson/fromJson 往返保留归一化字段', () {
    final original = PracticeScoreItem.fromSztzJson(sztzItem(score: 3.75));
    final restored = PracticeScoreItem.fromJson(original.toJson());
    expect(restored.toJson(), original.toJson());
  });

  test('旧 Scholar 缓存无明细字段时保留旧总分', () {
    final scholar = Scholar.fromJson({
      'pt2': 4.5,
      'pt3': 2,
      'pt4': 1.25,
      'isPracticeScoresGet': true,
    });
    expect(scholar.pt2, 4.5);
    expect(scholar.pt3, 2);
    expect(scholar.pt4, 1.25);
    expect(scholar.practiceScoreItems, isEmpty);
    expect(scholar.practiceDetailsAvailable, isFalse);
    expect(scholar.practiceDataSource, PracticeDataSource.zdbkCache);
  });
}
