import 'package:celechron/http/zjuServices/courses.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Courses 登录识别 HTTP 200 meta-refresh 中间跳转', () {
    final source = Uri.parse('https://identity.zju.edu.cn/auth/continue');
    const body = '<html><head>'
        '<meta http-equiv="refresh" '
        'content="0;URL=https://courses.zju.edu.cn/">'
        '</head></html>';

    expect(
      coursesMetaRefreshTarget(body, source),
      Uri.parse('https://courses.zju.edu.cn/'),
    );
  });

  test('Courses 登录不跟随非浙大域名的 meta-refresh', () {
    final source = Uri.parse('https://identity.zju.edu.cn/auth/continue');
    const body = '<meta http-equiv="refresh" '
        'content="0;URL=https://example.com/phishing">';

    expect(coursesMetaRefreshTarget(body, source), isNull);
  });
}
