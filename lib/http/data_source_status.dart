/// 标记一次读取的真实来源，便于上层区分实时数据与可用但过期的降级结果。
enum DataSourceStatus {
  live,
  cache,
  fallback,
  unavailable,
}

extension DataSourceStatusLabel on DataSourceStatus {
  String get label => switch (this) {
        DataSourceStatus.live => '实时成功',
        DataSourceStatus.cache => '使用缓存',
        DataSourceStatus.fallback => '使用默认配置',
        DataSourceStatus.unavailable => '不可用',
      };

  bool get isDegraded =>
      this == DataSourceStatus.cache || this == DataSourceStatus.fallback;
}
