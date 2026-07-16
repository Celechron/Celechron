import 'package:celechron/services/diagnostic_report.dart';
import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'diagnostic_log_fixture.dart';

DiagnosticRefreshReport reportById(
  DiagnosticReportBundle bundle,
  String refreshId,
) =>
    bundle.reports.singleWhere((report) => report.refreshId == refreshId);

DiagnosticModuleReport moduleByName(
  DiagnosticRefreshReport report,
  String name,
) =>
    report.modules.singleWhere((module) => module.name == name);

void main() {
  const parser = DiagnosticReportParser();

  test('UTC 转本地时间并显示 UTC 偏移', () {
    final utc = DateTime.parse('2026-07-16T11:58:04.000Z');
    expect(
      formatLocalDiagnosticTime(
        utc,
        utcOffset: const Duration(hours: 8),
      ),
      '2026-07-16 19:58:04 UTC+08:00',
    );
    expect(formatUtcDiagnosticTime(utc), '2026-07-16T11:58:04.000Z');
  });

  test('同一 refreshId 聚合且不同 refreshId 严格隔离', () {
    final bundle = parser.parse(buildLatestDiagnosticFixture());
    expect(bundle.reports.map((report) => report.refreshId),
        ['fg-success', 'fg-degraded', 'bg-refresh']);

    final degraded = reportById(bundle, 'fg-degraded');
    final success = reportById(bundle, 'fg-success');
    expect(degraded.startedAtUtc, DateTime.parse('2026-07-16T11:58:04.000Z'));
    expect(degraded.durationMs, 2128);
    expect(success.durationMs, 1741);
    expect(
      formatLocalDiagnosticTime(
        reportById(bundle, 'bg-refresh').startedAtUtc,
        utcOffset: const Duration(hours: 8),
      ),
      '2026-07-16 19:53:32 UTC+08:00',
    );
    expect(
      success.issues.any((issue) => issue.details.refreshId == 'fg-degraded'),
      isFalse,
    );
    expect(
      bundle.reports.expand((report) => report.issues).any(
          (issue) => issue.category == DiagnosticIssueCategory.coordination),
      isFalse,
    );
  });

  test('识别前台和后台来源以及缺少 finish 的后台任务', () {
    final bundle = parser.parse(buildLatestDiagnosticFixture());
    final background = reportById(bundle, 'bg-refresh');
    final foreground = reportById(bundle, 'fg-degraded');

    expect(background.origin, 'background');
    expect(background.severity, DiagnosticReportSeverity.incomplete);
    expect(background.finishedAtUtc, isNull);
    expect(
      background.issues.single.explanation,
      contains('可能被系统终止，或日志尚未在 isolate 退出前写入完成'),
    );
    expect(foreground.origin, 'foreground');
    expect(bundle.globalTimeline.single.title, 'App 进入前台');
  });

  test('失败优先于降级，降级优先于成功', () {
    final degraded = reportById(
      parser.parse(buildLatestDiagnosticFixture()),
      'fg-degraded',
    );
    expect(degraded.severity, DiagnosticReportSeverity.degraded);
    expect(moduleByName(degraded, '课表').state, DiagnosticModuleState.cache);
    expect(moduleByName(degraded, '主修').state, DiagnosticModuleState.cache);

    final failedLog = [
      diagnosticLine(
        '2026-07-16T12:00:00.000Z',
        refreshId: 'failed',
        source: 'foreground',
        module: 'refresh',
        operation: 'start',
      ),
      diagnosticLine(
        '2026-07-16T12:00:00.100Z',
        refreshId: 'failed',
        source: 'foreground',
        module: '成绩',
        operation: 'result',
        message: '失败：没有可用数据',
      ),
      diagnosticLine(
        '2026-07-16T12:00:00.200Z',
        refreshId: 'failed',
        source: 'foreground',
        module: '课表',
        operation: 'result',
        message: '使用缓存',
      ),
      diagnosticLine(
        '2026-07-16T12:00:00.300Z',
        refreshId: 'failed',
        source: 'foreground',
        module: 'refresh',
        operation: 'finish',
      ),
    ].join('\n');
    expect(parser.parse(failedLog).latestReport!.severity,
        DiagnosticReportSeverity.failed);
  });

  test('顶层异常只记录一个 finish 并保留耗时和堆栈', () async {
    final service = DiagnosticLogService.instance;
    final before = service.currentText();
    String? refreshId;

    await expectLater(
      service.runRefresh<void>(
        origin: RefreshOrigin.foreground,
        action: () async {
          refreshId = service.currentRefreshId;
          throw StateError('top-level-boom');
        },
      ),
      throwsA(isA<StateError>()),
    );

    final current = service.currentText();
    final appended =
        before.isEmpty ? current : current.substring(before.length + 1);
    final ownLines = appended
        .split('\n')
        .where((line) => line.contains('refreshId=$refreshId'))
        .toList();
    final finishes =
        ownLines.where((line) => line.contains('operation=finish')).toList();
    expect(finishes, hasLength(1));
    expect(finishes.single, contains('level=error'));
    expect(finishes.single, contains('durationMs='));
    expect(finishes.single, contains('exceptionType=StateError'));
    expect(finishes.single, contains('stack='));

    final report = parser.parse(ownLines.join('\n')).latestReport!;
    expect(report.severity, DiagnosticReportSeverity.failed);
    expect(diagnosticReportTitle(report), '刷新失败');
    expect(report.durationMs, isNotNull);
    final issue = report.issues.singleWhere(
      (issue) => issue.category == DiagnosticIssueCategory.refreshExecution,
    );
    expect(issue.title, '刷新执行异常');
    expect(issue.details.stack, isNotNull);
    expect(
      report.issues.any(
        (issue) => issue.category == DiagnosticIssueCategory.serverOrNetwork,
      ),
      isFalse,
    );
  });

  test('旧格式 error finish 后跟普通 finish 仍判定顶层失败', () {
    final raw = [
      diagnosticLine(
        '2026-07-16T12:00:00.000Z',
        refreshId: 'legacy-top-error',
        source: 'foreground',
        module: 'refresh',
        operation: 'start',
      ),
      diagnosticLine(
        '2026-07-16T12:00:00.050Z',
        refreshId: 'legacy-top-error',
        source: 'foreground',
        module: 'refresh',
        operation: 'finish',
        level: 'error',
        exceptionType: 'StateError',
        exception: 'Bad state: legacy boom',
        message: '完整刷新异常结束',
        stack: r'#0 Scholar.refresh (scholar.dart:200)\n#1 main',
      ),
      diagnosticLine(
        '2026-07-16T12:00:00.073Z',
        refreshId: 'legacy-top-error',
        source: 'foreground',
        module: 'refresh',
        operation: 'finish',
        durationMs: '73',
        message: '完整刷新结束',
      ),
    ].join('\n');

    final report = parser.parse(raw).latestReport!;
    expect(report.severity, DiagnosticReportSeverity.failed);
    expect(report.durationMs, 73);
    expect(report.timeline.where((event) => event.title == '刷新异常结束'),
        hasLength(1));
    final issue = report.issues.singleWhere(
      (issue) => issue.category == DiagnosticIssueCategory.refreshExecution,
    );
    expect(issue.title, '刷新执行异常');
    expect(issue.details.stack, contains('scholar.dart:200'));
  });

  test('共享调用关联 owner 且不生成未执行模块', () {
    final raw = [
      diagnosticLine(
        '2026-07-16T12:00:01.000Z',
        refreshId: 'shared-caller',
        source: 'foreground',
        module: 'refresh',
        operation: 'start',
      ),
      diagnosticLine(
        '2026-07-16T12:00:01.010Z',
        refreshId: 'shared-caller',
        relatedRefreshId: 'owner-refresh',
        source: 'foreground',
        module: 'refresh',
        operation: 'shareFlight',
      ),
      diagnosticLine(
        '2026-07-16T12:00:01.100Z',
        refreshId: 'shared-caller',
        source: 'foreground',
        module: 'refresh',
        operation: 'finish',
        durationMs: '100',
      ),
    ].join('\n');

    final report = parser.parse(raw).latestReport!;
    expect(report.disposition, DiagnosticRefreshDisposition.shared);
    expect(report.severity, DiagnosticReportSeverity.coordinated);
    expect(report.relatedRefreshId, 'owner-refresh');
    expect(report.modules, isEmpty);
    expect(diagnosticReportTitle(report), '已共享现有刷新');
    expect(diagnosticReportDescription(report), contains('关联任务：owner-refresh'));
  });

  test('共享 Future 异常时共享调用显示失败', () {
    final raw = [
      diagnosticLine(
        '2026-07-16T12:00:02.000Z',
        refreshId: 'shared-failed',
        source: 'foreground',
        module: 'refresh',
        operation: 'start',
      ),
      diagnosticLine(
        '2026-07-16T12:00:02.010Z',
        refreshId: 'shared-failed',
        relatedRefreshId: 'owner-failed',
        source: 'foreground',
        module: 'refresh',
        operation: 'shareFlight',
      ),
      diagnosticLine(
        '2026-07-16T12:00:02.100Z',
        refreshId: 'shared-failed',
        source: 'foreground',
        module: 'refresh',
        operation: 'finish',
        level: 'error',
        durationMs: '100',
        exceptionType: 'StateError',
        exception: 'Bad state: owner failed',
        message: '完整刷新异常结束',
      ),
    ].join('\n');

    final report = parser.parse(raw).latestReport!;
    expect(report.severity, DiagnosticReportSeverity.failed);
    expect(diagnosticReportTitle(report), '共享任务失败');
    expect(report.modules, isEmpty);
    expect(report.issues.any((issue) => issue.title == '共享任务失败'), isTrue);
  });

  test('owner 返回模块失败结果时共享报告继承失败状态', () {
    final raw = [
      diagnosticLine(
        '2026-07-16T12:00:03.000Z',
        refreshId: 'owner-result-failed',
        source: 'foreground',
        module: 'refresh',
        operation: 'start',
      ),
      diagnosticLine(
        '2026-07-16T12:00:03.010Z',
        refreshId: 'shared-result-failed',
        source: 'foreground',
        module: 'refresh',
        operation: 'start',
      ),
      diagnosticLine(
        '2026-07-16T12:00:03.020Z',
        refreshId: 'shared-result-failed',
        relatedRefreshId: 'owner-result-failed',
        source: 'foreground',
        module: 'refresh',
        operation: 'shareFlight',
      ),
      diagnosticLine(
        '2026-07-16T12:00:03.050Z',
        refreshId: 'owner-result-failed',
        source: 'foreground',
        module: '成绩',
        operation: 'result',
        message: '失败：没有可用数据',
      ),
      diagnosticLine(
        '2026-07-16T12:00:03.100Z',
        refreshId: 'owner-result-failed',
        source: 'foreground',
        module: 'refresh',
        operation: 'finish',
      ),
      diagnosticLine(
        '2026-07-16T12:00:03.110Z',
        refreshId: 'shared-result-failed',
        source: 'foreground',
        module: 'refresh',
        operation: 'finish',
      ),
    ].join('\n');

    final shared = reportById(
      parser.parse(raw),
      'shared-result-failed',
    );
    expect(shared.severity, DiagnosticReportSeverity.failed);
    expect(diagnosticReportTitle(shared), '共享任务失败');
    expect(shared.modules, isEmpty);
    expect(shared.issues.any((issue) => issue.title == '共享任务失败'), isTrue);
  });

  test('901 和 922 生成克制的会话说明', () {
    final report = reportById(
      parser.parse(buildLatestDiagnosticFixture()),
      'fg-degraded',
    );
    final sessionIssues = report.issues
        .where((issue) => issue.category == DiagnosticIssueCategory.session)
        .toList();
    expect(sessionIssues, hasLength(2));
    expect(sessionIssues.map((issue) => issue.explanation).join(),
        contains('可能失效或请求被服务端拒绝'));
    expect(sessionIssues.map((issue) => issue.explanation).join(),
        isNot(contains('一定')));
    expect(moduleByName(report, '考试').state, DiagnosticModuleState.liveSuccess);
    expect(moduleByName(report, '考试').relogged, isTrue);
    expect(moduleByName(report, '成绩').state, DiagnosticModuleState.liveSuccess);
    expect(moduleByName(report, '成绩').relogged, isTrue);
  });

  test('_TypeError 翻译为空字段处理问题', () {
    final report = reportById(
      parser.parse(buildLatestDiagnosticFixture()),
      'fg-degraded',
    );
    final issue = report.issues.singleWhere(
      (issue) => issue.category == DiagnosticIssueCategory.appParsing,
    );
    expect(issue.title, 'App 未正确处理空字段');
    expect(issue.details.exceptionType, '_TypeError');
    expect(issue.details.stack, contains('zdbk.dart:373'));
  });

  test('缓存更新时间进入模块报告', () {
    final report = reportById(
      parser.parse(buildLatestDiagnosticFixture()),
      'fg-degraded',
    );
    final timetable = moduleByName(report, '课表');
    expect(timetable.cacheUpdatedAtUtc,
        DateTime.parse('2026-07-16T11:45:00.000Z'));
    expect(timetable.reason, contains('缓存数据'));
  });

  test('未来学年校历 404 是预期回退且不降低成功级别', () {
    final report = reportById(
      parser.parse(buildLatestDiagnosticFixture()),
      'fg-success',
    );
    expect(report.severity, DiagnosticReportSeverity.success);
    expect(moduleByName(report, '校历').state, DiagnosticModuleState.liveSuccess);
    final fallback = report.issues.singleWhere(
      (issue) => issue.category == DiagnosticIssueCategory.expectedFallback,
    );
    expect(fallback.severity, DiagnosticIssueSeverity.info);
  });

  test('后台启动前和登录后让行均显示独立协调状态', () {
    final raw = [
      diagnosticLine(
        '2026-07-16T12:01:00.000Z',
        refreshId: 'yield',
        source: 'background',
        module: 'refresh',
        operation: 'start',
      ),
      diagnosticLine(
        '2026-07-16T12:01:00.010Z',
        refreshId: 'yield',
        source: 'background',
        module: 'refresh',
        operation: 'backgroundYield',
        message: '后台刷新检测到活跃前台，已正常让行',
      ),
      diagnosticLine(
        '2026-07-16T12:01:00.020Z',
        refreshId: 'yield',
        source: 'background',
        module: 'refresh',
        operation: 'finish',
        durationMs: '20',
      ),
      diagnosticLine(
        '2026-07-16T12:01:01.000Z',
        refreshId: 'yield-after-login',
        source: 'background',
        module: 'refresh',
        operation: 'start',
      ),
      diagnosticLine(
        '2026-07-16T12:01:01.010Z',
        refreshId: 'yield-after-login',
        source: 'background',
        module: 'refresh',
        operation: 'backgroundYield',
        message: '后台刷新登录完成后检测到活跃前台，已正常让行',
      ),
      diagnosticLine(
        '2026-07-16T12:01:01.020Z',
        refreshId: 'yield-after-login',
        source: 'background',
        module: 'refresh',
        operation: 'finish',
        durationMs: '20',
      ),
    ].join('\n');
    final reports = parser.parse(raw).reports;
    expect(reports, hasLength(2));
    for (final report in reports) {
      expect(report.severity, DiagnosticReportSeverity.coordinated);
      expect(
          report.disposition, DiagnosticRefreshDisposition.backgroundYielded);
      expect(diagnosticReportTitle(report), '后台已主动让行');
      expect(report.modules, isEmpty);
      expect(report.issues, isEmpty);
      expect(
          report.successCount + report.degradedCount + report.failedCount, 0);
    }
    expect(
      reportById(parser.parse(raw), 'yield-after-login')
          .timeline
          .any((event) => event.title == '后台登录后检测到前台并让行'),
      isTrue,
    );
  });

  test('共享、排队和跨 isolate 锁等待使用不同时间线文案', () {
    final raw = [
      diagnosticLine(
        '2026-07-16T12:01:10.000Z',
        refreshId: 'coordination-copy',
        source: 'foreground',
        module: 'refresh',
        operation: 'start',
      ),
      diagnosticLine(
        '2026-07-16T12:01:10.010Z',
        refreshId: 'coordination-copy',
        relatedRefreshId: 'owner',
        source: 'foreground',
        module: 'refresh',
        operation: 'shareFlight',
      ),
      diagnosticLine(
        '2026-07-16T12:01:10.020Z',
        refreshId: 'coordination-copy',
        source: 'foreground',
        module: 'refresh',
        operation: 'queueOperation',
      ),
      diagnosticLine(
        '2026-07-16T12:01:10.030Z',
        refreshId: 'coordination-copy',
        source: 'foreground',
        module: 'refresh',
        operation: 'lockWait',
      ),
      diagnosticLine(
        '2026-07-16T12:01:10.040Z',
        refreshId: 'coordination-copy',
        source: 'foreground',
        module: 'refresh',
        operation: 'finish',
      ),
    ].join('\n');
    final titles = parser
        .parse(raw)
        .latestReport!
        .timeline
        .map((event) => event.title)
        .toSet();
    expect(titles, contains('共享同账号同操作的刷新 Future'));
    expect(titles, contains('同账号不同操作正在排队'));
    expect(titles, contains('跨 isolate 等待账号文件锁'));
  });

  test('模块耗时使用模块边界或事件跨度并标记估算', () {
    final raw = [
      diagnosticLine(
        '2026-07-16T12:02:10.000Z',
        refreshId: 'module-duration',
        source: 'foreground',
        module: 'refresh',
        operation: 'start',
      ),
      diagnosticLine(
        '2026-07-16T12:02:10.100Z',
        refreshId: 'module-duration',
        source: 'foreground',
        module: '课表接口',
        operation: 'httpResponse',
        status: '200',
        durationMs: '20',
      ),
      diagnosticLine(
        '2026-07-16T12:02:11.500Z',
        refreshId: 'module-duration',
        source: 'foreground',
        module: '课表',
        operation: 'result',
        message: '实时成功',
      ),
      diagnosticLine(
        '2026-07-16T12:02:10.200Z',
        refreshId: 'module-duration',
        source: 'foreground',
        module: '考试',
        operation: 'moduleStart',
      ),
      diagnosticLine(
        '2026-07-16T12:02:11.200Z',
        refreshId: 'module-duration',
        source: 'foreground',
        module: '考试',
        operation: 'moduleFinish',
        durationMs: '1000',
        status: '200',
      ),
      diagnosticLine(
        '2026-07-16T12:02:11.600Z',
        refreshId: 'module-duration',
        source: 'foreground',
        module: 'refresh',
        operation: 'finish',
      ),
    ].join('\n');
    final report = parser.parse(raw).latestReport!;
    final timetable = moduleByName(report, '课表');
    final exam = moduleByName(report, '考试');
    expect(timetable.durationMs, 1400);
    expect(timetable.durationEstimated, isTrue);
    expect(formatModuleDuration(timetable), '耗时约 1.4 秒');
    expect(exam.durationMs, 1000);
    expect(exam.durationEstimated, isFalse);
    expect(formatModuleDuration(exam), '耗时1.0 秒');
  });

  test('旧 busyResult 被标记为刷新协调异常', () {
    final raw = [
      diagnosticLine(
        '2026-07-16T12:02:00.000Z',
        refreshId: 'busy',
        source: 'foreground',
        module: 'refresh',
        operation: 'start',
      ),
      diagnosticLine(
        '2026-07-16T12:02:00.010Z',
        refreshId: 'busy',
        source: 'foreground',
        module: '刷新聚合',
        operation: 'moduleResult',
        message: '刷新：同一账号已有刷新任务，本次已跳过',
      ),
      diagnosticLine(
        '2026-07-16T12:02:00.020Z',
        refreshId: 'busy',
        source: 'foreground',
        module: 'refresh',
        operation: 'finish',
      ),
    ].join('\n');
    final report = parser.parse(raw).latestReport!;
    expect(report.severity, DiagnosticReportSeverity.failed);
    expect(report.issues.single.title, '刷新协调异常');
  });

  test('易读报告不会暴露结构化隐私字段', () {
    final raw = [
      diagnosticLine(
        '2026-07-16T12:03:00.000Z',
        refreshId: 'privacy',
        source: 'foreground',
        module: '成绩',
        operation: 'exception',
        exceptionType: '_TypeError',
        exception:
            r'{"studentName":"Private Person","studentId":"1234567890","score":99}',
      ),
    ].join('\n');
    final report = parser.parse(raw).latestReport!;
    final technical = report.issues.single.details.exceptionSummary!;
    expect(technical, isNot(contains('Private Person')));
    expect(technical, isNot(contains('1234567890')));
    expect(technical, isNot(contains('99')));
    expect(technical, contains('<已隐藏>'));
  });

  test('空日志、损坏日志和缺失字段安全降级', () {
    expect(parser.parse('').reports, isEmpty);
    final damaged = parser.parse(
      '2026-07-16T12:00:00Z | refreshId=broken\nnot a log line',
    );
    expect(damaged.reports, isEmpty);
    expect(damaged.damagedLineCount, 1);
  });

  test('接近真实导出格式的多行日志可解析且保留转义堆栈', () {
    final bundle = parser.parse(buildComprehensiveDiagnosticExportFixture());
    expect(bundle.reports, isNotEmpty);
    expect(
      bundle.reports.expand((report) => report.issues).any(
            (issue) => issue.details.stack?.contains(r'\n') ?? false,
          ),
      isTrue,
    );
    expect(
      bundle.reports.expand((report) => report.issues).where(
            (issue) => issue.category == DiagnosticIssueCategory.session,
          ),
      hasLength(2),
    );
    expect(reportById(bundle, 'shared-caller').relatedRefreshId, 'fg-success');
  });

  test('导出按易读报告到完整原始日志排序并保留原文', () {
    final raw = buildLatestDiagnosticFixture();
    final export = formatDiagnosticExport(
      bundle: parser.parse(raw),
      rawLog: raw,
      version: '1.2.0',
      buildNumber: '1',
      platform: 'android',
      exportedAt: DateTime.parse('2026-07-16T12:10:00Z'),
      utcOffset: const Duration(hours: 8),
    );
    expect(export, contains('本地导出时间：2026-07-16 20:10:00 UTC+08:00'));
    expect(export, contains('UTC 导出时间：2026-07-16T12:10:00.000Z'));
    expect(export.indexOf('=== 1. 易读诊断报告 ==='),
        lessThan(export.indexOf('=== 5. 完整原始日志（UTC） ===')));
    expect(export, endsWith(raw));
  });
}
