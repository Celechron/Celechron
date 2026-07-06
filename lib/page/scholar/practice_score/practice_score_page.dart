import 'package:celechron/design/multiple_columns.dart';
import 'package:celechron/model/practice_score_item.dart';
import 'package:celechron/model/scholar.dart';
import 'package:flutter/cupertino.dart';

class PracticeScoreColumns extends StatelessWidget {
  final Scholar scholar;

  const PracticeScoreColumns({super.key, required this.scholar});

  @override
  Widget build(BuildContext context) {
    Widget score(int categoryId, double value) => Text(
          value.toStringAsFixed(2),
          key: ValueKey('practice-score-category-$categoryId'),
          style: CupertinoTheme.of(context)
              .textTheme
              .navTitleTextStyle
              .copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        );

    void open(int categoryId) {
      Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => PracticeScorePage(
            scholar: scholar,
            categoryId: categoryId,
          ),
        ),
      );
    }

    final passed = <String>[
      if (scholar.practiceMyPassed != null)
        '美育：${scholar.practiceMyPassed! ? '已通过' : '未通过'}',
      if (scholar.practiceLyPassed != null)
        '劳育：${scholar.practiceLyPassed! ? '已通过' : '未通过'}',
    ];
    return Column(
      children: [
        MultipleColumns(
          contents: [
            score(1, scholar.pt2),
            score(2, scholar.pt3),
            score(3, scholar.pt4),
          ],
          titles: const ['二课计点', '三课计点', '四课计点'],
          onTaps: [
            () => open(1),
            () => open(2),
            () => open(3),
          ],
        ),
        if (passed.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            passed.join(' · '),
            key: const ValueKey('practice-passed-status'),
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class PracticeScorePage extends StatelessWidget {
  final Scholar scholar;
  final int categoryId;

  const PracticeScorePage({
    super.key,
    required this.scholar,
    required this.categoryId,
  });

  String get _categoryName => switch (categoryId) {
        1 => '第二课堂',
        2 => '第三课堂',
        3 => '第四课堂',
        _ => '实践课堂',
      };

  @override
  Widget build(BuildContext context) {
    final items = scholar.practiceScoreItems
        .where((item) => item.categoryId == categoryId)
        .toList()
      ..sort((a, b) => _sortDate(b).compareTo(_sortDate(a)));
    final included =
        items.where((item) => item.countsTowardTotal).toList(growable: false);
    final excluded =
        items.where((item) => !item.countsTowardTotal).toList(growable: false);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('$_categoryName项目'),
      ),
      backgroundColor: CupertinoDynamicColor.resolve(
        CupertinoColors.systemGroupedBackground,
        context,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SummaryCard(
              categoryName: _categoryName,
              total: switch (categoryId) {
                1 => scholar.pt2,
                2 => scholar.pt3,
                3 => scholar.pt4,
                _ => 0,
              },
              includedCount: included.length,
              excludedCount: excluded.length,
              source: scholar.practiceSummarySource,
              detailSource: scholar.practiceDataSource,
              updatedAt: scholar.practiceUpdatedAt,
              stale: scholar.practiceSummaryStale,
              detailsStale: scholar.practiceDetailsStale,
            ),
            const SizedBox(height: 16),
            if (!scholar.practiceDetailsAvailable)
              _NoDetailsCard(source: scholar.practiceDataSource)
            else ...[
              _SectionTitle(title: '已计入总分', count: included.length),
              if (included.isEmpty)
                const _EmptyGroup(text: '暂无已计入总分的项目')
              else
                ...included.map(
                  (item) => _PracticeItemCard(
                    item: item,
                    onTap: () => _openDetail(context, item),
                  ),
                ),
              const SizedBox(height: 12),
              _SectionTitle(title: '审核中或未计入', count: excluded.length),
              if (excluded.isEmpty)
                const _EmptyGroup(text: '暂无审核中或未计入的项目')
              else
                ...excluded.map(
                  (item) => _PracticeItemCard(
                    item: item,
                    onTap: () => _openDetail(context, item),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, PracticeScoreItem item) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => PracticeScoreDetailPage(item: item),
      ),
    );
  }

  static DateTime _sortDate(PracticeScoreItem item) =>
      item.updatedAt ?? item.activityStart ?? DateTime(1970);
}

class PracticeScoreDetailPage extends StatelessWidget {
  final PracticeScoreItem item;

  const PracticeScoreDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('项目名称', item.projectName),
      ('获得记点', _score(item)),
      ('课堂类别', item.categoryName),
      ('审核状态', item.statusLabel),
      ('项目类别', item.projectType),
      ('素质类别', item.qualityType),
      ('参与身份或得分原因', item.role ?? '未填写'),
      ('情况说明', item.remark ?? '未填写'),
      ('活动开始时间', _dateTime(item.activityStart)),
      ('活动结束时间', _dateTime(item.activityEnd)),
      ('最近更新时间', _dateTime(item.updatedAt)),
    ];
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('实践项目详情')),
      backgroundColor: CupertinoDynamicColor.resolve(
        CupertinoColors.systemGroupedBackground,
        context,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _Card(
              child: Column(
                children: [
                  for (var index = 0; index < rows.length; index++) ...[
                    _DetailRow(label: rows[index].$1, value: rows[index].$2),
                    if (index != rows.length - 1) const _Divider(),
                  ],
                ],
              ),
            ),
            if (!item.countsTowardTotal) ...[
              const SizedBox(height: 12),
              const Text(
                '该项目当前未计入总分。',
                style: TextStyle(
                  color: CupertinoColors.systemOrange,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String categoryName;
  final double total;
  final int includedCount;
  final int excludedCount;
  final PracticeSummarySource source;
  final PracticeDataSource detailSource;
  final DateTime? updatedAt;
  final bool stale;
  final bool detailsStale;

  const _SummaryCard({
    required this.categoryName,
    required this.total,
    required this.includedCount,
    required this.excludedCount,
    required this.source,
    required this.detailSource,
    required this.updatedAt,
    required this.stale,
    required this.detailsStale,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            categoryName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '正式汇总计点',
            style: TextStyle(color: CupertinoColors.secondaryLabel),
          ),
          const SizedBox(height: 4),
          Text(
            total.toStringAsFixed(2),
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text('已计入 $includedCount 项 · 未计入 $excludedCount 项'),
          const SizedBox(height: 6),
          Text(
            '计点来源：${source.label}',
            style: const TextStyle(color: CupertinoColors.secondaryLabel),
          ),
          const SizedBox(height: 4),
          Text(
            '项目明细来源：${detailSource.label}',
            style: const TextStyle(color: CupertinoColors.secondaryLabel),
          ),
          const SizedBox(height: 4),
          Text(
            '更新时间：${_dateTime(updatedAt)}',
            style: const TextStyle(color: CupertinoColors.secondaryLabel),
          ),
          if (stale) ...[
            const SizedBox(height: 10),
            const Text(
              '当前计点使用缓存或项目合计，请在网络恢复后刷新。',
              style: TextStyle(color: CupertinoColors.systemOrange),
            ),
          ],
          if (detailsStale) ...[
            const SizedBox(height: 6),
            const Text(
              '项目明细为缓存或上一次结果。',
              style: TextStyle(color: CupertinoColors.systemOrange),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            '正式汇总与项目记录可能不完全一致，项目明细仍按 getSqjl 原样展示。',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoDetailsCard extends StatelessWidget {
  final PracticeDataSource source;

  const _NoDetailsCard({required this.source});

  @override
  Widget build(BuildContext context) {
    final zdbkOnly = source == PracticeDataSource.zdbkLive ||
        source == PracticeDataSource.zdbkCache;
    return _Card(
      child: Text(
        zdbkOnly ? '当前仅获取到旧实践汇总，暂无 getSqjl 项目明细。' : '当前 getSqjl 项目明细不可用，请稍后刷新。',
        key: const ValueKey('practice-no-details'),
        style: const TextStyle(
          color: CupertinoColors.secondaryLabel,
          height: 1.5,
        ),
      ),
    );
  }
}

class _PracticeItemCard extends StatelessWidget {
  final PracticeScoreItem item;
  final VoidCallback onTap;

  const _PracticeItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final counted = item.countsTowardTotal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CupertinoButton(
        key: ValueKey('practice-item-${item.id}'),
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: _Card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.projectName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      counted
                          ? item.statusLabel
                          : '${item.statusLabel} · 未计入总分',
                      style: TextStyle(
                        color: counted
                            ? CupertinoColors.systemGreen
                            : CupertinoColors.systemOrange,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.projectType} · ${item.qualityType}',
                      style: const TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '更新于 ${_dateTime(item.updatedAt)}',
                      style: const TextStyle(
                        color: CupertinoColors.tertiaryLabel,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${counted ? '+' : ''}${_score(item)}',
                style: TextStyle(
                  color: counted
                      ? CupertinoColors.systemGreen
                      : CupertinoColors.label,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                CupertinoIcons.chevron_forward,
                size: 14,
                color: CupertinoColors.tertiaryLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
        child: Text(
          '$title（$count）',
          style: const TextStyle(
            color: CupertinoColors.secondaryLabel,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _EmptyGroup extends StatelessWidget {
  final String text;

  const _EmptyGroup({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 18),
        child: Text(
          text,
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      );
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(
            CupertinoColors.secondarySystemGroupedBackground,
            context,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.label,
              context,
            ),
            fontSize: 15,
          ),
          child: child,
        ),
      );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Text(
                label,
                style: const TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            ),
            Expanded(
              child: Text(value, textAlign: TextAlign.right),
            ),
          ],
        ),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        height: 0.5,
        color: CupertinoDynamicColor.resolve(
          CupertinoColors.separator,
          context,
        ),
      );
}

String _score(PracticeScoreItem item) => item.score.isFinite && item.score >= 0
    ? item.score.toStringAsFixed(2)
    : '—';

String _dateTime(DateTime? value) {
  if (value == null) return '未知';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
