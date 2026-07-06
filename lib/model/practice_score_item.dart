import 'package:celechron/utils/json_utils.dart';

/// 实践分来源；明细平台与仅含汇总的教务网来源必须明确区分。
enum PracticeDataSource {
  sztzLive,
  sztzCache,
  zdbkLive,
  zdbkCache,
  unavailable;

  String get label => switch (this) {
        PracticeDataSource.sztzLive => '素质拓展平台实时数据',
        PracticeDataSource.sztzCache => '素质拓展平台缓存',
        PracticeDataSource.zdbkLive => '教务网旧实践分实时汇总',
        PracticeDataSource.zdbkCache => '教务网旧实践分缓存',
        PracticeDataSource.unavailable => '当前不可用',
      };

  static PracticeDataSource fromJson(Object? value) {
    final name = asString(value);
    return PracticeDataSource.values.firstWhere(
      (source) => source.name == name,
      orElse: () => PracticeDataSource.unavailable,
    );
  }
}

/// 外层记点汇总来源；与 getSqjl 的项目明细来源分开记录。
enum PracticeSummarySource {
  networkMyInfo,
  cachedMyInfo,
  calculatedFromSqjl,
  legacyPersisted,
  unavailable;

  String get label => switch (this) {
        PracticeSummarySource.networkMyInfo => '素拓 getMyInfo 实时汇总',
        PracticeSummarySource.cachedMyInfo => '素拓 getMyInfo 缓存汇总',
        PracticeSummarySource.calculatedFromSqjl => '素拓项目记录计算',
        PracticeSummarySource.legacyPersisted => '旧版本地汇总',
        PracticeSummarySource.unavailable => '当前不可用',
      };

  static PracticeSummarySource fromJson(Object? value) {
    final name = asString(value);
    return PracticeSummarySource.values.firstWhere(
      (source) => source.name == name,
      orElse: () => PracticeSummarySource.unavailable,
    );
  }
}

/// 素拓响应的隐私最小化模型，仅保留展示和汇总所需字段。
class PracticeScoreItem {
  final int id;
  final int categoryId;
  final String categoryName;
  final String projectName;
  final String projectType;
  final String qualityType;
  final double score;
  final int? statusValue;
  final String statusLabel;
  final bool approved;
  final bool deleted;
  final String? role;
  final String? remark;
  final DateTime? activityStart;
  final DateTime? activityEnd;
  final DateTime? updatedAt;

  const PracticeScoreItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.projectName,
    required this.projectType,
    required this.qualityType,
    required this.score,
    required this.statusValue,
    required this.statusLabel,
    required this.approved,
    required this.deleted,
    required this.role,
    required this.remark,
    required this.activityStart,
    required this.activityEnd,
    required this.updatedAt,
  });

  /// 只有审核通过、未删除且分值有效的二/三/四课堂记录计入汇总。
  bool get countsTowardTotal =>
      approved &&
      !deleted &&
      categoryId >= 1 &&
      categoryId <= 3 &&
      score.isFinite &&
      score >= 0;

  factory PracticeScoreItem.fromSztzJson(Map<String, dynamic> json) {
    final id = asInt(json['id']);
    if (id == null) {
      throw const FormatException('实践记录缺少有效 ID');
    }

    // jd 是当前学生实际获得记点；xm 下的分数字段属于项目范围，不参与计算。
    final project = asStringMap(json['xm']) ?? const <String, dynamic>{};
    final category = asStringMap(project['xmfl']) ?? const <String, dynamic>{};
    final projectType =
        asStringMap(project['xmlb']) ?? const <String, dynamic>{};
    final qualityType =
        asStringMap(project['xmlx']) ?? const <String, dynamic>{};
    final status = asStringMap(json['cyrshzt']) ?? const <String, dynamic>{};
    final currentState =
        asStringMap(json['currentState']) ?? const <String, dynamic>{};

    // 优先使用分类 ID；中文名称只为旧响应缺少 ID 时提供兼容映射。
    var categoryName = _text(category['mc']) ?? '未分类课堂';
    var categoryId = asInt(category['id']) ?? 0;
    if (categoryId == 0) {
      categoryId = switch (categoryName) {
        '第二课堂' => 1,
        '第三课堂' => 2,
        '第四课堂' => 3,
        _ => 0,
      };
    }
    if (categoryName == '未分类课堂') {
      categoryName = switch (categoryId) {
        1 => '第二课堂',
        2 => '第三课堂',
        3 => '第四课堂',
        _ => categoryName,
      };
    }

    final statusValue = asInt(status['value']);
    final statusLabel =
        _text(status['label']) ?? _text(currentState['name']) ?? '状态未知';
    final score = asDouble(json['jd']) ?? -1;

    return PracticeScoreItem(
      id: id,
      categoryId: categoryId,
      categoryName: categoryName,
      projectName: _text(project['mc']) ?? '未命名项目',
      projectType: _text(projectType['mc']) ?? '未填写',
      qualityType: _text(qualityType['mc']) ?? '未填写',
      score: score,
      statusValue: statusValue,
      statusLabel: statusLabel,
      approved: statusValue == 5 || statusLabel == '审核通过',
      deleted: asBool(json['sfsc']) ?? false,
      role: _text(json['hdjjygrcdgz']),
      remark: _text(json['qksm']),
      activityStart: _localDate(json['hdsj']),
      activityEnd: _localDate(json['hdjssj']),
      updatedAt: _localDate(json['gxsj']),
    );
  }

  factory PracticeScoreItem.fromJson(Map<String, dynamic> json) {
    final id = asInt(json['id']);
    if (id == null) {
      throw const FormatException('本地实践记录缺少有效 ID');
    }
    final statusLabel = _text(json['statusLabel']) ?? '状态未知';
    final statusValue = asInt(json['statusValue']);
    return PracticeScoreItem(
      id: id,
      categoryId: asInt(json['categoryId']) ?? 0,
      categoryName: _text(json['categoryName']) ?? '未分类课堂',
      projectName: _text(json['projectName']) ?? '未命名项目',
      projectType: _text(json['projectType']) ?? '未填写',
      qualityType: _text(json['qualityType']) ?? '未填写',
      score: asDouble(json['score']) ?? -1,
      statusValue: statusValue,
      statusLabel: statusLabel,
      approved: asBool(json['approved']) ??
          (statusValue == 5 || statusLabel == '审核通过'),
      deleted: asBool(json['deleted']) ?? false,
      role: _text(json['role']),
      remark: _text(json['remark']),
      activityStart: _localDate(json['activityStart']),
      activityEnd: _localDate(json['activityEnd']),
      updatedAt: _localDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'projectName': projectName,
        'projectType': projectType,
        'qualityType': qualityType,
        'score': score,
        'statusValue': statusValue,
        'statusLabel': statusLabel,
        'approved': approved,
        'deleted': deleted,
        'role': role,
        'remark': remark,
        'activityStart': activityStart?.toIso8601String(),
        'activityEnd': activityEnd?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  static List<PracticeScoreItem> parseSztzItems(
    Iterable<dynamic> values, {
    void Function(int index, Object error, StackTrace stackTrace)? onError,
  }) {
    // 外层记录 ID 是去重依据；单条损坏不应使整批实践数据失效。
    final byId = <int, PracticeScoreItem>{};
    var index = 0;
    for (final value in values) {
      try {
        final map = asStringMap(value);
        if (map == null) {
          throw const FormatException('实践记录不是对象');
        }
        final item = PracticeScoreItem.fromSztzJson(map);
        if (!item.deleted) byId.putIfAbsent(item.id, () => item);
      } on Object catch (error, stackTrace) {
        onError?.call(index, error, stackTrace);
      }
      index++;
    }
    return byId.values.toList(growable: false);
  }

  static Map<int, double> approvedTotals(Iterable<PracticeScoreItem> items) {
    final totals = <int, double>{1: 0, 2: 0, 3: 0};
    for (final item in items) {
      if (item.countsTowardTotal) {
        totals[item.categoryId] = (totals[item.categoryId] ?? 0) + item.score;
      }
    }
    return totals;
  }

  static String? _text(Object? value) {
    final text = asString(value)?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _localDate(Object? value) {
    final parsed = asDateTime(value);
    return parsed?.toLocal();
  }
}

/// getMyInfo 给出的正式汇总；Jf 表示“记点”。
class PracticeScoreSummary {
  final double dektJf;
  final double dsktJf;
  final double dsiktJf;
  final bool? myPassed;
  final bool? lyPassed;
  final PracticeSummarySource source;
  final DateTime updatedAt;
  final bool stale;

  const PracticeScoreSummary({
    required this.dektJf,
    required this.dsktJf,
    required this.dsiktJf,
    required this.myPassed,
    required this.lyPassed,
    required this.source,
    required this.updatedAt,
    required this.stale,
  });

  /// 总记点只使用明确白名单。
  double get totalJf => dektJf + dsktJf + dsiktJf;

  /// 沿用项目已有分类：dekt/dskt/dsikt 分别对应第二/三/四课堂。
  double totalFor(int categoryId) => switch (categoryId) {
        1 => dektJf,
        2 => dsktJf,
        3 => dsiktJf,
        _ => 0,
      };

  factory PracticeScoreSummary.fromMyInfoJson(
    Map<String, dynamic> json, {
    required PracticeSummarySource source,
    required DateTime updatedAt,
  }) {
    const jfFields = ['dektJf', 'dsktJf', 'dsiktJf'];
    if (!jfFields.any(json.containsKey)) {
      throw const FormatException('getMyInfo 缺少全部必需记点字段');
    }
    return PracticeScoreSummary(
      dektJf: _parseJf(json, 'dektJf'),
      dsktJf: _parseJf(json, 'dsktJf'),
      dsiktJf: _parseJf(json, 'dsiktJf'),
      myPassed: _parsePassed(json['myTg'], fieldName: 'myTg'),
      lyPassed: _parsePassed(json['lyTg'], fieldName: 'lyTg'),
      source: source,
      updatedAt: updatedAt,
      stale: source != PracticeSummarySource.networkMyInfo,
    );
  }

  factory PracticeScoreSummary.fromCacheJson(
    Map<String, dynamic> json, {
    required DateTime updatedAt,
  }) {
    const requiredFields = [
      'dektJf',
      'dsktJf',
      'dsiktJf',
      'myPassed',
      'lyPassed',
    ];
    if (!requiredFields.every(json.containsKey)) {
      throw const FormatException('getMyInfo 汇总缓存字段不完整');
    }
    return PracticeScoreSummary(
      dektJf: _parseJf(json, 'dektJf'),
      dsktJf: _parseJf(json, 'dsktJf'),
      dsiktJf: _parseJf(json, 'dsiktJf'),
      myPassed: _parsePassed(json['myPassed'], fieldName: 'myPassed'),
      lyPassed: _parsePassed(json['lyPassed'], fieldName: 'lyPassed'),
      source: PracticeSummarySource.cachedMyInfo,
      updatedAt: updatedAt,
      stale: true,
    );
  }

  factory PracticeScoreSummary.calculatedFromSqjl(
    Iterable<PracticeScoreItem> items, {
    required DateTime updatedAt,
    required bool stale,
  }) {
    final totals = PracticeScoreItem.approvedTotals(items);
    return PracticeScoreSummary(
      dektJf: totals[1] ?? 0,
      dsktJf: totals[2] ?? 0,
      dsiktJf: totals[3] ?? 0,
      myPassed: null,
      lyPassed: null,
      source: PracticeSummarySource.calculatedFromSqjl,
      updatedAt: updatedAt,
      stale: stale,
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'dektJf': dektJf,
        'dsktJf': dsktJf,
        'dsiktJf': dsiktJf,
        'myPassed': myPassed,
        'lyPassed': lyPassed,
      };

  static double _parseJf(Map<String, dynamic> json, String fieldName) {
    if (!json.containsKey(fieldName)) return 0;
    final value = json[fieldName];
    if (value == null || (value is String && value.trim().isEmpty)) return 0;
    final parsed = asDouble(value);
    if (parsed == null || !parsed.isFinite) {
      throw FormatException('记点字段 $fieldName 无法转换为有限数值');
    }
    return parsed;
  }

  static bool? _parsePassed(
    Object? value, {
    required String fieldName,
  }) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
      throw FormatException('通过状态字段 $fieldName 数值无效');
    }

    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) return null;
    if (const {
      'true',
      '1',
      '1.0',
      'yes',
      'y',
      '是',
      '通过',
      '已通过',
      '达标',
      '合格',
    }.contains(text)) {
      return true;
    }
    if (const {
      'false',
      '0',
      '0.0',
      'no',
      'n',
      '否',
      '未通过',
      '不通过',
      '未达标',
      '不达标',
      '不合格',
    }.contains(text)) {
      return false;
    }
    throw FormatException('通过状态字段 $fieldName 无法识别');
  }
}

/// 一次实践数据读取结果；getSqjl 明细和 getMyInfo 汇总互不覆盖。
class PracticeScoreSnapshot {
  final List<PracticeScoreItem> items;
  final PracticeDataSource source;
  final DateTime? updatedAt;
  final bool detailsAvailable;
  final bool stale;
  final PracticeScoreSummary? summary;
  final Map<int, double> _summaryTotals;
  final String? errorMessage;
  final String? summaryErrorMessage;

  const PracticeScoreSnapshot({
    required this.items,
    required this.source,
    required this.updatedAt,
    required this.detailsAvailable,
    required this.stale,
    this.summary,
    Map<int, double> summaryTotals = const {},
    this.errorMessage,
    this.summaryErrorMessage,
  }) : _summaryTotals = summaryTotals;

  factory PracticeScoreSnapshot.sztz({
    required List<PracticeScoreItem> items,
    required PracticeDataSource source,
    required DateTime updatedAt,
    required bool stale,
    String? errorMessage,
  }) =>
      PracticeScoreSnapshot(
        items: List.unmodifiable(items),
        source: source,
        updatedAt: updatedAt,
        detailsAvailable: true,
        stale: stale,
        errorMessage: errorMessage,
      );

  factory PracticeScoreSnapshot.resolve({
    required PracticeScoreSnapshot details,
    PracticeScoreSummary? myInfoSummary,
    String? summaryErrorMessage,
  }) {
    // 三级顺序：getMyInfo 网络/缓存结果优先，均不可用才由 getSqjl 明细计算。
    final resolvedSummary = myInfoSummary ??
        (details.detailsAvailable
            ? PracticeScoreSummary.calculatedFromSqjl(
                details.items,
                updatedAt: details.updatedAt ?? DateTime.now(),
                stale: details.stale,
              )
            : null);
    return PracticeScoreSnapshot(
      items: details.items,
      source: details.source,
      updatedAt: details.updatedAt,
      detailsAvailable: details.detailsAvailable,
      stale: details.stale,
      summary: resolvedSummary,
      summaryTotals: details._summaryTotals,
      errorMessage: details.errorMessage,
      summaryErrorMessage: summaryErrorMessage,
    );
  }

  factory PracticeScoreSnapshot.zdbk({
    required Map<String, double> totals,
    required PracticeDataSource source,
    required DateTime updatedAt,
    required bool stale,
    String? errorMessage,
  }) =>
      PracticeScoreSnapshot(
        items: const [],
        source: source,
        updatedAt: updatedAt,
        detailsAvailable: false,
        stale: stale,
        summaryTotals: {
          1: totals['pt2'] ?? 0,
          2: totals['pt3'] ?? 0,
          3: totals['pt4'] ?? 0,
        },
        errorMessage: errorMessage,
      );

  static const unavailable = PracticeScoreSnapshot(
    items: [],
    source: PracticeDataSource.unavailable,
    updatedAt: null,
    detailsAvailable: false,
    stale: true,
  );

  Map<int, double> get totals => detailsAvailable
      ? PracticeScoreItem.approvedTotals(items)
      : Map.unmodifiable(_summaryTotals);

  PracticeSummarySource get summarySource =>
      summary?.source ??
      (source == PracticeDataSource.zdbkLive ||
              source == PracticeDataSource.zdbkCache
          ? PracticeSummarySource.legacyPersisted
          : PracticeSummarySource.unavailable);

  double totalFor(int categoryId) =>
      summary?.totalFor(categoryId) ?? totals[categoryId] ?? 0;

  bool get hasAnyData => detailsAvailable || summary != null;
}
