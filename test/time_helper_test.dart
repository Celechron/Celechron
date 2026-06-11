import 'package:flutter_test/flutter_test.dart';

import 'package:celechron/model/exam.dart';
import 'package:celechron/utils/time_helper.dart';

void main() {
  group('TimeHelper.parseExamDateTime', () {
    test('parses calendar date format', () {
      final result = TimeHelper.parseExamDateTime('2025年08月23日(14:00-16:40)');

      expect(result[0], DateTime(2025, 8, 23, 14));
      expect(result[1], DateTime(2025, 8, 23, 16, 40));
      expect(
        TimeHelper.parseExamDateLabel('2025年08月23日(14:00-16:40)'),
        isNull,
      );
    });

    test('parses winter exam week format and preserves its label', () {
      const input = '冬考试周第10天(08:00-10:00)';
      final result = TimeHelper.parseExamDateTime(input);

      expect(result[0], DateTime(1970, 4, 10, 8));
      expect(result[1], DateTime(1970, 4, 10, 10));
      expect(TimeHelper.parseExamDateLabel(input), '冬考试周第 10 天');
    });

    test('keeps autumn and winter exam days in separate groups', () {
      final autumn = TimeHelper.parseExamDateTime('秋考试周第3天(10:30-12:30)');
      final winter = TimeHelper.parseExamDateTime('冬考试周第3天(10:30-12:30)');

      expect(autumn[0], DateTime(1970, 3, 3, 10, 30));
      expect(winter[0], DateTime(1970, 4, 3, 10, 30));
      expect(autumn[0], isNot(winter[0]));
    });

    test('continues to support the legacy exam week format', () {
      const input = '第5天(14:00-16:00)';
      final result = TimeHelper.parseExamDateTime(input);

      expect(result[0], DateTime(1970, 1, 5, 14));
      expect(result[1], DateTime(1970, 1, 5, 16));
      expect(TimeHelper.parseExamDateLabel(input), '考试周第 5 天');
    });

    test(
      'accepts numeric dates, Chinese parentheses and alternate separator',
      () {
        const input = '2025-08-23（14:00至16:40）';
        final result = TimeHelper.parseExamDateTime(input);

        expect(result[0], DateTime(2025, 8, 23, 14));
        expect(result[1], DateTime(2025, 8, 23, 16, 40));
        expect(TimeHelper.parseExamDateLabel(input), isNull);
      },
    );

    test('preserves an unknown future exam-period label', () {
      const input = '期末集中考试第2天 13:30~15:30';
      final result = TimeHelper.parseExamDateTime(input);

      expect(result[0], DateTime(1970, 1, 2, 13, 30));
      expect(result[1], DateTime(1970, 1, 2, 15, 30));
      expect(
        TimeHelper.parseExamDateLabel(input),
        '期末集中考试第 2 天',
      );
    });
  });

  test('Exam preserves and displays a custom exam date label', () {
    final exam = Exam.empty()
      ..id = 'test'
      ..name = '测试课程'
      ..time = [DateTime(1970, 4, 10, 8), DateTime(1970, 4, 10, 10)]
      ..dateLabel = '冬考试周第 10 天';

    final restored = Exam.fromJson(exam.toJson());

    expect(restored.dateLabel, '冬考试周第 10 天');
    expect(restored.chineseDate, '冬考试周第 10 天');
    expect(restored.chineseTime, '冬考试周第 10 天 08:00 - 10:00');
  });
}
