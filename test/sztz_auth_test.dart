import 'dart:convert';

import 'package:celechron/http/zjuServices/sztz.dart';
import 'package:celechron/http/zjuServices/zjuam.dart';
import 'package:flutter_test/flutter_test.dart';

String ctxResponse(Map<String, dynamic> context) => jsonEncode({
      'success': true,
      'code': 0,
      'data': base64.encode(utf8.encode(jsonEncode(context))),
    });

void main() {
  test('uses the exact encoded SZTZ CAS service URL', () {
    final uri = ZjuAm.buildServiceLoginUri(
      Uri.parse('https://sztz.zju.edu.cn/dekt/'),
    );
    expect(
      uri.toString(),
      'https://zjuam.zju.edu.cn/cas/login?'
      'service=https%3A%2F%2Fsztz.zju.edu.cn%2Fdekt%2F',
    );
  });

  group('Sztz ctx authentication', () {
    test('accepts a non-anonymous user', () {
      final response = ctxResponse({
        'anonymous': false,
        'userId': 'fictional-user',
        'roles': ['STUDENT_ROLE'],
      });
      expect(Sztz.isAuthenticatedCtxResponse(response), isTrue);
    });

    test('rejects anonymous flag, anonymous userId and anonymous role', () {
      expect(
        Sztz.isAuthenticatedCtxResponse(ctxResponse({
          'anonymous': true,
          'userId': 'fictional-user',
          'roles': ['STUDENT_ROLE'],
        })),
        isFalse,
      );
      expect(
        Sztz.isAuthenticatedCtxResponse(ctxResponse({
          'anonymous': false,
          'userId': 'ANONYMOUS',
          'roles': ['STUDENT_ROLE'],
        })),
        isFalse,
      );
      expect(
        Sztz.isAuthenticatedCtxResponse(ctxResponse({
          'anonymous': false,
          'userId': 'fictional-user',
          'roles': ['STUDENT_ROLE', 'ANONYMOUS_USER_ROLE'],
        })),
        isFalse,
      );
    });

    test('rejects invalid top-level result and invalid Base64 data', () {
      expect(
        Sztz.isAuthenticatedCtxResponse(
          jsonEncode({'success': false, 'code': 0, 'data': ''}),
        ),
        isFalse,
      );
      expect(
        Sztz.isAuthenticatedCtxResponse(
          jsonEncode({'success': true, 'code': 0, 'data': '%%%'}),
        ),
        isFalse,
      );
    });
  });

  test('SESSION /dekt path matches ctx and practice but not similar prefix',
      () {
    expect(Sztz.cookiePathMatches('/dekt', '/dekt/ctx'), isTrue);
    expect(
      Sztz.cookiePathMatches('/dekt', '/dekt/student/home/getSqjl'),
      isTrue,
    );
    expect(Sztz.cookiePathMatches('/dekt', '/dektual/ctx'), isFalse);
    expect(Sztz.cookiePathMatches('/dekt', '/other'), isFalse);
  });
}
