import 'diagnostic_sanitizer.dart';

enum DiagnosticReportSeverity { success, degraded, failed, incomplete }

enum DiagnosticModuleState { liveSuccess, cache, failed, notExecuted }

enum DiagnosticIssueCategory {
  serverOrNetwork,
  session,
  cache,
  appParsing,
  coordination,
  expectedFallback,
  incompleteLog,
}

enum DiagnosticIssueSeverity { info, warning, error }

class DiagnosticTechnicalDetails {
  final String refreshId;
  final DateTime timestampUtc;
  final int? statusCode;
  final String interfaceName;
  final String? url;
  final String? exceptionType;
  final String? exceptionSummary;
  final String? stack;

  const DiagnosticTechnicalDetails({
    required this.refreshId,
    required this.timestampUtc,
    required this.interfaceName,
    this.statusCode,
    this.url,
    this.exceptionType,
    this.exceptionSummary,
    this.stack,
  });
}

class DiagnosticIssue {
  final String id;
  final DiagnosticIssueCategory category;
  final DiagnosticIssueSeverity severity;
  final String title;
  final String explanation;
  final DiagnosticTechnicalDetails details;

  const DiagnosticIssue({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.explanation,
    required this.details,
  });
}

class DiagnosticTimelineEvent {
  final String id;
  final String? refreshId;
  final DateTime timestampUtc;
  final String title;
  final String? description;

  const DiagnosticTimelineEvent({
    required this.id,
    required this.refreshId,
    required this.timestampUtc,
    required this.title,
    this.description,
  });
}

class DiagnosticModuleReport {
  final String name;
  final DiagnosticModuleState state;
  final int? durationMs;
  final bool relogged;
  final bool retried;
  final DateTime? cacheUpdatedAtUtc;
  final String? cacheUpdatedText;
  final String reason;

  const DiagnosticModuleReport({
    required this.name,
    required this.state,
    required this.relogged,
    required this.retried,
    required this.reason,
    this.durationMs,
    this.cacheUpdatedAtUtc,
    this.cacheUpdatedText,
  });
}

class DiagnosticRefreshReport {
  final String refreshId;
  final String origin;
  final DateTime startedAtUtc;
  final DateTime? finishedAtUtc;
  final int? durationMs;
  final DiagnosticReportSeverity severity;
  final List<DiagnosticModuleReport> modules;
  final List<DiagnosticTimelineEvent> timeline;
  final List<DiagnosticIssue> issues;
  final bool relogged;
  final bool retried;
  final bool cacheUsed;

  const DiagnosticRefreshReport({
    required this.refreshId,
    required this.origin,
    required this.startedAtUtc,
    required this.finishedAtUtc,
    required this.durationMs,
    required this.severity,
    required this.modules,
    required this.timeline,
    required this.issues,
    required this.relogged,
    required this.retried,
    required this.cacheUsed,
  });

  int get successCount => modules
      .where((module) => module.state == DiagnosticModuleState.liveSuccess)
      .length;

  int get degradedCount => modules
      .where((module) => module.state == DiagnosticModuleState.cache)
      .length;

  int get failedCount => modules
      .where((module) => module.state == DiagnosticModuleState.failed)
      .length;
}

class DiagnosticReportBundle {
  final List<DiagnosticRefreshReport> reports;
  final List<DiagnosticTimelineEvent> globalTimeline;
  final int damagedLineCount;

  const DiagnosticReportBundle({
    required this.reports,
    required this.globalTimeline,
    required this.damagedLineCount,
  });

  static const empty = DiagnosticReportBundle(
    reports: [],
    globalTimeline: [],
    damagedLineCount: 0,
  );

  DiagnosticRefreshReport? get latestReport =>
      reports.isEmpty ? null : reports.first;
}

class DiagnosticLogEntry {
  final DateTime timestampUtc;
  final Map<String, String> fields;

  const DiagnosticLogEntry(this.timestampUtc, this.fields);

  String get refreshId => fields['refreshId'] ?? '-';
  String get source => fields['source'] ?? 'foreground';
  String get level => fields['level'] ?? 'info';
  String get module => fields['module'] ?? '未知模块';
  String get operation => fields['operation'] ?? 'unknown';
  String get message => fields['message'] ?? '';
  String get exceptionType => fields['exceptionType'] ?? '-';
  String get exception => fields['exception'] ?? '-';
  String get stack => fields['stack'] ?? '-';
  String get url => fields['url'] ?? '-';
  bool get relogged => fields['relogged'] == 'true';
  bool get retried => fields['retried'] == 'true';
  bool get cacheUsed => fields['cacheUsed'] == 'true';
  int? get statusCode => int.tryParse(fields['status'] ?? '');
  int? get durationMs => int.tryParse(fields['durationMs'] ?? '');

  static DiagnosticLogEntry? tryParse(String line) {
    final firstSeparator = line.indexOf(' | ');
    if (firstSeparator <= 0) return null;
    final timestamp = DateTime.tryParse(line.substring(0, firstSeparator));
    if (timestamp == null) return null;

    final fieldText = line.substring(firstSeparator + 3);
    final matches = RegExp(r'(?:^| \| )([A-Za-z][A-Za-z0-9]*)=')
        .allMatches(fieldText)
        .toList();
    if (matches.isEmpty) return null;
    final fields = <String, String>{};
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final key = match.group(1)!;
      final end = index + 1 < matches.length
          ? matches[index + 1].start
          : fieldText.length;
      fields[key] = sanitizeDiagnosticText(
        fieldText.substring(match.end, end).trim(),
      );
    }
    if (!fields.containsKey('refreshId') || !fields.containsKey('operation')) {
      return null;
    }
    return DiagnosticLogEntry(timestamp.toUtc(), fields);
  }
}

class DiagnosticReportParser {
  static const moduleOrder = <String>[
    '校历',
    '课表',
    '考试',
    '成绩',
    '主修',
    '作业',
    '实践/素质拓展',
  ];

  const DiagnosticReportParser();

  DiagnosticReportBundle parse(String rawText) {
    if (rawText.trim().isEmpty) return DiagnosticReportBundle.empty;
    final entries = <DiagnosticLogEntry>[];
    var damaged = 0;
    for (final line in rawText.split(RegExp(r'\r?\n'))) {
      if (line.trim().isEmpty) continue;
      final parsed = DiagnosticLogEntry.tryParse(line);
      if (parsed == null) {
        if (line.contains(' | refreshId=') ||
            RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(line)) {
          damaged++;
        }
        continue;
      }
      entries.add(parsed);
    }
    entries.sort((a, b) => a.timestampUtc.compareTo(b.timestampUtc));

    final grouped = <String, List<DiagnosticLogEntry>>{};
    final globalEntries = <DiagnosticLogEntry>[];
    for (final entry in entries) {
      if (entry.refreshId == '-' || entry.refreshId.isEmpty) {
        globalEntries.add(entry);
      } else {
        grouped.putIfAbsent(entry.refreshId, () => []).add(entry);
      }
    }

    final reports = grouped.entries
        .map((entry) => _buildReport(entry.key, entry.value))
        .toList()
      ..sort((a, b) => b.startedAtUtc.compareTo(a.startedAtUtc));
    final globalTimeline = _buildTimeline(globalEntries, refreshId: null);
    return DiagnosticReportBundle(
      reports: reports,
      globalTimeline: globalTimeline,
      damagedLineCount: damaged,
    );
  }

  DiagnosticRefreshReport _buildReport(
    String refreshId,
    List<DiagnosticLogEntry> entries,
  ) {
    final startEntries = entries
        .where(
            (entry) => entry.module == 'refresh' && entry.operation == 'start')
        .toList();
    final finishEntries = entries
        .where(
            (entry) => entry.module == 'refresh' && entry.operation == 'finish')
        .toList();
    final startedAt = startEntries.isNotEmpty
        ? startEntries.first.timestampUtc
        : entries.first.timestampUtc;
    final finishedAt =
        finishEntries.isEmpty ? null : finishEntries.last.timestampUtc;
    final duration = finishEntries
            .map((entry) => entry.durationMs)
            .whereType<int>()
            .lastOrNull ??
        finishedAt?.difference(startedAt).inMilliseconds;
    final origin = startEntries.isNotEmpty
        ? startEntries.first.source
        : entries.first.source;

    final moduleBuilders = <String, _ModuleBuilder>{};
    for (final entry in entries) {
      final canonical = _canonicalModule(entry.module, entry.message);
      if (canonical == null) continue;
      moduleBuilders
          .putIfAbsent(canonical, () => _ModuleBuilder(canonical))
          .add(entry,
              expectedFallback: _isExpectedCalendarFallback(entry, entries));
    }
    final modules = moduleOrder
        .map((name) =>
            moduleBuilders[name]?.build() ??
            DiagnosticModuleReport(
              name: name,
              state: DiagnosticModuleState.notExecuted,
              relogged: false,
              retried: false,
              reason: '本次日志中没有该模块的执行记录。',
            ))
        .toList();

    final issues = _buildIssues(refreshId, entries, modules);
    if (startEntries.isNotEmpty && finishEntries.isEmpty) {
      final entry = startEntries.first;
      issues.add(DiagnosticIssue(
        id: '$refreshId-incomplete',
        category: DiagnosticIssueCategory.incompleteLog,
        severity: DiagnosticIssueSeverity.warning,
        title: '没有记录到刷新结束事件',
        explanation: origin == 'background'
            ? '该后台任务没有记录到结束事件，可能被系统终止，或日志尚未在 isolate 退出前写入完成。'
            : '该刷新没有记录到结束事件，可能尚未完成、被终止，或日志写入不完整。',
        details: _details(refreshId, entry),
      ));
    }

    DiagnosticReportSeverity severity;
    if (startEntries.isNotEmpty && finishEntries.isEmpty) {
      severity = DiagnosticReportSeverity.incomplete;
    } else if (modules
            .any((module) => module.state == DiagnosticModuleState.failed) ||
        issues.any((issue) =>
            issue.category == DiagnosticIssueCategory.coordination &&
            issue.severity == DiagnosticIssueSeverity.error)) {
      severity = DiagnosticReportSeverity.failed;
    } else if (modules
        .any((module) => module.state == DiagnosticModuleState.cache)) {
      severity = DiagnosticReportSeverity.degraded;
    } else {
      severity = DiagnosticReportSeverity.success;
    }

    return DiagnosticRefreshReport(
      refreshId: refreshId,
      origin: origin,
      startedAtUtc: startedAt,
      finishedAtUtc: finishedAt,
      durationMs: duration,
      severity: severity,
      modules: modules,
      timeline: _buildTimeline(entries, refreshId: refreshId),
      issues: issues,
      relogged: entries.any((entry) => entry.relogged),
      retried: entries.any((entry) => entry.retried),
      cacheUsed: entries.any((entry) => entry.cacheUsed) ||
          modules.any((module) => module.state == DiagnosticModuleState.cache),
    );
  }

  List<DiagnosticTimelineEvent> _buildTimeline(
    List<DiagnosticLogEntry> entries, {
    required String? refreshId,
  }) {
    final events = <DiagnosticTimelineEvent>[];
    final seen = <String>{};
    void add(DiagnosticLogEntry entry, String type, String title,
        [String? description]) {
      final key = '$type-${entry.module}-${entry.operation}';
      if (!seen.add(key)) return;
      events.add(DiagnosticTimelineEvent(
        id: '${refreshId ?? 'global'}-${entry.timestampUtc.microsecondsSinceEpoch}-$type',
        refreshId: refreshId,
        timestampUtc: entry.timestampUtc,
        title: title,
        description: description,
      ));
    }

    for (final entry in entries) {
      if (entry.module == 'refresh' && entry.operation == 'start') {
        add(entry, 'start', entry.source == 'background' ? '后台任务开始' : '前台刷新开始');
      } else if (entry.module == 'refresh' && entry.operation == 'finish') {
        add(
            entry,
            'finish',
            '刷新结束',
            entry.durationMs == null
                ? null
                : '总耗时 ${formatDuration(entry.durationMs)}');
      } else {
        switch (entry.operation) {
          case 'foregroundActive':
            add(entry, 'foregroundActive', 'App 进入前台');
          case 'lockWait':
            add(entry, 'lockWait', '等待同账号刷新锁');
          case 'shareFlight':
            add(entry, 'shareFlight', '共享正在执行的刷新任务');
          case 'backgroundYield':
            add(entry, 'backgroundYield', '后台因前台刷新主动让行');
          case 'staleLockRemoved':
            add(entry, 'staleLockRemoved', '发现并清理遗留刷新锁');
          case 'lockAcquired':
            add(entry, 'lockAcquired', '已获取同账号刷新锁');
          case 'lockReleased':
            add(entry, 'lockReleased', '已释放同账号刷新锁');
          case 'readCache':
          case 'readCacheItem':
            add(entry, 'cache-${_canonicalModule(entry.module, entry.message)}',
                '${_canonicalModule(entry.module, entry.message) ?? entry.module}使用缓存');
        }
      }
      if (entry.relogged) {
        add(entry, 'relogin', '重新登录后继续请求');
      }
      if (entry.retried) {
        add(entry, 'retry', '失败请求已重试');
      }
    }
    events.sort((a, b) => a.timestampUtc.compareTo(b.timestampUtc));
    return events;
  }

  List<DiagnosticIssue> _buildIssues(
    String refreshId,
    List<DiagnosticLogEntry> entries,
    List<DiagnosticModuleReport> modules,
  ) {
    final issues = <DiagnosticIssue>[];
    final seen = <String>{};
    void add(
      DiagnosticLogEntry entry,
      String key,
      DiagnosticIssueCategory category,
      DiagnosticIssueSeverity severity,
      String title,
      String explanation,
    ) {
      if (!seen.add(key)) return;
      issues.add(DiagnosticIssue(
        id: '$refreshId-$key',
        category: category,
        severity: severity,
        title: title,
        explanation: explanation,
        details: _details(refreshId, entry),
      ));
    }

    for (final entry in entries) {
      final text = '${entry.message} ${entry.exception} ${entry.stack}';
      final expectedFallback = _isExpectedCalendarFallback(entry, entries);
      if (expectedFallback) {
        add(
          entry,
          'expected-calendar-fallback',
          DiagnosticIssueCategory.expectedFallback,
          DiagnosticIssueSeverity.info,
          '未来学年校历使用预期回退',
          '未来学年配置尚未发布，App 已使用默认配置；这不会被视为严重故障。',
        );
        continue;
      }
      if (entry.statusCode == 901 || entry.statusCode == 922) {
        final status = entry.statusCode!;
        add(
          entry,
          'session-$status-${_canonicalModule(entry.module, entry.message) ?? entry.module}',
          DiagnosticIssueCategory.session,
          DiagnosticIssueSeverity.warning,
          '教务网会话可能失效',
          '教务网会话可能失效或请求被服务端拒绝，本次请求返回 $status。',
        );
      } else if (entry.statusCode != null && entry.statusCode! >= 400) {
        add(
          entry,
          'http-${entry.statusCode}-${entry.module}',
          DiagnosticIssueCategory.serverOrNetwork,
          DiagnosticIssueSeverity.warning,
          '服务端请求未成功',
          '服务端返回 HTTP ${entry.statusCode}，请稍后重试或查看技术详情。',
        );
      }
      if (entry.exceptionType.contains('TypeError') ||
          text.contains('Null check operator used on a null value')) {
        add(
          entry,
          'type-error-${_canonicalModule(entry.module, entry.message) ?? entry.module}',
          DiagnosticIssueCategory.appParsing,
          DiagnosticIssueSeverity.error,
          'App 未正确处理空字段',
          'App 未正确处理接口中的空字段；如果有缓存，旧数据仍会保留。',
        );
      } else if (entry.exceptionType.contains('Socket') ||
          entry.exceptionType.contains('Timeout') ||
          text.toLowerCase().contains('connection closed')) {
        add(
          entry,
          'network-${entry.module}',
          DiagnosticIssueCategory.serverOrNetwork,
          DiagnosticIssueSeverity.warning,
          '网络请求未完成',
          '网络连接中断或请求超时，App 可能已重试或使用缓存。',
        );
      }
      if (text.contains('同一账号已有刷新任务') && text.contains('已跳过')) {
        add(
          entry,
          'legacy-busy-result',
          DiagnosticIssueCategory.coordination,
          DiagnosticIssueSeverity.error,
          '刷新协调异常',
          '检测到旧版“已有刷新任务并跳过”结果；正常情况下调用者应共享或等待现有任务。',
        );
      }
    }

    for (final module in modules.where(
      (module) => module.state == DiagnosticModuleState.cache,
    )) {
      final source = entries.lastWhere(
        (entry) => _canonicalModule(entry.module, entry.message) == module.name,
        orElse: () => entries.first,
      );
      add(
        source,
        'cache-${module.name}',
        DiagnosticIssueCategory.cache,
        DiagnosticIssueSeverity.warning,
        '${module.name}使用缓存',
        module.reason,
      );
    }
    return issues;
  }

  static bool _isExpectedCalendarFallback(
    DiagnosticLogEntry entry,
    List<DiagnosticLogEntry> entries,
  ) {
    if (entry.statusCode != 404 ||
        _canonicalModule(entry.module, entry.message) != '校历') {
      return false;
    }
    final ownText = '${entry.module} ${entry.operation} ${entry.message}';
    if (ownText.contains('未来') ||
        ownText.contains('futureProbe') ||
        ownText.contains('默认') ||
        ownText.contains('回退')) {
      return true;
    }
    return entries.any((other) =>
        other.operation == 'futureProbe' &&
        _canonicalModule(other.module, other.message) == '校历' &&
        other.timestampUtc.difference(entry.timestampUtc).abs() <
            const Duration(seconds: 5));
  }

  static String? _canonicalModule(String module, String message) {
    final text = '$module $message';
    if (text.contains('主修')) return '主修';
    if (text.contains('课表')) return '课表';
    if (text.contains('考试')) return '考试';
    if (text.contains('成绩') || text.contains('成绩单')) return '成绩';
    if (text.contains('作业') || text.contains('DDL')) return '作业';
    if (text.contains('实践') || text.contains('素质拓展')) return '实践/素质拓展';
    if (text.contains('校历')) return '校历';
    return null;
  }

  static DiagnosticTechnicalDetails _details(
    String refreshId,
    DiagnosticLogEntry entry,
  ) {
    String? present(String value) =>
        value == '-' || value.isEmpty ? null : value;
    return DiagnosticTechnicalDetails(
      refreshId: sanitizeDiagnosticText(refreshId),
      timestampUtc: entry.timestampUtc,
      statusCode: entry.statusCode,
      interfaceName: sanitizeDiagnosticText(entry.module),
      url: present(entry.url),
      exceptionType: present(entry.exceptionType),
      exceptionSummary: present(entry.exception),
      stack: present(entry.stack),
    );
  }
}

class _ModuleBuilder {
  final String name;
  final List<DiagnosticModuleState> terminalStates = [];
  DateTime? firstAt;
  DateTime? lastAt;
  int? recordedDurationMs;
  bool relogged = false;
  bool retried = false;
  bool cacheUsed = false;
  bool observedSuccess = false;
  bool observedFailure = false;
  DateTime? cacheUpdatedAtUtc;
  String? cacheUpdatedText;
  final Set<int> statuses = {};
  bool appParsingError = false;

  _ModuleBuilder(this.name);

  void add(DiagnosticLogEntry entry, {required bool expectedFallback}) {
    firstAt ??= entry.timestampUtc;
    lastAt = entry.timestampUtc;
    if (entry.durationMs != null &&
        (recordedDurationMs == null ||
            entry.durationMs! > recordedDurationMs!)) {
      recordedDurationMs = entry.durationMs;
    }
    relogged |= entry.relogged;
    retried |= entry.retried;
    if (entry.statusCode != null) statuses.add(entry.statusCode!);
    appParsingError |= entry.exceptionType.contains('TypeError') ||
        entry.exception.contains('Null check operator used on a null value') ||
        entry.stack.contains('Null check operator used on a null value');
    final text = '${entry.message} ${entry.exception}';
    final isCache = entry.cacheUsed ||
        entry.operation == 'readCache' ||
        entry.operation == 'readCacheItem' ||
        text.contains('使用缓存') ||
        text.contains('缓存数据');
    cacheUsed |= isCache;
    if (isCache) _readCacheTime(entry.message);

    if (entry.operation == 'result') {
      if (text.contains('使用缓存') || text.contains('缓存')) {
        terminalStates.add(DiagnosticModuleState.cache);
      } else if (text.contains('失败') || text.contains('查询出错')) {
        terminalStates.add(DiagnosticModuleState.failed);
      } else if (text.contains('成功')) {
        terminalStates.add(DiagnosticModuleState.liveSuccess);
      }
    }
    if (!expectedFallback &&
        ((entry.statusCode != null && entry.statusCode! >= 400) ||
            (entry.exceptionType != '-' && entry.exceptionType.isNotEmpty))) {
      observedFailure = true;
    }
    if (entry.statusCode != null &&
        entry.statusCode! >= 200 &&
        entry.statusCode! < 300) {
      observedSuccess = true;
    }
  }

  void _readCacheTime(String text) {
    final match = RegExp(r'缓存时间\s*[=：:]\s*([^;；|\\n]+)').firstMatch(text);
    if (match == null) return;
    final value = sanitizeDiagnosticText(match.group(1)!.trim());
    cacheUpdatedText = value;
    cacheUpdatedAtUtc = DateTime.tryParse(value)?.toUtc();
  }

  DiagnosticModuleReport build() {
    DiagnosticModuleState state;
    if (terminalStates.contains(DiagnosticModuleState.failed)) {
      state = DiagnosticModuleState.failed;
    } else if (terminalStates.contains(DiagnosticModuleState.cache) ||
        cacheUsed) {
      state = DiagnosticModuleState.cache;
    } else if (terminalStates.contains(DiagnosticModuleState.liveSuccess) ||
        observedSuccess) {
      state = DiagnosticModuleState.liveSuccess;
    } else if (observedFailure) {
      state = DiagnosticModuleState.failed;
    } else {
      state = DiagnosticModuleState.notExecuted;
    }
    final duration = recordedDurationMs ??
        (firstAt != null && lastAt != null && lastAt != firstAt
            ? lastAt!.difference(firstAt!).inMilliseconds
            : null);
    return DiagnosticModuleReport(
      name: name,
      state: state,
      durationMs: duration,
      relogged: relogged,
      retried: retried,
      cacheUpdatedAtUtc: cacheUpdatedAtUtc,
      cacheUpdatedText: cacheUpdatedText,
      reason: _reason(state),
    );
  }

  String _reason(DiagnosticModuleState state) {
    final sessionStatuses = statuses
        .where((status) => status == 901 || status == 922)
        .toList()
      ..sort();
    switch (state) {
      case DiagnosticModuleState.liveSuccess:
        if (relogged && retried) return '重新登录并重试后，已实时获取成功。';
        if (relogged) return '重新登录后，已实时获取成功。';
        if (retried) return '重试后，已实时获取成功。';
        return '已从服务端实时获取最新数据。';
      case DiagnosticModuleState.cache:
        final cacheText = cacheUpdatedAtUtc != null
            ? formatLocalDiagnosticTime(cacheUpdatedAtUtc!)
            : cacheUpdatedText == null
                ? '已有'
                : sanitizeDiagnosticText(cacheUpdatedText!);
        if (sessionStatuses.isNotEmpty) {
          return '教务网会话可能已失效或请求被服务端拒绝，实时请求返回 '
              '${sessionStatuses.join('/')}，本次保留了 $cacheText 的缓存数据。';
        }
        if (appParsingError) {
          return 'App 未正确处理接口中的空字段，本次保留了 $cacheText 的缓存数据。';
        }
        return '实时请求未成功，本次保留了 $cacheText 的缓存数据。';
      case DiagnosticModuleState.failed:
        if (sessionStatuses.isNotEmpty) {
          return '教务网会话可能已失效或请求被服务端拒绝，且没有可用缓存。';
        }
        if (appParsingError) return 'App 未正确处理接口中的空字段。';
        return '该模块没有取得可用的实时数据或缓存。';
      case DiagnosticModuleState.notExecuted:
        return '本次日志中没有该模块的执行记录。';
    }
  }
}

extension _IterableLastOrNull<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}

String diagnosticSeverityLabel(DiagnosticReportSeverity severity) {
  switch (severity) {
    case DiagnosticReportSeverity.success:
      return '刷新成功';
    case DiagnosticReportSeverity.degraded:
      return '部分降级';
    case DiagnosticReportSeverity.failed:
      return '刷新失败';
    case DiagnosticReportSeverity.incomplete:
      return '记录不完整';
  }
}

String diagnosticModuleStateLabel(DiagnosticModuleState state) {
  switch (state) {
    case DiagnosticModuleState.liveSuccess:
      return '实时成功';
    case DiagnosticModuleState.cache:
      return '使用缓存';
    case DiagnosticModuleState.failed:
      return '失败';
    case DiagnosticModuleState.notExecuted:
      return '未执行';
  }
}

String diagnosticOriginLabel(String origin) =>
    origin == 'background' ? '后台刷新' : '前台刷新';

String diagnosticIssueCategoryLabel(DiagnosticIssueCategory category) {
  switch (category) {
    case DiagnosticIssueCategory.serverOrNetwork:
      return '服务端或网络问题';
    case DiagnosticIssueCategory.session:
      return '会话失效';
    case DiagnosticIssueCategory.cache:
      return '使用缓存';
    case DiagnosticIssueCategory.appParsing:
      return 'App 解析异常';
    case DiagnosticIssueCategory.coordination:
      return '刷新协调问题';
    case DiagnosticIssueCategory.expectedFallback:
      return '预期回退';
    case DiagnosticIssueCategory.incompleteLog:
      return '日志不完整';
  }
}

String formatDuration(int? durationMs) {
  if (durationMs == null) return '未知';
  if (durationMs < 1000) return '${durationMs}ms';
  return '${(durationMs / 1000).toStringAsFixed(1)} 秒';
}

String formatLocalDiagnosticTime(DateTime utc, {Duration? utcOffset}) {
  final normalized = utc.toUtc();
  final offset = utcOffset ?? normalized.toLocal().timeZoneOffset;
  final local = normalized.add(offset);
  return '${_four(local.year)}-${_two(local.month)}-${_two(local.day)} '
      '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)} '
      '${formatUtcOffset(offset)}';
}

String formatUtcDiagnosticTime(DateTime utc) => utc.toUtc().toIso8601String();

String formatUtcOffset(Duration offset) {
  final negative = offset.isNegative;
  final minutes = offset.inMinutes.abs();
  return 'UTC${negative ? '-' : '+'}${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
String _four(int value) => value.toString().padLeft(4, '0');

String formatDiagnosticExport({
  required DiagnosticReportBundle bundle,
  required String rawLog,
  required String version,
  required String buildNumber,
  required String platform,
  DateTime? exportedAt,
  Duration? utcOffset,
}) {
  final now = (exportedAt ?? DateTime.now()).toUtc();
  final offset = utcOffset ?? now.toLocal().timeZoneOffset;
  final latest = bundle.latestReport;
  final buffer = StringBuffer()
    ..writeln('Celechron 诊断日志')
    ..writeln('本地导出时间：${formatLocalDiagnosticTime(now, utcOffset: offset)}')
    ..writeln('UTC 导出时间：${formatUtcDiagnosticTime(now)}')
    ..writeln('App 版本：$version+$buildNumber')
    ..writeln('平台：${sanitizeDiagnosticText(platform)}')
    ..writeln('refreshId：${latest?.refreshId ?? '-'}')
    ..writeln(
        '来源：${latest == null ? '-' : diagnosticOriginLabel(latest.origin)}')
    ..writeln()
    ..writeln('=== 1. 易读诊断报告 ===');

  if (bundle.reports.isEmpty) {
    buffer.writeln('暂无可解析的刷新记录。');
  } else {
    for (final report in bundle.reports) {
      buffer
        ..writeln()
        ..writeln(
            '${formatLocalDiagnosticTime(report.startedAtUtc, utcOffset: offset)} '
            '${diagnosticOriginLabel(report.origin)} · ${diagnosticSeverityLabel(report.severity)}')
        ..writeln('refreshId：${report.refreshId}')
        ..writeln('总耗时：${formatDuration(report.durationMs)}')
        ..writeln('模块：成功 ${report.successCount} / 降级 ${report.degradedCount} / '
            '失败 ${report.failedCount}')
        ..writeln('重新登录：${report.relogged ? '是' : '否'}；'
            '重试：${report.retried ? '是' : '否'}；'
            '缓存回退：${report.cacheUsed ? '是' : '否'}');
    }
  }

  buffer.writeln('\n=== 2. 模块结果 ===');
  for (final report in bundle.reports) {
    buffer.writeln('\n[${report.refreshId}]');
    for (final module in report.modules) {
      buffer
          .writeln('${module.name}：${diagnosticModuleStateLabel(module.state)}；'
              '耗时=${formatDuration(module.durationMs)}；${module.reason}');
    }
  }

  buffer.writeln('\n=== 3. 关键时间线 ===');
  final timeline = <DiagnosticTimelineEvent>[
    ...bundle.globalTimeline,
    for (final report in bundle.reports) ...report.timeline,
  ]..sort((a, b) => a.timestampUtc.compareTo(b.timestampUtc));
  if (timeline.isEmpty) buffer.writeln('无关键时间线事件。');
  for (final event in timeline) {
    buffer.writeln(
        '${formatLocalDiagnosticTime(event.timestampUtc, utcOffset: offset)} '
        '${event.title}${event.description == null ? '' : '：${event.description}'} '
        '[refreshId=${event.refreshId ?? '-'}]');
  }

  buffer.writeln('\n=== 4. 发现的问题 ===');
  final issues = [for (final report in bundle.reports) ...report.issues];
  if (issues.isEmpty) buffer.writeln('未发现需要说明的问题。');
  for (final issue in issues) {
    buffer
      ..writeln(
          '${diagnosticIssueCategoryLabel(issue.category)}：${issue.title}')
      ..writeln(issue.explanation)
      ..writeln('  refreshId=${issue.details.refreshId}；'
          'UTC=${formatUtcDiagnosticTime(issue.details.timestampUtc)}；'
          'HTTP=${issue.details.statusCode ?? '-'}；'
          '接口=${issue.details.interfaceName}；'
          'URL=${issue.details.url ?? '-'}；'
          '异常=${issue.details.exceptionType ?? '-'}；'
          '摘要=${issue.details.exceptionSummary ?? '-'}；'
          '堆栈=${issue.details.stack ?? '-'}');
  }

  buffer
    ..writeln('\n=== 5. 完整原始日志（UTC） ===')
    ..writeln('以下时间保持 ISO 8601 UTC；与上方本地时间存在时区偏移是正常的。')
    ..write(rawLog);
  return buffer.toString();
}
