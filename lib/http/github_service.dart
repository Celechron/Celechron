import 'dart:convert';
import 'dart:io';

import 'package:celechron/http/zjuServices/exceptions.dart';
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
  ];

  Future<Tuple<Exception?, List<String>>> getContributors(
      HttpClient httpClient) async {
    try {
      var request = await httpClient
          .getUrl(Uri.parse(
              'https://api.github.com/repos/Celechron/Celechron/contributors'))
          .timeout(const Duration(seconds: 10),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));

      request.headers.add('Accept', 'application/vnd.github+json');
      request.headers.add('X-GitHub-Api-Version', '2022-11-28');

      var response = await request.close().timeout(const Duration(seconds: 10),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));

      if (response.statusCode == 200) {
        var jsonString = await response.transform(utf8.decoder).join();
        var data = jsonDecode(jsonString) as List<dynamic>;
        var logins = data.map((item) => item['login'] as String).toList();

        // 如果抓取到的列表为空，返回默认作者名单
        if (logins.isEmpty) {
          return Tuple(null, defaultContributors);
        }

        return Tuple(null, logins);
      } else {
        // 请求失败时返回默认作者名单
        return Tuple(
            ExceptionWithMessage("获取contributors失败: ${response.statusCode}"),
            defaultContributors);
      }
    } catch (e) {
      // 网络错误或其他异常时返回默认作者名单
      var exception =
          e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception;
      return Tuple(exception, defaultContributors);
    }
  }
}
