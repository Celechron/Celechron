import 'dart:convert';
import 'dart:io';

class TimeConfigService {

  static Future<String?> getConfig(
      HttpClient httpClient, String semesterId) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    request = await httpClient.getUrl(Uri.parse(
        'https://open-mobile-timeconf-1312007296.cos.ap-shanghai.myqcloud.com/$semesterId.json'));
    response = await request.close();

    if (response.statusCode == 200) {
      return await response.transform(utf8.decoder).join();
    } else {
      return null;
    }
  }
}
