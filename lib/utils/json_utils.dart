/// 宽容地规范接口和旧缓存中的动态 JSON 类型；不满足目标类型时返回 null。
Map<String, dynamic>? asStringMap(Object? value) {
  if (value is! Map) return null;
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) return null;
    result[key] = entry.value;
  }
  return result;
}

List<dynamic>? asDynamicList(Object? value) =>
    value is List ? List<dynamic>.from(value) : null;

String? asString(Object? value) {
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return null;
}

int? asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

bool? asBool(Object? value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return null;
}

DateTime? asDateTime(Object? value) {
  final text = asString(value)?.trim();
  if (text == null || text.isEmpty) return null;
  if (RegExp(r'^\d{8}$').hasMatch(text)) {
    return DateTime.tryParse(
        '${text.substring(0, 4)}-${text.substring(4, 6)}-${text.substring(6, 8)}');
  }
  return DateTime.tryParse(text);
}
