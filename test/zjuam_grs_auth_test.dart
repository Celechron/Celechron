import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:celechron/http/zjuServices/grs_new.dart';
import 'package:celechron/http/zjuServices/zjuam.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _cacheKeyPrefix = 'zju_sso_cookie_';

void _seedCachedCookie(String username, String value) {
  FlutterSecureStorage.setMockInitialValues({
    '$_cacheKeyPrefix$username': jsonEncode({
      'value': value,
      'savedAt':
          DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String(),
    }),
  });
}

Uri _validateUri(String ticket) => Uri.https(
      'yjsy.zju.edu.cn',
      '/dataapi/sys/cas/client/validateLogin',
      {
        'ticket': ticket,
        'service': ZjuAm.graduateServiceUri.toString(),
      },
    );

_ScriptedResponse _ticketResponse(String ticket) => _ScriptedResponse(
      statusCode: HttpStatus.found,
      headers: {
        HttpHeaders.locationHeader:
            '${ZjuAm.graduateServiceUri}?ticket=$ticket',
      },
    );

_ScriptedResponse _tokenResponse(String token) => _ScriptedResponse(
      statusCode: HttpStatus.ok,
      headers: {HttpHeaders.contentTypeHeader: 'application/json'},
      body: jsonEncode({
        'success': true,
        'result': {'token': token},
      }),
    );

final _loginUri = Uri.parse('https://zjuam.zju.edu.cn/cas/login');
final _pubKeyUri = Uri.parse('https://zjuam.zju.edu.cn/cas/v2/getPubKey');

void _expectPasswordLogin(
  _ScriptedHttpClient client, {
  required String cookieValue,
}) {
  final modulus = List<String>.filled(128, 'f').join();
  client
    ..expectGet(
      _loginUri,
      _ScriptedResponse(
        statusCode: HttpStatus.ok,
        headers: {HttpHeaders.contentTypeHeader: 'text/html'},
        cookies: [Cookie('JSESSIONID', 'form-session')],
        body: '<input name="execution" value="execution-1">',
      ),
    )
    ..expectGet(
      _pubKeyUri,
      _ScriptedResponse(
        statusCode: HttpStatus.ok,
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        body: jsonEncode({'modulus': modulus, 'exponent': '1'}),
      ),
    )
    ..expectPost(
      _loginUri,
      _ScriptedResponse(
        statusCode: HttpStatus.found,
        cookies: [Cookie('iPlanetDirectoryPro', cookieValue)],
      ),
    );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('旧版持久化 SSO Cookie 被忽略并删除，启动使用密码新建会话', () async {
    const username = 'auth-test-ignore-legacy-cache';
    _seedCachedCookie(username, 'stale-persisted-cookie');

    final client = _ScriptedHttpClient();
    _expectPasswordLogin(client, cookieValue: 'fresh-process-cookie');

    final cookie = await ZjuAm.getSsoCookie(
      client,
      username,
      'test-password',
    );

    expect(cookie?.value, 'fresh-process-cookie');
    expect(
      client.requests.where(
          (request) => request.method == 'POST' && request.uri == _loginUri),
      hasLength(1),
    );
    expect(
      await const FlutterSecureStorage().read(key: '$_cacheKeyPrefix$username'),
      isNull,
    );
    expect(client.pendingDescriptions, isEmpty);
  });

  test('同一 HttpClient 的并发认证共享一次密码登录', () async {
    const username = 'auth-test-same-client-single-flight';
    final requestStarted = Completer<void>();
    final releaseResponse = Completer<void>();
    final modulus = List<String>.filled(128, 'f').join();
    final client = _ScriptedHttpClient()
      ..expectGetAsync(_loginUri, (_) async {
        requestStarted.complete();
        await releaseResponse.future;
        return _ScriptedResponse(
          statusCode: HttpStatus.ok,
          headers: {HttpHeaders.contentTypeHeader: 'text/html'},
          cookies: [Cookie('JSESSIONID', 'form-session')],
          body: '<input name="execution" value="execution-1">',
        );
      })
      ..expectGet(
        _pubKeyUri,
        _ScriptedResponse(
          statusCode: HttpStatus.ok,
          headers: {HttpHeaders.contentTypeHeader: 'application/json'},
          body: jsonEncode({'modulus': modulus, 'exponent': '1'}),
        ),
      )
      ..expectPost(
        _loginUri,
        _ScriptedResponse(
          statusCode: HttpStatus.found,
          cookies: [Cookie('iPlanetDirectoryPro', 'shared-cookie')],
        ),
      );

    final first = ZjuAm.getSsoCookie(client, username, 'test-password');
    await requestStarted.future;
    final second = ZjuAm.getSsoCookie(client, username, 'test-password');
    releaseResponse.complete();

    final cookies = await Future.wait([first, second]);
    expect(cookies[0], isNotNull);
    expect(identical(cookies[0], cookies[1]), isTrue);
    expect(
      client.requests.where(
          (request) => request.method == 'POST' && request.uri == _loginUri),
      hasLength(1),
    );
    expect(client.pendingDescriptions, isEmpty);
  });

  test('Scholar 与校园卡的不同 HttpClient 不共享 SSO Cookie', () async {
    const username = 'auth-test-client-scoped';
    final scholarClient = _ScriptedHttpClient();
    final ecardClient = _ScriptedHttpClient();
    _expectPasswordLogin(scholarClient, cookieValue: 'scholar-cookie');
    _expectPasswordLogin(ecardClient, cookieValue: 'ecard-cookie');

    final scholarCookie = await ZjuAm.getSsoCookie(
      scholarClient,
      username,
      'test-password',
    );
    final ecardCookie = await ZjuAm.getSsoCookie(
      ecardClient,
      username,
      'test-password',
    );

    expect(scholarCookie?.value, 'scholar-cookie');
    expect(ecardCookie?.value, 'ecard-cookie');
    expect(identical(scholarCookie, ecardCookie), isFalse);
    expect(scholarClient.pendingDescriptions, isEmpty);
    expect(ecardClient.pendingDescriptions, isEmpty);
  });

  test('同一 HttpClient 短时间内复用刚建立的内存会话', () async {
    const username = 'auth-test-process-reuse';
    final client = _ScriptedHttpClient();
    _expectPasswordLogin(client, cookieValue: 'process-cookie');

    final first = await ZjuAm.getSsoCookie(client, username, 'test-password');
    final second = await ZjuAm.getSsoCookie(client, username, 'test-password');

    expect(first, isNotNull);
    expect(identical(first, second), isTrue);
    expect(client.pendingDescriptions, isEmpty);
  });

  test('清除登录态后同一 HttpClient 必须重新密码登录', () async {
    const username = 'auth-test-clear-process-cookie';
    final client = _ScriptedHttpClient();
    _expectPasswordLogin(client, cookieValue: 'first-cookie');
    _expectPasswordLogin(client, cookieValue: 'second-cookie');

    final first = await ZjuAm.getSsoCookie(client, username, 'test-password');
    await ZjuAm.clearCachedSsoCookie(username);
    final second = await ZjuAm.getSsoCookie(client, username, 'test-password');

    expect(first?.value, 'first-cookie');
    expect(second?.value, 'second-cookie');
    expect(client.pendingDescriptions, isEmpty);
  });

  test('研究生院只在实际登录时申请并立即兑换一张 CAS ticket', () async {
    const username = 'auth-test-graduate-just-in-time-ticket';
    const ticket = 'ST-just-in-time';
    final casUri = ZjuAm.buildServiceLoginUri(ZjuAm.graduateServiceUri);
    final client = _ScriptedHttpClient();
    _expectPasswordLogin(client, cookieValue: 'fresh-cookie');
    client
      ..expectGet(casUri, _ticketResponse(ticket))
      ..expectGet(_validateUri(ticket), _tokenResponse('graduate-token'));

    final cookie = await ZjuAm.getSsoCookie(client, username, 'test-password');
    await GrsNew().login(client, cookie);

    expect(
      client.requests.where((request) => request.uri == casUri),
      hasLength(1),
    );
    expect(client.pendingDescriptions, isEmpty);
  });
}

typedef _ResponseFactory = FutureOr<HttpClientResponse> Function(
  _ScriptedRequest request,
);

class _ExpectedExchange {
  final String method;
  final Uri uri;
  final _ResponseFactory responseFactory;

  _ExpectedExchange(this.method, this.uri, this.responseFactory);

  String get description => '$method $uri';
}

class _ScriptedHttpClient implements HttpClient {
  final Queue<_ExpectedExchange> _pending = Queue<_ExpectedExchange>();
  final List<_ScriptedRequest> requests = <_ScriptedRequest>[];

  List<String> get pendingDescriptions =>
      _pending.map((exchange) => exchange.description).toList(growable: false);

  void expectGet(Uri uri, HttpClientResponse response) {
    expectGetAsync(uri, (_) => response);
  }

  void expectGetAsync(Uri uri, _ResponseFactory responseFactory) {
    _pending.add(_ExpectedExchange('GET', uri, responseFactory));
  }

  void expectPost(Uri uri, HttpClientResponse response) {
    _pending.add(_ExpectedExchange('POST', uri, (_) => response));
  }

  Future<HttpClientRequest> _open(String method, Uri uri) async {
    if (_pending.isEmpty) {
      throw StateError('Unexpected HTTP request: $method $uri');
    }
    final expected = _pending.removeFirst();
    if (expected.method != method || expected.uri != uri) {
      throw StateError(
        'Unexpected HTTP request: $method $uri; expected ${expected.description}',
      );
    }
    final request = _ScriptedRequest(method, uri, expected.responseFactory);
    requests.add(request);
    return request;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _open('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _open('POST', url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected HttpClient call: $invocation');
}

class _ScriptedRequest implements HttpClientRequest {
  @override
  final String method;
  @override
  final Uri uri;
  final _ResponseFactory _responseFactory;
  @override
  final List<Cookie> cookies = <Cookie>[];
  @override
  final _TestHttpHeaders headers = _TestHttpHeaders();
  final List<int> body = <int>[];

  bool _followRedirects = true;
  bool _closed = false;

  _ScriptedRequest(this.method, this.uri, this._responseFactory);

  @override
  bool get followRedirects => _followRedirects;

  @override
  set followRedirects(bool value) => _followRedirects = value;

  @override
  void add(List<int> data) => body.addAll(data);

  @override
  Future<HttpClientResponse> close() async {
    if (_closed) throw StateError('HTTP request closed twice: $method $uri');
    _closed = true;
    return await _responseFactory(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected HttpClientRequest call: $invocation');
}

class _ScriptedResponse extends StreamView<List<int>>
    implements HttpClientResponse {
  @override
  final int statusCode;
  @override
  final HttpHeaders headers;
  @override
  final List<Cookie> cookies;
  final int _bodyLength;

  _ScriptedResponse({
    required this.statusCode,
    Map<String, String> headers = const {},
    List<Cookie> cookies = const [],
    String body = '',
  })  : headers = _TestHttpHeaders(headers),
        cookies = List<Cookie>.from(cookies),
        _bodyLength = utf8.encode(body).length,
        super(Stream<List<int>>.fromIterable([utf8.encode(body)]));

  @override
  int get contentLength => _bodyLength;

  @override
  bool get isRedirect =>
      statusCode == HttpStatus.movedPermanently ||
      statusCode == HttpStatus.found ||
      statusCode == HttpStatus.seeOther ||
      statusCode == HttpStatus.temporaryRedirect ||
      statusCode == HttpStatus.permanentRedirect;

  @override
  String get reasonPhrase => '';

  @override
  bool get persistentConnection => false;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected HttpClientResponse call: $invocation');
}

class _TestHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = <String, List<String>>{};
  ContentType? _contentType;

  _TestHttpHeaders([Map<String, String> initial = const {}]) {
    for (final entry in initial.entries) {
      set(entry.key, entry.value);
    }
  }

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) {
    _contentType = value;
    if (value == null) {
      _values.remove(HttpHeaders.contentTypeHeader);
    } else {
      _values[HttpHeaders.contentTypeHeader] = <String>[value.toString()];
    }
  }

  @override
  List<String>? operator [](String name) {
    final values = _values[name.toLowerCase()];
    return values == null ? null : List<String>.from(values);
  }

  @override
  String? value(String name) {
    final values = _values[name.toLowerCase()];
    if (values == null || values.isEmpty) return null;
    if (values.length > 1) {
      throw HttpException('More than one value for header $name');
    }
    return values.single;
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    final key = name.toLowerCase();
    final additions = value is Iterable
        ? value.map((item) => item.toString())
        : <String>[value.toString()];
    _values.putIfAbsent(key, () => <String>[]).addAll(additions);
    if (key == HttpHeaders.contentTypeHeader) {
      _contentType = ContentType.parse(_values[key]!.last);
    }
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    final key = name.toLowerCase();
    final values = value is Iterable
        ? value.map((item) => item.toString()).toList()
        : <String>[value.toString()];
    _values[key] = values;
    if (key == HttpHeaders.contentTypeHeader) {
      _contentType = ContentType.parse(values.single);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected HttpHeaders call: $invocation');
}
