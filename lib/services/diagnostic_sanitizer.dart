String sanitizeDiagnosticText(String value) {
  var result = value;
  result = result.replaceAllMapped(
    RegExp(
      r'("(?:name|realName|studentName|xm|xh|studentId|account|cardAccount|'
      r'balance|score|grade|courseName|examName)"\s*:\s*)'
      r'("(?:\\.|[^"])*"|[-+]?\d+(?:\.\d+)?|true|false|null)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}"<已隐藏>"',
  );
  result = result.replaceAllMapped(
    RegExp(
      r'((?:姓名|学号|校园卡(?:账号|账户)?|余额|成绩|分数|课程(?:名称)?|'
      r'考试(?:名称)?|realName|studentName|studentId|cardAccount|balance|'
      r'score|grade|courseName|examName)\s*[:=：]\s*)'
      r'[^,;；|\r\n}\]]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}<已隐藏>',
  );
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
      return uri == null ? '<已隐藏 URL>' : sanitizeDiagnosticUri(uri);
    },
  );
  result = result.replaceAll(
    RegExp(r'(?<!\d)\d{8,12}(?!\d)'),
    '<账号已隐藏>',
  );
  return result.replaceAll('\r', ' ').replaceAll('\n', r'\n');
}

String sanitizeDiagnosticUri(Uri uri) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
  ).toString();
}

String sanitizeDiagnosticLocation(String location) {
  final uri = Uri.tryParse(location);
  return uri == null ? '<无效 Location>' : sanitizeDiagnosticUri(uri);
}
