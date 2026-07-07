import 'package:flutter_test/flutter_test.dart';

import 'package:celechron/http/spider.dart';

void main() {
  group('moduleStatusesFromErrors', () {
    const labels = ['校历', '课表', '考试', '成绩', '主修', '作业', '实践'];

    test('null 为成功、「查询进行中」为进行中、其余为失败，且按下标对应标签', () {
      final statuses = moduleStatusesFromErrors([
        null,
        '课表查询进行中',
        '考试查询出错：Connection closed',
        null,
        '主修查询进行中',
        '作业查询出错：超时',
        '实践查询进行中',
      ], labels);

      expect(statuses, hasLength(7));
      expect(statuses[0].label, '校历');
      expect(statuses[0].state, FetchModuleState.success);
      expect(statuses[1].state, FetchModuleState.pending);
      expect(statuses[2].state, FetchModuleState.failed);
      expect(statuses[3].state, FetchModuleState.success);
      expect(statuses[4].state, FetchModuleState.pending);
      expect(statuses[5].state, FetchModuleState.failed);
      expect(statuses[6].label, '实践');
      expect(statuses[6].state, FetchModuleState.pending);
    });

    test('最终态（无「查询进行中」标记）只区分成功与失败', () {
      final statuses = moduleStatusesFromErrors(
          [null, null, '考试查询出错：500', null, null, null, null], labels);
      expect(
          statuses.where((s) => s.state == FetchModuleState.failed).single.label,
          '考试');
      expect(statuses.where((s) => s.state == FetchModuleState.pending), isEmpty);
    });

    test('长度不一致时视为不可信，返回空列表（如 MockSpider 的 6 项错误表）', () {
      final statuses = moduleStatusesFromErrors(
          [null, null, null, null, null, null], labels);
      expect(statuses, isEmpty);
    });
  });
}
