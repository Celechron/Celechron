import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class DiagnosticLogPage extends StatefulWidget {
  final String version;
  final String buildNumber;

  const DiagnosticLogPage({
    required this.version,
    this.buildNumber = '1',
    super.key,
  });

  @override
  State<DiagnosticLogPage> createState() => _DiagnosticLogPageState();
}

class _DiagnosticLogPageState extends State<DiagnosticLogPage> {
  String _logText = '正在读取日志…';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final text = await DiagnosticLogService.instance.recentText();
    if (!mounted) return;
    setState(() {
      _logText = text.isEmpty ? '暂无诊断日志。执行一次刷新后再试。' : text;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _logText));
    if (mounted) await _showMessage('已复制', '当前诊断日志已复制到剪贴板。');
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final fileName = await DiagnosticLogService.instance.exportAndShare(
        version: widget.version,
        buildNumber: widget.buildNumber,
      );
      if (mounted) await _showMessage('导出成功', '已生成 $fileName');
    } on Object catch (error, stackTrace) {
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.error,
        module: '诊断日志',
        operation: 'export',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) await _showMessage('导出失败', '无法导出日志：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    await DiagnosticLogService.instance.clear();
    await _reload();
    if (mounted) await _showMessage('已清空', '测试日志已清空。');
  }

  Future<void> _showMessage(String title, String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('诊断与测试'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('测试日志'),
              footer: const Text(
                '日志最多保留 2000 行和最近 10 个导出文件；'
                '账号、Cookie、密码、ticket 与 token 会自动脱敏。',
              ),
              children: [
                CupertinoListTile(
                  title: const Text('复制当前日志'),
                  onTap: _copy,
                ),
                CupertinoListTile(
                  title: Text(_busy ? '正在导出…' : '导出并分享 TXT'),
                  onTap: _busy ? null : _export,
                ),
                CupertinoListTile(
                  title: const Text(
                    '清空测试日志',
                    style: TextStyle(color: CupertinoColors.systemRed),
                  ),
                  onTap: _clear,
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondarySystemGroupedBackground,
                  context,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _logText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
