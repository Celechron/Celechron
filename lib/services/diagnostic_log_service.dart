import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum CelechronLogLevel { debug, info, warning, error }

enum RefreshOrigin { foreground, background, probe }

/// 一次完整刷新的关联上下文，通过 Zone 传递给并行模块。
class RefreshDiagnosticContext {
  final String refreshId;
  final RefreshOrigin origin;
  final DateTime startedAt;
  final Map<String, String> moduleResults = {};
  int? durationMs;

  RefreshDiagnosticContext({
    required this.refreshId,
    required this.origin,
    required this.startedAt,
  });
}

/// 统一收集、脱敏并串行落盘诊断信息，避免并发写入互相覆盖。
class DiagnosticLogService {
  static const _contextKey = #celechronRefreshDiagnosticContext;
  static const _maxMemoryLines = 2000;
  static const _maxExportFiles = 10;
  static const _bufferFileName = 'celechron-diagnostic-buffer.log';

  static final DiagnosticLogService instance = DiagnosticLogService._();

  final List<String> _memoryLines = [];
  Future<void> _fileQueue = Future<void>.value();
  RefreshDiagnosticContext? _lastRefreshContext;

  DiagnosticLogService._();

  RefreshDiagnosticContext? get currentContext =>
      Zone.current[_contextKey] as RefreshDiagnosticContext?;

  RefreshDiagnosticContext? get latestContext =>
      currentContext ?? _lastRefreshContext;

  String? get currentRefreshId => latestContext?.refreshId;

  Map<String, String> get latestModuleResults =>
      Map.unmodifiable(latestContext?.moduleResults ?? const {});

  RefreshOrigin get currentOrigin =>
      currentContext?.origin ?? RefreshOrigin.foreground;

  static String createRefreshId() {
    final now = DateTime.now().toUtc();
    return '${now.microsecondsSinceEpoch.toRadixString(36)}-'
        '${now.hashCode.abs().toRadixString(36)}';
  }

  Future<T> runRefresh<T>({
    required RefreshOrigin origin,
    required Future<T> Function() action,
  }) async {
    // Zone 让异步子任务无需显式传参也能使用同一个 refreshId。
    final context = RefreshDiagnosticContext(
      refreshId: createRefreshId(),
      origin: origin,
      startedAt: DateTime.now(),
    );
    return runZoned(
      () async {
        record(
          module: 'refresh',
          operation: 'start',
          message: '完整刷新开始',
        );
        try {
          return await action();
        } on Object catch (error, stackTrace) {
          record(
            level: CelechronLogLevel.error,
            module: 'refresh',
            operation: 'finish',
            message: '完整刷新异常结束',
            error: error,
            stackTrace: stackTrace,
          );
          rethrow;
        } finally {
          final elapsed =
              DateTime.now().difference(context.startedAt).inMilliseconds;
          context.durationMs = elapsed;
          context.moduleResults['总耗时'] = '${elapsed}ms';
          record(
            module: 'refresh',
            operation: 'finish',
            message: '完整刷新结束',
            durationMs: elapsed,
          );
          _lastRefreshContext = context;
        }
      },
      zoneValues: {_contextKey: context},
    );
  }

  void setModuleResult(String module, String result) {
    currentContext?.moduleResults[module] = _sanitize(result);
    record(module: module, operation: 'result', message: result);
  }

  void record({
    CelechronLogLevel level = CelechronLogLevel.info,
    required String module,
    required String operation,
    String? message,
    Uri? requestUri,
    int? statusCode,
    String? contentType,
    String? location,
    int? durationMs,
    bool relogged = false,
    bool retried = false,
    bool cacheUsed = false,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // 所有自由文本和跳转地址都在进入内存、文件前完成脱敏。
    final context = currentContext;
    final fields = <String>[
      DateTime.now().toUtc().toIso8601String(),
      'level=${level.name}',
      'refreshId=${context?.refreshId ?? '-'}',
      'source=${context?.origin.name ?? 'foreground'}',
      'module=${_sanitize(module)}',
      'operation=${_sanitize(operation)}',
      'url=${requestUri == null ? '-' : sanitizeUri(requestUri)}',
      'status=${statusCode ?? '-'}',
      'contentType=${contentType == null ? '-' : _sanitize(contentType)}',
      'location=${location == null ? '-' : sanitizeLocation(location)}',
      'durationMs=${durationMs ?? '-'}',
      'relogged=$relogged',
      'retried=$retried',
      'cacheUsed=$cacheUsed',
      'exceptionType=${error?.runtimeType ?? '-'}',
      'exception=${error == null ? '-' : _sanitize(error.toString())}',
      if (message != null) 'message=${_sanitize(message)}',
      'stack=${stackTrace == null ? '-' : _sanitizeStack(stackTrace)}',
    ];
    final line = fields.join(' | ');
    _memoryLines.add(line);
    if (_memoryLines.length > _maxMemoryLines) {
      _memoryLines.removeRange(0, _memoryLines.length - _maxMemoryLines);
    }
    if (kDebugMode) debugPrint(line);
    _enqueuePersist(line);
  }

  String currentText() => _memoryLines.join('\n');

  Future<String> recentText() async {
    await _fileQueue;
    return _readRecentLines();
  }

  Future<void> copyReadyText(void Function(String text) copy) async {
    await _fileQueue;
    copy(await _readRecentLines());
  }

  Future<String> exportAndShare({
    required String version,
    required String buildNumber,
  }) async {
    await _fileQueue;
    final directory = await _exportDirectory();
    final now = DateTime.now();
    final fileName = 'celechron-test-log-${_fileTimestamp(now)}.txt';
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    final context = latestContext;
    final moduleSummary = context?.moduleResults.entries
            .map((entry) => '${entry.key}：${entry.value}')
            .join('\n') ??
        '<当前上下文无模块摘要>';
    final header = [
      'Celechron 诊断日志',
      '版本：$version',
      '构建号：$buildNumber',
      '平台：${Platform.operatingSystem}',
      '系统版本：${_sanitize(Platform.operatingSystemVersion)}',
      '导出时间：${now.toUtc().toIso8601String()}',
      'refreshId：${context?.refreshId ?? '-'}',
      '来源：${context?.origin.name ?? 'foreground'}',
      '模块结果：',
      moduleSummary,
      '',
      '日志：',
    ].join('\n');
    final logs = await _readRecentLines();
    await file.writeAsString(
      '$header\n$logs\n',
      encoding: utf8,
      flush: true,
    );
    await _pruneExports(directory);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/plain')],
        text: 'Celechron 测试日志：$fileName',
      ),
    );
    return fileName;
  }

  Future<void> clear() async {
    _memoryLines.clear();
    await _fileQueue;
    final file = await _bufferFile();
    if (await file.exists()) {
      await file.writeAsString('', encoding: utf8, flush: true);
    }
    final exportDirectory = await _exportDirectory();
    await for (final entity in exportDirectory.list()) {
      if (entity is File &&
          entity.path.contains('celechron-test-log-') &&
          entity.path.endsWith('.txt')) {
        await entity.delete();
      }
    }
  }

  void _enqueuePersist(String line) {
    // 写入链保证日志顺序；单次失败被吸收，不能反向影响业务刷新。
    _fileQueue = _fileQueue.then((_) async {
      final file = await _bufferFile();
      await file.writeAsString(
        '$line\n',
        mode: FileMode.append,
        encoding: utf8,
        flush: false,
      );
      if (await file.length() > 2 * 1024 * 1024) {
        final recent = await _readRecentLines(file: file);
        await file.writeAsString(
          recent.isEmpty ? '' : '$recent\n',
          encoding: utf8,
          flush: true,
        );
      }
    }).catchError((Object error, StackTrace stackTrace) {
      if (kDebugMode) {
        debugPrint('诊断日志持久化失败：$error\n$stackTrace');
      }
    });
  }

  Future<File> _bufferFile() async {
    final logDirectory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'celechron_diagnostic_logs',
    );
    await logDirectory.create(recursive: true);
    return File(
        '${logDirectory.path}${Platform.pathSeparator}$_bufferFileName');
  }

  Future<Directory> _exportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDirectory =
        Directory('${directory.path}${Platform.pathSeparator}CelechronLogs');
    await exportDirectory.create(recursive: true);
    return exportDirectory;
  }

  Future<String> _readRecentLines({File? file}) async {
    final target = file ?? await _bufferFile();
    if (!await target.exists()) return currentText();
    final lines = await target.readAsLines(encoding: utf8);
    final start =
        lines.length > _maxMemoryLines ? lines.length - _maxMemoryLines : 0;
    return lines.sublist(start).join('\n');
  }

  Future<void> _pruneExports(Directory directory) async {
    final files = await directory
        .list()
        .where((entity) =>
            entity is File &&
            entity.path.contains('celechron-test-log-') &&
            entity.path.endsWith('.txt'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final file in files.skip(_maxExportFiles)) {
      await file.delete();
    }
  }

  static String sanitizeUri(Uri uri) {
    // 只保留定位接口所需的 scheme/host/path，查询参数可能含 ticket 或账号。
    final path = uri.path.isEmpty ? '/' : uri.path;
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path,
    ).toString();
  }

  static String sanitizeLocation(String location) {
    final uri = Uri.tryParse(location);
    return uri == null ? '<无效 Location>' : sanitizeUri(uri);
  }

  @visibleForTesting
  static String sanitizeForDiagnostic(String value) => _sanitize(value);

  static String _sanitizeStack(StackTrace stackTrace) {
    return _sanitize(stackTrace.toString())
        .replaceAll('\r\n', r'\n')
        .replaceAll('\n', r'\n');
  }

  static String _sanitize(String value) {
    // 规则覆盖常见凭据名、URL 查询串和连续账号数字；日志调用方仍应避免原文。
    var result = value;
    result = result.replaceAllMapped(
      RegExp(
        r'(authorization|proxy-authorization|cookie|set-cookie)'
        r'\s*[:=]\s*[^\r\n|]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=<已隐藏>',
    );
    result = result.replaceAllMapped(
      RegExp(
        r'(password|passwd|token|ticket|code|session|'
        r'iplanetdirectorypro|jsessionid|synjones-auth)'
        r'\s*[:=]\s*[^;,\s|]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=<已隐藏>',
    );
    result = result.replaceAllMapped(
      RegExp(r'https?://[^\s|]+'),
      (match) {
        final uri = Uri.tryParse(match.group(0) ?? '');
        return uri == null ? '<已隐藏 URL>' : sanitizeUri(uri);
      },
    );
    result = result.replaceAll(
      RegExp(r'(?<!\d)\d{8,12}(?!\d)'),
      '<账号已隐藏>',
    );
    return result.replaceAll('\r', ' ').replaceAll('\n', r'\n');
  }

  static String _fileTimestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}-'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}
