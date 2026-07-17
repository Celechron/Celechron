import 'dart:io';

import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/http/zjuServices/response_utils.dart';
import 'package:celechron/utils/tuple.dart';

class GitHubService {
  // 默认作者名单
  static const List<String> defaultContributors = [
    'nosig',
    'iotang',
    'cxz66666',
    'Azuk 443',
    'FoggyDawn',
    'poormonitor',
    'heddxh',
    'ChenyuHeee',
  ];

  Future<Tuple<Exception?, List<String>>> getContributors(
      HttpClient httpClient) async {
    final uri = Uri.parse(
        'https://api.github.com/repos/Celechron/Celechron/contributors');
    try {
      var request = await httpClient.getUrl(uri).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw requestTimeout());

      request.headers.add('Accept', 'application/vnd.github+json');
      request.headers.add('X-GitHub-Api-Version', '2022-11-28');
      request.followRedirects = false;

      var response = await request.close().timeout(const Duration(seconds: 10),
          onTimeout: () => throw requestTimeout());

      final jsonString = await readResponseText(
        response,
        context: 'GitHub contributors 接口',
        expectJson: true,
        requestUri: uri,
      );
      final data = decodeJsonList(jsonString,
          context: 'GitHub contributors 接口；HTTP ${response.statusCode}');
      final logins = data
          .map(asStringMap)
          .whereType<Map<String, dynamic>>()
          .map((item) => asString(item['login']))
          .whereType<String>()
          .toList();

      // 如果抓取到的列表为空，返回默认作者名单
      if (logins.isEmpty) {
        return Tuple(null, defaultContributors);
      }

      return Tuple(null, logins);
    } on Object catch (error, stackTrace) {
      // 网络错误或其他异常时返回默认作者名单
      final exception = exceptionFrom(
        error,
        context: 'GitHub contributors 接口',
        requestUri: uri,
        stackTrace: stackTrace,
      );
      return Tuple(exception, defaultContributors);
    }
  }
}
