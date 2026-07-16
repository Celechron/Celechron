import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:celechron/http/zjuServices/courses.dart';
import 'package:celechron/http/zjuServices/zjuam.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CoursesProbeApp());
}

class CoursesProbeApp extends StatelessWidget {
  const CoursesProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: CoursesProbePage(),
    );
  }
}

class CoursesProbePage extends StatefulWidget {
  const CoursesProbePage({super.key});

  @override
  State<CoursesProbePage> createState() => _CoursesProbePageState();
}

class _CoursesProbePageState extends State<CoursesProbePage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  late HttpClient _httpClient;
  Courses _courses = Courses();

  bool _running = false;
  String _logs = '';

  @override
  void initState() {
    super.initState();
    _resetClient();
  }

  void _resetClient() {
    _httpClient = HttpClient()
      ..userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/122.0.0.0 Safari/537.36';

    _courses = Courses();
  }

  void _log(String text) {
    final line = '[${DateTime.now().toIso8601String()}] $text';

    debugPrint(line);

    if (!mounted) return;
    setState(() {
      _logs += '$line\n';
    });
  }

  Future<void> _runTest({required bool clearSsoCache}) async {
    if (_running) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _log('请先填写学号和密码');
      return;
    }

    setState(() {
      _running = true;
      _logs = '';
    });

    final stopwatch = Stopwatch()..start();

    try {
      _log('========================================');
      _log('开始测试学在浙大爬取链路');
      _log('是否清除 SSO 缓存：$clearSsoCache');

      if (clearSsoCache) {
        await ZjuAm.clearCachedSsoCookie(username);
        _log('已经清除统一身份认证缓存');

        _httpClient.close(force: true);
        _resetClient();
      }

      _log('步骤 1：请求统一身份认证 Cookie');

      final ssoCookie = await ZjuAm.getSsoCookie(
        _httpClient,
        username,
        password,
      );

      if (ssoCookie == null) {
        throw StateError('统一身份认证没有返回 Cookie');
      }

      // 绝对不要输出 Cookie value。
      _log('统一身份认证成功');
      _log('SSO Cookie 名称：${ssoCookie.name}');
      _log('SSO Cookie domain：${ssoCookie.domain ?? "<缺失>"}');
      _log('SSO Cookie path：${ssoCookie.path ?? "<缺失>"}');

      _log('步骤 2：执行 Courses.login');

      final loginWatch = Stopwatch()..start();

      final loginSuccess = await _courses.login(
        _httpClient,
        ssoCookie,
      );

      loginWatch.stop();

      _log('Courses.login 返回值：$loginSuccess');
      _log('Courses.login 耗时：${loginWatch.elapsedMilliseconds} ms');

      _log('步骤 3：第一次请求 /api/todos');

      final firstWatch = Stopwatch()..start();
      final firstResult = await _courses.getTodo(_httpClient);
      firstWatch.stop();

      if (firstResult.item1 == null) {
        _log('第一次作业请求成功');
        _log('作业数量：${firstResult.item2.length}');
      } else {
        _log('第一次作业请求失败');
        _log('错误类型：${firstResult.item1.runtimeType}');
        _log('错误详情：${firstResult.item1}');
      }

      _log('第一次请求耗时：${firstWatch.elapsedMilliseconds} ms');

      _log('步骤 4：再次请求 /api/todos');

      final secondWatch = Stopwatch()..start();
      final secondResult = await _courses.getTodo(_httpClient);
      secondWatch.stop();

      if (secondResult.item1 == null) {
        _log('第二次作业请求成功');
        _log('作业数量：${secondResult.item2.length}');
      } else {
        _log('第二次作业请求失败');
        _log('错误类型：${secondResult.item1.runtimeType}');
        _log('错误详情：${secondResult.item1}');
      }

      _log('第二次请求耗时：${secondWatch.elapsedMilliseconds} ms');
    } catch (error, stackTrace) {
      _log('测试过程抛出异常');
      _log('异常类型：${error.runtimeType}');
      _log('异常信息：$error');
      _log('StackTrace：');
      _log(stackTrace.toString());
    } finally {
      stopwatch.stop();
      _log('总耗时：${stopwatch.elapsedMilliseconds} ms');
      _log('========================================');

      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('学在浙大接口测试'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CupertinoTextField(
              controller: _usernameController,
              placeholder: '学号',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _passwordController,
              placeholder: '密码',
              obscureText: true,
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: _running ? null : () => _runTest(clearSsoCache: false),
              child: const Text('使用现有 SSO 缓存测试'),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              onPressed: _running ? null : () => _runTest(clearSsoCache: true),
              child: const Text('清除缓存后完整登录测试'),
            ),
            const SizedBox(height: 24),
            if (_running) const CupertinoActivityIndicator(),
            const SizedBox(height: 16),
            const Text(
              '测试日志',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                _logs.isEmpty ? '尚未执行测试' : _logs,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _httpClient.close(force: true);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
